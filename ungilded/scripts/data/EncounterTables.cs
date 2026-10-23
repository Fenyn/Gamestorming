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

    public static readonly CreatureRef KoboldWarrior = new()
    {
        DisplayName = "Kobold Warrior", Pack = "pathfinder-monster-core", Slug = "kobold-warrior",
    };

    public static readonly CreatureRef Wolf = new()
    {
        DisplayName = "Wolf", Pack = "pathfinder-monster-core", Slug = "wolf",
    };

    public static readonly CreatureRef Viper = new()
    {
        DisplayName = "Viper", Pack = "pathfinder-monster-core", Slug = "viper",
    };

    public static readonly CreatureRef HuntingSpider = new()
    {
        DisplayName = "Hunting Spider", Pack = "pathfinder-monster-core", Slug = "hunting-spider",
    };

    public static readonly CreatureRef Boar = new()
    {
        DisplayName = "Boar", Pack = "pathfinder-monster-core", Slug = "boar",
    };

    public static readonly CreatureRef GiantViper = new()
    {
        DisplayName = "Giant Viper", Pack = "pathfinder-monster-core", Slug = "giant-viper",
    };

    public static readonly CreatureRef GiantMonitorLizard = new()
    {
        DisplayName = "Giant Monitor Lizard", Pack = "pathfinder-monster-core", Slug = "giant-monitor-lizard",
    };

    public static readonly CreatureRef DireWolf = new()
    {
        DisplayName = "Dire Wolf", Pack = "pathfinder-monster-core", Slug = "dire-wolf",
    };

    public static readonly CreatureRef GrizzlyBear = new()
    {
        DisplayName = "Grizzly Bear", Pack = "pathfinder-monster-core", Slug = "grizzly-bear",
    };

    public static readonly CreatureRef GiantStagBeetle = new()
    {
        DisplayName = "Giant Stag Beetle", Pack = "pathfinder-monster-core", Slug = "giant-stag-beetle",
    };
}
