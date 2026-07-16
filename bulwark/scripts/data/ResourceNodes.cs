using System.Collections.Generic;
using Bulwark.Cozy;

namespace Bulwark.Data;

/// <summary>
/// Declarative definition of a harvestable territory resource node. Data-only per CLAUDE.md —
/// adding a node type touches <see cref="ResourceNodes"/> only, no system code. Harvest costs
/// game-minutes through the day clock (the PF2e exploration-activity seam), not real time.
/// </summary>
public sealed class ResourceNodeDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Tool-belt verb required to harvest (Hand = forage).</summary>
    public required ToolKind Tool { get; init; }

    /// <summary>Item added to the shared inventory on harvest (an <see cref="ItemDefinition.Id"/>).</summary>
    public required string YieldItemId { get; init; }

    /// <summary>How many yield items one harvest produces.</summary>
    public int YieldCount { get; init; } = 1;

    /// <summary>Game-minutes the harvest interaction costs (charged via DayClock.SpendTime).</summary>
    public int HarvestMinutes { get; init; } = 10;

    /// <summary>
    /// Respawn window lower bound, in days after depletion (design/forage.md). Fixed-cadence nodes
    /// use min == max: 1/1 = the next morning (the old RespawnsDaily=true behavior), 0/0 = never
    /// (one-shot). Trees roll a random 7–14. The actual day is rolled AT HARVEST TIME from the
    /// save's deterministic RNG seam and persisted — never re-rolled on load.
    /// </summary>
    public int RespawnDaysMin { get; init; } = 1;

    /// <summary>Respawn window upper bound (see <see cref="RespawnDaysMin"/>); max &lt;= 0 = never.</summary>
    public int RespawnDaysMax { get; init; } = 1;

    /// <summary>
    /// Prefab scene the world instantiates for this node (scenes/territory/nodes/*.tscn with real
    /// art), or null for the placeholder token scene (scenes/territory/resource_node.tscn).
    /// Data-only per CLAUDE.md: a new node type declares its prefab here — no system code changes.
    /// </summary>
    public string? ScenePath { get; init; }
}

/// <summary>Static registry of resource-node definitions. T1 MVP set; additions are data-only.</summary>
public static class ResourceNodes
{
    public static readonly ResourceNodeDefinition Rock = new()
    {
        Id = "rock", DisplayName = "Rock", Tool = ToolKind.Pick,
        YieldItemId = "stone", YieldCount = 2, HarvestMinutes = 15,
        ScenePath = "res://scenes/territory/nodes/node_rock.tscn",
    };

    public static readonly ResourceNodeDefinition HerbPatch = new()
    {
        Id = "herb_patch", DisplayName = "Herb Patch", Tool = ToolKind.Hand,
        YieldItemId = "herb", YieldCount = 2, HarvestMinutes = 10,
        ScenePath = "res://scenes/territory/nodes/node_herb_patch.tscn",
    };

    public static readonly ResourceNodeDefinition BerryBush = new()
    {
        Id = "berry_bush", DisplayName = "Berry Bush", Tool = ToolKind.Hand,
        YieldItemId = "berries", YieldCount = 3, HarvestMinutes = 10,
        ScenePath = "res://scenes/territory/nodes/node_berry_bush.tscn",
    };

    // One-shot windfall: once collected it does not respawn (exercises RespawnDays 0/0 = never).
    public static readonly ResourceNodeDefinition FallenWood = new()
    {
        Id = "fallen_wood", DisplayName = "Fallen Wood", Tool = ToolKind.Axe,
        YieldItemId = "wood", YieldCount = 2, HarvestMinutes = 15,
        RespawnDaysMin = 0, RespawnDaysMax = 0,
        ScenePath = "res://scenes/territory/nodes/node_fallen_wood.tscn",
    };

    // --- Choppable trees (design/forage.md): first-class Axe nodes with real art. Stardew-scale
    //     yield (a full tree ≈ 10 wood) with a random 7–14 day regrow (rolled at chop time) so
    //     wood stays a gathering trip, not a daily faucet — the forest carries enough trees that
    //     the long window still leaves plenty standing. Multiple prefab variants share these two
    //     definitions (round/autumn/medium canopies = forest_tree; the pines = pine_tree). ---
    public static readonly ResourceNodeDefinition ForestTree = new()
    {
        Id = "forest_tree", DisplayName = "Tree", Tool = ToolKind.Axe,
        YieldItemId = "wood", YieldCount = 10, HarvestMinutes = 20,
        RespawnDaysMin = 7, RespawnDaysMax = 14,
        ScenePath = "res://scenes/territory/nodes/tree_round.tscn",
    };

    public static readonly ResourceNodeDefinition PineTree = new()
    {
        Id = "pine_tree", DisplayName = "Pine Tree", Tool = ToolKind.Axe,
        YieldItemId = "wood", YieldCount = 10, HarvestMinutes = 20,
        RespawnDaysMin = 7, RespawnDaysMax = 14,
        ScenePath = "res://scenes/territory/nodes/tree_pine_tall.tscn",
    };

    // --- Verdant Fringe content-flag closures (materials.md): copper_ore and fiber previously had
    //     item defs with no gather source; these two nodes close that gap. ---
    public static readonly ResourceNodeDefinition CopperVein = new()
    {
        Id = "copper_vein", DisplayName = "Copper Vein", Tool = ToolKind.Pick,
        YieldItemId = "copper_ore", YieldCount = 8, HarvestMinutes = 15,
        ScenePath = "res://scenes/territory/nodes/node_copper_vein.tscn",
    };

    public static readonly ResourceNodeDefinition BramblePatch = new()
    {
        Id = "bramble_patch", DisplayName = "Bramble Patch", Tool = ToolKind.Hand,
        YieldItemId = "fiber", YieldCount = 3, HarvestMinutes = 10,
        ScenePath = "res://scenes/territory/nodes/node_bramble_patch.tscn",
    };

    // --- Elderwood nodes (materials.md families 2 + 3), gated behind the Command Post's Elderwood
    //     unlock per the doc's acquisition-route notes. ---
    public static readonly ResourceNodeDefinition ElderwoodTreeStand = new()
    {
        Id = "elderwood_tree_stand", DisplayName = "Elderwood Tree Stand", Tool = ToolKind.Axe,
        YieldItemId = "hardwood", YieldCount = 12, HarvestMinutes = 15,
    };

    public static readonly ResourceNodeDefinition ElderwoodCoalSeam = new()
    {
        Id = "elderwood_coal_seam", DisplayName = "Elderwood Coal Seam", Tool = ToolKind.Pick,
        YieldItemId = "coal", YieldCount = 8, HarvestMinutes = 15,
    };

    public static readonly ResourceNodeDefinition WildMushroomPatch = new()
    {
        Id = "wild_mushroom_patch", DisplayName = "Wild Mushroom Patch", Tool = ToolKind.Hand,
        YieldItemId = "wild_mushroom", YieldCount = 3, HarvestMinutes = 10,
        ScenePath = "res://scenes/territory/nodes/node_mushroom_patch.tscn",
    };

    public static readonly ResourceNodeDefinition ForestRootPatch = new()
    {
        Id = "forest_root_patch", DisplayName = "Forest Root Patch", Tool = ToolKind.Hand,
        YieldItemId = "forest_root", YieldCount = 2, HarvestMinutes = 10,
        ScenePath = "res://scenes/territory/nodes/node_forest_root.tscn",
    };

    // Rare Elderwood forage, gated behind the far-forest campsite discovery per materials.md.
    public static readonly ResourceNodeDefinition WardSaltDeposit = new()
    {
        Id = "ward_salt_deposit", DisplayName = "Ward Salt Deposit", Tool = ToolKind.Hand,
        YieldItemId = "ward_salt", YieldCount = 2, HarvestMinutes = 10,
    };

    // Rare Elderwood forage node: the second of arcane_essence's two sources (the other being the
    // Apothecary T2 reagent-refining recipe from nightcap_mushroom — see Recipes.ArcaneEssence).
    public static readonly ResourceNodeDefinition LeyGlade = new()
    {
        Id = "ley_glade", DisplayName = "Ley Glade", Tool = ToolKind.Hand,
        YieldItemId = "arcane_essence", YieldCount = 2, HarvestMinutes = 10,
    };

    // --- Sunken Reach nodes (materials.md families 2 + 3), gated behind the Command Post's Sunken
    //     Reach unlock per the doc's acquisition-route notes. ---
    public static readonly ResourceNodeDefinition BogIronDeposit = new()
    {
        Id = "bog_iron_deposit", DisplayName = "Bog-Iron Deposit", Tool = ToolKind.Pick,
        YieldItemId = "iron_ore", YieldCount = 8, HarvestMinutes = 15,
    };

    public static readonly ResourceNodeDefinition DrownedTreeStand = new()
    {
        Id = "drowned_tree_stand", DisplayName = "Drowned-Tree Stand", Tool = ToolKind.Axe,
        YieldItemId = "bogwood", YieldCount = 12, HarvestMinutes = 15,
    };

    public static readonly ResourceNodeDefinition BogMossPatch = new()
    {
        Id = "bog_moss_patch", DisplayName = "Bog Moss Patch", Tool = ToolKind.Hand,
        YieldItemId = "bog_moss", YieldCount = 3, HarvestMinutes = 10,
    };

    public static readonly ResourceNodeDefinition MarshReedPatch = new()
    {
        Id = "marsh_reed_patch", DisplayName = "Marsh Reed Patch", Tool = ToolKind.Hand,
        YieldItemId = "marsh_reed", YieldCount = 3, HarvestMinutes = 10,
    };

    // Deep Sunken Reach forage, gated behind further zone exploration per materials.md.
    public static readonly ResourceNodeDefinition BitterRootPatch = new()
    {
        Id = "bitter_root_patch", DisplayName = "Bitter Root Patch", Tool = ToolKind.Hand,
        YieldItemId = "bitter_root", YieldCount = 2, HarvestMinutes = 10,
    };

    // The deepest, rarest Sunken Reach forage — gated behind further zone exploration, same as
    // ward_salt in the Elderwood.
    public static readonly ResourceNodeDefinition NightcapMushroomPatch = new()
    {
        Id = "nightcap_mushroom_patch", DisplayName = "Nightcap Mushroom Patch", Tool = ToolKind.Hand,
        YieldItemId = "nightcap_mushroom", YieldCount = 2, HarvestMinutes = 10,
    };

    // --- Debris (design/forage.md, third category): Stardew-style clutter. One-hit quick clears
    //     (5 min, 1 yield) that NEVER respawn in place (0/0) — new debris only ever comes from the
    //     ForageSystem debris pass, which accumulates pieces to its cap until the player clears
    //     them. Clearing the map IS the gameplay. ---
    public static readonly ResourceNodeDefinition LooseStones = new()
    {
        Id = "loose_stones", DisplayName = "Loose Stones", Tool = ToolKind.Pick,
        YieldItemId = "stone", YieldCount = 1, HarvestMinutes = 5,
        RespawnDaysMin = 0, RespawnDaysMax = 0,
        ScenePath = "res://scenes/territory/nodes/node_loose_stones.tscn",
    };

    public static readonly ResourceNodeDefinition FallenBranch = new()
    {
        Id = "fallen_branch", DisplayName = "Fallen Branch", Tool = ToolKind.Axe,
        YieldItemId = "wood", YieldCount = 1, HarvestMinutes = 5,
        RespawnDaysMin = 0, RespawnDaysMax = 0,
        ScenePath = "res://scenes/territory/nodes/node_fallen_branch.tscn",
    };

    public static readonly ResourceNodeDefinition ScrubWeeds = new()
    {
        Id = "scrub_weeds", DisplayName = "Scrub Weeds", Tool = ToolKind.Hand,
        YieldItemId = "fiber", YieldCount = 1, HarvestMinutes = 5,
        RespawnDaysMin = 0, RespawnDaysMax = 0,
        ScenePath = "res://scenes/territory/nodes/node_scrub_weeds.tscn",
    };

    private static readonly DefinitionRegistry<ResourceNodeDefinition> Registry = new(d => d.Id,
        Rock, HerbPatch, BerryBush, FallenWood,
        ForestTree, PineTree,
        CopperVein, BramblePatch,
        ElderwoodTreeStand, ElderwoodCoalSeam, WildMushroomPatch, ForestRootPatch, WardSaltDeposit, LeyGlade,
        BogIronDeposit, DrownedTreeStand, BogMossPatch, MarshReedPatch, BitterRootPatch, NightcapMushroomPatch,
        LooseStones, FallenBranch, ScrubWeeds);

    public static IReadOnlyCollection<ResourceNodeDefinition> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static ResourceNodeDefinition Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out ResourceNodeDefinition def) => Registry.TryGet(id, out def);
}
