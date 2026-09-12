using System;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Delve.Run;

/// <summary>
/// How big the board for a generated fight is. The forest biome ships 18x18 to 24x24, which is a
/// long walk for small combat harnesses or a solo tutorial. The side scales with the number of
/// friendly combatants; normal expeditions use the full-party scale and have room to flank.
/// Boards stay square-ish because the biome's
/// own range is.
/// </summary>
public sealed record BattleMapRules
{
    /// <summary>Side scale for a lone character. Halves the biome's board.</summary>
    public float SoloScale { get; init; } = 0.5f;

    /// <summary>Side scale at <see cref="Party.MaxSize"/> friendly combatants.</summary>
    public float FullPartyScale { get; init; } = 0.85f;

    /// <summary>Smallest side to generate. Below this the two deployment zones meet.</summary>
    public int MinSide { get; init; } = 12;

    /// <summary>The scale for this many friendly combatants, straight-line between the two ends.</summary>
    public float ScaleFor(int friendly)
    {
        int span = Math.Max(1, Party.MaxSize - 1);
        float t = Math.Clamp((friendly - 1) / (float)span, 0f, 1f);
        return SoloScale + (FullPartyScale - SoloScale) * t;
    }

    /// <summary>
    /// The board size for a fight: the biome's own size rolled on <paramref name="seed"/>, scaled
    /// for the party that walks onto it and floored at <see cref="MinSide"/>.
    /// </summary>
    public (int Width, int Height) SizeFor(BiomeDefinition biome, int seed, int friendly)
    {
        var rng = new Random(seed);
        int width = rng.Next(biome.MinSize.x, biome.MaxSize.x + 1);
        int height = rng.Next(biome.MinSize.y, biome.MaxSize.y + 1);

        float scale = ScaleFor(friendly);
        return (Scale(width, scale), Scale(height, scale));
    }

    private int Scale(int side, float scale)
        => Math.Max(MinSide, (int)MathF.Round(side * scale));
}
