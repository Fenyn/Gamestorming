using System.Collections.Generic;
using PF2e.MapGen;

namespace Delve.Data;

/// <summary>
/// A plain sRGB colour. Deliberately NOT <c>Godot.Color</c>: themes are declarative data that the
/// headless generation/validation paths read without touching the engine. <see cref="Delve.Combat.Map.MapMaterials"/>
/// converts to <c>Godot.Color</c> at the one place a material is built (AlbedoColor from C# is
/// interpreted as sRGB, so these are authored as ordinary sRGB values — no linearization here).
/// </summary>
/// <param name="A">Alpha below 1 marks the colour as translucent: the material factory switches on
/// alpha blending from the colour alone, so overlays and tinted surfaces need no flag of their own.
/// It also carries through to the water shader's colour uniform.</param>
public readonly record struct MapColor(float R, float G, float B, float A = 1f);

/// <summary>Top-face and cliff-face looks for one <see cref="SurfaceType"/> in a theme.</summary>
public sealed record MapSurfaceStyle
{
    /// <summary>Colour of the tile's walkable top face — the look when <see cref="TopTexture"/> is
    /// null, and the flat placeholder any headless/diagnostic path reads either way.</summary>
    public required MapColor Top { get; init; }

    /// <summary>Colour of cliff/wall faces belonging to tiles with this surface. Darker by convention.
    /// Flat fallback when <see cref="WallTexture"/> is null.</summary>
    public required MapColor Wall { get; init; }

    /// <summary>Optional res:// path of a seamless pixel-art texture for the top faces, tiled once
    /// per world metre (one board tile). Plain string so the theme stays engine-free.</summary>
    public string? TopTexture { get; init; }

    /// <summary>Optional res:// path of a seamless texture for cliff/wall faces.</summary>
    public string? WallTexture { get; init; }

    /// <summary>Multiplied over <see cref="TopTexture"/> — white leaves the art untinted; a colour
    /// re-shades a shared texture (e.g. the dirt tile darkened into mud).</summary>
    public MapColor TopTint { get; init; } = new(1f, 1f, 1f);

    /// <summary>Multiplied over <see cref="WallTexture"/>.</summary>
    public MapColor WallTint { get; init; } = new(1f, 1f, 1f);
}

/// <summary>
/// Visual theme for one generated biome: the flat placeholder palette the terrain mesh builder routes
/// geometry through, plus the height scale the whole 3D board agrees on.
///
/// Keyed by <c>BiomeId</c> — the same string <see cref="PF2e.MapGen.Biomes.MapGenRegistry"/> resolves,
/// so a biome and its look are joined by one id and nothing else. Engine-free by design (see
/// <see cref="MapColor"/>).
/// </summary>
public sealed record MapThemeDefinition
{
    /// <summary>Registry id of the biome this theme dresses ("forest", "sewer").</summary>
    public required string BiomeId { get; init; }

    public required string DisplayName { get; init; }

    /// <summary>Per-surface colours. Surfaces with no entry fall back to <see cref="FallbackTop"/>/<see cref="FallbackWall"/>.</summary>
    public required IReadOnlyDictionary<SurfaceType, MapSurfaceStyle> Surfaces { get; init; }

    /// <summary>
    /// World Y units per corner-height unit. 0.125 puts one elevation
    /// (<see cref="PF2e.Grid.TileCornerHeights.UnitsPerElevation"/> = 4 units) at 0.5 m, which is the
    /// half-tile step the 1 tile = 1 m board (<c>GridSpace.TileSize</c>) is built around.
    /// </summary>
    public float HeightScale { get; init; } = MapThemes.DefaultHeightScale;

    public MapColor FallbackTop { get; init; } = new(0.55f, 0.55f, 0.57f);
    public MapColor FallbackWall { get; init; } = new(0.35f, 0.35f, 0.38f);

    // ── Overlays. Defaults are Unity's shipped MapTheme values: all three on, same widths, same
    //    near-black translucent colours. Unity built the overlay materials inside its palette rather
    //    than on the theme, so the colours were map-wide; they live here instead because a theme is
    //    where a look belongs, and a future biome can dial one down without touching the builder. ──

    /// <summary>Dark strips along cliff top edges — a depth cue at the lip of a drop.</summary>
    public bool EnableCliffEdgeStrips { get; init; } = true;

    /// <summary>Strip width as a fraction of tile size.</summary>
    public float CliffEdgeStripWidth { get; init; } = 0.08f;

    /// <summary>Colour of the cliff-lip strips.</summary>
    public MapColor EdgeStripColor { get; init; } = new(0f, 0f, 0f, 0.7f);

    /// <summary>Mortar bands across cliff faces at each cubic-unit boundary (every 2 elevations).</summary>
    public bool EnableCliffBands { get; init; } = true;

    /// <summary>Band thickness in world units. Keep small; the bands are meant to be countable, not loud.</summary>
    public float CliffBandThickness { get; init; } = 0.03f;

    /// <summary>Colour of the cliff mortar bands.</summary>
    public MapColor CliffBandColor { get; init; } = new(0f, 0f, 0f, 0.35f);

    /// <summary>Per-tile lattice drawn on walkable top faces.</summary>
    public bool EnableTopGridLines { get; init; } = true;

    /// <summary>Grid-line width as a fraction of tile size.</summary>
    public float TopGridLineWidth { get; init; } = 0.025f;

    /// <summary>Colour of the top-face lattice.</summary>
    public MapColor TopGridLineColor { get; init; } = new(0f, 0f, 0f, 0.4f);

    /// <summary>The full style entry for a surface, or null when the theme has none (callers then
    /// fall back to <see cref="FallbackTop"/>/<see cref="FallbackWall"/> via the colour accessors).</summary>
    public MapSurfaceStyle? Style(SurfaceType surface) =>
        Surfaces.TryGetValue(surface, out var style) ? style : null;

    public MapColor TopColor(SurfaceType surface) =>
        Surfaces.TryGetValue(surface, out var style) ? style.Top : FallbackTop;

    public MapColor WallColor(SurfaceType surface) =>
        Surfaces.TryGetValue(surface, out var style) ? style.Wall : FallbackWall;
}

/// <summary>
/// The shipped map themes, one per biome id in <see cref="PF2e.MapGen.Biomes.MapGenRegistry"/>.
/// Placeholder flat colours — readable enough to judge terrain shape in a screenshot, and cheap to
/// replace once real materials exist.
/// </summary>
public static class MapThemes
{
    /// <summary>World Y per corner-height unit. Shared default; see <see cref="MapThemeDefinition.HeightScale"/>.</summary>
    public const float DefaultHeightScale = 0.125f;

    /// <summary>Open woodland: green tops, earthy banks, blue-green water.</summary>
    public static readonly MapThemeDefinition Forest = new()
    {
        BiomeId = "forest",
        DisplayName = "Woodland",
        Surfaces = new Dictionary<SurfaceType, MapSurfaceStyle>
        {
            // Textured surfaces: seamless 48px Winlu ground tiles (assets/textures/terrain/), one
            // repeat per board tile. Cliffs share the mossy rock face; mud re-tints the alt dirt.
            [SurfaceType.Grass] = Style(new(0.33f, 0.55f, 0.24f), new(0.20f, 0.33f, 0.15f)) with
            {
                TopTexture = Tex("grass_a"),
                WallTexture = Tex("rock_b"),
            },
            [SurfaceType.Dirt] = Style(new(0.48f, 0.36f, 0.24f), new(0.30f, 0.22f, 0.15f)) with
            {
                TopTexture = Tex("dirt_a"),
                WallTexture = Tex("rock_b"),
            },
            [SurfaceType.Stone] = Style(new(0.55f, 0.55f, 0.57f), new(0.35f, 0.35f, 0.38f)) with
            {
                TopTexture = Tex("stone_b"),
                WallTexture = Tex("stone_a"),
                WallTint = new(0.75f, 0.75f, 0.78f),
            },
            // Deck boards carry staggered end-joints (bridge_deck); the slab sides read as stacked
            // lengthwise beams (bridge_beam = the same boards rotated).
            [SurfaceType.Wood] = Style(new(0.62f, 0.46f, 0.28f), new(0.40f, 0.29f, 0.17f)) with
            {
                TopTexture = Tex("bridge_deck"),
                WallTexture = Tex("bridge_beam"),
                WallTint = new(0.78f, 0.74f, 0.70f),
            },
            [SurfaceType.Water] = Style(new(0.16f, 0.38f, 0.62f, 0.8f), new(0.10f, 0.24f, 0.40f)),
            [SurfaceType.Mud] = Style(new(0.32f, 0.25f, 0.18f), new(0.20f, 0.16f, 0.11f)) with
            {
                TopTexture = Tex("dirt_b"),
                TopTint = new(0.70f, 0.64f, 0.58f),
                WallTexture = Tex("rock_b"),
            },
            [SurfaceType.Sand] = Style(new(0.80f, 0.72f, 0.50f), new(0.58f, 0.51f, 0.34f)),
            [SurfaceType.Snow] = Style(new(0.90f, 0.92f, 0.95f), new(0.68f, 0.72f, 0.78f)),
            [SurfaceType.Lava] = Style(new(0.90f, 0.35f, 0.10f), new(0.42f, 0.13f, 0.05f)),
        },
    };

    /// <summary>Undercity drains: cold stone, mossy ledges, murky water.</summary>
    public static readonly MapThemeDefinition Sewer = new()
    {
        BiomeId = "sewer",
        DisplayName = "Undercity Drain",
        FallbackTop = new(0.40f, 0.41f, 0.43f),
        FallbackWall = new(0.24f, 0.25f, 0.27f),
        Surfaces = new Dictionary<SurfaceType, MapSurfaceStyle>
        {
            [SurfaceType.Grass] = Style(new(0.28f, 0.38f, 0.24f), new(0.17f, 0.24f, 0.15f)),
            [SurfaceType.Dirt] = Style(new(0.36f, 0.30f, 0.22f), new(0.22f, 0.18f, 0.13f)),
            [SurfaceType.Stone] = Style(new(0.40f, 0.41f, 0.43f), new(0.24f, 0.25f, 0.27f)),
            [SurfaceType.Wood] = Style(new(0.46f, 0.35f, 0.22f), new(0.29f, 0.21f, 0.13f)),
            [SurfaceType.Water] = Style(new(0.17f, 0.32f, 0.28f, 0.8f), new(0.10f, 0.19f, 0.17f)),
            [SurfaceType.Mud] = Style(new(0.26f, 0.22f, 0.16f), new(0.16f, 0.13f, 0.10f)),
            [SurfaceType.Sand] = Style(new(0.62f, 0.57f, 0.42f), new(0.44f, 0.40f, 0.29f)),
            [SurfaceType.Snow] = Style(new(0.78f, 0.81f, 0.84f), new(0.56f, 0.60f, 0.65f)),
            [SurfaceType.Lava] = Style(new(0.90f, 0.35f, 0.10f), new(0.42f, 0.13f, 0.05f)),
        },
    };

    /// <summary>Every shipped theme by biome id.</summary>
    public static readonly IReadOnlyDictionary<string, MapThemeDefinition> All =
        new Dictionary<string, MapThemeDefinition>
        {
            [Forest.BiomeId] = Forest,
            [Sewer.BiomeId] = Sewer,
        };

    /// <summary>
    /// Theme for a biome id, falling back to <see cref="Forest"/> for an unknown id. A missing theme
    /// is a content bug, not a crash: the map still builds, in the wrong colours, and the caller keeps
    /// running. <see cref="TryGet"/> is the strict form.
    /// </summary>
    public static MapThemeDefinition Get(string biomeId) =>
        biomeId != null && All.TryGetValue(biomeId, out var theme) ? theme : Forest;

    public static bool TryGet(string biomeId, out MapThemeDefinition theme)
    {
        if (biomeId != null && All.TryGetValue(biomeId, out var found))
        {
            theme = found;
            return true;
        }
        theme = Forest;
        return false;
    }

    private static MapSurfaceStyle Style(MapColor top, MapColor wall) => new() { Top = top, Wall = wall };

    private static string Tex(string name) => $"res://assets/textures/terrain/{name}.png";
}
