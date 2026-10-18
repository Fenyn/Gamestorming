namespace Ungilded.Data;

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
}

/// <summary>
/// Pack creatures the dev harness and the combat spikes reference.
/// </summary>
public static class EncounterTables
{
    public static readonly CreatureRef GoblinWarrior = new()
    {
        DisplayName = "Goblin Warrior", Pack = "pathfinder-monster-core", Slug = "goblin-warrior",
    };

    public static readonly CreatureRef GiantRat = new()
    {
        DisplayName = "Giant Rat", Pack = "pathfinder-monster-core", Slug = "giant-rat",
    };
}
