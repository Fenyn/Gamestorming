using System.Collections.Generic;
using System.Linq;
using CharacterRegistry = Bulwark.Data.Characters.Characters;

namespace Bulwark.Data;

/// <summary>
/// Static registry of the villager cast (Phase 3 keystone) — same DefinitionRegistry pattern as
/// <see cref="Buildings"/>, <see cref="Crops"/>, etc. Populated from two sources:
///   1. Character profiles (non-starting PCs emit VillagerDefinitions via <see cref="Characters"/>).
///   2. Standalone hand-authored VillagerDefinitions below (for the 14 non-starting characters in
///      design/economy/characters.md, which is the source of truth for every arrival trigger).
/// </summary>
public static class Villagers
{
    // ===================== Hand-authored roster (design/economy/characters.md) =====================
    //
    // Several arrival triggers reference story flags / counters that GameState does not yet raise
    // (flagged per-character below); the trigger shape is authored now so the villager cast is
    // complete, and the flag/counter itself is a follow-up GameState wiring task, not a data-pass
    // concern. Building associations mirror buildings.md's character-first / building-first split.

    // Arkus is NOT hand-authored here: he has a full CharacterProfile (characters/Arkus.cs) whose
    // emitted VillagerDefinition carries his arrival (StoryFlag arkus_found, latched by the found
    // cutscene on the first return after dire_wolf_slain). One source of truth — do not re-add him.

    /// <summary>Monk. Character-first → Infirmary: a random event 1-3 days after the Infirmary is
    /// built brings him in (StoryDirector.OnDayStarted sets josen_arrived), rather than gating the
    /// building itself. Mend the Wounded starts on his arrival.</summary>
    public static readonly VillagerDefinition Josen = new()
    {
        Id = "josen",
        DisplayName = "Josen",
        AssociatedBuildingId = "infirmary",
        Recruitable = true,
        JoinPresetKey = "josen",
        Arrival = ArrivalTrigger.StoryFlag("josen_arrived"),
    };

    /// <summary>Witch. Character-first → Apothecary: the Elderwood biome is explored (requires
    /// Command Post tier 2 to have already opened it).</summary>
    public static readonly VillagerDefinition Spore = new()
    {
        Id = "spore",
        DisplayName = "Spore",
        AssociatedBuildingId = "apothecary",
        Recruitable = true,
        JoinPresetKey = "spore",
        Arrival = ArrivalTrigger.StoryFlag("elderwood_explored"),
    };

    /// <summary>Ranger. Character-first → Watchtower: the far-forest campsite zone, deep in the
    /// Elderwood (farther in than Spore's own trigger), is discovered.</summary>
    public static readonly VillagerDefinition Thistle = new()
    {
        Id = "thistle",
        DisplayName = "Thistle",
        AssociatedBuildingId = "watchtower",
        Recruitable = true,
        JoinPresetKey = "thistle",
        Arrival = ArrivalTrigger.StoryFlag("elderwood_far_campsite_discovered"),
    };

    /// <summary>Champion. Character-first → Training Yard: eight buildings constructed at the
    /// outpost. NOTE: no direct "building count" ArrivalTrigger variant exists — this is authored as
    /// a story flag; GameState needs to raise it once the 8-building threshold is crossed (Command
    /// Post excluded per buildings.md, since it's the start state rather than something the player
    /// builds).</summary>
    public static readonly VillagerDefinition Aldric = new()
    {
        Id = "aldric",
        DisplayName = "Aldric",
        AssociatedBuildingId = "training_yard",
        Recruitable = true,
        JoinPresetKey = "aldric",
        Arrival = ArrivalTrigger.StoryFlag("eight_buildings_constructed"),
    };

    /// <summary>Magus. Character-first → Arcane Study: Trading Post reaches tier 2.</summary>
    public static readonly VillagerDefinition Sera = new()
    {
        Id = "sera",
        DisplayName = "Sera",
        AssociatedBuildingId = "arcane_study",
        Recruitable = true,
        JoinPresetKey = "sera",
        Arrival = ArrivalTrigger.BuildingReached("trading_post", 2),
    };

    /// <summary>Oracle. Building-first: arrives the moment the Chapel is constructed.</summary>
    public static readonly VillagerDefinition Oskar = new()
    {
        Id = "oskar",
        DisplayName = "Oskar",
        AssociatedBuildingId = "chapel",
        Recruitable = true,
        JoinPresetKey = "oskar",
        Arrival = ArrivalTrigger.BuildingReached("chapel", 1),
    };

    /// <summary>Druid. Building-first: Farmhouse reaches tier 2 AND a territory-expansion milestone
    /// is reached.</summary>
    public static readonly VillagerDefinition Grub = new()
    {
        Id = "grub",
        DisplayName = "Grub",
        AssociatedBuildingId = "farmhouse",
        Recruitable = true,
        JoinPresetKey = "grub",
        Arrival = ArrivalTrigger.All(
            ArrivalTrigger.BuildingReached("farmhouse", 2),
            ArrivalTrigger.StoryFlag("territory_expanded")),
    };

    /// <summary>Thaumaturge. Character-first → Reliquary: the party holds 8 monster trophies/rare
    /// drops at once. NOTE: trophies span many distinct item ids, and ItemCountReached only checks a
    /// single item id, so a clean single-item count can't express "8 across any trophy" — authored
    /// as a story flag instead; GameState needs to raise it once the party's combined trophy-category
    /// count (current carry + warehouse) reaches 8.</summary>
    public static readonly VillagerDefinition Hazel = new()
    {
        Id = "hazel",
        DisplayName = "Hazel",
        AssociatedBuildingId = "reliquary",
        Recruitable = true,
        JoinPresetKey = "hazel",
        Arrival = ArrivalTrigger.StoryFlag("eight_trophies_collected"),
    };

    /// <summary>Bard. Building-first: Tavern reaches tier 2 (the common room exists).</summary>
    public static readonly VillagerDefinition Wynn = new()
    {
        Id = "wynn",
        DisplayName = "Wynn",
        AssociatedBuildingId = "tavern",
        Recruitable = true,
        JoinPresetKey = "wynn",
        Arrival = ArrivalTrigger.BuildingReached("tavern", 2),
    };

    /// <summary>Summoner. Building-first: Tavern reaches tier 3 (boarding rooms exist) — this only
    /// makes her present as townsfolk. Not recruitable from this trigger alone: her PC-reveal runs on
    /// a separate hearts 2-4 friendship event (design/characters/hilde.md), so she starts as
    /// non-recruitable townsfolk here.</summary>
    public static readonly VillagerDefinition Hilde = new()
    {
        Id = "hilde",
        DisplayName = "Hilde",
        AssociatedBuildingId = "tavern",
        Recruitable = false,
        JoinPresetKey = null,
        Arrival = ArrivalTrigger.BuildingReached("tavern", 3),
    };

    /// <summary>Swashbuckler. Missable: Trading Post and Tavern are both built, plus a calendar
    /// threshold that paces when her visits begin. This trigger only governs her ARRIVAL (visits) —
    /// actual recruitment stays separately friendship-gated at hearts 5-6
    /// (design/characters/raven.md, per the documented friendship exception), not modeled here.</summary>
    public static readonly VillagerDefinition Raven = new()
    {
        Id = "raven",
        DisplayName = "Raven",
        AssociatedBuildingId = null,
        Recruitable = true,
        JoinPresetKey = "raven",
        Arrival = ArrivalTrigger.All(
            ArrivalTrigger.BuildingReached("trading_post", 1),
            ArrivalTrigger.BuildingReached("tavern", 1),
            ArrivalTrigger.DateReached(Season.Summer, 1, 1)),
    };

    /// <summary>Sorcerer. Expedition event: found mid-fight during an early Sunken Reach expedition
    /// encounter (reachable once Command Post tier 3 opens the swamp).</summary>
    public static readonly VillagerDefinition Flick = new()
    {
        Id = "flick",
        DisplayName = "Flick",
        AssociatedBuildingId = null,
        Recruitable = true,
        JoinPresetKey = "flick",
        Arrival = ArrivalTrigger.StoryFlag("early_swamp_encounter"),
    };

    /// <summary>Psychic. Missable, gated behind another character rather than a building: Oskar
    /// reaches 6/10 hearts AND the Sunken Reach has been explored. Per the documented friendship
    /// exception, her availability rides Oskar's friendship track rather than her own.</summary>
    public static readonly VillagerDefinition Vasska = new()
    {
        Id = "vasska",
        DisplayName = "Vasska",
        AssociatedBuildingId = null,
        Recruitable = true,
        JoinPresetKey = "vasska",
        Arrival = ArrivalTrigger.All(
            ArrivalTrigger.FriendshipReached("oskar", 6),
            ArrivalTrigger.StoryFlag("sunken_reach_explored")),
    };

    private static readonly VillagerDefinition[] HandAuthored =
    {
        Josen, Spore, Thistle, Aldric, Sera, Oskar, Grub,
        Hazel, Wynn, Hilde, Raven, Flick, Vasska,
    };

    private static readonly DefinitionRegistry<VillagerDefinition> Registry = new(d => d.Id,
        CharacterRegistry.AllVillagerDefinitions().Concat(HandAuthored).ToArray());

    /// <summary>Every defined villager.</summary>
    public static IReadOnlyCollection<VillagerDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined villager.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a villager by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static VillagerDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out VillagerDefinition def) => Registry.TryGet(id, out def);
}
