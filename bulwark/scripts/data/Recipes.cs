using System;
using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// One input a recipe consumes. Either a specific item (<see cref="ItemId"/>) or any item from a
/// category (<see cref="CategoryWildcard"/>). Exactly one must be set. When a wildcard is used,
/// the crafting system picks the first held item that matches at craft time.
/// </summary>
public sealed class RecipeInput
{
    /// <summary>Specific item id, or null when <see cref="CategoryWildcard"/> is set.</summary>
    public string? ItemId { get; init; }

    /// <summary>When set, any item whose <see cref="ItemCategory"/> matches is accepted.</summary>
    public ItemCategory? CategoryWildcard { get; init; }

    public required int Quantity { get; init; }

    public bool IsWildcard => CategoryWildcard != null;
}

/// <summary>
/// Declarative definition of a single crafting recipe — the raw→refined artisan chains and the
/// kitchen's meals (Phase 5). Data-only per CLAUDE.md: adding a recipe touches <see cref="Recipes"/>
/// only, no system code. <see cref="Bulwark.Cozy.CraftingSystem"/> validates + executes it.
///
/// GATING: <see cref="RequiredCategory"/> is a Phase-4 CategoryUnlock id a station BUILDING grants
/// (reusing GameState.IsCategoryUnlocked). <c>null</c> = ALWAYS craftable baseline (no station needed —
/// e.g. plank/cut_stone); a non-null id gates the recipe behind that station's category (smelter,
/// tanner, still, loom, meals/Tavern). Phase 5 does NOT ship station-building content — the user wires the
/// station buildings (which declare the matching CategoryUnlock effect) later; until then the gated
/// recipes are simply unavailable, and the spike proves the gate with a synthetic unlock.
/// </summary>
public sealed class RecipeDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Inputs consumed per craft (each scaled by the craft count).</summary>
    public required IReadOnlyList<RecipeInput> Inputs { get; init; }

    /// <summary>The produced item id (must be an <see cref="Items"/> id).</summary>
    public required string OutputItemId { get; init; }

    /// <summary>Units of <see cref="OutputItemId"/> produced per craft.</summary>
    public int OutputQuantity { get; init; } = 1;

    /// <summary>In-game minutes one craft costs (charged via <see cref="Bulwark.Cozy.DayClock"/>).</summary>
    public required int CraftMinutes { get; init; }

    /// <summary>
    /// CategoryUnlock id gating this recipe, or null for the always-craftable baseline. See the class
    /// summary — a station building grants the category (Phase 4 effect), and the crafting system asks
    /// GameState.IsCategoryUnlocked to gate.
    /// </summary>
    public string? RequiredCategory { get; init; }

    /// <summary>True when this recipe needs no station (baseline).</summary>
    public bool IsBaseline => RequiredCategory == null;
}

/// <summary>
/// Static registry of every crafting recipe. The Phase-5 PROVING SET only — the framework is
/// data-driven so the user extends the catalog here. Two baseline refined chains (plank, cut_stone)
/// need no station; the rest gate on their station's CategoryUnlock id (smelter/tanner/still/loom),
/// and the meals gate on "meals" (the Tavern's tier-1 CategoryUnlock detail — see Buildings.Tavern).
/// </summary>
public static class Recipes
{
    // Station CategoryUnlock ids the gated recipes reference. A station BUILDING (authored later by
    // the user) declares a matching BuildingEffectType.CategoryUnlock effect with these Detail ids.
    public const string SmelterCategory = "smelter";
    public const string TannerCategory = "tanner";
    public const string StillCategory = "still";
    public const string LoomCategory = "loom";
    // "meals" (not "tavern") — matches the Tavern tier-1 effect's Detail (Buildings.cs), which is what
    // GameState.IsCategoryUnlocked actually gets asked about at craft time.
    public const string TavernCategory = "meals";
    public const string ApothecaryCategory = "apothecary";

    // ---- Refined chains: baseline (no station) ----
    public static readonly RecipeDefinition Plank = new()
    {
        Id = "craft_plank", DisplayName = "Plank",
        Inputs = new RecipeInput[] { new() { ItemId = "wood", Quantity = 2 } },
        OutputItemId = "plank", OutputQuantity = 1, CraftMinutes = 10,
    };
    public static readonly RecipeDefinition CutStone = new()
    {
        Id = "craft_cut_stone", DisplayName = "Cut Stone",
        Inputs = new RecipeInput[] { new() { ItemId = "stone", Quantity = 2 } },
        OutputItemId = "cut_stone", OutputQuantity = 1, CraftMinutes = 10,
    };

    // ---- Refined chains: station-gated ----
    public static readonly RecipeDefinition CopperIngot = new()
    {
        Id = "craft_copper_ingot", DisplayName = "Copper Ingot",
        Inputs = new RecipeInput[] { new() { ItemId = "copper_ore", Quantity = 2 } },
        OutputItemId = "copper_ingot", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = SmelterCategory,
    };
    public static readonly RecipeDefinition Leather = new()
    {
        Id = "craft_leather", DisplayName = "Leather",
        Inputs = new RecipeInput[] { new() { ItemId = "beast_hide", Quantity = 1 } },
        OutputItemId = "leather", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = TannerCategory,
    };
    public static readonly RecipeDefinition Tincture = new()
    {
        Id = "craft_tincture", DisplayName = "Tincture",
        Inputs = new RecipeInput[] { new() { ItemId = "herb", Quantity = 2 } },
        OutputItemId = "tincture", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = StillCategory,
    };
    public static readonly RecipeDefinition Cloth = new()
    {
        Id = "craft_cloth", DisplayName = "Cloth",
        Inputs = new RecipeInput[] { new() { ItemId = "fiber", Quantity = 3 } },
        OutputItemId = "cloth", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = LoomCategory,
    };

    // --- materials.md family 3/9 addition: the Elderwood/Sunken Reach ore ceiling. Smelter T2 per the
    //     catalog; the RequiredCategory schema has no tier field, so this gates on the same SmelterCategory
    //     as CopperIngot (the building ladder's own T2 tier check happens at the CategoryUnlock effect,
    //     authored later alongside the smelter building). ---
    public static readonly RecipeDefinition IronIngot = new()
    {
        Id = "craft_iron_ingot", DisplayName = "Iron Ingot",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "iron_ore", Quantity = 2 },
            new() { ItemId = "coal", Quantity = 1 },
        },
        OutputItemId = "iron_ingot", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = SmelterCategory,
    };

    // --- Husbandry/apiary refined goods (materials.md families 5/6/9), all tavern/still/loom-gated
    //     the same way the Phase-5 chains above are. ---
    public static readonly RecipeDefinition Cheese = new()
    {
        Id = "craft_cheese", DisplayName = "Cheese",
        Inputs = new RecipeInput[] { new() { ItemId = "milk", Quantity = 2 } },
        OutputItemId = "cheese", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = TavernCategory,
    };
    public static readonly RecipeDefinition Butter = new()
    {
        Id = "craft_butter", DisplayName = "Butter",
        Inputs = new RecipeInput[] { new() { ItemId = "cream", Quantity = 2 } },
        OutputItemId = "butter", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = TavernCategory,
    };
    public static readonly RecipeDefinition SpunYarn = new()
    {
        Id = "craft_spun_yarn", DisplayName = "Spun Yarn",
        Inputs = new RecipeInput[] { new() { ItemId = "wool", Quantity = 2 } },
        OutputItemId = "spun_yarn", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = LoomCategory,
    };
    public static readonly RecipeDefinition Mead = new()
    {
        Id = "craft_mead", DisplayName = "Mead",
        Inputs = new RecipeInput[] { new() { ItemId = "honey", Quantity = 2 } },
        OutputItemId = "mead", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = StillCategory,
    };

    // --- Apothecary T2 reagent refining (materials.md families 2/7/10). Closes the arcane_essence
    //     content flag's second route (the first being ResourceNodes.LeyGlade) and wires spirit_dust's
    //     only source. Gated on ApothecaryCategory, a new station category alongside smelter/tanner/
    //     still/loom/tavern — no Apothecary building ships this pass; the category is data-only until
    //     one is authored, same as the other station categories above. ---
    public static readonly RecipeDefinition ArcaneEssence = new()
    {
        Id = "craft_arcane_essence", DisplayName = "Arcane Essence",
        Inputs = new RecipeInput[] { new() { ItemId = "nightcap_mushroom", Quantity = 2 } },
        OutputItemId = "arcane_essence", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = ApothecaryCategory,
    };
    public static readonly RecipeDefinition SpiritDust = new()
    {
        Id = "craft_spirit_dust", DisplayName = "Spirit Dust",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "drowned_bone", Quantity = 1 },
            new() { ItemId = "bog_moss", Quantity = 2 },
        },
        OutputItemId = "spirit_dust", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = ApothecaryCategory,
    };

    // ---- Wildcard-input refined chain: any fish → smoked fish (tavern-gated) ----
    public static readonly RecipeDefinition SmokedFish = new()
    {
        Id = "craft_smoked_fish", DisplayName = "Smoked Fish",
        Inputs = new RecipeInput[] { new() { CategoryWildcard = ItemCategory.Fish, Quantity = 1 } },
        OutputItemId = "smoked_fish", OutputQuantity = 1, CraftMinutes = 15,
        RequiredCategory = TavernCategory,
    };

    // ---- Meals: tavern-gated (output is a Food item that Meals maps to a day-long buff) ----
    public static readonly RecipeDefinition HeartyStew = new()
    {
        Id = "cook_hearty_stew", DisplayName = "Hearty Stew",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "potato", Quantity = 2 },
            new() { ItemId = "wheat", Quantity = 1 },
        },
        OutputItemId = "hearty_stew", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = TavernCategory,
    };
    public static readonly RecipeDefinition HerbTonic = new()
    {
        Id = "cook_herb_tonic", DisplayName = "Herb Tonic",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "herb", Quantity = 2 },
            new() { ItemId = "berries", Quantity = 1 },
        },
        OutputItemId = "herb_tonic", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = TavernCategory,
    };
    public static readonly RecipeDefinition TravelRation = new()
    {
        Id = "cook_travel_ration", DisplayName = "Travel Ration",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "wheat", Quantity = 2 },
            new() { ItemId = "berries", Quantity = 2 },
        },
        OutputItemId = "travel_ration", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = TavernCategory,
    };

    public static readonly RecipeDefinition BattleDraught = new()
    {
        Id = "cook_battle_draught", DisplayName = "Battle Draught",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "tomato", Quantity = 2 },
            new() { ItemId = "herb", Quantity = 1 },
        },
        OutputItemId = "battle_draught", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = TavernCategory,
    };
    public static readonly RecipeDefinition GuardRation = new()
    {
        Id = "cook_guard_ration", DisplayName = "Guard Ration",
        Inputs = new RecipeInput[]
        {
            new() { ItemId = "potato", Quantity = 2 },
            new() { ItemId = "berries", Quantity = 1 },
        },
        OutputItemId = "guard_ration", OutputQuantity = 1, CraftMinutes = 20,
        RequiredCategory = TavernCategory,
    };

    private static readonly DefinitionRegistry<RecipeDefinition> Registry = new(d => d.Id,
        Plank, CutStone,
        CopperIngot, Leather, Tincture, Cloth, IronIngot,
        Cheese, Butter, SpunYarn, Mead,
        ArcaneEssence, SpiritDust,
        SmokedFish,
        HeartyStew, HerbTonic, TravelRation, BattleDraught, GuardRation);

    /// <summary>Every defined recipe.</summary>
    public static IReadOnlyCollection<RecipeDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined recipe.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a recipe by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static RecipeDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out RecipeDefinition def) => Registry.TryGet(id, out def);
}
