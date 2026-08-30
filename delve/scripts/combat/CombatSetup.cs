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

    /// <summary>Enemy-team combatants (team 2) with their starting grid anchors.</summary>
    public List<(ICharacter Unit, PF2eVec Pos)> Enemies { get; init; } = new();

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
    /// Self-heal the deployment before placement: every anchor must be in-bounds, standable and
    /// unshared, or the unit is remapped to the nearest free legal cell. With a <see cref="Layout"/>,
    /// "standable" additionally means the layout calls the tile walkable, so a party anchor can never
    /// land inside a wall or over a chasm. Returns one human-readable line per correction (empty when
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
            bool inBounds = InBounds(pos);
            bool standable = inBounds && IsStandable(pos);
            if (standable && occupied.Add(pos))
                continue;

            PF2eVec fixedPos = NearestFreeCell(pos, occupied);
            occupied.Add(fixedPos);
            team[i] = (unit, fixedPos);
            string reason = !inBounds ? $"outside the {GridWidth}x{GridHeight} board"
                : !standable ? "not walkable terrain"
                : "occupied";
            corrections.Add(
                $"{label} anchor ({pos.x}, {pos.y}) for {unit.Name} is {reason}; moved to ({fixedPos.x}, {fixedPos.y}).");
        }
    }

    private bool InBounds(PF2eVec p) => p.x >= 0 && p.y >= 0 && p.x < GridWidth && p.y < GridHeight;

    /// <summary>In-bounds tiles are all standable on a flat board; a layout also has to call it walkable.</summary>
    private bool IsStandable(PF2eVec p) => Layout == null || Layout.IsWalkable(p.x, p.y);

    /// <summary>Nearest free, standable, in-bounds cell by Chebyshev ring scan from the clamped anchor.</summary>
    private PF2eVec NearestFreeCell(PF2eVec from, HashSet<PF2eVec> occupied)
    {
        var start = new PF2eVec(
            Math.Clamp(from.x, 0, GridWidth - 1),
            Math.Clamp(from.y, 0, GridHeight - 1));

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
                    if (InBounds(cell) && IsStandable(cell) && !occupied.Contains(cell))
                        return cell;
                }
            }
        }

        // Board fuller than its standable cell count — impossible for sane setups; fail predictably.
        throw new InvalidOperationException(
            $"No free standable cell on a {GridWidth}x{GridHeight} board for {occupied.Count} occupied anchors.");
    }
}
