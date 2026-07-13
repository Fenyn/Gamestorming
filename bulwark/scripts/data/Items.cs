using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>Broad classification an item falls under, used for UI grouping and validation.</summary>
public enum ItemCategory
{
    Crop,
    Seed,
    Resource,
    Tool,

    /// <summary>Combat loot butchered from defeated creatures — smithy/alchemy mats and sale fodder.</summary>
    MonsterPart,

    /// <summary>Refined artisan good crafted from raw resources at a station (plank, ingot, leather,
    /// tincture, cloth). Phase-5 crafting output; consumed by construction bundles + advanced recipes.</summary>
    Refined,

    /// <summary>A MAGICAL (non-metal) crafting reagent — the abstracted rune material. Runes are a
    /// magical enchantment layer on equipment, so rune application at the smithy consumes a magical
    /// reagent (arcane_essence), NOT metal. Kept broad/abstracted: one reagent drives runes generally.</summary>
    Reagent,

    /// <summary>A prepared meal crafted at the kitchen. Eating one applies a day-long roster buff
    /// (see <see cref="Bulwark.Data.Meals"/>). Phase-5 provision layer.</summary>
    Food,

    /// <summary>A per-fight / instant consumable used IN COMBAT as an action (or out of combat) — healing
    /// potion, combat elixir, antidote. Its effect(s) are defined in <see cref="Bulwark.Data.Consumables"/>
    /// and applied via <see cref="Bulwark.Cozy.ConsumableSystem"/>. Distinct from day-long <see cref="Food"/>
    /// meals. Apothecary/Lab domain. (Poisons deferred — framework only, no poison content.)</summary>
    Consumable,
}

/// <summary>
/// Declarative definition of a single item. Data-only per CLAUDE.md — adding an item touches
/// <see cref="Items"/> only, no system code. Seed items point at the crop they plant via
/// <see cref="CropId"/> (a <see cref="CropDefinition.Id"/>).
/// </summary>
public sealed class ItemDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public required ItemCategory Category { get; init; }

    /// <summary>Whether copies collapse into a single counted stack. Non-stackables count as 1 each.</summary>
    public bool Stackable { get; init; } = true;

    /// <summary>For <see cref="ItemCategory.Seed"/> items: the crop id this seed plants. Null otherwise.</summary>
    public string? CropId { get; init; }

    /// <summary>
    /// Gold gained per unit when sold at the smithy (Phase 1 economy). 0 = unsellable. Currency is
    /// tracked by the dedicated <see cref="Bulwark.Cozy.Wallet"/>, not as an inventory stack.
    /// </summary>
    public int SellValue { get; init; }

    /// <summary>
    /// PF2e Bulk of one unit — what the per-member carry system (<see cref="Bulwark.Cozy.Inventory"/>)
    /// sums against each member's Strength-derived limit. PF2e scale: Light = 0.1 (10 Light = 1 Bulk),
    /// negligible = 0. Default is Light (0.1) so forageables/seeds/herbs/berries/mushrooms/fiber and
    /// monster parts stay cheap to haul; bulky raw building materials (wood/stone/ore/plank/ingot)
    /// override to ≈1. Tuned so weight matters but early gathering isn't punishing.
    /// </summary>
    public float Bulk { get; init; } = 0.1f;
}

/// <summary>
/// Static registry of every item definition in the game. Starter content only for M2; further
/// items are data-only additions here.
/// </summary>
public static class Items
{
    // --- Seeds (reference a crop id) ---
    public static readonly ItemDefinition TurnipSeed = new()
    {
        Id = "turnip_seed", DisplayName = "Turnip Seeds", Category = ItemCategory.Seed, CropId = "turnip",
    };
    public static readonly ItemDefinition PotatoSeed = new()
    {
        Id = "potato_seed", DisplayName = "Potato Seeds", Category = ItemCategory.Seed, CropId = "potato",
    };
    public static readonly ItemDefinition WheatSeed = new()
    {
        Id = "wheat_seed", DisplayName = "Wheat Seeds", Category = ItemCategory.Seed, CropId = "wheat",
    };
    public static readonly ItemDefinition TomatoSeed = new()
    {
        Id = "tomato_seed", DisplayName = "Tomato Seeds", Category = ItemCategory.Seed, CropId = "tomato",
    };

    // --- Crops (harvest yields; modest sale value — surplus feeds the gold economy) ---
    public static readonly ItemDefinition Turnip = new()
    {
        Id = "turnip", DisplayName = "Turnip", Category = ItemCategory.Crop, SellValue = 3,
    };
    public static readonly ItemDefinition Potato = new()
    {
        Id = "potato", DisplayName = "Potato", Category = ItemCategory.Crop, SellValue = 4,
    };
    public static readonly ItemDefinition Wheat = new()
    {
        Id = "wheat", DisplayName = "Wheat", Category = ItemCategory.Crop, SellValue = 5,
    };
    public static readonly ItemDefinition Tomato = new()
    {
        Id = "tomato", DisplayName = "Tomato", Category = ItemCategory.Crop, SellValue = 6,
    };

    // --- Raw resources (modest sale value; consumed by construction bundles later) ---
    public static readonly ItemDefinition Wood = new()
    {
        Id = "wood", DisplayName = "Wood", Category = ItemCategory.Resource, SellValue = 1, Bulk = 1f,
    };
    public static readonly ItemDefinition Stone = new()
    {
        Id = "stone", DisplayName = "Stone", Category = ItemCategory.Resource, SellValue = 1, Bulk = 1f,
    };
    public static readonly ItemDefinition Herb = new()
    {
        Id = "herb", DisplayName = "Herbs", Category = ItemCategory.Resource, SellValue = 2,
    };
    public static readonly ItemDefinition Berries = new()
    {
        Id = "berries", DisplayName = "Berries", Category = ItemCategory.Resource, SellValue = 2,
    };

    // --- New raw gathered resources (Phase 5 chains). copper_ore + fiber gate refined goods;
    //     see the CONTENT FLAG in the phase report — the item defs exist so the chains are complete,
    //     but no forest gather node places copper_ore/fiber yet (data-only until a node is authored). ---
    public static readonly ItemDefinition CopperOre = new()
    {
        Id = "copper_ore", DisplayName = "Copper Ore", Category = ItemCategory.Resource, SellValue = 2, Bulk = 1f,
    };
    public static readonly ItemDefinition Fiber = new()
    {
        Id = "fiber", DisplayName = "Fiber", Category = ItemCategory.Resource, SellValue = 1,
    };

    // --- Refined artisan goods (Phase 5 crafting output). Bulky mats (plank/cut_stone/ingot) ≈ 1 Bulk;
    //     soft goods (leather/tincture/cloth) stay Light. SellValue > the raw inputs' combined value. ---
    public static readonly ItemDefinition Plank = new()
    {
        Id = "plank", DisplayName = "Plank", Category = ItemCategory.Refined, SellValue = 3, Bulk = 1f,
    };
    public static readonly ItemDefinition CutStone = new()
    {
        Id = "cut_stone", DisplayName = "Cut Stone", Category = ItemCategory.Refined, SellValue = 3, Bulk = 1f,
    };
    public static readonly ItemDefinition CopperIngot = new()
    {
        Id = "copper_ingot", DisplayName = "Copper Ingot", Category = ItemCategory.Refined, SellValue = 6, Bulk = 1f,
    };
    public static readonly ItemDefinition Leather = new()
    {
        Id = "leather", DisplayName = "Leather", Category = ItemCategory.Refined, SellValue = 12,
    };
    public static readonly ItemDefinition Tincture = new()
    {
        Id = "tincture", DisplayName = "Tincture", Category = ItemCategory.Refined, SellValue = 6,
    };
    public static readonly ItemDefinition Cloth = new()
    {
        Id = "cloth", DisplayName = "Cloth", Category = ItemCategory.Refined, SellValue = 5,
    };

    // --- Meals (Phase 5 kitchen output; eating applies a day-long roster buff via Meals). Light Bulk. ---
    public static readonly ItemDefinition HeartyStew = new()
    {
        Id = "hearty_stew", DisplayName = "Hearty Stew", Category = ItemCategory.Food, SellValue = 8,
    };
    public static readonly ItemDefinition HerbTonic = new()
    {
        Id = "herb_tonic", DisplayName = "Herb Tonic", Category = ItemCategory.Food, SellValue = 8,
    };
    public static readonly ItemDefinition TravelRation = new()
    {
        Id = "travel_ration", DisplayName = "Travel Ration", Category = ItemCategory.Food, SellValue = 6,
    };
    public static readonly ItemDefinition BattleDraught = new()
    {
        Id = "battle_draught", DisplayName = "Battle Draught", Category = ItemCategory.Food, SellValue = 10,
    };
    public static readonly ItemDefinition GuardRation = new()
    {
        Id = "guard_ration", DisplayName = "Guard Ration", Category = ItemCategory.Food, SellValue = 10,
    };

    // --- Magical reagent (Refinement 3: the abstracted RUNE material — magical, non-metal, Light Bulk).
    //     Rune application at the smithy consumes gold + N arcane_essence. CONTENT FLAG: no forest gather
    //     node produces arcane_essence yet — the item def exists so the rune-cost chain is complete, but a
    //     source (magical forage/harvest node, like the pending copper_ore/fiber nodes) must be authored to
    //     make it reachable in play. SellValue modest; tunable. ---
    public static readonly ItemDefinition ArcaneEssence = new()
    {
        Id = "arcane_essence", DisplayName = "Arcane Essence", Category = ItemCategory.Reagent, SellValue = 10,
    };

    // --- Per-fight consumables (Apothecary/Lab; used in combat as an action or out of combat).
    //     Effects defined in Consumables; applied via ConsumableSystem. Light Bulk (0.1) — easy to carry. ---
    public static readonly ItemDefinition MinorHealingPotion = new()
    {
        Id = "minor_healing_potion", DisplayName = "Minor Healing Potion", Category = ItemCategory.Consumable, SellValue = 4,
    };
    public static readonly ItemDefinition GuardianElixir = new()
    {
        Id = "guardian_elixir", DisplayName = "Guardian Elixir", Category = ItemCategory.Consumable, SellValue = 3,
    };
    public static readonly ItemDefinition Antidote = new()
    {
        Id = "antidote", DisplayName = "Antidote", Category = ItemCategory.Consumable, SellValue = 3,
    };

    // --- Combat drops (monster parts — smithy/alchemy mats + sale fodder) ---
    public static readonly ItemDefinition GoblinFang = new()
    {
        Id = "goblin_fang", DisplayName = "Goblin Fang", Category = ItemCategory.MonsterPart, SellValue = 5,
    };
    public static readonly ItemDefinition RatPelt = new()
    {
        Id = "rat_pelt", DisplayName = "Rat Pelt", Category = ItemCategory.MonsterPart, SellValue = 3,
    };
    public static readonly ItemDefinition BeastHide = new()
    {
        Id = "beast_hide", DisplayName = "Beast Hide", Category = ItemCategory.MonsterPart, SellValue = 8,
    };

    private static readonly DefinitionRegistry<ItemDefinition> Registry = new(d => d.Id,
        TurnipSeed, PotatoSeed, WheatSeed, TomatoSeed,
        Turnip, Potato, Wheat, Tomato,
        Wood, Stone, Herb, Berries,
        CopperOre, Fiber,
        Plank, CutStone, CopperIngot, Leather, Tincture, Cloth,
        ArcaneEssence,
        HeartyStew, HerbTonic, TravelRation, BattleDraught, GuardRation,
        MinorHealingPotion, GuardianElixir, Antidote,
        GoblinFang, RatPelt, BeastHide);

    /// <summary>Every defined item.</summary>
    public static IReadOnlyCollection<ItemDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined item.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up an item by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static ItemDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out ItemDefinition def) => Registry.TryGet(id, out def);
}
