using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// Declarative definition of a crop's growth behaviour. Data-only per CLAUDE.md.
/// <see cref="Seasons"/> lists the seasons the crop grows in; planting out of season is rejected
/// and a growing crop dies when the season leaves its list. Regrowing crops re-mature every
/// <see cref="RegrowDays"/> days after the first harvest instead of clearing the plot.
/// </summary>
public sealed class CropDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Seed item consumed to plant (a <see cref="ItemDefinition.Id"/>).</summary>
    public required string SeedItemId { get; init; }

    /// <summary>Item produced on harvest.</summary>
    public required string YieldItemId { get; init; }

    /// <summary>How many yield items each harvest produces.</summary>
    public int YieldCount { get; init; } = 1;

    /// <summary>Watered days from planting to first maturity.</summary>
    public required int GrowthDays { get; init; }

    /// <summary>Seasons the crop can grow in.</summary>
    public required IReadOnlyList<Season> Seasons { get; init; }

    /// <summary>When true, harvesting keeps the plant and it re-matures after <see cref="RegrowDays"/>.</summary>
    public bool Regrows { get; init; }

    /// <summary>Watered days between regrowth harvests (only meaningful when <see cref="Regrows"/>).</summary>
    public int RegrowDays { get; init; }
}

/// <summary>Static registry of crop definitions. Starter set for M2; additions are data-only.</summary>
public static class Crops
{
    public static readonly CropDefinition Turnip = new()
    {
        Id = "turnip", DisplayName = "Turnip",
        SeedItemId = "turnip_seed", YieldItemId = "turnip", YieldCount = 1,
        GrowthDays = 4, Seasons = new[] { Season.Spring },
    };

    public static readonly CropDefinition Potato = new()
    {
        Id = "potato", DisplayName = "Potato",
        SeedItemId = "potato_seed", YieldItemId = "potato", YieldCount = 2,
        GrowthDays = 6, Seasons = new[] { Season.Spring, Season.Summer },
    };

    public static readonly CropDefinition Wheat = new()
    {
        Id = "wheat", DisplayName = "Wheat",
        SeedItemId = "wheat_seed", YieldItemId = "wheat", YieldCount = 1,
        GrowthDays = 5, Seasons = new[] { Season.Summer, Season.Fall },
    };

    // Regrowing example: matures in 8 days, then re-yields every 4 watered days.
    public static readonly CropDefinition Tomato = new()
    {
        Id = "tomato", DisplayName = "Tomato",
        SeedItemId = "tomato_seed", YieldItemId = "tomato", YieldCount = 1,
        GrowthDays = 8, Seasons = new[] { Season.Summer },
        Regrows = true, RegrowDays = 4,
    };

    // --- materials.md family 1 additions (2026-07-14): fill out the Spring/Fall/Winter roster
    //     alongside the Spring/Summer/Fall starter set above. Winter-hardy crops (winter_squash,
    //     hearth_root, frost_kale) grow outdoors once Farmhouse T2 opens zone 2 — see buildings.md;
    //     the Greenhouse (T4) lifts the season restriction entirely rather than gating these. ---
    public static readonly CropDefinition Carrot = new()
    {
        Id = "carrot", DisplayName = "Carrot",
        SeedItemId = "carrot_seed", YieldItemId = "carrot", YieldCount = 1,
        GrowthDays = 4, Seasons = new[] { Season.Spring },
    };

    public static readonly CropDefinition WinterSquash = new()
    {
        Id = "winter_squash", DisplayName = "Winter Squash",
        SeedItemId = "winter_squash_seed", YieldItemId = "winter_squash", YieldCount = 1,
        GrowthDays = 10, Seasons = new[] { Season.Fall, Season.Winter },
    };

    public static readonly CropDefinition HearthRoot = new()
    {
        Id = "hearth_root", DisplayName = "Hearth Root",
        SeedItemId = "hearth_root_seed", YieldItemId = "hearth_root", YieldCount = 1,
        GrowthDays = 10, Seasons = new[] { Season.Fall, Season.Winter },
    };

    public static readonly CropDefinition FrostKale = new()
    {
        Id = "frost_kale", DisplayName = "Frost Kale",
        SeedItemId = "frost_kale_seed", YieldItemId = "frost_kale", YieldCount = 1,
        GrowthDays = 8, Seasons = new[] { Season.Winter },
    };

    private static readonly DefinitionRegistry<CropDefinition> Registry = new(d => d.Id,
        Turnip, Potato, Wheat, Tomato, Carrot, WinterSquash, HearthRoot, FrostKale);

    public static IReadOnlyCollection<CropDefinition> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static CropDefinition Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out CropDefinition def) => Registry.TryGet(id, out def);
}
