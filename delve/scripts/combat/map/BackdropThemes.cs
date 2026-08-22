using System.Collections.Generic;
using Delve.Data;

namespace Delve.Combat.Map;

/// <summary>Optional drifting-particle scenery a backdrop theme can ask for.</summary>
public enum BackdropParticleKind
{
    None,

    /// <summary>Slow ambient motes drifting over the board (pollen / dust in a shaft of light).</summary>
    Motes,
}

/// <summary>
/// What kind of prop wall <see cref="EdgeSceneryBuilder"/> rings the battlefield boundary with —
/// the natural "arena fence" standing on the terrain apron just outside the playable tiles.
/// </summary>
public enum BackdropEdgeKind
{
    None,

    /// <summary>Dense band of composed low-poly trees (tiered conifers + blob-canopy deciduous),
    /// short at the line rising taller behind, continuing as a forest fill out to the fog line.</summary>
    TreeWall,

    /// <summary>Low boxy flat-colour masonry wall — undercity brickwork.</summary>
    StoneWall,

    /// <summary>Scattered squat boulders.</summary>
    Boulders,
}

/// <summary>
/// Everything <see cref="CombatBackdrop"/> needs to dress the space AROUND one biome's battle map:
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

    /// <summary>Build the huge matte ground plane far below the board (hides the void under the map's
    /// edge cliffs).</summary>
    public bool HasGroundPlane { get; init; }

    /// <summary>Colour of the ground plane.</summary>
    public MapColor GroundPlaneColor { get; init; }

    /// <summary>Optional drifting particles over the board.</summary>
    public BackdropParticleKind Particles { get; init; } = BackdropParticleKind.None;

    /// <summary>Mote colour; alpha is the mote opacity.</summary>
    public MapColor MoteColor { get; init; }

    // ── Terrain apron + battlefield perimeter (built by EdgeSceneryBuilder) ──

    /// <summary>Apron colour at the board edge — the ground continuing past the map. Author slightly
    /// darker than the biome's walkable tops so the playable area stays the brightest thing.</summary>
    public required MapColor ApronColor { get; init; }

    /// <summary>Apron colour at the far rim. Author close to <see cref="GroundPlaneColor"/> so the
    /// skirt dissolves into the ground plane and fog instead of ending on a seam.</summary>
    public required MapColor ApronRimColor { get; init; }

    /// <summary>Colour of the short water strip continued outward where a river meets the map edge.
    /// Author close to the biome's water top colour.</summary>
    public MapColor ApronWaterColor { get; init; }

    /// <summary>Perimeter prop wall standing on the apron at the battlefield boundary.</summary>
    public BackdropEdgeKind Edge { get; init; } = BackdropEdgeKind.None;

    /// <summary>Primary perimeter prop colour (tree canopy / masonry / boulder).</summary>
    public MapColor EdgePropColor { get; init; }

    /// <summary>Secondary perimeter prop colour; each instance lerps between the two for variation.</summary>
    public MapColor EdgePropColorB { get; init; }

    /// <summary>Perimeter prop size floor, metres. Trees: front-row height. Walls: lowest course.
    /// Boulders: smallest diameter.</summary>
    public float EdgePropHeightMin { get; init; }

    /// <summary>Perimeter prop size ceiling, metres. Trees: back-row height. Walls: tallest course.
    /// Boulders: largest diameter.</summary>
    public float EdgePropHeightMax { get; init; }

    /// <summary>Tree trunk colour (TreeWall edges). Fixed per theme — trunks ignore the per-instance
    /// canopy tint so they stay wooden under any canopy hue.</summary>
    public MapColor TreeTrunkColor { get; init; }

    /// <summary>Height ceiling, metres, for the tallest trees of the forest fill — the continuation
    /// of a TreeWall perimeter outward until the fog swallows it. Ignored by other edge kinds.</summary>
    public float FarTreeHeightMax { get; init; }

    /// <summary>Which <see cref="TileDecor"/> sprite set dresses the walkable tiles (grass tufts,
    /// stones, flowers as HD-2D billboards), or null for bare tiles.</summary>
    public string? DecorSetId { get; init; }
}

/// <summary>
/// The shipped backdrop themes, one per biome id plus the neutral default the flat dev board and any
/// unknown biome fall back to. Companion table to <see cref="MapThemes"/>: same keying, same
/// engine-free colour type, same fallback-not-crash contract.
/// </summary>
public static class BackdropThemes
{
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
        GroundPlaneColor = new(0.11f, 0.12f, 0.15f),
        ApronColor = new(0.155f, 0.165f, 0.205f),
        ApronRimColor = new(0.11f, 0.12f, 0.15f),
        ApronWaterColor = new(0.16f, 0.30f, 0.42f),
        Edge = BackdropEdgeKind.Boulders,
        EdgePropColor = new(0.34f, 0.35f, 0.39f),
        EdgePropColorB = new(0.25f, 0.26f, 0.30f),
        EdgePropHeightMin = 0.5f,
        EdgePropHeightMax = 1.2f,
    };

    /// <summary>
    /// Open woodland day: blue sky over pale haze, warm sun, unbroken forest from arena edge to fog
    /// line, drifting motes. Every green here is a kin of <see cref="Delve.Data.MapThemes.Forest"/>'s
    /// grass top (0.33, 0.55, 0.24) — slightly darker and duller so the playable field stays the
    /// brightest surface and the fog does the distance dimming, never a grey-dead apron.
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
        GroundPlaneColor = new(0.17f, 0.27f, 0.14f),
        Particles = BackdropParticleKind.Motes,
        MoteColor = new(1.0f, 0.98f, 0.85f, 0.14f),
        ApronColor = new(0.31f, 0.50f, 0.22f),
        ApronRimColor = new(0.19f, 0.30f, 0.15f),
        ApronWaterColor = new(0.16f, 0.38f, 0.62f),
        Edge = BackdropEdgeKind.TreeWall,
        // Canopy pair = the crown-tier colour; conifer tiers band darker toward the ground from here.
        EdgePropColor = new(0.20f, 0.38f, 0.16f),
        EdgePropColorB = new(0.28f, 0.48f, 0.19f),
        EdgePropHeightMin = 1.3f,
        EdgePropHeightMax = 4.6f,
        TreeTrunkColor = new(0.29f, 0.21f, 0.14f),
        FarTreeHeightMax = 9f,
        DecorSetId = "forest",
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
        GroundPlaneColor = new(0.045f, 0.055f, 0.055f),
        ApronColor = new(0.155f, 0.165f, 0.165f),
        ApronRimColor = new(0.06f, 0.075f, 0.072f),
        ApronWaterColor = new(0.17f, 0.32f, 0.28f),
        Edge = BackdropEdgeKind.StoneWall,
        EdgePropColor = new(0.30f, 0.31f, 0.33f),
        EdgePropColorB = new(0.22f, 0.23f, 0.25f),
        EdgePropHeightMin = 1.5f,
        EdgePropHeightMax = 2.0f,
    };

    /// <summary>Every shipped backdrop by biome id (the default is the fallback, not an entry).</summary>
    public static readonly IReadOnlyDictionary<string, BackdropThemeDefinition> All =
        new Dictionary<string, BackdropThemeDefinition>
        {
            [Forest.BiomeId] = Forest,
            [Sewer.BiomeId] = Sewer,
        };

    /// <summary>
    /// Backdrop for a biome id; null or unknown ids get <see cref="Default"/>. Same contract as
    /// <see cref="MapThemes.Get"/>: a missing entry mis-dresses the scene, it never crashes it.
    /// </summary>
    public static BackdropThemeDefinition Get(string? biomeId) =>
        biomeId != null && All.TryGetValue(biomeId, out var theme) ? theme : Default;
}
