using Delve.Data;
using Godot;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Dresses the space around the battle map for one biome: swaps the WorldEnvironment onto a
/// <see cref="ProceduralSkyMaterial"/> gradient with depth fog, retunes the scene's one
/// DirectionalLight3D, and builds the far scenery that is not terrain (the ground surround, drifting
/// motes) as its own children. The ground outside the board is no longer scenery at all — it is the
/// generated halo of <see cref="SkirtLayout"/>, rendered by the ordinary terrain mesh builder — so
/// what is left here is the matte surround the halo rim dissolves into, plus the HD-2D sprite
/// scatter <see cref="TileDecor"/> spreads over board AND halo alike.
///
/// Structure only — every colour and tunable comes from <see cref="BackdropThemes"/>; the constants
/// here are placement geometry shared by all themes. Built in code with the same flat-colour material
/// language as <see cref="MapMaterials"/>. <see cref="Apply"/> is idempotent:
/// it clears its own scenery first, so restarting an encounter never stacks backdrops.
/// </summary>
public partial class Backdrop : Node3D
{
    // ── Placement geometry (theme-independent structure) ──

    /// <summary>Side length of the matte ground surround. Its own far edge has to sit deep enough
    /// inside the fog to be invisible, or it draws a hard horizon line across the sky — which is why
    /// this is much larger than the old apron-backed plane needed to be.</summary>
    private const float GroundPlaneSize = 2400f;

    /// <summary>
    /// Ground surround Y. A hair below the halo's outer ring (flat at elevation 0), so the two read
    /// as one surface running into the fog and the rim's own void cliff is buried. The surround is a
    /// FRAME rather than a plane for exactly this reason: a solid plane this high would also roof
    /// over a canyon carved inside the board.
    /// </summary>
    private const float GroundPlaneY = -0.05f;

    /// <summary>Board size, in tiles, the biome fog densities were authored against. A larger board
    /// is framed from further out, so its fog is thinned by the same ratio.</summary>
    private const float FogReferenceBoardTiles = 14f;

    /// <summary>Floor on that thinning — past it the board reads as unfogged, which loses the depth
    /// cue the fog is there for.</summary>
    private const float FogScaleMin = 0.8f;

    // ── Motes: deliberately sparse, small, and faint — ambience in motion, never readable as
    //    stray white squares in a still frame. ──
    private const int MoteCount = 12;
    private const float MoteLifetimeSeconds = 12f;
    private const float MoteQuadSize = 0.035f;
    private const float MoteFieldHalfHeight = 2.2f;
    private const float MoteFieldCenterY = 2.0f;
    private const float MoteFieldPadding = 2f;
    private const float MoteSpeedMin = 0.05f;
    private const float MoteSpeedMax = 0.25f;

    /// <summary>
    /// Apply <paramref name="biomeId"/>'s backdrop (null/unknown → the neutral default) around a
    /// board of the given tile bounds. Reconfigures <paramref name="worldEnvironment"/> and
    /// <paramref name="sun"/> in place and rebuilds this node's scenery children.
    ///
    /// <paramref name="skirt"/> is the rendered board-plus-halo layout and
    /// <paramref name="skirtHeights"/> its heights, both in SKIRT tile coordinates; the tile decor
    /// runs over all of it. A flat board passes null and <see cref="TerrainHeightMap.Flat"/>, which
    /// scatters decor over the placeholder board only.
    /// </summary>
    public void Apply(
        string? biomeId,
        SkirtResult? skirt,
        TerrainHeightMap skirtHeights,
        int gridWidth,
        int gridHeight,
        WorldEnvironment worldEnvironment,
        DirectionalLight3D sun)
    {
        var theme = BackdropThemes.Get(biomeId);

        ApplyEnvironment(worldEnvironment, theme, gridWidth, gridHeight);
        ApplySun(sun, theme);

        this.ClearChildren();
        Vector3 center = GridSpace.BoardCenter(gridWidth, gridHeight);
        int margin = skirt?.Margin ?? 0;
        if (theme.HasGroundPlane)
            AddGroundSurround(center, gridWidth, gridHeight, margin, theme);

        var decorLayout = skirt?.Layout;
        var decor = TileDecor.Build(
            theme, decorLayout,
            decorLayout?.Width ?? gridWidth, decorLayout?.Height ?? gridHeight,
            skirtHeights, margin);
        if (decor != null) AddChild(decor);

        if (theme.Particles == BackdropParticleKind.Motes)
            AddMotes(center, gridWidth, gridHeight, theme);
    }

    // ---------------------------------------------------------------- Atmosphere

    /// <summary>
    /// Replace the environment resource wholesale: sky gradient + exponential fog + flat ambient.
    /// A fresh resource (rather than mutating the .tscn baseline) keeps the swap deterministic — the
    /// inline Environment stays the untouched pre-backdrop baseline.
    /// </summary>
    private static void ApplyEnvironment(
        WorldEnvironment worldEnvironment, BackdropThemeDefinition theme, int gridWidth, int gridHeight)
    {
        var sky = new ProceduralSkyMaterial
        {
            SkyTopColor = MapMaterials.ToGodot(theme.SkyTop),
            SkyHorizonColor = MapMaterials.ToGodot(theme.SkyHorizon),
            // Ground side of the horizon matches the sky side so the seam reads as one haze band.
            GroundHorizonColor = MapMaterials.ToGodot(theme.SkyHorizon),
            GroundBottomColor = MapMaterials.ToGodot(theme.SkyGround),
        };

        worldEnvironment.Environment = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Sky,
            Sky = new Sky { SkyMaterial = sky },
            // Flat colour ambient, same source mode as the scene's baseline environment.
            AmbientLightSource = Godot.Environment.AmbientSource.Color,
            AmbientLightColor = MapMaterials.ToGodot(theme.AmbientColor),
            AmbientLightEnergy = theme.AmbientEnergy,
            FogEnabled = true,
            FogMode = Godot.Environment.FogModeEnum.Exponential,
            FogLightColor = MapMaterials.ToGodot(theme.FogColor),
            // Densities were authored on a 14-tile board; a bigger one is framed from further away,
            // so the same density would swallow it. Thin it by the size ratio, never below half, and
            // never THICKEN a small board (the authored value is already its worst case).
            FogDensity = theme.FogDensity * Mathf.Clamp(
                FogReferenceBoardTiles / Mathf.Max(gridWidth, gridHeight), FogScaleMin, 1f),
            FogSkyAffect = theme.FogSkyAffect,
        };
    }

    /// <summary>Retune the scene's existing sun in place — colour, energy, direction. Never adds a second light.</summary>
    private static void ApplySun(DirectionalLight3D sun, BackdropThemeDefinition theme)
    {
        sun.LightColor = MapMaterials.ToGodot(theme.SunColor);
        sun.LightEnergy = theme.SunEnergy;
        sun.RotationDegrees = new Vector3(-theme.SunElevationDegrees, theme.SunAzimuthDegrees, 0f);
    }

    // ---------------------------------------------------------------- Scenery

    /// <summary>
    /// The matte ground the halo's outer ring runs out onto: four quads forming a frame around the
    /// rendered terrain's footprint, out to the fog horizon. The hole is what makes it a frame and
    /// not a plane — see <see cref="GroundPlaneY"/>.
    /// </summary>
    private void AddGroundSurround(
        Vector3 boardCenter, int gridWidth, int gridHeight, int margin, BackdropThemeDefinition theme)
    {
        float x0 = -margin, z0 = -margin;
        float x1 = gridWidth + margin, z1 = gridHeight + margin;
        float ox0 = boardCenter.X - GroundPlaneSize * 0.5f, oz0 = boardCenter.Z - GroundPlaneSize * 0.5f;
        float ox1 = boardCenter.X + GroundPlaneSize * 0.5f, oz1 = boardCenter.Z + GroundPlaneSize * 0.5f;

        var buffer = new MeshBuffer(withUv: false, withColor: false);
        AddSurroundQuad(buffer, ox0, oz0, ox1, z0);   // south of the terrain
        AddSurroundQuad(buffer, ox0, z1, ox1, oz1);   // north
        AddSurroundQuad(buffer, ox0, z0, x0, z1);     // west
        AddSurroundQuad(buffer, x1, z0, ox1, z1);     // east

        AddChild(new MeshInstance3D
        {
            Name = "GroundSurround",
            Mesh = buffer.ToArrayMesh(
                "backdrop_ground", MapMaterials.Build(theme.GroundPlaneColor, "backdrop_ground")),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        });
    }

    /// <summary>One up-facing quad of the surround, spanning x0..x1 by z0..z1 at the surround's Y.</summary>
    private static void AddSurroundQuad(MeshBuffer buffer, float x0, float z0, float x1, float z1) =>
        TerrainGeometry.AddQuad(buffer, null,
            new Vector3(x0, GroundPlaneY, z0), new Vector3(x1, GroundPlaneY, z0),
            new Vector3(x1, GroundPlaneY, z1), new Vector3(x0, GroundPlaneY, z1));

    /// <summary>
    /// Slow ambient motes drifting over the whole board. Preprocessed for a full lifetime so the
    /// field is already populated on the first rendered frame.
    /// </summary>
    private void AddMotes(Vector3 boardCenter, int gridWidth, int gridHeight, BackdropThemeDefinition theme)
    {
        var halfExtents = new Vector3(
            gridWidth * 0.5f + MoteFieldPadding,
            MoteFieldHalfHeight,
            gridHeight * 0.5f + MoteFieldPadding);

        var quad = new QuadMesh
        {
            Size = new Vector2(MoteQuadSize, MoteQuadSize),
            Material = new StandardMaterial3D
            {
                ResourceName = "backdrop_mote",
                AlbedoColor = MapMaterials.ToGodot(theme.MoteColor),
                ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
                Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            },
        };

        AddChild(new GpuParticles3D
        {
            Name = "Motes",
            Amount = MoteCount,
            Lifetime = MoteLifetimeSeconds,
            Preprocess = MoteLifetimeSeconds,
            DrawPass1 = quad,
            Position = new Vector3(boardCenter.X, MoteFieldCenterY, boardCenter.Z),
            // Explicit AABB: the default is far smaller than the emission box, and an undersized one
            // culls the whole system the moment the camera orbits off-centre.
            VisibilityAabb = new Aabb(-halfExtents, halfExtents * 2f),
            ProcessMaterial = new ParticleProcessMaterial
            {
                EmissionShape = ParticleProcessMaterial.EmissionShapeEnum.Box,
                EmissionBoxExtents = halfExtents,
                Gravity = Vector3.Zero,
                Direction = Vector3.Up,
                Spread = 180f,
                InitialVelocityMin = MoteSpeedMin,
                InitialVelocityMax = MoteSpeedMax,
            },
        });
    }
}
