using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Delve.Dungeon;

/// <summary>What the forest generator makes of one glade: its landform weights, its setpieces, and
/// whether its size is fixed.</summary>
public sealed record GladeRecipe
{
    /// <summary>Macro shape id to pick weight. Shapes left out never roll.</summary>
    public required IReadOnlyDictionary<string, float> Shapes { get; init; }

    public IReadOnlyList<string> Setpieces { get; init; } = GladeRecipes.OpenSetpieces;

    /// <summary>Setpieces every glade of this kind carries.</summary>
    public IReadOnlyList<string> Forced { get; init; } = Array.Empty<string>();

    public int MaxFeatures { get; init; } = 2;

    /// <summary>Interior size that overrides the glade scene's size variants; 0 keeps them.</summary>
    public int Size { get; init; }

    /// <summary>Landmarks placed on 2x2 blocking footprints, farthest from the mouths first.</summary>
    public IReadOnlyList<string> Props { get; init; } = Array.Empty<string>();
}

/// <summary>The glade table: one recipe per room purpose, with a floor's own row where the two forest
/// floors differ. Open ground and gentle hills by default; perches only where the place is one.</summary>
public static class GladeRecipes
{
    public static readonly IReadOnlyList<string> OpenSetpieces = new[] { "rocky_outcrop", "gully", "rocky_escarpment" };

    private static readonly Dictionary<string, float> Open = new()
    {
        ["open_field"] = 3, ["rolling_hills"] = 3, ["stream_bridge"] = 2, ["small_river"] = 1, ["plateau_mesa"] = 1,
    };

    private static readonly Dictionary<string, float> Perch = new()
    {
        ["plateau_mesa"] = 3, ["cliff_face"] = 2, ["rolling_hills"] = 1,
    };

    private static readonly Dictionary<string, float> Water = new()
    {
        ["stream_bridge"] = 3, ["small_river"] = 2,
    };

    private static readonly GladeRecipe Default = new() { Shapes = Open };

    private static readonly Dictionary<RoomPurpose, GladeRecipe> ByPurpose = new()
    {
        [RoomPurpose.Checkpoint] = new() { Shapes = Perch, Forced = new[] { "rocky_escarpment" } },
        [RoomPurpose.Cistern] = new() { Shapes = Water },
        [RoomPurpose.Workshop] = new() { Shapes = Open, Setpieces = new[] { "ruined_foundation", "rocky_outcrop" } },
        [RoomPurpose.WardChamber] = new() { Shapes = Perch, Forced = new[] { "rocky_outcrop" }, Size = 18, Props = new[] { "beacon", "holloway" } },
        [RoomPurpose.Refuge] = new() { Shapes = Open, Props = new[] { "camp" } },
    };

    private static readonly Dictionary<(string Floor, RoomPurpose Purpose), GladeRecipe> ByFloor = new()
    {
        [("deepforest", RoomPurpose.Shrine)] = new() { Shapes = Open, Forced = new[] { "stone_circle" }, MaxFeatures = 1 },
        [("deepforest", RoomPurpose.WardChamber)] = new() { Shapes = Open, Forced = new[] { "rocky_escarpment" }, Size = 18, Props = new[] { "beacon", "root_stair", "regent_tree" } },
    };

    public static GladeRecipe For(string floor, RoomPurpose purpose) =>
        ByFloor.TryGetValue((floor, purpose), out var own) ? own
        : ByPurpose.TryGetValue(purpose, out var recipe) ? recipe : Default;

    private static readonly Dictionary<GladeRecipe, BiomeDefinition> Biomes = new();

    /// <summary>The forest biome with this recipe's shapes and setpieces, built once per recipe.</summary>
    public static BiomeDefinition Biome(GladeRecipe recipe)
    {
        if (Biomes.TryGetValue(recipe, out var built)) return built;
        var forest = MapGenRegistry.GetBiome(GladeGeneration.Biome);
        built = new BiomeDefinition
        {
            Id = forest.Id,
            BiomeName = forest.BiomeName,
            WallHeight = forest.WallHeight,
            CoverHeight = forest.CoverHeight,
            CliffThreshold = forest.CliffThreshold,
            MaxElevation = forest.MaxElevation,
            RefineNaturalRelief = forest.RefineNaturalRelief,
            MinSize = forest.MinSize,
            MaxSize = forest.MaxSize,
            DefaultGroundSurface = forest.DefaultGroundSurface,
            DefaultDifficultSurface = forest.DefaultDifficultSurface,
            DefaultCoverSurface = forest.DefaultCoverSurface,
            DefaultWallSurface = forest.DefaultWallSurface,
            MinFeatures = Math.Min(forest.MinFeatures, recipe.MaxFeatures),
            MaxFeatures = recipe.MaxFeatures,
            DefaultParams = forest.DefaultParams,
            MacroShapes = recipe.Shapes.Select(s => new MacroShapeEntry { Shape = MacroShapeCatalog.All[s.Key], Weight = s.Value }).ToArray(),
            AvailableSetpieces = recipe.Setpieces.Select(id => SetpieceCatalog.All[id]).ToArray(),
            AvailableDebrisPatches = forest.AvailableDebrisPatches,
            ForcedSetpieces = recipe.Forced.Select(id => SetpieceCatalog.All[id]).ToArray(),
            OnlyForcedSetpieces = false,
        };
        Biomes[recipe] = built;
        return built;
    }
}
