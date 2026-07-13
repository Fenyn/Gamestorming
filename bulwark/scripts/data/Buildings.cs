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

    /// <summary>Declarative effects this tier grants (data only this phase).</summary>
    public IReadOnlyList<BuildingEffect> Effects { get; init; } = Array.Empty<BuildingEffect>();
}

/// <summary>
/// Declarative definition of a buildable outpost structure. Data-only per CLAUDE.md — adding a
/// building touches <see cref="Buildings"/> (plus authoring its <c>scenes/buildings/&lt;id&gt;.tscn</c>
/// and hand-placing its <c>%Building_&lt;id&gt;</c> marker) — no system code. The two-stage loop:
/// pay <see cref="ConstructionBundle"/> to commission (→ tier 1), then accumulate each higher tier's
/// <see cref="BuildingTier.UpgradeBundle"/> to advance.
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
}

/// <summary>
/// Static registry of every buildable structure. MVP set (farmhouse, smithy, infirmary) with real
/// construction/upgrade bundles drawn from existing items (wood/stone/herb/berries/crops/monster
/// parts). Bundle sizes are tuned to stay affordable within the per-member PF2e Bulk carry caps.
/// Adding a building is a data-only edit here.
/// </summary>
public static class Buildings
{
    public static readonly BuildingDefinition Farmhouse = new()
    {
        Id = "farmhouse",
        DisplayName = "Farmhouse",
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 8 },
            new() { ItemId = "stone", Quantity = 6 },
        },
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.FarmPlots, Magnitude = 2, Detail = "+2 farm plots" },
                },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "wood", Quantity = 6 },
                    new() { ItemId = "wheat", Quantity = 8 },
                    new() { ItemId = "berries", Quantity = 6 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.FarmPlots, Magnitude = 2, Detail = "+2 more farm plots" },
                    new() { Type = BuildingEffectType.WateringAutomation, Detail = "Auto-watering" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "stone", Quantity = 8 },
                    new() { ItemId = "tomato", Quantity = 10 },
                    new() { ItemId = "beast_hide", Quantity = 4 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.Greenhouse, Detail = "Greenhouse: off-season crops" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Smithy = new()
    {
        Id = "smithy",
        DisplayName = "Smithy",
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 6 },
            new() { ItemId = "stone", Quantity = 10 },
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
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "stone", Quantity = 8 },
                    new() { ItemId = "goblin_fang", Quantity = 6 },
                    new() { ItemId = "rat_pelt", Quantity = 5 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.SmithyTier, Magnitude = 1, Detail = "Improved weapon catalog" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "stone", Quantity = 10 },
                    new() { ItemId = "beast_hide", Quantity = 6 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.SmithyTier, Magnitude = 2, Detail = "Advanced weapon catalog + property runes" },
                },
            },
        },
    };

    public static readonly BuildingDefinition Infirmary = new()
    {
        Id = "infirmary",
        DisplayName = "Infirmary",
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 5 },
            new() { ItemId = "herb", Quantity = 8 },
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
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "herb", Quantity = 10 },
                    new() { ItemId = "berries", Quantity = 8 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 2, Detail = "Faster recovery" },
                },
            },
            new()
            {
                Tier = 3, StageIndex = 3,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "herb", Quantity = 12 },
                    new() { ItemId = "beast_hide", Quantity = 4 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "Antidotes + tonics category" },
                },
            },
        },
    };

    public static readonly BuildingDefinition TradingPost = new()
    {
        Id = "trading_post",
        DisplayName = "Trading Post",
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 6 },
            new() { ItemId = "stone", Quantity = 4 },
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
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "wood", Quantity = 6 },
                    new() { ItemId = "wheat", Quantity = 6 },
                    new() { ItemId = "berries", Quantity = 4 },
                },
                Effects = new BuildingEffect[]
                {
                    new() { Type = BuildingEffectType.CategoryUnlock, Detail = "expanded_store" },
                },
            },
        },
    };

    private static readonly DefinitionRegistry<BuildingDefinition> Registry = new(d => d.Id,
        Farmhouse, Smithy, Infirmary, TradingPost);

    /// <summary>Every defined building.</summary>
    public static IReadOnlyCollection<BuildingDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined building.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up a building by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static BuildingDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out BuildingDefinition def) => Registry.TryGet(id, out def);
}
