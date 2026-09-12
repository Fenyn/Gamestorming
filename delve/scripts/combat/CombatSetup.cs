using System;
using System.Collections.Generic;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Immutable description of a combat encounter to hand to <see cref="CombatSession"/>.
/// Plain data — no engine lifecycle, no Godot types. Positions are grid anchors.
///
/// A setup describes EITHER a flat board (<see cref="GridWidth"/> x <see cref="GridHeight"/>, the
/// original shape) or a generated one (<see cref="Layout"/> + <see cref="BiomeId"/>). Everything
/// downstream branches on <c>Layout != null</c> and nothing else, so every existing flat caller keeps
/// working untouched.
/// </summary>
public sealed record CombatSetup
{
    private readonly int _gridWidth = 12;
    private readonly int _gridHeight = 10;
    // Whether the caller wrote a board size at all. A layout-only setup leaves the 12x10 defaults in
    // place on purpose, and reporting THAT as a mismatch would cry wolf on every generated encounter.
    private readonly bool _sizeAuthored;

    /// <summary>Player-team combatants (team 1) with their starting grid anchors.</summary>
    public List<(ICharacter Unit, PF2eVec Pos)> Party { get; init; } = new();

    /// <summary>Run control permissions, applied before initiative and reaction wiring.</summary>
    public PartyControlPolicy Control { get; init; } = new();

    /// <summary>Enemy-team combatants (team 2) with their starting grid anchors.</summary>
    public List<(ICharacter Unit, PF2eVec Pos)> Enemies { get; init; } = new();

    /// <summary>Team-1 combatants the player does not command: AI-run allies who fight beside the
    /// party but are not in it, and never count toward its defeat check.</summary>
    public List<(ICharacter Unit, PF2eVec Pos)> Allies { get; init; } = new();

    /// <summary>How carefully the units in <see cref="Allies"/> fight.</summary>
    public AllyAiRules AllyAi { get; init; } = AllyAiRules.Default;

    /// <summary>
    /// Generated battle map, or null for a flat board. Pure Pf2e.Core data — the record stays
    /// engine-free. When set, the session populates its BattleGrid from it instead of
    /// <c>BattleGrid.CreateFlat</c> and the scene builds terrain geometry for it.
    /// </summary>
    public PF2e.MapGen.MapLayout? Layout { get; init; }

    /// <summary>
    /// Registry id of the biome <see cref="Layout"/> was generated from ("forest", "sewer"), which is
    /// also the key its visual theme is looked up under. Null falls back to the default theme — a
    /// mis-dressed map, never a crash.
    /// </summary>
    public string? BiomeId { get; init; }

    /// <summary>
    /// Board width. With a <see cref="Layout"/> the layout's own width wins (an authored value that
    /// disagrees is reported by <see cref="Normalize"/>), so bounds tests, the camera pivot and the
    /// grid all read one number.
    /// </summary>
    public int GridWidth
    {
        get => Layout?.Width ?? _gridWidth;
        init { _gridWidth = value; _sizeAuthored = true; }
    }

    /// <summary>Board height. See <see cref="GridWidth"/> for the layout precedence rule.</summary>
    public int GridHeight
    {
        get => Layout?.Height ?? _gridHeight;
        init { _gridHeight = value; _sizeAuthored = true; }
    }

    /// <summary>Optional deterministic RNG seed (applied via Rng.Seed before initiative).</summary>
    public int? RngSeed { get; init; }

    /// <summary>XP this fight awards on victory: the encounter's total, relative to the party's
    /// level at build time (PF2e RAW - the budget IS the award). 0 for spikes that never award.</summary>
    public int XpAward { get; init; }

    /// <summary>
    /// Self-heal deployment before placement: every cell of a unit's TileWidth-square footprint must
    /// be in-bounds, standable and unshared, or its anchor is moved to the nearest legal footprint.
    /// With a <see cref="Layout"/>, every covered tile must be walkable, so even a non-anchor cell
    /// cannot overlap a wall, chasm or previously deployed unit. Throws when no footprint fits.
    /// Returns one human-readable line per correction (empty when
    /// the setup was already legal) so callers can surface data/board mismatches loudly instead of
    /// letting units render off the visible board.
    /// </summary>
    public IReadOnlyList<string> Normalize()
    {
        var corrections = new List<string>();
        var occupied = new HashSet<PF2eVec>();

        // A board size authored alongside a layout is advisory only — the layout's dimensions are the
        // ones every consumer sees. Report the disagreement rather than silently papering over it.
        if (Layout != null && _sizeAuthored && (_gridWidth != Layout.Width || _gridHeight != Layout.Height))
        {
            corrections.Add(
                $"board size {_gridWidth}x{_gridHeight} does not match the generated "
                + $"{Layout.Width}x{Layout.Height} layout; the layout's dimensions are used.");
        }

        NormalizeTeam(Party, "party", corrections, occupied);
        NormalizeTeam(Allies, "ally", corrections, occupied);
        NormalizeTeam(Enemies, "enemy", corrections, occupied);
        return corrections;
    }

    private void NormalizeTeam(
        List<(ICharacter Unit, PF2eVec Pos)> team,
        string label,
        List<string> corrections,
        HashSet<PF2eVec> occupied)
    {
        for (int i = 0; i < team.Count; i++)
        {
            var (unit, pos) = team[i];
            int width = unit.TileWidth;
            string? reason = FootprintProblem(pos, width, occupied);
            if (reason == null)
            {
                ReserveFootprint(pos, width, occupied);
                continue;
            }

            PF2eVec fixedPos = NearestFreeFootprint(pos, width, occupied, unit.Name);
            ReserveFootprint(fixedPos, width, occupied);
            team[i] = (unit, fixedPos);
            corrections.Add(
                $"{label} {width}x{width} footprint at anchor ({pos.x}, {pos.y}) for {unit.Name} is {reason}; moved to ({fixedPos.x}, {fixedPos.y}).");
        }
    }

    /// <summary>In-bounds tiles are all standable on a flat board; a layout also has to call it walkable.</summary>
    private bool IsStandable(PF2eVec p) => Layout == null || Layout.IsWalkable(p.x, p.y);

    private string? FootprintProblem(PF2eVec anchor, int width, HashSet<PF2eVec> occupied)
    {
        if (width < 1)
            throw new InvalidOperationException($"Invalid creature footprint width {width}.");
        if (anchor.x < 0 || anchor.y < 0 || width > GridWidth || width > GridHeight
            || anchor.x > GridWidth - width || anchor.y > GridHeight - width)
            return $"outside the {GridWidth}x{GridHeight} board";
        for (int y = 0; y < width; y++)
            for (int x = 0; x < width; x++)
            {
                var cell = new PF2eVec(anchor.x + x, anchor.y + y);
                if (!IsStandable(cell)) return "not walkable terrain";
                if (occupied.Contains(cell)) return "occupied";
            }
        return null;
    }

    private static void ReserveFootprint(PF2eVec anchor, int width, HashSet<PF2eVec> occupied)
    {
        for (int y = 0; y < width; y++)
            for (int x = 0; x < width; x++)
                occupied.Add(new PF2eVec(anchor.x + x, anchor.y + y));
    }

    /// <summary>Nearest legal square by Chebyshev rings from the clamped legal anchor range.</summary>
    private PF2eVec NearestFreeFootprint(PF2eVec from, int width, HashSet<PF2eVec> occupied, string unitName)
    {
        if (width > GridWidth || width > GridHeight)
            throw new InvalidOperationException(
                $"No free standable {width}x{width} footprint for {unitName} on a {GridWidth}x{GridHeight} board.");
        var start = new PF2eVec(
            Math.Clamp(from.x, 0, GridWidth - width),
            Math.Clamp(from.y, 0, GridHeight - width));

        int maxRadius = Math.Max(GridWidth, GridHeight);
        for (int r = 0; r <= maxRadius; r++)
        {
            for (int dy = -r; dy <= r; dy++)
            {
                for (int dx = -r; dx <= r; dx++)
                {
                    if (Math.Max(Math.Abs(dx), Math.Abs(dy)) != r)
                        continue;
                    var cell = new PF2eVec(start.x + dx, start.y + dy);
                    if (FootprintProblem(cell, width, occupied) == null)
                        return cell;
                }
            }
        }

        // Free cells can remain while no contiguous creature footprint fits.
        throw new InvalidOperationException(
            $"No free standable {width}x{width} footprint for {unitName} on a {GridWidth}x{GridHeight} board ({occupied.Count} occupied cells).");
    }
}
