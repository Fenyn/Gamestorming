using System.Collections.Generic;
using Delve.Data;

namespace Delve.Terrain;

/// <summary>
/// One biome's complete look: the terrain palette the mesh builder and the ground baker read, and the
/// atmosphere and edge scenery the backdrop builds around it. The two halves used to be separate
/// tables keyed by the same id, which let a biome's apron drift away from its own ground.
/// </summary>
public sealed record BiomeTheme
{
    /// <summary>Registry id of the biome, the same string <c>MapGenRegistry</c> resolves.</summary>
    public required string Id { get; init; }

    public required MapThemeDefinition Terrain { get; init; }

    public required BackdropThemeDefinition Backdrop { get; init; }
}

/// <summary>
/// The one biome-look registry. Built from <see cref="MapThemes.All"/>, so a biome exists here the
/// moment it has a terrain palette; the backdrop half comes from <see cref="BackdropThemes.Authored"/>
/// and falls back to the neutral <see cref="BackdropThemes.Default"/> when a biome has no entry yet.
///
/// <see cref="MapThemes.Get"/> and <see cref="BackdropThemes.Get"/> remain as shorthand for the two
/// halves, so existing callers need no change.
/// </summary>
public static class BiomeThemes
{
    /// <summary>
    /// The pairing an unknown biome id gets: the forest terrain palette (matching
    /// <see cref="MapThemes.Get"/>) under the neutral dusk-slate backdrop (matching what
    /// <see cref="BackdropThemes.Get"/> has always returned). A missing biome mis-dresses the
    /// encounter; it never stops it.
    /// </summary>
    public static readonly BiomeTheme Default = new()
    {
        Id = "default",
        Terrain = MapThemes.Forest,
        Backdrop = BackdropThemes.Default,
    };

    /// <summary>Every shipped biome look by id.</summary>
    public static readonly IReadOnlyDictionary<string, BiomeTheme> All = BuildAll();

    /// <summary>Look for a biome id; null or unknown ids get <see cref="Default"/>.</summary>
    public static BiomeTheme Get(string? biomeId) =>
        biomeId != null && All.TryGetValue(biomeId, out var theme) ? theme : Default;

    private static IReadOnlyDictionary<string, BiomeTheme> BuildAll()
    {
        var themes = new Dictionary<string, BiomeTheme>();
        foreach (var (id, terrain) in MapThemes.All)
        {
            themes[id] = new BiomeTheme
            {
                Id = id,
                Terrain = terrain,
                Backdrop = BackdropThemes.Authored.TryGetValue(id, out var backdrop)
                    ? backdrop
                    : BackdropThemes.Default,
            };
        }
        return themes;
    }
}
