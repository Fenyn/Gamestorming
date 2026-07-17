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

    /// <summary>A catch from a fishing route — the Phase-6+ fishing minigame/route output. Framework
    /// only this pass: no fishing route exists yet and no item carries this category.</summary>
    Fish,

    /// <summary>Coop/barn husbandry output (eggs, milk, wool, and the like). Framework only this
    /// pass: no husbandry building/routine exists yet and no item carries this category.</summary>
    AnimalProduct,

    /// <summary>An elite/boss combat drop destined for construction bundles and the future Reliquary
    /// rather than ordinary sale (see design/economy/characters.md — Hazel/Reliquary). Framework only
    /// this pass: no item carries this category yet.</summary>
    Trophy,
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
    public static readonly ItemDefinition CarrotSeed = new()
    {
        Id = "carrot_seed", DisplayName = "Carrot Seeds", Category = ItemCategory.Seed, CropId = "carrot",
    };
    public static readonly ItemDefinition WinterSquashSeed = new()
    {
        Id = "winter_squash_seed", DisplayName = "Winter Squash Seeds", Category = ItemCategory.Seed, CropId = "winter_squash",
    };
    public static readonly ItemDefinition HearthRootSeed = new()
    {
        Id = "hearth_root_seed", DisplayName = "Hearth Root Seeds", Category = ItemCategory.Seed, CropId = "hearth_root",
    };
    public static readonly ItemDefinition FrostKaleSeed = new()
    {
        Id = "frost_kale_seed", DisplayName = "Frost Kale Seeds", Category = ItemCategory.Seed, CropId = "frost_kale",
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
    public static readonly ItemDefinition Carrot = new()
    {
        Id = "carrot", DisplayName = "Carrot", Category = ItemCategory.Crop, SellValue = 3,
    };
    public static readonly ItemDefinition WinterSquash = new()
    {
        Id = "winter_squash", DisplayName = "Winter Squash", Category = ItemCategory.Crop, SellValue = 6,
    };
    public static readonly ItemDefinition HearthRoot = new()
    {
        Id = "hearth_root", DisplayName = "Hearth Root", Category = ItemCategory.Crop, SellValue = 6,
    };
    public static readonly ItemDefinition FrostKale = new()
    {
        Id = "frost_kale", DisplayName = "Frost Kale", Category = ItemCategory.Crop, SellValue = 4,
    };

    // --- Raw resources (modest sale value; consumed by construction bundles later). Wood/stone are
    //     Light Bulk (0.1) per the materials.md full-Stardew-scale rescale (2026-07-14): a 150-300-unit
    //     gathering day must stay physically haulable in one trip, so raw building commons are Light,
    //     not the ≈1 Bulk they shipped with. ---
    public static readonly ItemDefinition Wood = new()
    {
        Id = "wood", DisplayName = "Wood", Category = ItemCategory.Resource, SellValue = 1, Bulk = 0.1f,
    };
    public static readonly ItemDefinition Stone = new()
    {
        Id = "stone", DisplayName = "Stone", Category = ItemCategory.Resource, SellValue = 1, Bulk = 0.1f,
    };
    public static readonly ItemDefinition Herb = new()
    {
        Id = "herb", DisplayName = "Herbs", Category = ItemCategory.Resource, SellValue = 2,
    };
    public static readonly ItemDefinition Berries = new()
    {
        Id = "berries", DisplayName = "Berries", Category = ItemCategory.Resource, SellValue = 2,
    };

    // --- New raw gathered resources (Phase 5 chains). copper_ore + fiber gate refined goods; the
    //     content flag is now closed — ResourceNodes.CopperVein and ResourceNodes.BramblePatch place
    //     both in the Verdant Fringe (see materials.md's content-flag-closure section). copper_ore is
    //     Light Bulk (0.1) per the same rescale as wood/stone above; fiber was already Light by default. ---
    public static readonly ItemDefinition CopperOre = new()
    {
        Id = "copper_ore", DisplayName = "Copper Ore", Category = ItemCategory.Resource, SellValue = 2, Bulk = 0.1f,
    };
    public static readonly ItemDefinition Fiber = new()
    {
        Id = "fiber", DisplayName = "Fiber", Category = ItemCategory.Resource, SellValue = 1,
    };

    // --- Elderwood/Sunken Reach raw commons (materials.md family 3: wood, stone, and ore). All Light
    //     Bulk (0.1) like their Verdant Fringe counterparts above. ---
    public static readonly ItemDefinition Hardwood = new()
    {
        Id = "hardwood", DisplayName = "Hardwood", Category = ItemCategory.Resource, SellValue = 5, Bulk = 0.1f,
    };
    public static readonly ItemDefinition Coal = new()
    {
        Id = "coal", DisplayName = "Coal", Category = ItemCategory.Resource, SellValue = 5, Bulk = 0.1f,
    };
    public static readonly ItemDefinition IronOre = new()
    {
        Id = "iron_ore", DisplayName = "Iron Ore", Category = ItemCategory.Resource, SellValue = 6, Bulk = 0.1f,
    };
    public static readonly ItemDefinition Bogwood = new()
    {
        Id = "bogwood", DisplayName = "Bogwood", Category = ItemCategory.Resource, SellValue = 5, Bulk = 0.1f,
    };

    // --- Biome forage (materials.md family 2). Elderwood (wild_mushroom, forest_root) and Sunken
    //     Reach (bog_moss, marsh_reed, bitter_root, nightcap_mushroom) hand-gathered items. Light Bulk. ---
    public static readonly ItemDefinition WildMushroom = new()
    {
        Id = "wild_mushroom", DisplayName = "Wild Mushroom", Category = ItemCategory.Resource, SellValue = 2,
    };
    public static readonly ItemDefinition ForestRoot = new()
    {
        Id = "forest_root", DisplayName = "Forest Root", Category = ItemCategory.Resource, SellValue = 2,
    };
    public static readonly ItemDefinition BogMoss = new()
    {
        Id = "bog_moss", DisplayName = "Bog Moss", Category = ItemCategory.Resource, SellValue = 1,
    };
    public static readonly ItemDefinition MarshReed = new()
    {
        Id = "marsh_reed", DisplayName = "Marsh Reed", Category = ItemCategory.Resource, SellValue = 2,
    };
    public static readonly ItemDefinition BitterRoot = new()
    {
        Id = "bitter_root", DisplayName = "Bitter Root", Category = ItemCategory.Resource, SellValue = 5,
    };
    public static readonly ItemDefinition NightcapMushroom = new()
    {
        Id = "nightcap_mushroom", DisplayName = "Nightcap Mushroom", Category = ItemCategory.Resource, SellValue = 12,
    };

    // --- Fish (materials.md family 4, NEW). Fishing Dock route; no fishing system ships this pass —
    //     item defs only, per the same "data exists, system authored later" pattern as arcane_essence. ---
    public static readonly ItemDefinition RiverMinnow = new()
    {
        Id = "river_minnow", DisplayName = "River Minnow", Category = ItemCategory.Fish, SellValue = 2,
    };
    public static readonly ItemDefinition StreamTrout = new()
    {
        Id = "stream_trout", DisplayName = "Stream Trout", Category = ItemCategory.Fish, SellValue = 5,
    };
    public static readonly ItemDefinition LakeBass = new()
    {
        Id = "lake_bass", DisplayName = "Lake Bass", Category = ItemCategory.Fish, SellValue = 6,
    };
    public static readonly ItemDefinition FrostPike = new()
    {
        Id = "frost_pike", DisplayName = "Frost Pike", Category = ItemCategory.Fish, SellValue = 12,
    };
    public static readonly ItemDefinition MurkCatfish = new()
    {
        Id = "murk_catfish", DisplayName = "Murk Catfish", Category = ItemCategory.Fish, SellValue = 6,
    };
    public static readonly ItemDefinition BogEel = new()
    {
        Id = "bog_eel", DisplayName = "Bog Eel", Category = ItemCategory.Fish, SellValue = 7,
    };
    public static readonly ItemDefinition SiltCarp = new()
    {
        Id = "silt_carp", DisplayName = "Silt Carp", Category = ItemCategory.Fish, SellValue = 3,
    };
    public static readonly ItemDefinition ShadowGar = new()
    {
        Id = "shadow_gar", DisplayName = "Shadow Gar", Category = ItemCategory.Fish, SellValue = 14,
    };
    public static readonly ItemDefinition MarshClam = new()
    {
        Id = "marsh_clam", DisplayName = "Marsh Clam", Category = ItemCategory.Fish, SellValue = 3,
    };

    // --- Animal products (materials.md family 5, NEW). Farmhouse coop/barn husbandry route; no
    //     husbandry system ships this pass — item defs only. ---
    public static readonly ItemDefinition Egg = new()
    {
        Id = "egg", DisplayName = "Egg", Category = ItemCategory.AnimalProduct, SellValue = 2,
    };
    public static readonly ItemDefinition Feather = new()
    {
        Id = "feather", DisplayName = "Feather", Category = ItemCategory.AnimalProduct, SellValue = 1,
    };
    public static readonly ItemDefinition Milk = new()
    {
        Id = "milk", DisplayName = "Milk", Category = ItemCategory.AnimalProduct, SellValue = 3,
    };
    public static readonly ItemDefinition Wool = new()
    {
        Id = "wool", DisplayName = "Wool", Category = ItemCategory.AnimalProduct, SellValue = 5,
    };
    public static readonly ItemDefinition Cream = new()
    {
        Id = "cream", DisplayName = "Cream", Category = ItemCategory.AnimalProduct, SellValue = 3,
    };

    // --- Apiary and tap (materials.md family 6, NEW). Passive daily producers (Farmhouse beehive +
    //     mushroom log, territory tap lines); Category Resource per the catalog. No producer system
    //     ships this pass — item defs only. ---
    public static readonly ItemDefinition Honey = new()
    {
        Id = "honey", DisplayName = "Honey", Category = ItemCategory.Resource, SellValue = 6,
    };
    public static readonly ItemDefinition TreeSap = new()
    {
        Id = "tree_sap", DisplayName = "Tree Sap", Category = ItemCategory.Resource, SellValue = 2,
    };
    public static readonly ItemDefinition BogResin = new()
    {
        Id = "bog_resin", DisplayName = "Bog Resin", Category = ItemCategory.Resource, SellValue = 5,
    };
    public static readonly ItemDefinition LogMushroom = new()
    {
        Id = "log_mushroom", DisplayName = "Log Mushroom", Category = ItemCategory.Resource, SellValue = 3,
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
    public static readonly ItemDefinition IronIngot = new()
    {
        Id = "iron_ingot", DisplayName = "Iron Ingot", Category = ItemCategory.Refined, SellValue = 14, Bulk = 1f,
    };
    public static readonly ItemDefinition Cheese = new()
    {
        Id = "cheese", DisplayName = "Cheese", Category = ItemCategory.Refined, SellValue = 8,
    };
    public static readonly ItemDefinition Butter = new()
    {
        Id = "butter", DisplayName = "Butter", Category = ItemCategory.Refined, SellValue = 6,
    };
    public static readonly ItemDefinition SpunYarn = new()
    {
        Id = "spun_yarn", DisplayName = "Spun Yarn", Category = ItemCategory.Refined, SellValue = 7,
    };
    public static readonly ItemDefinition Mead = new()
    {
        Id = "mead", DisplayName = "Mead", Category = ItemCategory.Refined, SellValue = 9,
    };
    public static readonly ItemDefinition SmokedFish = new()
    {
        Id = "smoked_fish", DisplayName = "Smoked Fish", Category = ItemCategory.Refined, SellValue = 8,
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
    //     Rune application at the smithy consumes gold + N arcane_essence. The content flag is now
    //     closed with two routes: ResourceNodes.LeyGlade (Elderwood forage) and Recipes.ArcaneEssence
    //     (Apothecary T2 reagent refining from nightcap_mushroom). SellValue modest; tunable. ---
    public static readonly ItemDefinition ArcaneEssence = new()
    {
        Id = "arcane_essence", DisplayName = "Arcane Essence", Category = ItemCategory.Reagent, SellValue = 10,
    };
    public static readonly ItemDefinition WardSalt = new()
    {
        Id = "ward_salt", DisplayName = "Ward Salt", Category = ItemCategory.Reagent, SellValue = 10,
    };
    public static readonly ItemDefinition SpiritDust = new()
    {
        Id = "spirit_dust", DisplayName = "Spirit Dust", Category = ItemCategory.Reagent, SellValue = 14,
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
    public static readonly ItemDefinition GoblinScrap = new()
    {
        Id = "goblin_scrap", DisplayName = "Goblin Scrap", Category = ItemCategory.MonsterPart, SellValue = 2,
    };
    public static readonly ItemDefinition DeserterBadge = new()
    {
        Id = "deserter_badge", DisplayName = "Deserter Badge", Category = ItemCategory.MonsterPart, SellValue = 5,
    };
    public static readonly ItemDefinition WardenBark = new()
    {
        Id = "warden_bark", DisplayName = "Warden Bark", Category = ItemCategory.MonsterPart, SellValue = 6,
    };
    public static readonly ItemDefinition MudclawHide = new()
    {
        Id = "mudclaw_hide", DisplayName = "Mudclaw Hide", Category = ItemCategory.MonsterPart, SellValue = 6,
    };
    public static readonly ItemDefinition SerpentScale = new()
    {
        Id = "serpent_scale", DisplayName = "Serpent Scale", Category = ItemCategory.MonsterPart, SellValue = 6,
    };
    public static readonly ItemDefinition SporePod = new()
    {
        Id = "spore_pod", DisplayName = "Spore Pod", Category = ItemCategory.MonsterPart, SellValue = 5,
    };
    public static readonly ItemDefinition DrownedBone = new()
    {
        Id = "drowned_bone", DisplayName = "Drowned Bone", Category = ItemCategory.MonsterPart, SellValue = 6,
    };
    public static readonly ItemDefinition MarshLeech = new()
    {
        Id = "marsh_leech", DisplayName = "Marsh Leech", Category = ItemCategory.MonsterPart, SellValue = 3,
    };
    public static readonly ItemDefinition SapGland = new()
    {
        Id = "sap_gland", DisplayName = "Sap Gland", Category = ItemCategory.MonsterPart, SellValue = 4,
    };
    public static readonly ItemDefinition FeyCharm = new()
    {
        Id = "fey_charm", DisplayName = "Fey Charm", Category = ItemCategory.MonsterPart, SellValue = 4,
    };
    public static readonly ItemDefinition SpiderSilk = new()
    {
        Id = "spider_silk", DisplayName = "Spider Silk", Category = ItemCategory.MonsterPart, SellValue = 6,
    };
    public static readonly ItemDefinition ThornbackHide = new()
    {
        Id = "thornback_hide", DisplayName = "Thornback Hide", Category = ItemCategory.MonsterPart, SellValue = 7,
    };
    public static readonly ItemDefinition SwampDrakeScale = new()
    {
        Id = "swamp_drake_scale", DisplayName = "Swamp Drake Scale", Category = ItemCategory.MonsterPart, SellValue = 7,
    };
    public static readonly ItemDefinition WispEmber = new()
    {
        Id = "wisp_ember", DisplayName = "Wisp Ember", Category = ItemCategory.MonsterPart, SellValue = 6,
    };

    // --- Trophies (materials.md family 8): elite-roamer/boss-only drops, one id per creature family
    //     (the boss guarantees more units of the same trophy rather than a separate item). Almost
    //     always the wrong call to sell — construction bundle and future Reliquary material. ---
    public static readonly ItemDefinition GoblinTotem = new()
    {
        Id = "goblin_totem", DisplayName = "Goblin Totem", Category = ItemCategory.Trophy, SellValue = 25,
    };
    public static readonly ItemDefinition NestMatriarchTail = new()
    {
        Id = "nest_matriarch_tail", DisplayName = "Nest Matriarch's Tail", Category = ItemCategory.Trophy, SellValue = 25,
    };
    public static readonly ItemDefinition DeserterSignet = new()
    {
        Id = "deserter_signet", DisplayName = "Deserter's Signet", Category = ItemCategory.Trophy, SellValue = 30,
    };
    public static readonly ItemDefinition AlphaPelt = new()
    {
        Id = "alpha_pelt", DisplayName = "Alpha Pelt", Category = ItemCategory.Trophy, SellValue = 28,
    };
    public static readonly ItemDefinition HeartwoodShard = new()
    {
        Id = "heartwood_shard", DisplayName = "Heartwood Shard", Category = ItemCategory.Trophy, SellValue = 30,
    };
    public static readonly ItemDefinition ReaverTooth = new()
    {
        Id = "reaver_tooth", DisplayName = "Reaver's Tooth", Category = ItemCategory.Trophy, SellValue = 30,
    };
    public static readonly ItemDefinition VenomSac = new()
    {
        Id = "venom_sac", DisplayName = "Venom Sac", Category = ItemCategory.Trophy, SellValue = 32,
    };
    public static readonly ItemDefinition FungalCore = new()
    {
        Id = "fungal_core", DisplayName = "Fungal Core", Category = ItemCategory.Trophy, SellValue = 35,
    };
    public static readonly ItemDefinition HollowLocket = new()
    {
        Id = "hollow_locket", DisplayName = "Hollow Locket", Category = ItemCategory.Trophy, SellValue = 40,
    };
    public static readonly ItemDefinition AmberCore = new()
    {
        Id = "amber_core", DisplayName = "Amber Core", Category = ItemCategory.Trophy, SellValue = 26,
    };
    public static readonly ItemDefinition HollowCrown = new()
    {
        Id = "hollow_crown", DisplayName = "Hollow Crown", Category = ItemCategory.Trophy, SellValue = 27,
    };
    public static readonly ItemDefinition SilkqueenFang = new()
    {
        Id = "silkqueen_fang", DisplayName = "Silkqueen's Fang", Category = ItemCategory.Trophy, SellValue = 29,
    };
    public static readonly ItemDefinition GrovefatherKnuckle = new()
    {
        Id = "grovefather_knuckle", DisplayName = "Grovefather's Knuckle", Category = ItemCategory.Trophy, SellValue = 31,
    };
    public static readonly ItemDefinition SovereignHide = new()
    {
        Id = "sovereign_hide", DisplayName = "Sovereign Hide", Category = ItemCategory.Trophy, SellValue = 34,
    };
    public static readonly ItemDefinition DrowningLantern = new()
    {
        Id = "drowning_lantern", DisplayName = "Drowning Lantern", Category = ItemCategory.Trophy, SellValue = 37,
    };

    /// <summary>The dire wolf's pelt — the tutorial-arc capstone boss trophy (design/tutorial_quests.md
    /// quest 9). A Verdant Fringe boss drop, not a creature-family trophy: dropped only by the one-shot
    /// wolf-lair boss encounter. Bundle / Smithy material — almost always the wrong call to sell.</summary>
    public static readonly ItemDefinition DireWolfPelt = new()
    {
        Id = "dire_wolf_pelt", DisplayName = "Dire Wolf Pelt", Category = ItemCategory.Trophy, SellValue = 40,
    };

    private static readonly DefinitionRegistry<ItemDefinition> Registry = new(d => d.Id,
        TurnipSeed, PotatoSeed, WheatSeed, TomatoSeed, CarrotSeed, WinterSquashSeed, HearthRootSeed, FrostKaleSeed,
        Turnip, Potato, Wheat, Tomato, Carrot, WinterSquash, HearthRoot, FrostKale,
        Wood, Stone, Herb, Berries,
        CopperOre, Fiber,
        Hardwood, Coal, IronOre, Bogwood,
        WildMushroom, ForestRoot, BogMoss, MarshReed, BitterRoot, NightcapMushroom,
        RiverMinnow, StreamTrout, LakeBass, FrostPike, MurkCatfish, BogEel, SiltCarp, ShadowGar, MarshClam,
        Egg, Feather, Milk, Wool, Cream,
        Honey, TreeSap, BogResin, LogMushroom,
        Plank, CutStone, CopperIngot, Leather, Tincture, Cloth, IronIngot, Cheese, Butter, SpunYarn, Mead, SmokedFish,
        ArcaneEssence, WardSalt, SpiritDust,
        HeartyStew, HerbTonic, TravelRation, BattleDraught, GuardRation,
        MinorHealingPotion, GuardianElixir, Antidote,
        GoblinFang, RatPelt, BeastHide, GoblinScrap, DeserterBadge, WardenBark, MudclawHide, SerpentScale,
        SporePod, DrownedBone, MarshLeech, SapGland, FeyCharm, SpiderSilk, ThornbackHide, SwampDrakeScale, WispEmber,
        GoblinTotem, NestMatriarchTail, DeserterSignet, AlphaPelt, HeartwoodShard, ReaverTooth, VenomSac, FungalCore,
        HollowLocket, AmberCore, HollowCrown, SilkqueenFang, GrovefatherKnuckle, SovereignHide, DrowningLantern,
        DireWolfPelt);

    /// <summary>Every defined item.</summary>
    public static IReadOnlyCollection<ItemDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined item.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up an item by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static ItemDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out ItemDefinition def) => Registry.TryGet(id, out def);
}
