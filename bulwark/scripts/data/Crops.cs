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

    private static readonly Dictionary<string, CropDefinition> ById = BuildIndex(
        Turnip, Potato, Wheat, Tomato);

    public static IReadOnlyCollection<CropDefinition> All => ById.Values;

    public static bool IsDefined(string id) => ById.ContainsKey(id);

    public static CropDefinition Get(string id) => ById[id];

    public static bool TryGet(string id, out CropDefinition def) => ById.TryGetValue(id, out def!);

    private static Dictionary<string, CropDefinition> BuildIndex(params CropDefinition[] defs)
    {
        var index = new Dictionary<string, CropDefinition>(defs.Length);
        foreach (var def in defs)
            index[def.Id] = def;
        return index;
    }
}
