namespace Delve.Data;

/// <summary>
/// Reference to a PF2e pack creature, resolvable through DataManager the way CombatTestScene does:
/// FindCreature(<see cref="DisplayName"/>) with a LoadCreatureFile(<see cref="Pack"/>, <see cref="Slug"/>)
/// fallback. Data-only per CLAUDE.md.
/// </summary>
public sealed class CreatureRef
{
    public required string DisplayName { get; init; }
    public required string Pack { get; init; }
    public required string Slug { get; init; }

    /// <summary>
    /// Optional loot table id this creature rolls when defeated. Null = no drops. Unused in the
    /// combat proof (no loot system yet); kept so the ref shape matches bulwark's.
    /// </summary>
    public string? DropTableId { get; init; }
}

/// <summary>
/// Minimal creature roster for the combat proof: the single creature the test encounter and the
/// combat spikes reference. The full encounter-table stack stays in bulwark until the roguelite
/// run structure is designed.
/// </summary>
public static class EncounterTables
{
    public static readonly CreatureRef GoblinWarrior = new()
    {
        DisplayName = "Goblin Warrior", Pack = "pathfinder-monster-core", Slug = "goblin-warrior",
        DropTableId = "goblin_drops",
    };
}
