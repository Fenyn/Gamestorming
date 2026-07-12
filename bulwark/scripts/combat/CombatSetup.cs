using System;
using System.Collections.Generic;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Immutable description of a combat encounter to hand to <see cref="CombatSession"/>.
/// Plain data — no engine lifecycle, no Godot types. Positions are grid anchors.
/// </summary>
public sealed record CombatSetup
{
    /// <summary>Player-team combatants (team 1) with their starting grid anchors.</summary>
    public List<(ICharacter Unit, PF2eVec Pos)> Party { get; init; } = new();

    /// <summary>Enemy-team combatants (team 2) with their starting grid anchors.</summary>
    public List<(ICharacter Unit, PF2eVec Pos)> Enemies { get; init; } = new();

    public int GridWidth { get; init; } = 12;
    public int GridHeight { get; init; } = 10;

    /// <summary>Optional deterministic RNG seed (applied via Rng.Seed before initiative).</summary>
    public int? RngSeed { get; init; }

    /// <summary>
    /// Self-heal the deployment before placement: every anchor must be in-bounds and unshared, or
    /// the unit is remapped to the nearest free in-bounds cell. Returns one human-readable line per
    /// correction (empty when the setup was already legal) so callers can surface data/board
    /// mismatches loudly instead of letting units render off the visible board.
    /// </summary>
    public IReadOnlyList<string> Normalize()
    {
        var corrections = new List<string>();
        var occupied = new HashSet<PF2eVec>();

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
            if (inBounds && occupied.Add(pos))
                continue;

            PF2eVec fixedPos = NearestFreeCell(pos, occupied);
            occupied.Add(fixedPos);
            team[i] = (unit, fixedPos);
            string reason = inBounds ? "occupied" : $"outside the {GridWidth}x{GridHeight} board";
            corrections.Add(
                $"{label} anchor ({pos.x}, {pos.y}) for {unit.Name} is {reason}; moved to ({fixedPos.x}, {fixedPos.y}).");
        }
    }

    private bool InBounds(PF2eVec p) => p.x >= 0 && p.y >= 0 && p.x < GridWidth && p.y < GridHeight;

    /// <summary>Nearest free in-bounds cell by Chebyshev ring scan from the clamped anchor.</summary>
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
                    if (InBounds(cell) && !occupied.Contains(cell))
                        return cell;
                }
            }
        }

        // Board fuller than its cell count — impossible for sane setups; fail predictably.
        throw new InvalidOperationException(
            $"No free cell on a {GridWidth}x{GridHeight} board for {occupied.Count} occupied anchors.");
    }
}
