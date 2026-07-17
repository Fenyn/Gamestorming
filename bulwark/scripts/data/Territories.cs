using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>A resource-node placement in a territory: a stable node id bound to a node definition.
/// The territory scene carries a matching <c>%Node_&lt;NodeId&gt;</c> marker for its position.</summary>
public sealed class TerritoryNode
{
    public required string NodeId { get; init; }

    /// <summary>The <see cref="ResourceNodeDefinition.Id"/> this placement instantiates.</summary>
    public required string ResourceId { get; init; }
}

/// <summary>
/// One weighted entry in a territory's forage table (design/forage.md): the
/// <see cref="ResourceNodeDefinition.Id"/> the daily pass may spawn, its pick weight, and a
/// reserved season filter (null = all seasons; wired to the calendar when GameState exposes
/// season-gated forage).
/// </summary>
public sealed class ForageEntry
{
    /// <summary>The <see cref="ResourceNodeDefinition.Id"/> this entry spawns.</summary>
    public required string NodeId { get; init; }

    public int Weight { get; init; } = 1;

    /// <summary>Reserved season filter (forage.md); null = any season. Not evaluated yet.</summary>
    public Season? Season { get; init; }
}

/// <summary>A roaming-enemy spawn in a territory: a stable roamer id with its weighted encounter
/// table. The scene carries a matching <c>%Roamer_&lt;RoamerId&gt;</c> marker for its position.</summary>
public sealed class TerritoryRoamer
{
    public required string RoamerId { get; init; }

    /// <summary>Weighted encounter entries this roamer rolls on contact.</summary>
    public required IReadOnlyList<WeightedEncounter> Encounters { get; init; }

    /// <summary>
    /// Story flag latched when this roamer's encounter is WON (design/tutorial_quests.md). Null = an
    /// ordinary roamer that flips no flag. Used to wire designated encounters to the quest arc: the
    /// deeper "first expedition" encounter (<c>first_expedition_cleared</c>) and the wolf-lair boss
    /// (<c>dire_wolf_slain</c>). GameState sets it on victory through the normal one-way-latch path,
    /// which drives quest completion + villager arrivals.
    /// </summary>
    public string? ClearsStoryFlag { get; init; }

    /// <summary>
    /// True for a fixed BOSS site rather than a wandering roamer: it is NOT spawned by the territory
    /// scene's roaming-enemy pass. A dedicated quest-conditional lair scene places and governs it
    /// (appears when its quest starts, despawns for good once its <see cref="ClearsStoryFlag"/> is
    /// latched). The encounter/flag data still lives here so BeginEncounter resolves it like any
    /// other roamer.
    /// </summary>
    public bool IsBoss { get; init; }
}

/// <summary>
/// Declarative definition of one territory map: scene path plus the node/roamer placements the
/// systems (and the blockout builder) share as the single source of truth for ids.
/// </summary>
public sealed class TerritoryDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public required string ScenePath { get; init; }
    public required IReadOnlyList<TerritoryNode> Nodes { get; init; }
    public required IReadOnlyList<TerritoryRoamer> Roamers { get; init; }

    /// <summary>
    /// Optional story-flag gate on travelling here (design/tutorial_quests.md). Null = ungated (or
    /// opened only by a building's <see cref="BuildingEffectType.BiomeUnlock"/> effect).
    /// <see cref="Bulwark.Autoload.GameState.IsBiomeUnlocked"/> returns true when a BiomeUnlock effect
    /// OR this flag (resolved through HasFlagForConditions) is satisfied. The Elderwood sets
    /// <c>dire_wolf_slain</c> — the wolf guards the passage.
    /// </summary>
    public string? UnlockFlagId { get; init; }

    /// <summary>
    /// Weighted daily forage spawns (design/forage.md). Empty = the territory seeds no forage.
    /// The ForageSystem rolls this table on its daily pass; additions are data-only.
    /// </summary>
    public IReadOnlyList<ForageEntry> ForageTable { get; init; } = System.Array.Empty<ForageEntry>();

    /// <summary>
    /// Weighted debris clutter (design/forage.md, third category). Empty = no debris here. The
    /// ForageSystem's second (debris) pass rolls this table: own cap, own attempts, no weekly
    /// sweep, one-time initial sprinkle on the territory's first-ever pass. Additions are data-only.
    /// </summary>
    public IReadOnlyList<ForageEntry> DebrisTable { get; init; } = System.Array.Empty<ForageEntry>();
}

/// <summary>
/// Static registry of territory maps: the Verdant Fringe (M3, forest), the Elderwood (moderate), and
/// the Sunken Reach (dangerous). The latter two are blockout scenes only — the user hand-paints the
/// tilemap/visuals in the editor per CLAUDE.md; the scene files themselves are not part of this
/// data-only pass. Additions are data-only.
/// </summary>
public static class Territories
{
    public static readonly TerritoryDefinition Forest = new()
    {
        Id = "verdant_fringe",
        DisplayName = "the Verdant Fringe",
        ScenePath = "res://scenes/territory/forest.tscn",
        Nodes = new[]
        {
            new TerritoryNode { NodeId = "rock_1", ResourceId = "rock" },
            new TerritoryNode { NodeId = "rock_2", ResourceId = "rock" },
            new TerritoryNode { NodeId = "rock_3", ResourceId = "rock" },
            new TerritoryNode { NodeId = "herb_1", ResourceId = "herb_patch" },
            new TerritoryNode { NodeId = "herb_2", ResourceId = "herb_patch" },
            new TerritoryNode { NodeId = "berry_1", ResourceId = "berry_bush" },
            new TerritoryNode { NodeId = "berry_2", ResourceId = "berry_bush" },
            new TerritoryNode { NodeId = "berry_3", ResourceId = "berry_bush" },
            new TerritoryNode { NodeId = "wood_1", ResourceId = "fallen_wood" },
            new TerritoryNode { NodeId = "wood_2", ResourceId = "fallen_wood" },
        },
        // v1 forage table (design/forage.md): the cheap Hand/Axe commons only — trees, ore veins
        // and quest-gated rares stay authored. Weights favor the herb/berry staples.
        ForageTable = new[]
        {
            new ForageEntry { NodeId = "herb_patch", Weight = 3 },
            new ForageEntry { NodeId = "berry_bush", Weight = 3 },
            new ForageEntry { NodeId = "wild_mushroom_patch", Weight = 2 },
            new ForageEntry { NodeId = "fallen_wood", Weight = 2 },
            new ForageEntry { NodeId = "bramble_patch", Weight = 2 },
            new ForageEntry { NodeId = "forest_root_patch", Weight = 1 },
        },
        // Debris clutter (design/forage.md): stones and branches dominate the forest floor,
        // weeds fill in — the Stardew farm-clutter mix.
        DebrisTable = new[]
        {
            new ForageEntry { NodeId = "loose_stones", Weight = 3 },
            new ForageEntry { NodeId = "fallen_branch", Weight = 3 },
            new ForageEntry { NodeId = "scrub_weeds", Weight = 2 },
        },
        Roamers = new[]
        {
            // gob_1 is deliberately single-entry (deterministic — the territory spike relies on it).
            new TerritoryRoamer
            {
                RoamerId = "gob_1",
                Encounters = new[] { new WeightedEncounter { EncounterId = "goblin_pair" } },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "goblin_pair", Weight = 2 },
                    new WeightedEncounter { EncounterId = "goblin_patrol", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_3",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "goblin_patrol", Weight = 2 },
                    new WeightedEncounter { EncounterId = "goblin_warband", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_4",
                Encounters = new[] { new WeightedEncounter { EncounterId = "rat_pack" } },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_5",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "goblin_pair", Weight = 1 },
                    new WeightedEncounter { EncounterId = "rat_pack", Weight = 1 },
                },
            },
            // Brigands (deserter_badge common; see DropTables.BrigandDrops): the Command Post tier-2
            // bundle (design/tutorial_quests.md quest 10: goblin_fang 30, deserter_badge 20, wood 15)
            // is priced "entirely from Verdant Fringe fights" per design/economy/pacing.md, affordable
            // "alongside the Chapel and Smithy from the same first weeks of forest fighting" — so these
            // are ordinary roamers with no story-flag gate (unlike wolf_lair below), farmable from day
            // one same as the goblin/rat markers above. Two markers mixing the family's two common
            // encounters (outrider_ambush: 2 Deserters, deserter_patrol: 3), same weighted-mix pattern
            // as gob_2/gob_3; the elite (brigand_elite_outrider) and boss (brigand_boss_warband_captain)
            // are left unwired here, matching how the Elderwood/Sunken Reach keep bosses as set-pieces
            // rather than roamer picks, and how goblin/rat elites above are likewise not yet placed.
            new TerritoryRoamer
            {
                RoamerId = "brigand_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "outrider_ambush", Weight = 2 },
                    new WeightedEncounter { EncounterId = "deserter_patrol", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "brigand_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "deserter_patrol", Weight = 2 },
                    new WeightedEncounter { EncounterId = "outrider_ambush", Weight = 1 },
                },
            },
            // The First Expedition (design/tutorial_quests.md quest 5): the designated expedition-zone
            // encounter, deeper in the Fringe and a step past the gate-side pairs — an ordinary but
            // heavier goblin patrol (the wolf is absent; the dread is set dressing). Winning it latches
            // first_expedition_cleared, which completes the quest AND triggers Arkus's arrival.
            // Single-entry so the encounter is deterministic (mirrors gob_1's spike-relied contract).
            new TerritoryRoamer
            {
                RoamerId = "expedition_1",
                Encounters = new[] { new WeightedEncounter { EncounterId = "goblin_patrol" } },
                ClearsStoryFlag = "first_expedition_cleared",
            },
            // The Wolf of the Fringe (design/tutorial_quests.md quest 9): the one-shot boss site. Not
            // spawned as a wanderer (IsBoss) — the wolf-lair scene places it when the quest starts and
            // despawns it for good once dire_wolf_slain latches on victory.
            new TerritoryRoamer
            {
                RoamerId = "wolf_lair",
                Encounters = new[] { new WeightedEncounter { EncounterId = "dire_wolf" } },
                ClearsStoryFlag = "dire_wolf_slain",
                IsBoss = true,
            },
        },
    };

    /// <summary>
    /// The Elderwood (moderate, second territory; scene is a blockout — the user hand-paints visuals
    /// later per CLAUDE.md). Nodes cover the Elderwood-sourced gathers named in materials.md: hardwood
    /// and coal (mining), wild_mushroom and forest_root (forage), and the two gated-rare forages,
    /// ward_salt and the ley_glade arcane_essence route. Roamers cover the biome's four creature
    /// families (Beasts, Root Wardens, Canopy Spiders, Thornbacks) from <see cref="EncounterTables"/>,
    /// two markers per family mixing that family's common variants (weight 2-3) with its elite
    /// (weight 1); bosses are the biome's clear-the-grove set-piece, not a roaming weighted pick, so
    /// they are not placed here.
    /// </summary>
    public static readonly TerritoryDefinition Elderwood = new()
    {
        Id = "elderwood",
        DisplayName = "the Elderwood",
        ScenePath = "res://scenes/territory/elderwood.tscn",
        // The dire wolf guards the Elderwood passage: slaying it opens the biome (replaces the old
        // Command Post tier-2 BiomeUnlock).
        UnlockFlagId = "dire_wolf_slain",
        Nodes = new[]
        {
            new TerritoryNode { NodeId = "hardwood_1", ResourceId = "hardwood_stand" },
            new TerritoryNode { NodeId = "hardwood_2", ResourceId = "hardwood_stand" },
            new TerritoryNode { NodeId = "coal_1", ResourceId = "coal_seam" },
            new TerritoryNode { NodeId = "coal_2", ResourceId = "coal_seam" },
            new TerritoryNode { NodeId = "mushroom_1", ResourceId = "wild_mushroom_patch" },
            new TerritoryNode { NodeId = "mushroom_2", ResourceId = "wild_mushroom_patch" },
            new TerritoryNode { NodeId = "forest_root_1", ResourceId = "forest_root_patch" },
            new TerritoryNode { NodeId = "forest_root_2", ResourceId = "forest_root_patch" },
            new TerritoryNode { NodeId = "ward_salt_1", ResourceId = "ward_salt_deposit" },
            new TerritoryNode { NodeId = "ley_glade_1", ResourceId = "ley_glade" },
        },
        Roamers = new[]
        {
            new TerritoryRoamer
            {
                RoamerId = "beast_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "lone_predator", Weight = 3 },
                    new WeightedEncounter { EncounterId = "hunting_pack", Weight = 2 },
                    new WeightedEncounter { EncounterId = "beast_elite_alpha", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "beast_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "lone_predator", Weight = 2 },
                    new WeightedEncounter { EncounterId = "hunting_pack", Weight = 3 },
                    new WeightedEncounter { EncounterId = "beast_elite_alpha", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "warden_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "root_warden", Weight = 3 },
                    new WeightedEncounter { EncounterId = "stand_of_root_wardens", Weight = 2 },
                    new WeightedEncounter { EncounterId = "root_warden_elite_bramble_warden", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "warden_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "root_warden", Weight = 2 },
                    new WeightedEncounter { EncounterId = "stand_of_root_wardens", Weight = 3 },
                    new WeightedEncounter { EncounterId = "root_warden_elite_bramble_warden", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "spider_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "canopy_spider", Weight = 3 },
                    new WeightedEncounter { EncounterId = "spider_drop", Weight = 2 },
                    new WeightedEncounter { EncounterId = "canopy_spider_elite_weaver", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "spider_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "canopy_spider", Weight = 2 },
                    new WeightedEncounter { EncounterId = "spider_drop", Weight = 3 },
                    new WeightedEncounter { EncounterId = "canopy_spider_elite_weaver", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "thornback_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "thornback_brute", Weight = 3 },
                    new WeightedEncounter { EncounterId = "thornback_pair", Weight = 2 },
                    new WeightedEncounter { EncounterId = "thornback_elite_stumpfist", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "thornback_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "thornback_brute", Weight = 2 },
                    new WeightedEncounter { EncounterId = "thornback_pair", Weight = 3 },
                    new WeightedEncounter { EncounterId = "thornback_elite_stumpfist", Weight = 1 },
                },
            },
        },
    };

    /// <summary>
    /// The Sunken Reach (dangerous, third territory; scene is a blockout, same as the Elderwood).
    /// Nodes cover the swamp-sourced gathers named in materials.md: iron_ore (bog-iron) and bogwood
    /// (drowned-tree stand) by Pick/Axe, plus the four Sunken Reach forages (bog_moss, marsh_reed,
    /// bitter_root, and the deep-Reach-gated nightcap_mushroom). Roamers cover the biome's six
    /// creature families (Mudclaws, Marsh Serpents, Bog Fungus, The Drowned, Swamp Drakes, Marsh
    /// Wisps), two markers per family with the same common-weighted/elite-weighted-1 mix as the
    /// Elderwood; bosses are the biome's set-piece encounters, not placed as roamers.
    /// </summary>
    public static readonly TerritoryDefinition SunkenReach = new()
    {
        Id = "sunken_reach",
        DisplayName = "the Sunken Reach",
        ScenePath = "res://scenes/territory/sunken_reach.tscn",
        Nodes = new[]
        {
            new TerritoryNode { NodeId = "iron_1", ResourceId = "bog_iron_deposit" },
            new TerritoryNode { NodeId = "iron_2", ResourceId = "bog_iron_deposit" },
            new TerritoryNode { NodeId = "bogwood_1", ResourceId = "bogwood_stand" },
            new TerritoryNode { NodeId = "bogwood_2", ResourceId = "bogwood_stand" },
            new TerritoryNode { NodeId = "mossbed_1", ResourceId = "bog_moss_patch" },
            new TerritoryNode { NodeId = "mossbed_2", ResourceId = "bog_moss_patch" },
            new TerritoryNode { NodeId = "reed_1", ResourceId = "marsh_reed_patch" },
            new TerritoryNode { NodeId = "reed_2", ResourceId = "marsh_reed_patch" },
            new TerritoryNode { NodeId = "bitter_root_1", ResourceId = "bitter_root_patch" },
            new TerritoryNode { NodeId = "nightcap_1", ResourceId = "nightcap_mushroom_patch" },
        },
        Roamers = new[]
        {
            new TerritoryRoamer
            {
                RoamerId = "mudclaw_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "mudclaw_hunting_pair", Weight = 3 },
                    new WeightedEncounter { EncounterId = "mudclaw_ambush", Weight = 2 },
                    new WeightedEncounter { EncounterId = "mudclaw_elite_silt_reaver", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "mudclaw_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "mudclaw_hunting_pair", Weight = 2 },
                    new WeightedEncounter { EncounterId = "mudclaw_ambush", Weight = 3 },
                    new WeightedEncounter { EncounterId = "mudclaw_elite_silt_reaver", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "serpent_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "marsh_serpent", Weight = 3 },
                    new WeightedEncounter { EncounterId = "nest_of_serpents", Weight = 2 },
                    new WeightedEncounter { EncounterId = "marsh_serpent_elite_coildancer", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "serpent_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "marsh_serpent", Weight = 2 },
                    new WeightedEncounter { EncounterId = "nest_of_serpents", Weight = 3 },
                    new WeightedEncounter { EncounterId = "marsh_serpent_elite_coildancer", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "fungus_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "bloom_cluster", Weight = 3 },
                    new WeightedEncounter { EncounterId = "spore_swarm", Weight = 2 },
                    new WeightedEncounter { EncounterId = "bog_fungus_elite_bloomcap", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "fungus_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "bloom_cluster", Weight = 2 },
                    new WeightedEncounter { EncounterId = "spore_swarm", Weight = 3 },
                    new WeightedEncounter { EncounterId = "bog_fungus_elite_bloomcap", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "drowned_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "drowned_wanderer", Weight = 3 },
                    new WeightedEncounter { EncounterId = "drowned_procession", Weight = 2 },
                    new WeightedEncounter { EncounterId = "drowned_elite_deep_keeper", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "drowned_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "drowned_wanderer", Weight = 2 },
                    new WeightedEncounter { EncounterId = "drowned_procession", Weight = 3 },
                    new WeightedEncounter { EncounterId = "drowned_elite_deep_keeper", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "drake_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "swamp_drake", Weight = 3 },
                    new WeightedEncounter { EncounterId = "drake_pair", Weight = 2 },
                    new WeightedEncounter { EncounterId = "swamp_drake_elite_ironjaw", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "drake_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "swamp_drake", Weight = 2 },
                    new WeightedEncounter { EncounterId = "drake_pair", Weight = 3 },
                    new WeightedEncounter { EncounterId = "swamp_drake_elite_ironjaw", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "wisp_1",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "marsh_wisp", Weight = 3 },
                    new WeightedEncounter { EncounterId = "wisp_cluster", Weight = 2 },
                    new WeightedEncounter { EncounterId = "marsh_wisp_elite_lantern", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "wisp_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "marsh_wisp", Weight = 2 },
                    new WeightedEncounter { EncounterId = "wisp_cluster", Weight = 3 },
                    new WeightedEncounter { EncounterId = "marsh_wisp_elite_lantern", Weight = 1 },
                },
            },
        },
    };

    private static readonly DefinitionRegistry<TerritoryDefinition> Registry = new(d => d.Id,
        Forest, Elderwood, SunkenReach);

    public static IReadOnlyCollection<TerritoryDefinition> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static TerritoryDefinition Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out TerritoryDefinition def) => Registry.TryGet(id, out def);
}
