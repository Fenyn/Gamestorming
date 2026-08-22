using Delve.Data;
using Godot;
using PF2e.MapGen;

namespace Delve.Combat.Map;

/// <summary>
/// Dresses the space around the battle map for one biome: swaps the WorldEnvironment onto a
/// <see cref="ProceduralSkyMaterial"/> gradient with depth fog, retunes the scene's one
/// DirectionalLight3D, and builds whatever far scenery the theme asks for (ground plane, drifting
/// motes) as its own children. Everything standing on the ground — apron, perimeter props, and the
/// forest fill running out to the fog line — is built by <see cref="EdgeSceneryBuilder"/>; the HD-2D
/// sprite scatter on the walkable tiles themselves by <see cref="TileDecor"/>.
///
/// Structure only — every colour and tunable comes from <see cref="BackdropThemes"/>; the constants
/// here are placement geometry shared by all themes. Built in code with the same flat-colour material
/// language as <see cref="MapMaterials"/>. <see cref="Apply"/> is idempotent:
/// it clears its own scenery first, so restarting an encounter never stacks backdrops.
/// </summary>
public partial class CombatBackdrop : Node3D
{
    // ── Placement geometry (theme-independent structure) ──

    /// <summary>Side length of the matte ground plane. Its edge lies far past the fog horizon.</summary>
    private const float GroundPlaneSize = 700f;

    /// <summary>Ground plane Y — safely below the deepest terrain carve (water bands reach ~-1 m).</summary>
    private const float GroundPlaneY = -6f;

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
    /// <paramref name="layout"/>/<paramref name="heightMap"/> feed the edge scenery (terrain apron +
    /// battlefield perimeter); a flat board passes null and <see cref="TerrainHeightMap.Flat"/> and
    /// gets a level apron from the y = 0 board edge.
    /// </summary>
    public void Apply(
        string? biomeId,
        MapLayout? layout,
        TerrainHeightMap heightMap,
        int gridWidth,
        int gridHeight,
        WorldEnvironment worldEnvironment,
        DirectionalLight3D sun)
    {
        var theme = BackdropThemes.Get(biomeId);

        ApplyEnvironment(worldEnvironment, theme);
        ApplySun(sun, theme);

        ClearScenery();
        Vector3 center = Combat.GridSpace.BoardCenter(gridWidth, gridHeight);
        if (theme.HasGroundPlane)
            AddGroundPlane(center, theme);
        AddChild(EdgeSceneryBuilder.Build(
            theme, layout, gridWidth, gridHeight, heightMap.HeightScale, GroundPlaneY));
        if (TileDecor.Build(theme, layout, gridWidth, gridHeight, heightMap) is { } decor)
            AddChild(decor);
        if (theme.Particles == BackdropParticleKind.Motes)
            AddMotes(center, gridWidth, gridHeight, theme);
    }

    // ---------------------------------------------------------------- Atmosphere

    /// <summary>
    /// Replace the environment resource wholesale: sky gradient + exponential fog + flat ambient.
    /// A fresh resource (rather than mutating the .tscn baseline) keeps the swap deterministic — the
    /// inline Environment stays the untouched pre-backdrop baseline.
    /// </summary>
    private static void ApplyEnvironment(WorldEnvironment worldEnvironment, BackdropThemeDefinition theme)
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
            FogDensity = theme.FogDensity,
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

    private void ClearScenery()
    {
        foreach (var child in GetChildren())
        {
            RemoveChild(child);
            child.QueueFree();
        }
    }

    /// <summary>Huge matte plane far below the board: the map sits over ground, not over void.</summary>
    private void AddGroundPlane(Vector3 boardCenter, BackdropThemeDefinition theme)
    {
        AddChild(new MeshInstance3D
        {
            Name = "GroundPlane",
            Mesh = new PlaneMesh { Size = new Vector2(GroundPlaneSize, GroundPlaneSize) },
            MaterialOverride = MapMaterials.Build(theme.GroundPlaneColor, "backdrop_ground"),
            Position = new Vector3(boardCenter.X, GroundPlaneY, boardCenter.Z),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        });
    }

    /// <summary>
    /// Slow ambient motes drifting over the whole board. Preprocessed for a full lifetime so the
    /// field is already populated on the first rendered frame.
    /// </summary>
    private void AddMotes(Vector3 boardCenter, int gridWidth, int gridHeight, BackdropThemeDefinition theme)
    {
        var halfExtents = new Vector3(
            gridWidth * Combat.GridSpace.TileSize * 0.5f + MoteFieldPadding,
            MoteFieldHalfHeight,
            gridHeight * Combat.GridSpace.TileSize * 0.5f + MoteFieldPadding);

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
