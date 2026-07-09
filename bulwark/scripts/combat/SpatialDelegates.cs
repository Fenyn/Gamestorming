using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Utilities;

namespace Bulwark.Combat;

/// <summary>
/// Wires the engine's static spatial delegates for a combat encounter. The engine ships no
/// defaults: flanking (off-guard) and cover/line-of-sight/line-of-effect must be supplied by the
/// client. For M1's flat 12x10 grid, flanking is real (mirrors
/// <c>BattleSimulator.WireFlankingDelegate</c>) and cover/LOS are open stubs. When real map-driven
/// terrain arrives at M3, only <see cref="Wire"/> needs to change.
/// </summary>
public static class SpatialDelegates
{
    public static void Wire(BattleGrid grid)
    {
        OffGuardHelper.IsFlankingAttacker = IsFlankingAttacker;

        // Flat-grid stubs — no blocking terrain, so every attack has clear cover/LOS/LOE.
        // TODO(M3): replace with real geometry queries against the loaded map.
        CoverHelper.GetPositionalCover = (attacker, defender) => CoverLevel.None;
        CoverHelper.HasLineOfSight = (a, b) => true;
        CoverHelper.HasLineOfEffect = (a, b) => true;
    }

    public static void Unwire()
    {
        OffGuardHelper.IsFlankingAttacker = null;
        CoverHelper.GetPositionalCover = null;
        CoverHelper.HasLineOfSight = null;
        CoverHelper.HasLineOfEffect = null;
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
