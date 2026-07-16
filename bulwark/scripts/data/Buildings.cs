using System;
using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// One (itemId, quantity) offering in a construction or upgrade bundle — the Community-Center /
/// Coral-Island style resource cost. Data-only; the <see cref="Bulwark.Cozy.BuildingSystem"/>
/// consumes these from the party inventory.
/// </summary>
public sealed class BundleRequirement
{
    public required string ItemId { get; init; }
    public required int Quantity { get; init; }
}

/// <summary>
/// A declarative effect a building tier grants. Phase 2 carries these as DATA only — the actual
/// gameplay wiring (extra farm plots, healing, smithy-catalog widening) arrives in later phases.
/// Nothing consumes these yet; they exist so the roster + upgrade tiers describe what a building
/// will do, and the planning UI can preview it.
/// </summary>
public enum BuildingEffectType
{
    FarmPlots,
    WateringAutomation,
    Greenhouse,
    SmithyTier,
    InfirmaryHealing,
    CategoryUnlock,

    /// <summary>Percentage discount on Trading Post BUY prices (Magnitude = percent, summed across
    /// sources, clamped by the aggregator). Baseline 0 — no shipped building grants it; a
    /// friendship heart threshold can (e.g. befriending the merchant improves store prices).</summary>
    StorePriceDiscount,

    /// <summary>A territory/biome unlocked for travel (Detail = the territory id). Declarative only
    /// this pass — aggregated into an id set (<see cref="Bulwark.Cozy.OutpostEffects.UnlockedBiomes"/>);
    /// no travel/gate consumer reads it yet.</summary>
    BiomeUnlock,

    /// <summary>Tavern boarding-room level (Magnitude = level) — enables tavern boarders once a
    /// consumer reads it. Aggregated as the MAX magnitude reached (a ladder, not additive — the
    /// SmithyTier precedent). Declarative only this pass.</summary>
    Boarding,

    /// <summary>Flag: the tavern's stage exists and morale performances are possible. Declarative
    /// only this pass — no consumer reads it yet.</summary>
    Performances,

    /// <summary>Flag: the watchtower's fast-travel service is available. Declarative only this pass —
    /// no consumer reads it yet.</summary>
    FastTravel,

    /// <summary>Flag: the command post's resurrection service is available. Declarative only this
    /// pass — no consumer reads it yet.</summary>
    Resurrection,

    /// <summary>Husbandry unlock level (Magnitude: 1 = coop animals, 2 = barn animals) — aggregated as
    /// the MAX magnitude reached (a ladder, not additive). Declarative only this pass — no consumer
    /// reads it yet.</summary>
    Husbandry,

    /// <summary>Fishing unlock level (Magnitude: 1 = rod fishing, 2 = traps + deeper waters) —
    /// aggregated as the MAX magnitude reached. Declarative only this pass — no consumer reads it yet.</summary>
    Fishing,
}

/// <summary>A single declarative tier effect (see <see cref="BuildingEffectType"/>). Not yet consumed.</summary>
public sealed class BuildingEffect
{
    public required BuildingEffectType Type { get; init; }

    /// <summary>Numeric payload (e.g. +N plots, SmithyTier as int). 0 when the effect is a flag.</summary>
    public int Magnitude { get; init; }

    /// <summary>Optional free-text detail for the UI / later consumers.</summary>
    public string? Detail { get; init; }
}

/// <summary>
/// One restored tier of a building. Tier 1 is the base built state (reached by paying the
/// building's construction bundle at commission); tiers 2..N are reached by ACCUMULATING their
/// <see cref="UpgradeBundle"/> (partial contributions allowed) and then upgrading. Each tier maps
/// to a visual <see cref="StageIndex"/> inside the building scene's %Stages container (stage 0 is
/// the ruined/site art shown before commission).
/// </summary>
public sealed class BuildingTier
{
    /// <summary>1-based tier number.</summary>
    public required int Tier { get; init; }

    /// <summary>Visual stage index selected in the building scene when this tier is current.</summary>
    public required int StageIndex { get; init; }

    /// <summary>Bundle accumulated to advance INTO this tier from the previous one. Empty for tier 1
    /// (tier 1 is reached by the construction bundle at commission, not by contributions).</summary>
    public IReadOnlyList<BundleRequirement> UpgradeBundle { get; init; } = Array.Empty<BundleRequirement>();

    /// <summary>Gold charged all-at-once at the Upgrade step (Stardew carpenter model) — paired with
    /// the completed <see cref="UpgradeBundle"/>, never contributed piecemeal. Default 0: every
    /// shipped tier is free of gold until content adds a cost, so baseline behavior is unchanged.</summary>
    public int GoldCost { get; init; }

    /// <summary>Declarative effects this tier grants (data only this phase).</summary>
    public IReadOnlyList<BuildingEffect> Effects { get; init; } = Array.Empty<BuildingEffect>();
}

/// <summary>
/// One visual rule on a building definition (design/building_visuals.md): either an OVERLAY (a
/// <c>%Overlays</c> child shown while its driver matches) or a STAGE OVERRIDE (a <c>%Stages</c>
/// index forced while its driver matches) — set <see cref="OverlayKey"/> XOR
/// <see cref="StageOverride"/>, never both/neither (an invalid rule is ignored, with a warning, by
/// <see cref="Bulwark.Cozy.BuildingVisualState"/>). Stage-override rules are evaluated in list
/// order with LAST match wins, so a later rule (e.g. "rebuilt") can supersede an earlier one
/// (e.g. "burned").
///
/// Drivers (a rule matches when its set driver(s) match):
///  • <see cref="Season"/> alone — active for the whole season (a season-long dressing/override).
///  • <see cref="Season"/> + <see cref="FromDay"/>/<see cref="ToDay"/> — active during that
///    inclusive calendar window within the season (a festival).
///  • <see cref="FlagId"/> — active once the story flag is set (flags latch — permanent by default).
///  • <see cref="FlagId"/> + <see cref="UnlessFlagId"/> — retired once the later flag is ALSO set.
/// </summary>
public sealed class BuildingVisualRule
{
    /// <summary>Overlay rule: the <c>%Overlays</c> child Name this rule activates.</summary>
    public string? OverlayKey;

    /// <summary>Stage-override rule: the <c>%Stages</c> index forced while this rule matches.</summary>
    public int? StageOverride;

    /// <summary>Season driver — required for a window rule, optional standalone (season-long).</summary>
    public Season? Season;

    /// <summary>Calendar-window driver (inclusive day range within <see cref="Season"/>).</summary>
    public int? FromDay;

    /// <summary>Calendar-window driver (inclusive day range within <see cref="Season"/>).</summary>
    public int? ToDay;

    /// <summary>Story-flag driver: the rule matches once this flag is set.</summary>
    public string? FlagId;

    /// <summary>Retire clause: paired with <see cref="FlagId"/>, the rule stops matching once this
    /// flag is ALSO set (a later story beat supersedes an earlier overlay).</summary>
    public string? UnlessFlagId;
}

/// <summary>
/// Declarative definition of a buildable outpost structure. Data-only per CLAUDE.md — adding a
/// building touches <see cref="Buildings"/> (plus authoring its <c>scenes/buildings/&lt;id&gt;.tscn</c>
/// and hand-placing its <c>%Building_&lt;id&gt;</c> marker) — no system code. The two-stage loop:
/// pay <see cref="ConstructionBundle"/> (+ <see cref="GoldCost"/>) to commission (→ tier 1), then
/// accumulate each higher tier's <see cref="BuildingTier.UpgradeBundle"/> and pay its
/// <see cref="BuildingTier.GoldCost"/> to advance.
/// </summary>
public sealed class BuildingDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Marker the loader instances the building at (the user hand-places it in the outpost).</summary>
    public string MarkerName => $"Building_{Id}";

    /// <summary>Premade building scene carrying the staged visuals + collision footprint.</summary>
    public string ScenePath => $"res://scenes/buildings/{Id}.tscn";

    /// <summary>Offerings paid all-at-once at commission (must be fully affordable) → Built tier 1.</summary>
    public required IReadOnlyList<BundleRequirement> ConstructionBundle { get; init; }

    /// <summary>Gold charged alongside <see cref="ConstructionBundle"/> at commission (Stardew carpenter
    /// model). Default 0: every shipped building is free of gold until content adds a cost, so
    /// baseline behavior is unchanged.</summary>
    public int GoldCost { get; init; }

    /// <summary>Tiers in ascending order (tier 1 = base built state).</summary>
    public required IReadOnlyList<BuildingTier> Tiers { get; init; }

    /// <summary>Highest tier this building can reach.</summary>
    public int MaxTier => Tiers.Count;

    /// <summary>Look up a tier definition by its 1-based number.</summary>
    public bool TryGetTier(int tier, out BuildingTier def)
    {
        foreach (var t in Tiers)
        {
            if (t.Tier == tier)
            {
                def = t;
                return true;
            }
        }
        def = null!;
        return false;
    }

    /// <summary>Visual stage index for a given current tier (0 when not yet built).</summary>
    public int StageIndexForTier(int tier)
        => tier <= 0 ? 0 : TryGetTier(tier, out var t) ? t.StageIndex : tier;

    /// <summary>Overlay + stage-override rules (season/calendar-window/story-flag driven) evaluated
    /// by <see cref="Bulwark.Cozy.BuildingVisualState"/>. Default empty — framework only until
    /// content is authored; every existing building's visuals stay byte-identical (tier mapping
    /// only, no overrides, no non-season overlays).</summary>
    public IReadOnlyList<BuildingVisualRule> VisualRules { get; init; } = Array.Empty<BuildingVisualRule>();
}

/// <summary>
/// Static registry of every buildable structure — the full 13-building roster from
/// design/economy/buildings.md, which is the source of truth for every bundle, Gold cost, and
/// effect below. The Command Post is the one start-state building: it exists at tier 1 from day
/// one with no construction bundle, and its ladder is upgrades only (tiers 2-4). Trading Post,
/// Kitchen, and Farmhouse are commissionable from day one but are NOT start-state: each still pays
/// a construction bundle to stand up tier 1. The remaining nine buildings are character-first or
/// progress-gated (see characters.md / buildings.md section 1). Adding a building is a data-only
/// edit here.
/// </summary>
public static class Buildings
{
    public static readonly BuildingDefinition CommandPost = new()
    {
        Id = "command_post",
        DisplayName = "Command Post",
        GoldCost = 0,
        ConstructionBundle = Array.Empty<BundleRequirement>(),
        Tiers = new BuildingTier[]
        {
            new()
            {
                // Planning table (start state): the commission menu for every other building, plus
                // the roster screen. No upgrade bundle, no Gold cost, no declarative effect.
                Tier = 1, StageIndex = 1,
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 350,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "goblin_fang", Quantity = 30 },
                    new() { ItemId = "deserter_badge", Quantity = 20 },
                    new() { ItemId = "wood", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.BiomeUnlock, Detail = "elderwood" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 450,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "beast_hide", Quantity = 25 },
                    new() { ItemId = "warden_bark", Quantity = 20 },
                    new() { ItemId = "hardwood", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.BiomeUnlock, Detail = "sunken_reach" },
                },
            },
            new()
            {
                Tier = 4, StageIndex = 4,
                GoldCost = 2000,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "hollow_locket", Quantity = 1 },
                    new() { ItemId = "venom_sac", Quantity = 1 },
                    new() { ItemId = "goblin_totem", Quantity = 1 },
                    new() { ItemId = "iron_ingot", Quantity = 20 },
                    new() { ItemId = "ward_salt", Quantity = 15 },
                    new() { ItemId = "bogwood", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Resurrection },
                },
            },
        },
    };

    public static readonly BuildingDefinition TradingPost = new()
    {
        Id = "trading_post",
        DisplayName = "Trading Post",
        GoldCost = 60,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 90 },
            new() { ItemId = "stone", Quantity = 60 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "general_store" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 250,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "forest_root", Quantity = 20 },
                    new() { ItemId = "tree_sap", Quantity = 20 },
                    new() { ItemId = "silt_carp", Quantity = 20 },
                    new() { ItemId = "marsh_clam", Quantity = 20 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "expanded_store" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Smithy = new()
    {
        Id = "smithy",
        DisplayName = "Smithy",
        GoldCost = 120,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "goblin_fang", Quantity = 25 },
            new() { ItemId = "rat_pelt", Quantity = 20 },
            new() { ItemId = "wood", Quantity = 15 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.SmithyTier, Magnitude = 0, Detail = "Base weapon catalog + fundamental runes" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 300,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "goblin_scrap", Quantity = 25 },
                    new() { ItemId = "coal", Quantity = 25 },
                    new() { ItemId = "beast_hide", Quantity = 25 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.SmithyTier, Magnitude = 1, Detail = "Improved weapon catalog + armor" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 500,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "mudclaw_hide", Quantity = 20 },
                    new() { ItemId = "serpent_scale", Quantity = 25 },
                    new() { ItemId = "goblin_totem", Quantity = 1 },
                    new() { ItemId = "iron_ingot", Quantity = 15 },
                    new() { ItemId = "swamp_drake_scale", Quantity = 5 },
                    new() { ItemId = "grovefather_knuckle", Quantity = 1 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.SmithyTier, Magnitude = 2, Detail = "Advanced weapon catalog + property runes" },
                },
            },
            new()
            {
                Tier = 4, StageIndex = 4,
                GoldCost = 2200,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "goblin_totem", Quantity = 1 },
                    new() { ItemId = "alpha_pelt", Quantity = 1 },
                    new() { ItemId = "reaver_tooth", Quantity = 1 },
                    new() { ItemId = "iron_ingot", Quantity = 20 },
                    new() { ItemId = "bogwood", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.SmithyTier, Magnitude = 3, Detail = "Trophy-forged / masterwork tier" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Infirmary = new()
    {
        Id = "infirmary",
        DisplayName = "Infirmary",
        GoldCost = 90,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 120 },
            new() { ItemId = "herb", Quantity = 20 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 1, Detail = "Rest healing" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 350,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "herb", Quantity = 25 },
                    new() { ItemId = "berries", Quantity = 20 },
                    new() { ItemId = "beast_hide", Quantity = 8 },
                    new() { ItemId = "spun_yarn", Quantity = 10 },
                    new() { ItemId = "thornback_hide", Quantity = 4 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 2, Detail = "Faster recovery + affliction treatment" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1200,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "herb", Quantity = 30 },
                    new() { ItemId = "tincture", Quantity = 18 },
                    new() { ItemId = "leather", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 3, Detail = "Advanced care" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Chapel = new()
    {
        Id = "chapel",
        DisplayName = "Chapel",
        GoldCost = 70,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "rat_pelt", Quantity = 15 },
            new() { ItemId = "goblin_fang", Quantity = 15 },
            new() { ItemId = "cloth", Quantity = 12 },
            new() { ItemId = "sap_gland", Quantity = 5 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "focus_font_blessings" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 700,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "alpha_pelt", Quantity = 1 },
                    new() { ItemId = "hollow_locket", Quantity = 1 },
                    new() { ItemId = "drowning_lantern", Quantity = 1 },
                    new() { ItemId = "ward_salt", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "hero_point_grants_greater_blessings" },
                },
            },
        },
    };

    public static readonly BuildingDefinition ArcaneStudy = new()
    {
        Id = "arcane_study",
        DisplayName = "Arcane Study",
        GoldCost = 200,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "goblin_fang", Quantity = 20 },
            new() { ItemId = "rat_pelt", Quantity = 20 },
            new() { ItemId = "copper_ingot", Quantity = 12 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "spell_learning_scrolls" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 400,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "bog_resin", Quantity = 20 },
                    new() { ItemId = "serpent_scale", Quantity = 25 },
                    new() { ItemId = "goblin_fang", Quantity = 20 },
                    new() { ItemId = "silkqueen_fang", Quantity = 1 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "higher_spell_ranks" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1400,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "fungal_core", Quantity = 1 },
                    new() { ItemId = "spore_pod", Quantity = 20 },
                    new() { ItemId = "serpent_scale", Quantity = 20 },
                    new() { ItemId = "spirit_dust", Quantity = 15 },
                    new() { ItemId = "wisp_ember", Quantity = 5 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "rare_spells_research_tools" },
                },
            },
        },
    };

    public static readonly BuildingDefinition TrainingYard = new()
    {
        Id = "training_yard",
        DisplayName = "Training Yard",
        GoldCost = 220,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "rat_pelt", Quantity = 25 },
            new() { ItemId = "deserter_badge", Quantity = 20 },
            new() { ItemId = "wood", Quantity = 15 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "proficiency_feat_training" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 450,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "nest_matriarch_tail", Quantity = 1 },
                    new() { ItemId = "deserter_badge", Quantity = 25 },
                    new() { ItemId = "rat_pelt", Quantity = 25 },
                    new() { ItemId = "leather", Quantity = 12 },
                    new() { ItemId = "amber_core", Quantity = 1 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "dedications" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1300,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "mudclaw_hide", Quantity = 25 },
                    new() { ItemId = "serpent_scale", Quantity = 20 },
                    new() { ItemId = "nest_matriarch_tail", Quantity = 1 },
                    new() { ItemId = "iron_ingot", Quantity = 18 },
                    new() { ItemId = "sovereign_hide", Quantity = 1 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "respec_later_dedications" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Apothecary = new()
    {
        Id = "apothecary",
        DisplayName = "Apothecary",
        GoldCost = 190,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "herb", Quantity = 20 },
            new() { ItemId = "berries", Quantity = 15 },
            new() { ItemId = "wood", Quantity = 100 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "potions_elixirs_antidotes" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 350,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "tincture", Quantity = 15 },
                    new() { ItemId = "bitter_root", Quantity = 20 },
                    new() { ItemId = "marsh_leech", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "talismans_reagent_refining" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1300,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "venom_sac", Quantity = 1 },
                    new() { ItemId = "spore_pod", Quantity = 20 },
                    new() { ItemId = "bog_moss", Quantity = 25 },
                    new() { ItemId = "nightcap_mushroom", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "rare_consumables" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Kitchen = new()
    {
        Id = "kitchen",
        DisplayName = "Kitchen",
        GoldCost = 70,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 90 },
            new() { ItemId = "stone", Quantity = 60 },
            new() { ItemId = "herb", Quantity = 15 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "meals" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 300,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "mead", Quantity = 15 },
                    new() { ItemId = "egg", Quantity = 25 },
                    new() { ItemId = "wild_mushroom", Quantity = 20 },
                    new() { ItemId = "log_mushroom", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Performances },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1200,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "winter_squash", Quantity = 25 },
                    new() { ItemId = "hearth_root", Quantity = 25 },
                    new() { ItemId = "frost_pike", Quantity = 10 },
                    new() { ItemId = "smoked_fish", Quantity = 18 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Boarding, Magnitude = 1 },
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "feasts" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Farmhouse = new()
    {
        Id = "farmhouse",
        DisplayName = "Farmhouse",
        GoldCost = 90,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 120 },
            new() { ItemId = "stone", Quantity = 90 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.FarmPlots, Magnitude = 2, Detail = "Tillable zone 1: turnip, potato, wheat, tomato, carrot" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 400,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "turnip", Quantity = 25 },
                    new() { ItemId = "wheat", Quantity = 25 },
                    new() { ItemId = "wood", Quantity = 200 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.FarmPlots, Magnitude = 2, Detail = "Zone 2: winter squash, hearth root, frost kale" },
                    new() { Type = BuildingEffectType.Husbandry, Magnitude = 1, Detail = "Coop: eggs, feathers, mushroom log" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 450,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "carrot", Quantity = 25 },
                    new() { ItemId = "frost_kale", Quantity = 25 },
                    new() { ItemId = "marsh_reed", Quantity = 20 },
                    new() { ItemId = "beast_hide", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Husbandry, Magnitude = 2, Detail = "Barn: milk, cream, wool, beehive" },
                    new() { Type = BuildingEffectType.WateringAutomation, Detail = "Auto-watering (both zones)" },
                },
            },
            new()
            {
                Tier = 4, StageIndex = 4,
                GoldCost = 2500,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "plank", Quantity = 350 },
                    new() { ItemId = "cloth", Quantity = 18 },
                    new() { ItemId = "cheese", Quantity = 20 },
                    new() { ItemId = "honey", Quantity = 20 },
                    new() { ItemId = "butter", Quantity = 20 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Greenhouse, Detail = "Removes season restriction entirely" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Watchtower = new()
    {
        Id = "watchtower",
        DisplayName = "Watchtower",
        GoldCost = 350,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "deserter_badge", Quantity = 25 },
            new() { ItemId = "rat_pelt", Quantity = 20 },
            new() { ItemId = "feather", Quantity = 15 },
            new() { ItemId = "fey_charm", Quantity = 5 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "territory_reveal" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 400,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "deserter_badge", Quantity = 25 },
                    new() { ItemId = "mudclaw_hide", Quantity = 25 },
                    new() { ItemId = "wood", Quantity = 15 },
                    new() { ItemId = "hollow_crown", Quantity = 1 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "encounter_preview_ambush" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1500,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "hardwood", Quantity = 15 },
                    new() { ItemId = "bogwood", Quantity = 15 },
                    new() { ItemId = "deserter_badge", Quantity = 25 },
                    new() { ItemId = "mudclaw_hide", Quantity = 20 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.FastTravel },
                },
            },
        },
    };

    public static readonly BuildingDefinition Reliquary = new()
    {
        Id = "reliquary",
        DisplayName = "Reliquary",
        GoldCost = 380,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "goblin_fang", Quantity = 25 },
            new() { ItemId = "deserter_badge", Quantity = 25 },
            new() { ItemId = "ward_salt", Quantity = 12 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "trophy_collection_identification" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 450,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "drowned_bone", Quantity = 25 },
                    new() { ItemId = "rat_pelt", Quantity = 25 },
                    new() { ItemId = "cut_stone", Quantity = 15 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "bestiary_combat_intel" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                GoldCost = 1600,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "reaver_tooth", Quantity = 1 },
                    new() { ItemId = "shadow_gar", Quantity = 1 },
                    new() { ItemId = "nest_matriarch_tail", Quantity = 1 },
                    new() { ItemId = "deserter_signet", Quantity = 1 },
                    new() { ItemId = "heartwood_shard", Quantity = 1 },
                    new() { ItemId = "amber_core", Quantity = 1 },
                    new() { ItemId = "hollow_crown", Quantity = 1 },
                    new() { ItemId = "silkqueen_fang", Quantity = 1 },
                    new() { ItemId = "grovefather_knuckle", Quantity = 1 },
                    new() { ItemId = "sovereign_hide", Quantity = 1 },
                    new() { ItemId = "drowning_lantern", Quantity = 1 },
                    new() { ItemId = "spirit_dust", Quantity = 18 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "relic_display_buffs" },
                },
            },
        },
    };

    public static readonly BuildingDefinition FishingDock = new()
    {
        Id = "fishing_dock",
        DisplayName = "Fishing Dock",
        GoldCost = 110,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "plank", Quantity = 90 },
            new() { ItemId = "cut_stone", Quantity = 60 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Fishing, Magnitude = 1, Detail = "Rod fishing: Verdant Fringe pond/river" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 300,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "plank", Quantity = 120 },
                    new() { ItemId = "cloth", Quantity = 12 },
                    new() { ItemId = "cut_stone", Quantity = 100 },
                    new() { ItemId = "spider_silk", Quantity = 3 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Fishing, Magnitude = 2, Detail = "Trap fishing + deeper waters (both biomes)" },
                },
            },
        },
    };

    private static readonly DefinitionRegistry<BuildingDefinition> Registry = new(d => d.Id,
        CommandPost, TradingPost, Smithy, Infirmary, Chapel, ArcaneStudy, TrainingYard,
        Apothecary, Kitchen, Farmhouse, Watchtower, Reliquary, FishingDock);

    /// <summary>Every defined building.</summary>
    public static IReadOnlyCollection<BuildingDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined building.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a building by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static BuildingDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out BuildingDefinition def) => Registry.TryGet(id, out def);
}
