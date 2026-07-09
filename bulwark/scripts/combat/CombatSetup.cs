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
}
