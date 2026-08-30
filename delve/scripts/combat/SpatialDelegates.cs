using System;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>
/// Wires the engine's static spatial delegates for a combat encounter. The engine ships no
/// defaults: flanking (off-guard) and cover/line-of-sight/line-of-effect must be supplied by the
/// client. Flanking is always real (mirrors <c>BattleSimulator.WireFlankingDelegate</c>); the four
/// <see cref="CoverHelper"/> seams get <see cref="TerrainSpatial"/> on a grid with terrain in it and
/// open stubs on a flat board.
/// </summary>
public static class SpatialDelegates
{
    /// <summary>
    /// Install the spatial delegates for <paramref name="grid"/>.
    ///
    /// <para><b>Why flat boards keep the stubs.</b> The obvious move is to wire
    /// <see cref="TerrainSpatial"/> unconditionally, on the grounds that its terrain branches are all
    /// unreachable on a flat board. They are — but one branch is not about terrain at all: an intervening
    /// LIVING CREATURE grants lesser cover, and on a flat board that branch fires (eye height 3 clears the
    /// interpolated line of 3 exactly). That is a genuine PF2e rule the stubs have been silently skipping,
    /// so switching it on is a real balance change: +1 AC turns hits into misses, which changes damage,
    /// deaths and every downstream roll. It has no business riding along in a milestone about terrain, and
    /// it would desync the ~10 flat-board headless spikes that assert exact combat outcomes.</para>
    ///
    /// <para>So the wiring keys off <see cref="TerrainSpatial.HasSpatialFeatures"/> — any blocking or
    /// cover-granting tile, or any variation in corner heights. <see cref="BattleGrid.CreateFlat"/> boards
    /// have none of that and stay bit-identical; generated layouts get the real thing, creature cover
    /// included. Flat boards can opt in later by giving their grid real tiles, not by a flag.</para>
    /// </summary>
    /// <returns>
    /// A handle that removes exactly the delegates this call installed. Dispose it to unwire; there is
    /// no global unwire, because a second encounter overwrites all five delegates and a stale handle
    /// must not clear the live encounter's wiring. Each release is identity-guarded.
    /// </returns>
    public static IDisposable Wire(BattleGrid grid)
    {
        Func<ICharacter, ICharacter, bool> flanking = IsFlankingAttacker;
        Func<ICharacter, ICharacter, CoverLevel> cover;
        Func<ICharacter, bool> adjacentCover;
        Func<ICharacter, ICharacter, bool> lineOfSight;
        Func<PF2e.Vector2Int, PF2e.Vector2Int, bool> lineOfEffect;

        if (TerrainSpatial.HasSpatialFeatures(grid))
        {
            var spatial = new TerrainSpatial(grid);
            cover = spatial.GetPositionalCover;
            adjacentCover = spatial.IsAdjacentToTerrainCover;
            lineOfSight = spatial.HasLineOfSight;
            lineOfEffect = spatial.HasLineOfEffect;
        }
        else
        {
            // Flat board — no blocking terrain, so every attack has clear cover/LOS/LOE. Set explicitly
            // rather than left null so a previous terrain encounter's delegates can never leak in.
            cover = (attacker, defender) => CoverLevel.None;
            adjacentCover = _ => false;
            lineOfSight = (a, b) => true;
            lineOfEffect = (a, b) => true;
        }

        OffGuardHelper.IsFlankingAttacker = flanking;
        CoverHelper.GetPositionalCover = cover;
        CoverHelper.IsAdjacentToTerrainCover = adjacentCover;
        CoverHelper.HasLineOfSight = lineOfSight;
        CoverHelper.HasLineOfEffect = lineOfEffect;

        return new Handle(flanking, cover, adjacentCover, lineOfSight, lineOfEffect);
    }

    /// <summary>Releases the five delegates one <see cref="Wire"/> call installed, and only those.</summary>
    private sealed class Handle : IDisposable
    {
        private readonly Func<ICharacter, ICharacter, bool> _flanking;
        private readonly Func<ICharacter, ICharacter, CoverLevel> _cover;
        private readonly Func<ICharacter, bool> _adjacentCover;
        private readonly Func<ICharacter, ICharacter, bool> _lineOfSight;
        private readonly Func<PF2e.Vector2Int, PF2e.Vector2Int, bool> _lineOfEffect;
        private bool _disposed;

        public Handle(
            Func<ICharacter, ICharacter, bool> flanking,
            Func<ICharacter, ICharacter, CoverLevel> cover,
            Func<ICharacter, bool> adjacentCover,
            Func<ICharacter, ICharacter, bool> lineOfSight,
            Func<PF2e.Vector2Int, PF2e.Vector2Int, bool> lineOfEffect)
        {
            _flanking = flanking;
            _cover = cover;
            _adjacentCover = adjacentCover;
            _lineOfSight = lineOfSight;
            _lineOfEffect = lineOfEffect;
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            if (ReferenceEquals(OffGuardHelper.IsFlankingAttacker, _flanking))
                OffGuardHelper.IsFlankingAttacker = null;
            if (ReferenceEquals(CoverHelper.GetPositionalCover, _cover))
                CoverHelper.GetPositionalCover = null;
            if (ReferenceEquals(CoverHelper.IsAdjacentToTerrainCover, _adjacentCover))
                CoverHelper.IsAdjacentToTerrainCover = null;
            if (ReferenceEquals(CoverHelper.HasLineOfSight, _lineOfSight))
                CoverHelper.HasLineOfSight = null;
            if (ReferenceEquals(CoverHelper.HasLineOfEffect, _lineOfEffect))
                CoverHelper.HasLineOfEffect = null;
        }
    }

    // Verbatim port of BattleSimulator.WireFlankingDelegate: a target is flanked when a living
    // ally is within reach on the opposite side of the target from the attacker.
    private static bool IsFlankingAttacker(ICharacter attacker, ICharacter target)
    {
        var registry = CombatantRegistry.Instance;
        if (registry == null)
            return false;

        var (boundsMin, boundsMax) = CreatureSizeHelper.GetSpaceBounds(
            target.GridPosition, target.TileWidth);

        foreach (var ally in registry.All)
        {
            if (ally == attacker || ally == target) continue;
            if (ally.TeamId != attacker.TeamId) continue;
            if (ally.Health == null || ally.Health.IsDead) continue;

            int reach = CreatureSizeHelper.GetNaturalReachTiles(
                ally.StatProvider?.Size ?? CreatureSize.Medium);
            if (!FlankingCalculator.IsWithinReach(
                ally.GridPosition, ally.TileWidth,
                target.GridPosition, target.TileWidth, reach))
                continue;

            var allyCenter = CreatureSizeHelper.GetSpaceCenter(ally.GridPosition, ally.TileWidth);
            var attackerCenter = CreatureSizeHelper.GetSpaceCenter(
                attacker.GridPosition, attacker.TileWidth);

            if (FlankingCalculator.AreOnOppositeSides(
                attackerCenter, allyCenter, boundsMin, boundsMax))
                return true;
        }
        return false;
    }
}
