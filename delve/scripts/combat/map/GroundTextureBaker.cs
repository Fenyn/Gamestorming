using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.MapGen;

namespace Delve.Combat.Map;

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

    /// <summary>Per-surface base variants. Missing surfaces are filled with the theme's flat top
    /// colour so a mixed board never leaves a hole in the shared texture.</summary>
    private static readonly Dictionary<SurfaceType, string[]> BaseTiles = new()
    {
        [SurfaceType.Grass] = new[] { "grass_a", "grass_b", "grass_c" },
        [SurfaceType.Dirt] = new[] { "dirt_a", "dirt_b" },
        [SurfaceType.Mud] = new[] { "mud_a", "mud_b" },
        [SurfaceType.Stone] = new[] { "stone_b" },
        [SurfaceType.Wood] = new[] { "bridge_deck" },
    };

    /// <summary>Surfaces whose grass boundary gets the autotile fringe, and the sheet to cut it from.</summary>
    private static readonly Dictionary<SurfaceType, string> FringeSheets = new()
    {
        [SurfaceType.Dirt] = "fringe_dirt",
        [SurfaceType.Mud] = "fringe_mud",
    };

    /// <summary>Fringe sheet cells by name, matching winlu_ground_fringe.json (8x2 grid).</summary>
    private static readonly Dictionary<string, (int Col, int Row)> FringeCells = new()
    {
        ["edge_n"] = (0, 0), ["edge_s"] = (1, 0), ["edge_e"] = (2, 0), ["edge_w"] = (3, 0),
        ["corner_nw"] = (4, 0), ["corner_ne"] = (5, 0), ["corner_sw"] = (6, 0), ["corner_se"] = (7, 0),
        ["inner_nw"] = (0, 1), ["inner_ne"] = (1, 1), ["inner_sw"] = (2, 1), ["inner_se"] = (3, 1),
    };

    /// <summary>
    /// Bake the board's shared ground-top material, or null when the theme textures nothing.
    /// </summary>
    public static Material? Bake(MapLayout layout, MapThemeDefinition theme)
    {
        bool anyTexture = false;
        foreach (var surface in BaseTiles.Keys)
            anyTexture |= theme.Style(surface)?.TopTexture != null;
        if (!anyTexture) return null;

        var sources = new Dictionary<string, Image>();
        int w = layout.Width, h = layout.Height;
        var board = Image.CreateEmpty(w * TilePx, h * TilePx, false, Image.Format.Rgba8);

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            var surface = layout.GetSurface(x, y);
            var origin = new Vector2I(x * TilePx, y * TilePx);

            if (!BaseTiles.TryGetValue(surface, out var variants) ||
                theme.Style(surface)?.TopTexture == null)
            {
                // Untextured surface (water, sand, …): flat theme colour keeps the sheet holeless.
                board.FillRect(new Rect2I(origin, new Vector2I(TilePx, TilePx)),
                    MapMaterials.ToGodot(theme.TopColor(surface)));
                continue;
            }

            string pick = variants[(int)(Hash01(x, y, layout.Seed) * variants.Length) % variants.Length];

            // Bridge decks: slats run crosswise to the direction of travel, so a bridge running
            // along Z uses the plank tile rotated 90° (its boards are painted vertical).
            if (layout.GetTile(x, y) == TileRole.Bridge && BridgeRunsAlongZ(layout, x, y))
                pick += RotatedSuffix;

            BlitCell(board, LoadTile(sources, pick), 0, 0, origin, full: true);

            if (FringeSheets.TryGetValue(surface, out var sheet))
                CompositeFringe(board, LoadTile(sources, sheet), layout, x, y, origin);
        }

        var material = BuildGroundMaterial(board, w, h);
        return material;
    }

    /// <summary>True when the bridge tile continues north/south (its travel axis is world Z).</summary>
    private static bool BridgeRunsAlongZ(MapLayout layout, int x, int y)
    {
        bool along = IsBridge(layout, x, y - 1) || IsBridge(layout, x, y + 1);
        bool across = IsBridge(layout, x - 1, y) || IsBridge(layout, x + 1, y);
        return along && !across;

        static bool IsBridge(MapLayout l, int x, int y) =>
            x >= 0 && y >= 0 && x < l.Width && y < l.Height && l.GetTile(x, y) == TileRole.Bridge;
    }

    private const string GroundShaderPath = "res://assets/shaders/terrain_ground.gdshader";

    /// <summary>
    /// The board material: a straight top-down projection (terrain_ground.gdshader), NOT triplanar —
    /// on a steep slope triplanar fades toward the side projections, which sample the board-spanning
    /// atlas at garbage coordinates and smear unrelated cells across the face. The planar projection
    /// stretches a slope's own cell down the incline instead, the way RPG Maker cliff art behaves.
    /// Falls back to a triplanar StandardMaterial3D if the shader asset is missing.
    /// </summary>
    private static Material BuildGroundMaterial(Image board, int w, int h)
    {
        var texture = ImageTexture.CreateFromImage(board);

        var shader = ResourceLoader.Load<Shader>(GroundShaderPath);
        if (shader != null)
        {
            var material = new ShaderMaterial { ResourceName = "terrain_ground_baked", Shader = shader };
            material.SetShaderParameter("ground_texture", texture);
            material.SetShaderParameter("board_inv_size", new Vector2(1f / w, 1f / h));
            return material;
        }

        GD.PushError($"[GroundTextureBaker] ground shader missing at {GroundShaderPath}; using triplanar fallback.");
        return new StandardMaterial3D
        {
            ResourceName = "terrain_ground_baked",
            AlbedoTexture = texture,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
            Uv1Triplanar = true,
            Uv1WorldTriplanar = true,
            Uv1Scale = new Vector3(1f / w, 1f, 1f / h),
            Roughness = 1f,
            Metallic = 0f,
        };
    }

    /// <summary>
    /// Composite the grass fringe onto one dirt/mud tile, one 24px quadrant at a time: each quadrant
    /// looks at its two orthogonal neighbours and the diagonal, and takes that quadrant from the
    /// matching fringe piece (both-sides → outer corner, one side → edge, diagonal only → inner nub).
    /// </summary>
    private static void CompositeFringe(
        Image board, Image fringe, MapLayout layout, int x, int y, Vector2I origin)
    {
        bool n = IsGrass(layout, x, y - 1);
        bool s = IsGrass(layout, x, y + 1);
        bool west = IsGrass(layout, x - 1, y);
        bool e = IsGrass(layout, x + 1, y);
        bool nw = IsGrass(layout, x - 1, y - 1);
        bool ne = IsGrass(layout, x + 1, y - 1);
        bool sw = IsGrass(layout, x - 1, y + 1);
        bool se = IsGrass(layout, x + 1, y + 1);

        Blit(Quadrant(n, west, nw, "nw"), 0, 0);
        Blit(Quadrant(n, e, ne, "ne"), 1, 0);
        Blit(Quadrant(s, west, sw, "sw"), 0, 1);
        Blit(Quadrant(s, e, se, "se"), 1, 1);
        return;

        static string? Quadrant(bool ortho1, bool ortho2, bool diagonal, string corner) =>
            (ortho1, ortho2) switch
            {
                (true, true) => "corner_" + corner,
                (true, false) => "edge_" + corner[0],
                (false, true) => "edge_" + corner[1],
                _ => diagonal ? "inner_" + corner : null,
            };

        void Blit(string? piece, int qx, int qy)
        {
            if (piece == null) return;
            var (col, row) = FringeCells[piece];
            board.BlitRect(fringe,
                new Rect2I(col * TilePx + qx * HalfPx, row * TilePx + qy * HalfPx, HalfPx, HalfPx),
                origin + new Vector2I(qx * HalfPx, qy * HalfPx));
        }
    }

    private static bool IsGrass(MapLayout layout, int x, int y) =>
        x >= 0 && y >= 0 && x < layout.Width && y < layout.Height &&
        layout.GetSurface(x, y) == SurfaceType.Grass;

    private static void BlitCell(Image board, Image src, int col, int row, Vector2I origin, bool full)
    {
        int size = full ? TilePx : HalfPx;
        board.BlitRect(src, new Rect2I(col * size, row * size, TilePx, TilePx), origin);
    }

    /// <summary>Suffix on a tile name requesting the source art rotated 90° (bridge slats).</summary>
    private const string RotatedSuffix = "@rot90";

    /// <summary>Load one 48px tile / fringe sheet from the raw PNG, bypassing the import pipeline so
    /// the pixels are blit-ready in any headless context. A <see cref="RotatedSuffix"/> name loads
    /// the base art and rotates it clockwise.</summary>
    private static Image LoadTile(Dictionary<string, Image> cache, string name)
    {
        if (cache.TryGetValue(name, out var cached)) return cached;

        Image img;
        if (name.EndsWith(RotatedSuffix))
        {
            img = (Image)LoadTile(cache, name[..^RotatedSuffix.Length]).Duplicate();
            img.Rotate90(ClockDirection.Clockwise);
        }
        else
        {
            img = Image.LoadFromFile(ProjectSettings.GlobalizePath(Dir + name + ".png"));
            img.Convert(Image.Format.Rgba8);
        }
        cache[name] = img;
        return img;
    }

    /// <summary>Same tile-decision hash as EdgeSceneryBuilder / TileDecor.</summary>
    private static float Hash01(int a, int b, int seed)
    {
        unchecked
        {
            uint h = (uint)seed * 374761393u + (uint)a * 668265263u + (uint)b * 974634321u;
            h = (h ^ (h >> 13)) * 1274126177u;
            h ^= h >> 16;
            return (h & 0xFFFFFFu) * (1f / 0x1000000);
        }
    }
}
