using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>Broad classification an item falls under, used for UI grouping and validation.</summary>
public enum ItemCategory
{
    Crop,
    Seed,
    Resource,
    Tool,
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

    // --- Crops (harvest yields) ---
    public static readonly ItemDefinition Turnip = new()
    {
        Id = "turnip", DisplayName = "Turnip", Category = ItemCategory.Crop,
    };
    public static readonly ItemDefinition Potato = new()
    {
        Id = "potato", DisplayName = "Potato", Category = ItemCategory.Crop,
    };
    public static readonly ItemDefinition Wheat = new()
    {
        Id = "wheat", DisplayName = "Wheat", Category = ItemCategory.Crop,
    };
    public static readonly ItemDefinition Tomato = new()
    {
        Id = "tomato", DisplayName = "Tomato", Category = ItemCategory.Crop,
    };

    // --- Raw resources ---
    public static readonly ItemDefinition Wood = new()
    {
        Id = "wood", DisplayName = "Wood", Category = ItemCategory.Resource,
    };
    public static readonly ItemDefinition Stone = new()
    {
        Id = "stone", DisplayName = "Stone", Category = ItemCategory.Resource,
    };
    public static readonly ItemDefinition Herb = new()
    {
        Id = "herb", DisplayName = "Herbs", Category = ItemCategory.Resource,
    };
    public static readonly ItemDefinition Berries = new()
    {
        Id = "berries", DisplayName = "Berries", Category = ItemCategory.Resource,
    };

    private static readonly DefinitionRegistry<ItemDefinition> Registry = new(d => d.Id,
        TurnipSeed, PotatoSeed, WheatSeed, TomatoSeed,
        Turnip, Potato, Wheat, Tomato,
        Wood, Stone, Herb, Berries);

    /// <summary>Every defined item.</summary>
    public static IReadOnlyCollection<ItemDefinition> All => Registry.All;

    /// <summary>True when <paramref name="id"/> names a defined item.</summary>
    public static bool IsDefined(string id) => Registry.IsDefined(id);

    /// <summary>Look up an item by id. Throws if unknown — call <see cref="IsDefined"/> to probe.</summary>
    public static ItemDefinition Get(string id) => Registry.Get(id);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string id, out ItemDefinition def) => Registry.TryGet(id, out def);
}
