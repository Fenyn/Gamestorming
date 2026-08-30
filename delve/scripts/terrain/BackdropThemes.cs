using System.Collections.Generic;
using Delve.Data;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>Optional drifting-particle scenery a backdrop theme can ask for.</summary>
public enum BackdropParticleKind
{
    None,

    /// <summary>Slow ambient motes drifting over the board (pollen / dust in a shaft of light).</summary>
    Motes,
}

/// <summary>One tile-decor sprite: art path under assets/sprites/decor/, its pick weight inside its
/// list, and its world height in metres. <paramref name="Flat"/> lays the sprite on the tile surface
/// instead of billboarding it (flower patches).</summary>
public readonly record struct DecorDef(string Texture, float Weight, float Height, bool Flat = false);

/// <summary>The two scatter lists <see cref="TileDecor"/> draws from: one for ordinary ground, one
/// for difficult terrain, where the denser scrub is what makes the movement penalty visible.</summary>
public sealed record DecorSet
{
    public required DecorDef[] Ground { get; init; }

    public required DecorDef[] Difficult { get; init; }
}

/// <summary>
/// Everything <see cref="Backdrop"/> needs to dress the space AROUND one biome's battle map:
/// sky gradient, fog, ambient and sun light, and which optional scenery elements to build. Engine-free
/// by design, exactly like <see cref="MapThemeDefinition"/> — colours are plain sRGB
/// <see cref="MapColor"/> values converted to <c>Godot.Color</c> only inside the backdrop node.
///
/// Keyed by the same <c>BiomeId</c> string the map theme uses, so a biome's terrain palette and its
/// atmosphere are joined by one id. Adding a biome's backdrop = one new entry in
/// <see cref="BackdropThemes"/>; the structural node code never changes.
/// </summary>
public sealed record BackdropThemeDefinition
{
    /// <summary>Registry id of the biome this backdrop dresses ("forest", "sewer"), or "default".</summary>
    public required string BiomeId { get; init; }

    // ── Sky (ProceduralSkyMaterial gradient) ──

    /// <summary>Sky colour at the zenith.</summary>
    public required MapColor SkyTop { get; init; }

    /// <summary>Sky colour at the horizon line (also used for the ground side of the horizon, so the
    /// horizon reads as one continuous haze band rather than a hard sky/ground seam).</summary>
    public required MapColor SkyHorizon { get; init; }

    /// <summary>Below-horizon colour at the nadir — what shows if the camera ever sees past the
    /// backdrop's own ground plane.</summary>
    public required MapColor SkyGround { get; init; }

    // ── Fog (exponential depth fog) ──

    /// <summary>Fog colour. Author close to <see cref="SkyHorizon"/> so distant scenery fades into the
    /// sky instead of into a mismatched veil.</summary>
    public required MapColor FogColor { get; init; }

    /// <summary>Exponential fog density (per world metre). ~0.01 is a light haze on a 20 m board;
    /// ~0.03 swallows everything past mid-distance.</summary>
    public required float FogDensity { get; init; }

    /// <summary>How much the fog dims the sky itself (0 = sky stays crisp, 1 = fog wall). High values
    /// sell an enclosed space with no real sky.</summary>
    public float FogSkyAffect { get; init; }

    // ── Light ──

    /// <summary>Flat ambient light colour (AmbientSource.Color, matching the scene baseline).</summary>
    public required MapColor AmbientColor { get; init; }

    public required float AmbientEnergy { get; init; }

    /// <summary>Directional (sun) light colour.</summary>
    public required MapColor SunColor { get; init; }

    public required float SunEnergy { get; init; }

    /// <summary>Sun elevation above the horizon, degrees (90 = straight down).</summary>
    public required float SunElevationDegrees { get; init; }

    /// <summary>Sun azimuth, degrees of yaw around world Y. 40/47 elevation matches the scene's
    /// authored baseline light so the map's face shading stays familiar.</summary>
    public required float SunAzimuthDegrees { get; init; }

    // ── Optional scenery flags ──

    /// <summary>Build the matte ground surround the generated halo runs out onto.</summary>
    public bool HasGroundPlane { get; init; }

    /// <summary>Colour of the ground surround. Author it as the biome's own walkable ground,
    /// slightly dimmed, so the halo rim and the surround read as one surface into the fog.</summary>
    public MapColor GroundPlaneColor { get; init; }

    /// <summary>Optional drifting particles over the board.</summary>
    public BackdropParticleKind Particles { get; init; } = BackdropParticleKind.None;

    /// <summary>Mote colour; alpha is the mote opacity.</summary>
    public MapColor MoteColor { get; init; }

    // ── Generated skirt (the halo of synthesized tiles around the board) ──

    /// <summary>How the terrain OUTSIDE the board is grown: how wide the halo is, how its hills
    /// swell and settle, what continues outward from the board edge. Read by
    /// <see cref="SkirtLayout"/>, which returns a layout the ordinary mesh builder renders.</summary>
    public required SkirtStyle Skirt { get; init; }

    /// <summary>The sprite set <see cref="TileDecor"/> scatters over the walkable tiles (grass tufts,
    /// stones, flowers as HD-2D billboards), or null for bare tiles.</summary>
    public DecorSet? Decor { get; init; }

    /// <summary>True when this biome's Wall tiles are TREES: the renderer flattens them to their
    /// ground elevation and stands a billboard tree prop on each (<see cref="TreeWalls"/>), instead
    /// of drawing the raised terrain block a stone pillar or vault wall wants. Gameplay never sees
    /// the difference — the tile keeps its Wall role and still blocks movement and sight.</summary>
    public bool WallsAreTrees { get; init; }
}

/// <summary>
/// The authored backdrop entries, one per biome id plus the neutral default the flat dev board and
/// any unknown biome fall back to. <see cref="BiomeThemes"/> joins these to the terrain palettes in
/// <see cref="MapThemes"/> and owns the lookup; this class is only the content plus the
/// <see cref="Get"/> shorthand old callers still use.
///
/// A colour a biome shares with its own terrain — the ground surround the generated halo runs out
/// onto — is READ from <see cref="MapThemes"/> here rather than copied by hand, so the ground past
/// the fog line can never drift away from the ground inside the board.
/// </summary>
public static class BackdropThemes
{
    /// <summary>Woodland tile dressing: sparse tufts, stones and flowers on open ground; dense tall
    /// grass and bushes on difficult terrain.</summary>
    private static readonly DecorSet ForestDecor = new()
    {
        Ground = new DecorDef[]
        {
            new("forest/grass_mid_a.png", 6f, 0.42f),
            new("forest/grass_mid_b.png", 6f, 0.42f),
            new("forest/grass_low_a.png", 5f, 0.38f),
            new("forest/grass_low_b.png", 5f, 0.38f),
            new("forest/grass_tall_a.png", 3f, 0.55f),
            new("forest/grass_tall_b.png", 3f, 0.55f),
            new("forest/stone_flat.png", 2f, 0.16f),
            new("forest/stone_small.png", 2f, 0.13f),
            new("forest/stone_tall.png", 0.8f, 0.32f),
            new("forest/fireweed_a.png", 1.2f, 0.50f),
            new("forest/fireweed_b.png", 1.2f, 0.50f),
            new("forest/mushroom.png", 0.6f, 0.26f),
            new("forest/flowers_mixed.png", 2f, 0.66f, Flat: true),
            new("forest/flowers_red.png", 1.2f, 0.66f, Flat: true),
            new("forest/flowers_orange.png", 1.2f, 0.66f, Flat: true),
        },
        Difficult = new DecorDef[]
        {
            new("forest/grass_tall_a.png", 6f, 0.60f),
            new("forest/grass_tall_b.png", 6f, 0.60f),
            new("forest/bush_small.png", 3f, 0.48f),
            new("forest/grass_mid_a.png", 2f, 0.45f),
            new("forest/grass_mid_b.png", 2f, 0.45f),
            new("forest/fireweed_a.png", 1.5f, 0.52f),
            new("forest/fireweed_b.png", 1.5f, 0.52f),
        },
    };

    /// <summary>
    /// Neutral dusk-slate backdrop: used for the flat checker board and as the fallback for a biome
    /// with no entry. Deliberately close to the old void colour so pre-backdrop scenes read the same,
    /// just grounded — soft gradient, light haze, no scenery beyond the ground plane.
    /// </summary>
    public static readonly BackdropThemeDefinition Default = new()
    {
        BiomeId = "default",
        SkyTop = new(0.10f, 0.12f, 0.18f),
        SkyHorizon = new(0.26f, 0.28f, 0.36f),
        SkyGround = new(0.08f, 0.09f, 0.12f),
        FogColor = new(0.22f, 0.24f, 0.30f),
        FogDensity = 0.014f,
        FogSkyAffect = 0.15f,
        AmbientColor = new(0.62f, 0.64f, 0.72f),
        AmbientEnergy = 1.0f,
        SunColor = new(0.95f, 0.95f, 1.0f),
        SunEnergy = 1.0f,
        SunElevationDegrees = 47f,
        SunAzimuthDegrees = 40f,
        HasGroundPlane = true,
        GroundPlaneColor = new(0.145f, 0.155f, 0.190f),
        Skirt = new SkirtStyle
        {
            HillAmplitudeElevations = 1.5f,
            RiverMeander = 1.5f,
        },
    };

    /// <summary>
    /// Open woodland day: blue sky over pale haze, warm sun, hills and thickening woodland from the
    /// arena edge to the fog line, drifting motes. Every green here is a kin of
    /// <see cref="Delve.Data.MapThemes.Forest"/>'s grass top — the ground surround takes that colour
    /// directly and only dims it, so the playable field stays the brightest surface and the fog does
    /// the distance dimming.
    /// </summary>
    public static readonly BackdropThemeDefinition Forest = new()
    {
        BiomeId = "forest",
        SkyTop = new(0.32f, 0.50f, 0.72f),
        SkyHorizon = new(0.70f, 0.79f, 0.83f),
        SkyGround = new(0.24f, 0.30f, 0.24f),
        FogColor = new(0.64f, 0.74f, 0.78f),
        FogDensity = 0.010f,
        FogSkyAffect = 0.06f,
        AmbientColor = new(0.64f, 0.68f, 0.70f),
        AmbientEnergy = 1.0f,
        SunColor = new(1.0f, 0.96f, 0.87f),
        SunEnergy = 1.2f,
        SunElevationDegrees = 47f,
        SunAzimuthDegrees = 40f,
        HasGroundPlane = true,
        GroundPlaneColor = Shade(MapThemes.Forest, SurfaceType.Grass, 0.91f),
        Particles = BackdropParticleKind.Motes,
        MoteColor = new(1.0f, 0.98f, 0.85f, 0.14f),
        Decor = ForestDecor,
        WallsAreTrees = true,
        // Surfaces mirror the forest biome's own defaults (Grass / Dirt / Dirt), so a synthesized
        // patch outside the board is made of the same material as one inside it.
        Skirt = new SkirtStyle
        {
            HillAmplitudeElevations = 3f,
            HillFrequency = 9f,
            DifficultPatchChance = 0.35f,
            TreeDensityNear = 0.02f,
            TreeDensityFar = 0.22f,
            RiverMeander = 2.5f,
            GroundSurface = SurfaceType.Grass,
            DifficultSurface = SurfaceType.Dirt,
            WallSurface = SurfaceType.Dirt,
        },
    };

    /// <summary>
    /// Undercity drain: no sky to see — a near-black green-tinged gradient buried under heavy fog
    /// (high FogSkyAffect turns the sky into vault murk), dim cool light, high sun elevation for
    /// grate-shaft shading. No horizon scenery on purpose: the enclosure IS the backdrop.
    /// </summary>
    public static readonly BackdropThemeDefinition Sewer = new()
    {
        BiomeId = "sewer",
        SkyTop = new(0.020f, 0.028f, 0.030f),
        SkyHorizon = new(0.055f, 0.075f, 0.070f),
        SkyGround = new(0.020f, 0.025f, 0.025f),
        FogColor = new(0.085f, 0.115f, 0.105f),
        FogDensity = 0.030f,
        FogSkyAffect = 0.6f,
        AmbientColor = new(0.42f, 0.48f, 0.48f),
        AmbientEnergy = 0.85f,
        SunColor = new(0.75f, 0.84f, 0.82f),
        SunEnergy = 0.75f,
        SunElevationDegrees = 62f,
        SunAzimuthDegrees = 40f,
        HasGroundPlane = true,
        GroundPlaneColor = Shade(MapThemes.Sewer, SurfaceType.Stone, 0.91f),
        // No sky and no hills down here: the halo is solid masonry around a few outgoing tunnels.
        // Surfaces mirror the sewer biome's defaults (Stone / Mud / Stone).
        Skirt = new SkirtStyle
        {
            HillAmplitudeElevations = 0f,
            WallRings = 2,
            RiverMeander = 1f,
            GroundSurface = SurfaceType.Stone,
            DifficultSurface = SurfaceType.Mud,
            WallSurface = SurfaceType.Stone,
        },
    };

    /// <summary>Every authored backdrop by biome id (the default is the fallback, not an entry).
    /// <see cref="BiomeThemes"/> reads this table; scene code reads <see cref="Get"/>.</summary>
    public static readonly IReadOnlyDictionary<string, BackdropThemeDefinition> Authored =
        new Dictionary<string, BackdropThemeDefinition>
        {
            [Forest.BiomeId] = Forest,
            [Sewer.BiomeId] = Sewer,
        };

    /// <summary>
    /// Backdrop for a biome id; null or unknown ids get <see cref="Default"/>. Shorthand for
    /// <c>BiomeThemes.Get(id).Backdrop</c> — the one registry does the lookup.
    /// </summary>
    public static BackdropThemeDefinition Get(string? biomeId) => BiomeThemes.Get(biomeId).Backdrop;

    /// <summary>A terrain top colour scaled toward black. The ground surround is the biome's own
    /// ground continuing past the halo, so it starts from that ground's colour and only dims.</summary>
    private static MapColor Shade(MapThemeDefinition terrain, SurfaceType surface, float factor)
    {
        var c = terrain.TopColor(surface);
        return new(c.R * factor, c.G * factor, c.B * factor);
    }
}
