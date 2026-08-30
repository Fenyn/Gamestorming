using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Terrain;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Delve.Dev;

/// <summary>
/// Headless proof that the generated skirt — the halo of synthesized terrain that replaces the old
/// flat apron — is a layout the terrain builder can render without special cases. 30 seeds across
/// both biomes, asserting on the layout <see cref="SkirtLayout.Build"/> returns:
///
///  (a) Frame       — the skirt is (W + 2M) x (H + 2M), the margin is at least the floor, and every
///                    board tile survives the copy byte for byte in ALL nine per-tile fields.
///  (b) Join        — across every board edge, the first halo ring's corners equal the board's own
///                    ground corners, so the seam is flush and no cliff pass invents a wall there.
///  (c) Gentle      — out in the halo the corner field is a shared VERTEX grid (adjacent tiles agree
///                    on the corners between them) and no tile spans more than two units, which is
///                    what makes it read as hills instead of noise. Trees and water banks are
///                    exempt: a tree is a block and a bank meets a level river.
///  (d) Rim         — the outermost ring is dead flat at the ground plane's own height (or a wall
///                    standing exactly its own height on it).
///  (e) Vocabulary  — the halo only ever speaks in Ground / DifficultTerrain / Water / Wall,
///                    plus Void where it continues a canyon that leaves the board.
///  (f) Rivers      — every river leaving the board has water waiting for it one ring out.
///  (f) Canyons     — every void run leaving the board has void waiting for it one ring out.
///  (f) Reach       — wide rivers and canyons carry on right onto the rim ring; only brooks taper.
///  (g) Determinism — same seed, same skirt, field for field.
/// </summary>
public partial class TerrainSkirtSpike : SpikeBase
{
    private static readonly int[] Seeds =
    {
        1, 3, 7, 11, 19, 38, 42, 63, 99, 128, 137, 256, 311, 404, 512, 777,
        1024, 1337, 2026, 3141, 4711, 6180, 8123, 9999, 12345, 20260804,
        31337, 44100, 55555, 84105, 909090,
    };

    private static readonly string[] Biomes = { "forest", "sewer" };

    private static readonly (int dx, int dy)[] Cardinals = { (1, 0), (-1, 0), (0, 1), (0, -1) };

    protected override string Banner => "==================== TERRAIN SKIRT SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        int maps = 0;
        var defects = new Defects();

        foreach (string biome in Biomes)
        {
            GD.Print($"-------------------- {biome} --------------------");
            var style = BackdropThemes.Get(biome).Skirt;
            int wallHeight = MapGenRegistry.GetBiome(biome).WallHeight;

            foreach (int seed in Seeds)
            {
                var board = MapGenerator.GenerateValidated(biome, seed);
                if (board == null)
                {
                    Check($"{biome} seed {seed}: GenerateValidated produced a map", false);
                    continue;
                }

                var built = SkirtLayout.Build(board, style, wallHeight);
                maps++;

                CheckFrame(board, built, defects);
                CheckJoin(board, built, defects);
                CheckGentle(board, built, defects);
                CheckRim(board, built, wallHeight, defects);
                CheckVocabulary(board, built, defects);
                CheckRivers(board, built, defects);
                CheckCanyons(board, built, defects);
                CheckDryRim(board, built, style, defects);
                CheckTrees(board, built, style, defects);
                CheckDeterminism(board, style, wallHeight, built, defects);

                GD.Print($"        · seed {seed}: board {board.Width}x{board.Height}, "
                         + $"margin {built.Margin}, skirt {built.Layout.Width}x{built.Layout.Height}, "
                         + Census(board, built));
            }
        }

        Check($"{maps} skirts built over {Biomes.Length} biomes", maps == Biomes.Length * Seeds.Length);
        Check("(a) skirt is (W+2M)x(H+2M) with a margin of at least 8", defects.Report("frame"));
        Check("(a) every board tile survives the copy in all nine per-tile fields", defects.Report("copy"));
        Check("(b) the first halo ring's corners equal the board's ground corners", defects.Report("join"));
        Check("(c) adjacent halo tiles agree on the corners between them", defects.Report("vertex"));
        Check("(c) no halo ground tile spans more than two corner units", defects.Report("slope"));
        Check("(d) the outer ring sits flat on the ground plane", defects.Report("rim"));
        Check("(e) the halo only uses ground, difficult, water, wall and continued void", defects.Report("role"));
        Check("(f) every board-edge river continues into the first ring", defects.Report("river"));
        Check("(f) every board-edge canyon continues into the first ring", defects.Report("canyon"));
        Check("(f) wide rivers and canyons run all the way onto the rim ring", defects.Report("dryrim"));
        Check("(g) the same seed builds the same skirt", defects.Report("determinism"));
        Check("(h) tree spots stand on open ground, ring 2+, away from water", defects.Report("trees"));

        return Task.CompletedTask;
    }

    // ─────────────────────────── (a) frame + copy ───────────────────────────

    private static void CheckFrame(MapLayout board, SkirtResult built, Defects defects)
    {
        int m = built.Margin;
        var skirt = built.Layout;

        if (m < SkirtStyle.MinMargin) defects.Add("frame");
        if (skirt.Width != board.Width + 2 * m || skirt.Height != board.Height + 2 * m) defects.Add("frame");
        if (skirt.Seed != board.Seed || skirt.Name != board.Name + "_skirt") defects.Add("frame");

        for (int y = 0; y < board.Height; y++)
        {
            for (int x = 0; x < board.Width; x++)
            {
                int sx = x + m, sy = y + m;
                bool same = skirt.GetTile(sx, sy) == board.GetTile(x, y)
                            && skirt.GetSurface(sx, sy) == board.GetSurface(x, y)
                            && skirt.GetElevation(sx, sy) == board.GetElevation(x, y)
                            && skirt.GetSlopeType(sx, sy) == board.GetSlopeType(x, y)
                            && skirt.GetSlopeHeight(sx, sy) == board.GetSlopeHeight(x, y)
                            && SameCorners(skirt.GetCornerHeights(sx, sy), board.GetCornerHeights(x, y))
                            && skirt.GetFeatureLabel(sx, sy) == board.GetFeatureLabel(x, y)
                            && skirt.GetPlantTerrain(sx, sy) == board.GetPlantTerrain(x, y)
                            && skirt.GetBalanceDC(sx, sy) == board.GetBalanceDC(x, y);
                if (!same) defects.Add("copy");
            }
        }
    }

    // ─────────────────────────── (b) the join ───────────────────────────

    /// <summary>
    /// Walks the board's own perimeter and looks across each outward edge at the halo tile there.
    /// The two corners they share must be the board tile's ground corners exactly. Walls and water
    /// on either side are skipped: a tree block and a level river are not part of the ground surface
    /// the join is about.
    /// </summary>
    private static void CheckJoin(MapLayout board, SkirtResult built, Defects defects)
    {
        int m = built.Margin;
        var skirt = built.Layout;

        for (int by = 0; by < board.Height; by++)
        {
            for (int bx = 0; bx < board.Width; bx++)
            {
                if (bx != 0 && by != 0 && bx != board.Width - 1 && by != board.Height - 1) continue;

                var role = board.GetTile(bx, by);
                if (role is not (TileRole.Ground or TileRole.DifficultTerrain)) continue;

                foreach (var (dx, dy) in Cardinals)
                {
                    int nx = bx + dx, ny = by + dy;
                    if (board.IsInBounds(nx, ny)) continue;   // interior edge, not a board boundary

                    int sx = nx + m, sy = ny + m;
                    var haloRole = skirt.GetTile(sx, sy);
                    if (haloRole is TileRole.Wall or TileRole.Water) continue;

                    var (a, b) = SkirtLayout.JoinCorners(board, bx, by, -dx, -dy);
                    var halo = skirt.GetCornerHeights(sx, sy);
                    var (ha, hb) = EdgePair(halo, dx, dy);
                    if (ha != a || hb != b) defects.Add("join");
                }
            }
        }
    }

    /// <summary>The halo tile's two corners on the edge it shares with the board tile that lies in
    /// the (-dx, -dy) direction from it.</summary>
    private static (int a, int b) EdgePair(TileCornerHeights c, int dx, int dy)
    {
        if (dx > 0) return (c.NW, c.SW);   // halo east of board  → its west edge
        if (dx < 0) return (c.NE, c.SE);
        if (dy > 0) return (c.SW, c.SE);
        return (c.NW, c.NE);
    }

    // ─────────────────────────── (c) gentle hills ───────────────────────────

    private static void CheckGentle(MapLayout board, SkirtResult built, Defects defects)
    {
        var skirt = built.Layout;
        int m = built.Margin;

        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, m, board) < 2) continue;
                if (!IsOpenGround(skirt, sx, sy) || NearWater(skirt, sx, sy)) continue;

                var here = skirt.GetCornerHeights(sx, sy);
                if (here.HeightSpan > SkirtLayout.SlopeLimitUnits) defects.Add("slope");

                foreach (var (dx, dy) in Cardinals)
                {
                    int nx = sx + dx, ny = sy + dy;
                    if (SkirtLayout.TileRing(nx, ny, m, board) < 2) continue;
                    if (!skirt.IsInBounds(nx, ny) || !IsOpenGround(skirt, nx, ny)) continue;
                    if (NearWater(skirt, nx, ny)) continue;

                    var (a, b) = EdgePair(here, -dx, -dy);
                    var (na, nb) = EdgePair(skirt.GetCornerHeights(nx, ny), dx, dy);
                    if (a != na || b != nb) defects.Add("vertex");
                }
            }
        }
    }

    // ─────────────────────────── (d) the rim ───────────────────────────

    private static void CheckRim(MapLayout board, SkirtResult built, int wallHeight, Defects defects)
    {
        var skirt = built.Layout;
        int m = built.Margin;

        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, m, board) != m) continue;

                var role = skirt.GetTile(sx, sy);
                // A wide river or canyon runs through the rim on purpose; water lies flat at its
                // own level and a void tile has no meaningful corners at all.
                if (role == TileRole.Empty) continue;
                var c = skirt.GetCornerHeights(sx, sy);
                if (role == TileRole.Water) { if (!c.IsFlat) defects.Add("rim"); continue; }
                int expected = role == TileRole.Wall ? wallHeight : 0;
                if (!c.IsFlat || c.NW != expected) defects.Add("rim");
            }
        }
    }

    // ─────────────────────────── (e) vocabulary ───────────────────────────

    private static void CheckVocabulary(MapLayout board, SkirtResult built, Defects defects)
    {
        var skirt = built.Layout;
        int m = built.Margin;

        for (int sy = 0; sy < skirt.Height; sy++)
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, m, board) == 0) continue;
                var role = skirt.GetTile(sx, sy);
                if (role is not (TileRole.Ground or TileRole.DifficultTerrain
                    or TileRole.Water or TileRole.Wall or TileRole.Empty)) defects.Add("role");
                if (role == TileRole.Empty && !BoardHasEdgeVoid(board)) defects.Add("role");
            }
    }

    // ─────────────────────────── (f) rivers ───────────────────────────

    private static void CheckRivers(MapLayout board, SkirtResult built, Defects defects)
    {
        var skirt = built.Layout;
        int m = built.Margin;

        for (int by = 0; by < board.Height; by++)
        {
            for (int bx = 0; bx < board.Width; bx++)
            {
                if (board.GetTile(bx, by) != TileRole.Water) continue;

                foreach (var (dx, dy) in Cardinals)
                {
                    int nx = bx + dx, ny = by + dy;
                    if (board.IsInBounds(nx, ny)) continue;

                    bool continued = false;
                    for (int t = -1; t <= 1 && !continued; t++)
                    {
                        int sx = nx + m + (dx != 0 ? 0 : t);
                        int sy = ny + m + (dy != 0 ? 0 : t);
                        continued = skirt.GetTile(sx, sy) == TileRole.Water;
                    }
                    if (!continued) defects.Add("river");
                }
            }
        }
    }

    // ─────────────────────────── (f) canyons + dry rim ───────────────────────────

    /// <summary>Mirror of <see cref="CheckRivers"/> for the void a canyon_crossing map drives
    /// through the board edge: the halo tile straight outside it must still be void.</summary>
    private static void CheckCanyons(MapLayout board, SkirtResult built, Defects defects)
    {
        var skirt = built.Layout;
        int m = built.Margin;

        for (int by = 0; by < board.Height; by++)
        {
            for (int bx = 0; bx < board.Width; bx++)
            {
                if (board.GetTile(bx, by) != TileRole.Empty) continue;

                foreach (var (dx, dy) in Cardinals)
                {
                    int nx = bx + dx, ny = by + dy;
                    if (board.IsInBounds(nx, ny)) continue;
                    if (skirt.GetTile(nx + m, ny + m) != TileRole.Empty) defects.Add("canyon");
                }
            }
        }
    }

    /// <summary>A wide river (3+ tiles) or a canyon must still be there ON the rim ring: the whole
    /// point of continuing them is that the obstacle visibly runs off into the fog instead of
    /// pinching closed where a player could imagine walking around it.</summary>
    private static void CheckDryRim(
        MapLayout board, SkirtResult built, SkirtStyle style, Defects defects)
    {
        // An enclosed biome seals its halo into vault wall on purpose — there the WALL is the
        // thing you cannot walk around, and water or void ending under it is correct.
        if (style.WallRings > 0) return;

        var skirt = built.Layout;
        int m = built.Margin;

        bool wideRiver = false, canyon = false;
        for (int x = 0; x < board.Width; x++)
        {
            wideRiver |= WideEdgeRun(board, x, 0, 1, 0, TileRole.Water)
                         || WideEdgeRun(board, x, board.Height - 1, 1, 0, TileRole.Water);
            canyon |= board.GetTile(x, 0) == TileRole.Empty
                      || board.GetTile(x, board.Height - 1) == TileRole.Empty;
        }
        for (int y = 0; y < board.Height; y++)
        {
            wideRiver |= WideEdgeRun(board, 0, y, 0, 1, TileRole.Water)
                         || WideEdgeRun(board, board.Width - 1, y, 0, 1, TileRole.Water);
            canyon |= board.GetTile(0, y) == TileRole.Empty
                      || board.GetTile(board.Width - 1, y) == TileRole.Empty;
        }

        bool rimWater = false, rimVoid = false;
        for (int sy = 0; sy < skirt.Height; sy++)
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, m, board) != m) continue;
                rimWater |= skirt.GetTile(sx, sy) == TileRole.Water;
                rimVoid |= skirt.GetTile(sx, sy) == TileRole.Empty;
            }

        if (wideRiver && !rimWater) defects.Add("dryrim");
        if (canyon && !rimVoid) defects.Add("dryrim");
    }

    /// <summary>True when the edge tile starts a run of at least three like-role tiles along the
    /// given direction — the width gate a continued river must pass to run to the rim.</summary>
    private static bool WideEdgeRun(MapLayout board, int x, int y, int dx, int dy, TileRole role)
    {
        for (int i = 0; i < 3; i++)
        {
            int nx = x + dx * i, ny = y + dy * i;
            if (!board.IsInBounds(nx, ny) || board.GetTile(nx, ny) != role) return false;
        }
        return true;
    }

    private static bool BoardHasEdgeVoid(MapLayout board)
    {
        for (int x = 0; x < board.Width; x++)
            if (board.GetTile(x, 0) == TileRole.Empty
                || board.GetTile(x, board.Height - 1) == TileRole.Empty) return true;
        for (int y = 0; y < board.Height; y++)
            if (board.GetTile(0, y) == TileRole.Empty
                || board.GetTile(board.Width - 1, y) == TileRole.Empty) return true;
        return false;
    }

    // ─────────────────────────── (h) tree spots ───────────────────────────

    /// <summary>The halo tree scatter is spots for the renderer, not tiles: each spot must stand on
    /// open halo ground at ring 2+, away from water — and an open forest halo always grows SOME
    /// trees, while an enclosed vault grows none.</summary>
    private static void CheckTrees(
        MapLayout board, SkirtResult built, SkirtStyle style, Defects defects)
    {
        var skirt = built.Layout;
        int m = built.Margin;

        bool open = style.WallRings == 0
                    && (style.TreeDensityNear > 0f || style.TreeDensityFar > 0f);
        if (!open && built.Trees.Count > 0) defects.Add("trees");
        if (open && built.Trees.Count == 0) defects.Add("trees");

        foreach (var (x, y) in built.Trees)
        {
            if (SkirtLayout.TileRing(x, y, m, board) < 2) defects.Add("trees");
            if (skirt.GetTile(x, y) is not (TileRole.Ground or TileRole.DifficultTerrain))
                defects.Add("trees");
            if (NearWater(skirt, x, y)) defects.Add("trees");
        }
    }

    // ─────────────────────────── (g) determinism ───────────────────────────

    private static void CheckDeterminism(
        MapLayout board, SkirtStyle style, int wallHeight, SkirtResult first, Defects defects)
    {
        var again = SkirtLayout.Build(board, style, wallHeight);
        var a = first.Layout;
        var b = again.Layout;

        if (!again.Trees.SequenceEqual(first.Trees)) defects.Add("determinism");
        if (again.Margin != first.Margin || a.Width != b.Width || a.Height != b.Height)
        {
            defects.Add("determinism");
            return;
        }

        for (int y = 0; y < a.Height; y++)
            for (int x = 0; x < a.Width; x++)
            {
                bool same = a.GetTile(x, y) == b.GetTile(x, y)
                            && a.GetSurface(x, y) == b.GetSurface(x, y)
                            && a.GetElevation(x, y) == b.GetElevation(x, y)
                            && a.GetSlopeType(x, y) == b.GetSlopeType(x, y)
                            && a.GetSlopeHeight(x, y) == b.GetSlopeHeight(x, y)
                            && SameCorners(a.GetCornerHeights(x, y), b.GetCornerHeights(x, y))
                            && a.GetFeatureLabel(x, y) == b.GetFeatureLabel(x, y)
                            && a.GetPlantTerrain(x, y) == b.GetPlantTerrain(x, y)
                            && a.GetBalanceDC(x, y) == b.GetBalanceDC(x, y);
                if (!same) defects.Add("determinism");
            }
    }

    // ─────────────────────────── helpers ───────────────────────────

    private static bool IsOpenGround(MapLayout skirt, int x, int y)
        => skirt.GetTile(x, y) is TileRole.Ground or TileRole.DifficultTerrain;

    private static bool NearWater(MapLayout skirt, int x, int y)
    {
        for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++)
                if (skirt.GetTile(x + ox, y + oy) == TileRole.Water) return true;
        return false;
    }

    private static bool SameCorners(TileCornerHeights a, TileCornerHeights b)
        => a.NW == b.NW && a.NE == b.NE && a.SE == b.SE && a.SW == b.SW;

    /// <summary>What the halo ended up made of, for eyeballing the tuning between runs.</summary>
    private static string Census(MapLayout board, SkirtResult built)
    {
        int walls = 0, water = 0, difficult = 0, top = 0;
        var skirt = built.Layout;

        for (int sy = 0; sy < skirt.Height; sy++)
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, built.Margin, board) == 0) continue;
                switch (skirt.GetTile(sx, sy))
                {
                    case TileRole.Wall: walls++; break;
                    case TileRole.Water: water++; break;
                    case TileRole.DifficultTerrain: difficult++; break;
                }
                top = Math.Max(top, skirt.GetCornerHeights(sx, sy).MaxHeight);
            }

        return $"halo {walls} wall / {water} water / {difficult} difficult, tallest {top}u";
    }

    /// <summary>Defect tally by tag, so one broken tile does not print 60 lines.</summary>
    private sealed class Defects
    {
        private readonly Dictionary<string, int> _counts = new();

        public void Add(string tag) => _counts[tag] = _counts.GetValueOrDefault(tag) + 1;

        /// <summary>True when the tag is clean; logs the count once when it is not.</summary>
        public bool Report(string tag)
        {
            if (!_counts.TryGetValue(tag, out int n)) return true;
            GD.Print($"        ! {tag}: {n} defect(s)");
            return false;
        }
    }
}
