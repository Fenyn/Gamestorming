using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Bakes a nearest-filtered board atlas from surface variants, then merges touching natural
/// materials with irregular pixel transitions. Explicit top-down projection keeps each slope
/// sampling its own tile. Geometry and gameplay surface classifications are unaffected.
/// </summary>
public static class GroundTextureBaker
{
    /// <summary>
    /// Bake the board's shared ground-top material, or null when the theme textures nothing.
    /// <paramref name="eff"/> is the effective-surface grid from <see cref="EffectiveSurfaceGrid"/>,
    /// built once per map by the caller and shared with the mesh builder.
    /// <paramref name="worldOrigin"/> is the world XZ of the layout's tile (0,0) corner: the atlas
    /// is sampled relative to it, so a mesh translated away from the origin keeps its own cells.
    /// </summary>
    public static Material? Bake(
        MapLayout layout, MapThemeDefinition theme, SurfaceType[] eff, Vector2 worldOrigin = default)
    {
        bool anyTexture = false;
        foreach (var style in theme.Surfaces.Values)
            anyTexture |= style.HasTopTexture;
        if (!anyTexture) return null;

        var landmarks = new LandmarkTexturePainter(layout);
        var sources = new Dictionary<string, Image>();
        int w = layout.Width, h = layout.Height;
        int tilePx = theme.TilePx;
        var board = Image.CreateEmpty(w * tilePx, h * tilePx, false, Image.Format.Rgba8);

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            var surface = eff[y * w + x];
            var origin = new Vector2I(x * tilePx, y * tilePx);

            var variants = TopTextures(theme, surface);
            if (variants == null)
            {
                // Untextured surface (water, sand, …): flat theme colour keeps the sheet holeless.
                board.FillRect(new Rect2I(origin, new Vector2I(tilePx, tilePx)),
                    MapMaterials.ToGodot(theme.TopColor(surface)));
                continue;
            }

            string pick = variants[(int)(MapHash.Hash01(x, y, layout.Seed) * variants.Length) % variants.Length];

            // Bridge decks: slats run crosswise to the direction of travel, so a bridge running
            // along Z uses the plank tile rotated 90° (its boards are painted vertical).
            if (layout.GetTile(x, y) == TileRole.Bridge && BridgeRunsAlongZ(layout, x, y))
                pick += RotatedSuffix;

            // A texture larger than one tile is a field that spans several tiles: each tile takes its
            // own window of it by board position, so the painting runs on across tile edges.
            var source = LoadTile(sources, pick, tilePx);
            var window = new Vector2I(x * tilePx % Mathf.Max(tilePx, source.GetWidth()),
                y * tilePx % Mathf.Max(tilePx, source.GetHeight()));
            board.BlitRect(source, new Rect2I(window, new Vector2I(tilePx, tilePx)), origin);
            landmarks.Paint(board, layout, x, y, tilePx);
        }

        GroundTextureTransitions.Blend(board, layout, eff, tilePx);

        var material = BuildGroundMaterial(board, w, h, worldOrigin);
        return material;
    }

    /// <summary>The theme's top-texture variants for a surface, or null when it has none.</summary>
    private static string[]? TopTextures(MapThemeDefinition theme, SurfaceType surface)
    {
        var style = theme.Style(surface);
        return style is { HasTopTexture: true } ? style.TopTextures : null;
    }

    /// <summary>True when the bridge tile continues north/south (its travel axis is world Z).</summary>
    private static bool BridgeRunsAlongZ(MapLayout layout, int x, int y)
    {
        bool along = IsBridge(layout, x, y - 1) || IsBridge(layout, x, y + 1);
        bool across = IsBridge(layout, x - 1, y) || IsBridge(layout, x + 1, y);
        return along && !across;

        static bool IsBridge(MapLayout l, int x, int y) => l.TileAt(x, y) == TileRole.Bridge;
    }

    private const string GroundShaderPath = "res://assets/shaders/terrain_ground.gdshader";

    /// <summary>
    /// The board material: a straight top-down projection (terrain_ground.gdshader), NOT triplanar —
    /// on a steep slope triplanar fades toward the side projections, which sample the board-spanning
    /// atlas at garbage coordinates and smear unrelated cells across the face. The planar projection
    /// stretches a slope's own cell down the incline instead, the way RPG Maker cliff art behaves.
    /// Falls back to a triplanar StandardMaterial3D if the shader asset is missing.
    /// </summary>
    private static Material BuildGroundMaterial(Image board, int w, int h, Vector2 worldOrigin)
    {
        var texture = ImageTexture.CreateFromImage(board);

        var shader = MapMaterials.LoadShader(GroundShaderPath);
        if (shader != null)
        {
            var material = new ShaderMaterial { ResourceName = "terrain_ground_baked", Shader = shader };
            material.SetShaderParameter("ground_texture", texture);
            material.SetShaderParameter("board_inv_size", new Vector2(1f / w, 1f / h));
            material.SetShaderParameter("board_origin", worldOrigin);
            return material;
        }

        return new StandardMaterial3D
        {
            ResourceName = "terrain_ground_baked",
            AlbedoTexture = texture,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
            Uv1Triplanar = true,
            Uv1WorldTriplanar = true,
            Uv1Offset = new Vector3(-worldOrigin.X / w, 0f, -worldOrigin.Y / h),
            Uv1Scale = new Vector3(1f / w, 1f, 1f / h),
            Roughness = 1f,
            Metallic = 0f,
        };
    }

    /// <summary>Suffix on a tile path requesting the source art rotated 90° (bridge slats).</summary>
    private const string RotatedSuffix = "@rot90";

    /// <summary>
    /// Load one tile / fringe sheet as blit-ready pixels. Goes through
    /// <see cref="ResourceLoader"/> so the art comes from the imported resource, which an exported
    /// PCK contains and a raw-file read does not. A <see cref="RotatedSuffix"/> path loads the base
    /// art and rotates it clockwise. Returns a 1px magenta tile and reports the path when the
    /// resource is missing, so a bad path mis-dresses the board instead of crashing the build.
    /// </summary>
    private static Image LoadTile(Dictionary<string, Image> cache, string path, int tilePx)
    {
        if (cache.TryGetValue(path, out var cached)) return cached;

        Image img;
        if (path.EndsWith(RotatedSuffix))
        {
            img = (Image)LoadTile(cache, path[..^RotatedSuffix.Length], tilePx).Duplicate();
            img.Rotate90(ClockDirection.Clockwise);
        }
        else
        {
            img = ResourceLoader.Load<Texture2D>(path)?.GetImage()!;
            if (img == null)
            {
                GD.PushError($"[GroundTextureBaker] ground texture missing at {path}; tile is blank.");
                img = Image.CreateEmpty(tilePx, tilePx, false, Image.Format.Rgba8);
                img.Fill(Colors.Magenta);
            }
            else
            {
                // A VRAM-compressed re-import (detect_3d) would hand back block-compressed pixels
                // that GetPixel/BlitRect cannot read. Decompress first, then normalise the format.
                if (img.IsCompressed())
                    img.Decompress();
                img.Convert(Image.Format.Rgba8);
            }
        }
        cache[path] = img;
        return img;
    }
}
