using System.Collections.Generic;

namespace Bulwark.Data;

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

/// <summary>One creature line of an encounter: which creature, how many.</summary>
public sealed class EncounterCreature
{
    public required CreatureRef Creature { get; init; }
    public int Count { get; init; } = 1;
}

/// <summary>A named encounter: the creature list a combat is built from.</summary>
public sealed class EncounterDefinition
{
    public required string Id { get; init; }

    /// <summary>Shown in the "X attacks!" HUD line when the encounter starts.</summary>
    public required string DisplayName { get; init; }

    public required IReadOnlyList<EncounterCreature> Creatures { get; init; }
}

/// <summary>A weighted entry in a spawn-marker's encounter table.</summary>
public sealed class WeightedEncounter
{
    public required string EncounterId { get; init; }
    public int Weight { get; init; } = 1;
}

/// <summary>
/// Static registry of encounter definitions, keyed for the per-territory roamer tables
/// (see <see cref="Territories"/>). T1 forest = the goblin-tier creatures combat already uses.
/// </summary>
public static class EncounterTables
{
    // --- T1 creatures (PF2e level -1) ---
    public static readonly CreatureRef GoblinWarrior = new()
    {
        DisplayName = "Goblin Warrior", Pack = "pathfinder-monster-core", Slug = "goblin-warrior",
    };
    public static readonly CreatureRef GiantRat = new()
    {
        DisplayName = "Giant Rat", Pack = "pathfinder-monster-core", Slug = "giant-rat",
    };

    // --- T1 forest encounters ---
    public static readonly EncounterDefinition GoblinPair = new()
    {
        Id = "goblin_pair", DisplayName = "A goblin pair",
        Creatures = new[] { new EncounterCreature { Creature = GoblinWarrior, Count = 2 } },
    };
    public static readonly EncounterDefinition GoblinPatrol = new()
    {
        Id = "goblin_patrol", DisplayName = "A goblin patrol",
        Creatures = new[] { new EncounterCreature { Creature = GoblinWarrior, Count = 3 } },
    };
    public static readonly EncounterDefinition GoblinWarband = new()
    {
        Id = "goblin_warband", DisplayName = "A goblin warband",
        Creatures = new[] { new EncounterCreature { Creature = GoblinWarrior, Count = 4 } },
    };
    public static readonly EncounterDefinition RatPack = new()
    {
        Id = "rat_pack", DisplayName = "A pack of giant rats",
        Creatures = new[] { new EncounterCreature { Creature = GiantRat, Count = 3 } },
    };

    private static readonly Dictionary<string, EncounterDefinition> ById = BuildIndex(
        GoblinPair, GoblinPatrol, GoblinWarband, RatPack);

    public static IReadOnlyCollection<EncounterDefinition> All => ById.Values;

    public static bool IsDefined(string id) => ById.ContainsKey(id);

    public static EncounterDefinition Get(string id) => ById[id];

    public static bool TryGet(string id, out EncounterDefinition def) => ById.TryGetValue(id, out def!);

    private static Dictionary<string, EncounterDefinition> BuildIndex(params EncounterDefinition[] defs)
    {
        var index = new Dictionary<string, EncounterDefinition>(defs.Length);
        foreach (var def in defs)
            index[def.Id] = def;
        return index;
    }
}
