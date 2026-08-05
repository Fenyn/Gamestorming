using Bulwark.Data;
using Godot;
using PF2e.MapGen;

namespace Bulwark.Combat.Map;

/// <summary>
/// Builds the materials a themed terrain mesh is baked with: flat lit <see cref="StandardMaterial3D"/>
/// for tops and cliffs, the wave <see cref="ShaderMaterial"/> for water tops, and unshaded translucent
/// overlays for the grid lines, cliff-lip strips and mortar bands.
///
/// Terrain meshes are unique per encounter, so their materials are baked onto the mesh surfaces by
/// <see cref="TerrainMeshBuilder"/> (<c>SurfaceSetMaterial</c>) rather than overridden on the
/// MeshInstance3D. Shared meshes — the pooled highlight quads in <c>GridOverlay3D</c> — do the
/// opposite and carry no baked material; the two cases are deliberately NOT uniform.
///
/// Colours are authored as ordinary sRGB (<see cref="MapColor"/>): <c>AlbedoColor</c> assigned from
/// C# is interpreted as sRGB, and the water shader's <c>source_color</c> uniform hint does the same,
/// so no conversion happens here.
/// </summary>
public static class MapMaterials
{
    /// <summary>The wave shader applied to water top faces.</summary>
    public const string WaterShaderPath = "res://assets/shaders/terrain_water.gdshader";

    private const string WaterColorUniform = "water_color";

    private static Shader? _waterShader;
    private static bool _waterShaderMissingReported;

    /// <summary>
    /// Material for the top (walkable) faces of tiles with this surface. Water gets the animated
    /// shader — its surface, its map-edge depth band and its under-bridge fill all share one material
    /// so they displace together and never open a seam.
    /// </summary>
    public static Material Top(MapThemeDefinition theme, SurfaceType surface) =>
        surface == SurfaceType.Water
            ? Water(theme.TopColor(surface))
            : Build(theme.TopColor(surface), $"terrain_top_{surface}");

    /// <summary>Material for cliff faces belonging to tiles with this surface. Never animated.</summary>
    public static Material Wall(MapThemeDefinition theme, SurfaceType surface) =>
        Build(theme.WallColor(surface), $"terrain_wall_{surface}");

    /// <summary>
    /// Flat lit material for one palette colour. Alpha below 1 switches on alpha blending — keying
    /// transparency off the colour keeps translucency from being a special case in the builder.
    /// Roughness 1 / metallic 0 so the placeholder palette reads as matte blocking colour.
    /// </summary>
    public static StandardMaterial3D Build(MapColor color, string resourceName)
    {
        bool translucent = color.A < 1f;
        return new StandardMaterial3D
        {
            ResourceName = resourceName,
            AlbedoColor = ToGodot(color),
            Roughness = 1f,
            Metallic = 0f,
            Transparency = translucent
                ? BaseMaterial3D.TransparencyEnum.Alpha
                : BaseMaterial3D.TransparencyEnum.Disabled,
        };
    }

    /// <summary>
    /// Overlay material: unshaded (a lattice line must read the same on a lit slope and a shaded one),
    /// alpha-blended, and at render priority 1 so it draws after the terrain and the water it decorates
    /// rather than fighting them for the same depth.
    /// </summary>
    public static StandardMaterial3D Overlay(MapColor color, string resourceName) =>
        new()
        {
            ResourceName = resourceName,
            AlbedoColor = ToGodot(color),
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            RenderPriority = 1,
        };

    /// <summary>
    /// Wave material for water tops: the theme's water colour driven through
    /// <see cref="WaterShaderPath"/>. Falls back to the flat translucent material if the shader is
    /// missing, so a broken asset path costs the animation and not the map.
    /// </summary>
    public static Material Water(MapColor color)
    {
        var shader = LoadWaterShader();
        if (shader == null) return Build(color, "terrain_top_Water");

        var material = new ShaderMaterial { ResourceName = "terrain_water", Shader = shader };
        material.SetShaderParameter(WaterColorUniform, ToGodot(color));
        return material;
    }

    /// <summary>sRGB theme colour to engine colour. The single conversion point.</summary>
    public static Color ToGodot(MapColor color) => new(color.R, color.G, color.B, color.A);

    private static Shader? LoadWaterShader()
    {
        if (_waterShader != null) return _waterShader;

        _waterShader = ResourceLoader.Load<Shader>(WaterShaderPath);
        if (_waterShader == null && !_waterShaderMissingReported)
        {
            _waterShaderMissingReported = true;
            GD.PushError($"[MapMaterials] water shader missing at {WaterShaderPath}; water will not animate.");
        }
        return _waterShader;
    }
}
