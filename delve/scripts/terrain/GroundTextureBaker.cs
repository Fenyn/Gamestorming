using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Bakes one pixel-art ground texture for a whole board the way the Winlu sheets are meant to be
/// used: every tile gets a hashed pick from its surface's seamless variants, and dirt/mud tiles
/// bordering grass get the hand-painted autotile fringe composited in per 24px quadrant (edge /
/// outer-corner / inner-nub pieces from assets/textures/terrain/fringe_*.png), so transitions read
/// as painted ground instead of butted squares.
///
/// The result is a single nearest-filtered world-triplanar material spanning the board — tile (x,y)
/// occupies the 48px cell at (x,y) — shared by every non-water top face, so the mesh needs no UVs
/// and the per-surface material split only remains for walls and water. Deterministic per layout
/// (variant picks hash the layout seed). Returns null for a theme with no textured surfaces, which
/// sends the builder down the flat-colour path unchanged.
/// </summary>
public static class GroundTextureBaker
{
    private const int TilePx = 48;
    private const int HalfPx = TilePx / 2;

    private const string Dir = "res://assets/textures/terrain/";

    /// <summary>Surfaces whose grass boundary gets the autotile fringe, and the sheet to cut it from.</summary>
    private static readonly Dictionary<SurfaceType, string> FringeSheets = new()
    {
        [SurfaceType.Dirt] = Dir + "fringe_dirt.png",
        [SurfaceType.Mud] = Dir + "fringe_mud.png",
    };

    private const string MaskSheet = Dir + "fringe_mask.png";

    /// <summary>Fringe sheet cells by name, matching winlu_ground_fringe.json (8x2 grid).</summary>
    private static readonly Dictionary<string, (int Col, int Row)> FringeCells = new()
    {
        ["edge_n"] = (0, 0), ["edge_s"] = (1, 0), ["edge_e"] = (2, 0), ["edge_w"] = (3, 0),
        ["corner_nw"] = (4, 0), ["corner_ne"] = (5, 0), ["corner_sw"] = (6, 0), ["corner_se"] = (7, 0),
        ["inner_nw"] = (0, 1), ["inner_ne"] = (1, 1), ["inner_sw"] = (2, 1), ["inner_se"] = (3, 1),
    };

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

        var sources = new Dictionary<string, Image>();
        int w = layout.Width, h = layout.Height;
        var board = Image.CreateEmpty(w * TilePx, h * TilePx, false, Image.Format.Rgba8);

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            var surface = eff[y * w + x];
            var origin = new Vector2I(x * TilePx, y * TilePx);

            var variants = TopTextures(theme, surface);
            if (variants == null)
            {
                // Untextured surface (water, sand, …): flat theme colour keeps the sheet holeless.
                board.FillRect(new Rect2I(origin, new Vector2I(TilePx, TilePx)),
                    MapMaterials.ToGodot(theme.TopColor(surface)));
                continue;
            }

            string pick = variants[(int)(MapHash.Hash01(x, y, layout.Seed) * variants.Length) % variants.Length];

            // Bridge decks: slats run crosswise to the direction of travel, so a bridge running
            // along Z uses the plank tile rotated 90° (its boards are painted vertical).
            if (layout.GetTile(x, y) == TileRole.Bridge && BridgeRunsAlongZ(layout, x, y))
                pick += RotatedSuffix;

            board.BlitRect(LoadTile(sources, pick), new Rect2I(0, 0, TilePx, TilePx), origin);

            // Blend against whichever neighbouring surface creeps onto this one. Grass onto
            // dirt/mud uses the original hand-painted fringe art; every other pair goes through
            // the mask path, so transitions hold up for anything the generator outputs.
            if (FindCreeper(eff, w, h, x, y, surface, theme) is { } creeper)
            {
                if (creeper == SurfaceType.Grass && FringeSheets.TryGetValue(surface, out var sheet))
                    CompositeFringe(board, LoadTile(sources, sheet), eff, w, h, x, y, origin);
                else
                    CompositeCreepMask(board, sources, eff, w, h, x, y, origin, creeper, theme, layout.Seed);
            }
        }

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

    /// <summary>
    /// Which quadrant pieces one tile needs, given which of its 8 neighbours carry the creeping
    /// surface: each 24px quadrant looks at its two orthogonal neighbours and the diagonal and picks
    /// edge / outer-corner / inner-nub (or nothing). Shared by the hand-painted fringe path and the
    /// mask path so both blend shapes agree.
    /// </summary>
    private static IEnumerable<(string Piece, int Qx, int Qy)> QuadrantPieces(
        System.Func<int, int, bool> creeps, int x, int y)
    {
        bool n = creeps(x, y - 1);
        bool s = creeps(x, y + 1);
        bool west = creeps(x - 1, y);
        bool e = creeps(x + 1, y);

        var picks = new (string? Piece, int Qx, int Qy)[]
        {
            (Quadrant(n, west, creeps(x - 1, y - 1), "nw"), 0, 0),
            (Quadrant(n, e, creeps(x + 1, y - 1), "ne"), 1, 0),
            (Quadrant(s, west, creeps(x - 1, y + 1), "sw"), 0, 1),
            (Quadrant(s, e, creeps(x + 1, y + 1), "se"), 1, 1),
        };
        foreach (var p in picks)
            if (p.Piece != null)
                yield return (p.Piece, p.Qx, p.Qy);

        static string? Quadrant(bool ortho1, bool ortho2, bool diagonal, string corner) =>
            (ortho1, ortho2) switch
            {
                (true, true) => "corner_" + corner,
                (true, false) => "edge_" + corner[0],
                (false, true) => "edge_" + corner[1],
                _ => diagonal ? "inner_" + corner : null,
            };
    }

    /// <summary>Hand-painted grass fringe onto one dirt/mud tile — blits the original Winlu art.</summary>
    private static void CompositeFringe(
        Image board, Image fringe, SurfaceType[] eff, int w, int h, int x, int y, Vector2I origin)
    {
        foreach (var (piece, qx, qy) in QuadrantPieces(
                     (nx, ny) => SurfaceAt(eff, w, h, nx, ny) == SurfaceType.Grass, x, y))
        {
            var (col, row) = FringeCells[piece];
            board.BlitRect(fringe,
                new Rect2I(col * TilePx + qx * HalfPx, row * TilePx + qy * HalfPx, HalfPx, HalfPx),
                origin + new Vector2I(qx * HalfPx, qy * HalfPx));
        }
    }

    /// <summary>
    /// Generic transition for any creeping surface pair mapgen can output (grass over stone, dirt
    /// over stone, dirt over mud, …): the same quadrant shapes, but driven by fringe_mask.png — the
    /// hand-painted fringe's blob boundary extracted as a mask. Where the mask reads "creeper" the
    /// intruding surface's texture shows through; the mask's boundary band darkens whatever is under
    /// it, standing in for the painted outline. Pixel work, but only on transition quadrants.
    /// </summary>
    private static void CompositeCreepMask(
        Image board, Dictionary<string, Image> sources, SurfaceType[] eff, int w, int h,
        int x, int y, Vector2I origin, SurfaceType creeper, MapThemeDefinition theme, int seed)
    {
        var mask = LoadTile(sources, MaskSheet);
        var variants = TopTextures(theme, creeper)!;
        var intruder = LoadTile(sources,
            variants[(int)(MapHash.Hash01(x, y, seed) * variants.Length) % variants.Length]);

        foreach (var (piece, qx, qy) in QuadrantPieces(
                     (nx, ny) => SurfaceAt(eff, w, h, nx, ny) == creeper, x, y))
        {
            var (col, row) = FringeCells[piece];
            for (int j = 0; j < HalfPx; j++)
            for (int i = 0; i < HalfPx; i++)
            {
                int lx = qx * HalfPx + i, ly = qy * HalfPx + j;
                float m = mask.GetPixel(col * TilePx + lx, row * TilePx + ly).R;
                if (m > 0.8f)
                    board.SetPixel(origin.X + lx, origin.Y + ly, intruder.GetPixel(lx, ly));
                else if (m > 0.3f)
                    board.SetPixel(origin.X + lx, origin.Y + ly,
                        board.GetPixel(origin.X + lx, origin.Y + ly).Darkened(0.28f));
            }
        }
    }

    /// <summary>Highest-priority textured neighbour surface that creeps onto this tile, or null.</summary>
    private static SurfaceType? FindCreeper(
        SurfaceType[] eff, int w, int h, int x, int y, SurfaceType mine, MapThemeDefinition theme)
    {
        if (!CreepPriority.TryGetValue(mine, out int myPriority)) return null;

        SurfaceType? best = null;
        int bestPriority = myPriority;
        for (int dy = -1; dy <= 1; dy++)
        for (int dx = -1; dx <= 1; dx++)
        {
            if (dx == 0 && dy == 0) continue;
            var s = SurfaceAt(eff, w, h, x + dx, y + dy);
            if (s == null) continue;
            if (CreepPriority.TryGetValue(s.Value, out int p) && p > bestPriority &&
                TopTextures(theme, s.Value) != null)
            {
                best = s;
                bestPriority = p;
            }
        }
        return best;
    }

    private static SurfaceType? SurfaceAt(SurfaceType[] eff, int w, int h, int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h ? eff[y * w + x] : null;

    /// <summary>
    /// Creep order: a higher-priority surface's texture creeps over a lower one at their boundary,
    /// so organic ground overgrows worked ground (grass onto dirt onto stone) no matter what layout
    /// the generator emits. Wood is absent on purpose — deck edges stay carpentered, never overgrown.
    /// </summary>
    private static readonly Dictionary<SurfaceType, int> CreepPriority = new()
    {
        [SurfaceType.Grass] = 5,
        [SurfaceType.Dirt] = 3,
        [SurfaceType.Mud] = 2,
        [SurfaceType.Stone] = 1,
    };

    /// <summary>Suffix on a tile path requesting the source art rotated 90° (bridge slats).</summary>
    private const string RotatedSuffix = "@rot90";

    /// <summary>
    /// Load one 48px tile / fringe sheet as blit-ready pixels. Goes through
    /// <see cref="ResourceLoader"/> so the art comes from the imported resource, which an exported
    /// PCK contains and a raw-file read does not. A <see cref="RotatedSuffix"/> path loads the base
    /// art and rotates it clockwise. Returns a 1px magenta tile and reports the path when the
    /// resource is missing, so a bad path mis-dresses the board instead of crashing the build.
    /// </summary>
    private static Image LoadTile(Dictionary<string, Image> cache, string path)
    {
        if (cache.TryGetValue(path, out var cached)) return cached;

        Image img;
        if (path.EndsWith(RotatedSuffix))
        {
            img = (Image)LoadTile(cache, path[..^RotatedSuffix.Length]).Duplicate();
            img.Rotate90(ClockDirection.Clockwise);
        }
        else
        {
            img = ResourceLoader.Load<Texture2D>(path)?.GetImage()!;
            if (img == null)
            {
                GD.PushError($"[GroundTextureBaker] ground texture missing at {path}; tile is blank.");
                img = Image.CreateEmpty(TilePx, TilePx, false, Image.Format.Rgba8);
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
