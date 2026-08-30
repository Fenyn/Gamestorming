using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

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
///
/// Every material this class returns is CACHED and SHARED: two encounters in the same biome get the
/// same StandardMaterial3D/ShaderMaterial instance instead of a fresh copy per map. Callers must
/// therefore treat a returned material as read-only — assign it, never write to it. A node that
/// needs to animate a colour (unit rings, HP bars) builds its own material instead. The one
/// per-encounter material is the baked ground texture, which <see cref="GroundTextureBaker"/> owns.
/// </summary>
public static class MapMaterials
{
    /// <summary>Identity of a shared material: what kind it is, which palette entry it dresses, and
    /// the colour it carries. Textured walls key on the theme id and surface, because their look
    /// comes from the whole <see cref="MapSurfaceStyle"/> and not from one colour.</summary>
    private readonly record struct MaterialKey(string Kind, string Id, MapColor Color);

    /// <summary>Shared materials by identity. Static for the process: a terrain material is pure
    /// look, so it outlives the encounter that first asked for it.</summary>
    private static readonly Dictionary<MaterialKey, Material> Cache = new();

    /// <summary>The wave shader applied to water top faces.</summary>
    public const string WaterShaderPath = "res://assets/shaders/terrain_water.gdshader";

    private const string WaterColorUniform = "water_color";

    /// <summary>Depth (world metres) the surface art drapes down a cliff face: one elevation.</summary>
    private const string DrapeDepthUniform = "drape_depth";

    /// <summary>Loaded shaders by path. A path that failed once is cached as null and never
    /// reported twice — a missing shader costs its effect, not a wall of errors per frame.</summary>
    private static readonly Dictionary<string, Shader?> ShaderCache = new();

    /// <summary>
    /// Load a terrain shader once and keep it. Returns null and reports the path once when the asset
    /// is missing, so every caller can fall back on its own.
    /// </summary>
    public static Shader? LoadShader(string path)
    {
        if (ShaderCache.TryGetValue(path, out var cached)) return cached;

        var shader = ResourceLoader.Load<Shader>(path);
        ShaderCache[path] = shader;
        if (shader == null)
            GD.PushError($"[MapMaterials] shader missing at {path}; the effect it drives is skipped.");
        return shader;
    }

    /// <summary>
    /// Material for the top (walkable) faces of tiles with this surface. Water gets the animated
    /// shader — its surface, its map-edge depth band and its under-bridge fill all share one material
    /// so they displace together and never open a seam. Every other top face is a flat palette
    /// colour: a textured surface never reaches here, because <see cref="GroundTextureBaker"/> bakes
    /// all of them into one board-wide material.
    /// </summary>
    public static Material Top(MapThemeDefinition theme, SurfaceType surface) =>
        surface == SurfaceType.Water
            ? Water(theme.TopColor(surface))
            : Build(theme.TopColor(surface), $"terrain_top_{surface}");

    /// <summary>The lip-anchored cliff shader (see terrain_wall.gdshader).</summary>
    public const string WallShaderPath = "res://assets/shaders/terrain_wall.gdshader";

    /// <summary>
    /// Material for cliff faces belonging to tiles with this surface. Never animated. A textured
    /// wall renders through the lip-anchored wall shader: the mesh's wall UVs put V = 0 at the top
    /// lip, the first metre samples the surface's transition tile (grass/earth draping over the wall
    /// art) and deeper metres repeat the body texture.
    /// </summary>
    public static Material Wall(MapThemeDefinition theme, SurfaceType surface)
    {
        var key = new MaterialKey("wall", $"{theme.BiomeId}/{surface}", default);
        if (Cache.TryGetValue(key, out var shared)) return shared;
        var built = BuildWall(theme, surface);
        Cache[key] = built;
        return built;
    }

    private static Material BuildWall(MapThemeDefinition theme, SurfaceType surface)
    {
        var style = theme.Style(surface);
        if (style?.WallTexture == null)
            return Build(theme.WallColor(surface), $"terrain_wall_{surface}");

        var shader = LoadShader(WallShaderPath);
        var body = ResourceLoader.Load<Texture2D>(style.WallTexture);
        if (shader == null || body == null)
        {
            if (body == null)
                GD.PushError($"[MapMaterials] wall texture missing at {style.WallTexture}; using flat colour.");
            return Build(theme.WallColor(surface), $"terrain_wall_{surface}");
        }

        var top = style.WallTopTexture != null
            ? ResourceLoader.Load<Texture2D>(style.WallTopTexture) ?? body
            : body;

        var material = new ShaderMaterial { ResourceName = $"terrain_wall_{surface}", Shader = shader };
        material.SetShaderParameter("top_texture", top);
        material.SetShaderParameter("body_texture", body);
        material.SetShaderParameter("tint", ToGodot(style.WallTint));
        material.SetShaderParameter(
            DrapeDepthUniform, theme.HeightScale * TileCornerHeights.UnitsPerElevation);
        return material;
    }

    /// <summary>
    /// Flat lit material for one palette colour. Alpha below 1 switches on alpha blending — keying
    /// transparency off the colour keeps translucency from being a special case in the builder.
    /// Roughness 1 / metallic 0 so the placeholder palette reads as matte blocking colour.
    /// </summary>
    public static StandardMaterial3D Build(MapColor color, string resourceName)
    {
        var key = new MaterialKey("flat", resourceName, color);
        if (Cache.TryGetValue(key, out var shared)) return (StandardMaterial3D)shared;

        bool translucent = color.A < 1f;
        var material = new StandardMaterial3D
        {
            ResourceName = resourceName,
            AlbedoColor = ToGodot(color),
            Roughness = 1f,
            Metallic = 0f,
            Transparency = translucent
                ? BaseMaterial3D.TransparencyEnum.Alpha
                : BaseMaterial3D.TransparencyEnum.Disabled,
        };
        Cache[key] = material;
        return material;
    }

    /// <summary>
    /// Overlay material: unshaded (a lattice line must read the same on a lit slope and a shaded one),
    /// alpha-blended, and at render priority 1 so it draws after the terrain and the water it decorates
    /// rather than fighting them for the same depth.
    /// </summary>
    public static StandardMaterial3D Overlay(MapColor color, string resourceName)
    {
        var key = new MaterialKey("overlay", resourceName, color);
        if (Cache.TryGetValue(key, out var shared)) return (StandardMaterial3D)shared;

        var material = new StandardMaterial3D
        {
            ResourceName = resourceName,
            AlbedoColor = ToGodot(color),
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            RenderPriority = 1,
        };
        Cache[key] = material;
        return material;
    }

    /// <summary>
    /// Wave material for water tops: the theme's water colour driven through
    /// <see cref="WaterShaderPath"/>. Falls back to the flat translucent material if the shader is
    /// missing, so a broken asset path costs the animation and not the map.
    /// </summary>
    public static Material Water(MapColor color)
    {
        var shader = LoadShader(WaterShaderPath);
        if (shader == null) return Build(color, "terrain_top_Water");

        var key = new MaterialKey("water", "terrain_water", color);
        if (Cache.TryGetValue(key, out var shared)) return shared;

        var material = new ShaderMaterial { ResourceName = "terrain_water", Shader = shader };
        material.SetShaderParameter(WaterColorUniform, ToGodot(color));
        Cache[key] = material;
        return material;
    }

    /// <summary>sRGB theme colour to engine colour. The single conversion point.</summary>
    public static Color ToGodot(MapColor color) => new(color.R, color.G, color.B, color.A);
}
