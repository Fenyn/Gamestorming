using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dev;

/// <summary>
/// Headless proof that the cliff faces of a generated board are geometrically sound. Builds the
/// terrain mesh for 30 seeds across both biomes and asserts on the faces
/// <see cref="TerrainMeshBuilder"/> emitted, re-derived from the layout rather than from the pass
/// that wrote them:
///
///  (a) Honest bottoms  — a wall's two bottom corners are the CARDINAL neighbour's corners on the
///                        same shared edge, clamped to this tile's own top and to the canyon floor,
///                        or the canyon floor itself where the neighbour is void. Reading a
///                        min-corner vertex grid let a diagonal tile drag one end below the ledge
///                        the wall faces, which cut a slanted trapezoid through that ledge.
///  (b) No doubles      — no two wall quads occupy the same four world positions.
///  (c) One wall a drop — on an edge between two solid tiles, a drop one way emits exactly one wall;
///                        a TWISTED edge (higher at one end, lower at the other) emits one from each
///                        tile and their vertical spans stay disjoint instead of overlapping.
///  (d) Tiling strips   — every cliff-lip strip stays inside its own tile, and two strips on one tile
///                        never overlap. Strips meeting at a convex corner used to share the corner
///                        square and z-fight.
///
/// Elevation spans are printed per seed, so a plateau-heavy seed for a rendered check is one run away.
/// </summary>
public partial class TerrainCliffSpike : SpikeBase
{
    /// <summary>Seeds per biome. Both macro-shape weightings are covered by the same assertions.</summary>
    private static readonly int[] Seeds =
    {
        1, 7, 42, 99, 137, 404, 1337, 2026, 4711, 8123, 20260804, 31337, 55555, 84105, 909090,
    };

    private static readonly string[] Biomes = { "forest", "sewer" };

    /// <summary>Every interior edge is exactly one tile's north or east edge, so a sweep over these
    /// two visits each shared edge once.</summary>
    private static readonly CardinalDirection[] EdgeSweep =
    {
        CardinalDirection.North, CardinalDirection.East,
    };

    /// <summary>Tolerance on a world-position match, in metres. Corner heights are integers times
    /// the height scale, so a real mismatch is orders of magnitude larger.</summary>
    private const float Epsilon = 1e-4f;

    protected override string Banner => "==================== TERRAIN CLIFF SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        int maps = 0;
        var defects = new Defects();

        foreach (string biome in Biomes)
        {
            GD.Print($"-------------------- {biome} --------------------");
            foreach (int seed in Seeds)
            {
                var layout = MapGenerator.GenerateValidated(biome, seed);
                if (layout == null)
                {
                    Check($"{biome} seed {seed}: GenerateValidated produced a map", false);
                    continue;
                }

                var theme = MapThemes.Get(biome);
                var faces = new TerrainDebugFaces();
                TerrainMeshBuilder.Build(layout, theme, options: null, faces);
                maps++;

                CheckWallBottoms(layout, faces, defects);
                CheckNoDoubledWalls(layout, theme.HeightScale, faces, defects);
                CheckOneWallPerDrop(layout, faces, defects);
                CheckStripsTile(faces, defects);

                GD.Print($"        · seed {seed}: {layout.Width}x{layout.Height}, "
                         + $"{faces.Walls.Count} walls, {faces.Strips.Count} strips, "
                         + $"elevations {ElevationSpan(layout)}");
            }
        }

        Check($"{maps} maps built over {Biomes.Length} biomes", maps == Biomes.Length * Seeds.Length);
        Check("(a) every wall bottom equals its cardinal neighbour's edge corner (or the void floor)",
            defects.Report("bottom"));
        Check("(a) no wall hangs below its own top or below the canyon floor",
            defects.Report("span"));
        Check("(b) no two wall quads share the same four world positions",
            defects.Report("double"));
        Check("(c) an edge with a one-way drop emits exactly one wall",
            defects.Report("count"));
        Check("(c) the two walls of a twisted edge never overlap vertically",
            defects.Report("twist"));
        Check("(d) every cliff-lip strip stays inside its own tile",
            defects.Report("stray"));
        Check("(d) no two cliff-lip strips overlap",
            defects.Report("overlap"));

        return Task.CompletedTask;
    }

    // ─────────────────────────── (a) honest bottoms ───────────────────────────

    /// <summary>
    /// Re-derives what each emitted wall's bottoms MUST be, straight from the layout: the cardinal
    /// neighbour's two corners on the shared edge, clamped to this tile's own corner above them and
    /// to the canyon floor. A water or over-water bridge neighbour is the one exception — those tiles
    /// emit no wall of their own, so the face carries on below their surface.
    /// </summary>
    private static void CheckWallBottoms(MapLayout layout, TerrainDebugFaces faces, Defects defects)
    {
        foreach (var wall in faces.Walls)
        {
            (int expectedA, int expectedB) = ExpectedBottoms(layout, wall);
            if (wall.BottomA != expectedA || wall.BottomB != expectedB)
                defects.Add("bottom",
                    $"({wall.X},{wall.Y}) {wall.Dir}: bottoms ({wall.BottomA},{wall.BottomB}), "
                    + $"neighbour edge ({expectedA},{expectedB})");

            bool spans = wall.BottomA <= wall.TopA && wall.BottomB <= wall.TopB
                && (wall.BottomA < wall.TopA || wall.BottomB < wall.TopB)
                && wall.BottomA >= TerrainMeshBuilder.VoidFloorCornerHeight
                && wall.BottomB >= TerrainMeshBuilder.VoidFloorCornerHeight;
            if (!spans)
                defects.Add("span",
                    $"({wall.X},{wall.Y}) {wall.Dir}: tops ({wall.TopA},{wall.TopB}), "
                    + $"bottoms ({wall.BottomA},{wall.BottomB})");
        }
    }

    private static (int a, int b) ExpectedBottoms(MapLayout layout, TerrainDebugFaces.WallFace wall)
    {
        int floor = TerrainMeshBuilder.VoidFloorCornerHeight;
        (int nx, int ny) = LayoutQueries.Step(wall.X, wall.Y, wall.Dir);

        if (!layout.IsInBounds(nx, ny) || layout.GetTile(nx, ny) == TileRole.Empty)
            return (Math.Min(wall.TopA, floor), Math.Min(wall.TopB, floor));

        (int nA, int nB) = LayoutQueries.NeighborEdgeHeights(layout, wall.X, wall.Y, wall.Dir);

        var role = layout.GetTile(nx, ny);
        if (role == TileRole.Water
            || (role == TileRole.Bridge && !LayoutQueries.IsBridgeOverVoid(layout, nx, ny)))
        {
            nA -= TerrainMeshBuilder.WaterWallDepth;
            nB -= TerrainMeshBuilder.WaterWallDepth;
        }

        return (Math.Max(Math.Min(wall.TopA, nA), floor), Math.Max(Math.Min(wall.TopB, nB), floor));
    }

    // ─────────────────────────── (b) no doubled quads ───────────────────────────

    /// <summary>
    /// Two walls are the same quad when their four world positions match as a SET: the tile on either
    /// side of a shared edge reads that edge from opposite ends, so a doubled face arrives with its
    /// corners in reverse order.
    /// </summary>
    private static void CheckNoDoubledWalls(
        MapLayout layout, float hs, TerrainDebugFaces faces, Defects defects)
    {
        var seen = new Dictionary<string, TerrainDebugFaces.WallFace>();
        foreach (var wall in faces.Walls)
        {
            string key = QuadKey(wall, hs);
            if (seen.TryGetValue(key, out var first))
                defects.Add("double",
                    $"({wall.X},{wall.Y}) {wall.Dir} repeats ({first.X},{first.Y}) {first.Dir}");
            else
                seen[key] = wall;
        }
    }

    private static string QuadKey(TerrainDebugFaces.WallFace wall, float hs)
    {
        (Vector3 tl, Vector3 tr, Vector3 bl, Vector3 br) = LayoutQueries.GetEdgeWorldPositions(
            wall.X, wall.Y, wall.Dir, wall.TopA, wall.TopB, wall.BottomA, wall.BottomB, hs);

        var points = new List<string>
        {
            Point(tl), Point(tr), Point(bl), Point(br),
        };
        points.Sort(StringComparer.Ordinal);
        return string.Join("|", points);

        static string Point(Vector3 v) =>
            $"{Mathf.RoundToInt(v.X * 1000f)},{Mathf.RoundToInt(v.Y * 1000f)},{Mathf.RoundToInt(v.Z * 1000f)}";
    }

    // ─────────────────────────── (c) one wall per drop ───────────────────────────

    /// <summary>
    /// Every edge between two SOLID tiles, checked from the layout: the side that stands higher owes
    /// exactly one wall. A twisted edge owes one from each side, and the two must not cover the same
    /// stretch of the face — per corner their vertical intervals may touch at a point and no more.
    /// Water, bridge and void neighbours are left out: those edges are one-sided by design and (a)
    /// already pins their depth.
    /// </summary>
    private static void CheckOneWallPerDrop(MapLayout layout, TerrainDebugFaces faces, Defects defects)
    {
        var byEdge = new Dictionary<(int, int, CardinalDirection), TerrainDebugFaces.WallFace>();
        foreach (var wall in faces.Walls) byEdge[(wall.X, wall.Y, wall.Dir)] = wall;

        for (int x = 0; x < layout.Width; x++)
        for (int y = 0; y < layout.Height; y++)
        {
            if (!IsPlainSolid(layout, x, y)) continue;
            var corners = layout.GetCornerHeights(x, y);

            foreach (var dir in EdgeSweep)
            {
                (int nx, int ny) = LayoutQueries.Step(x, y, dir);
                if (!IsPlainSolid(layout, nx, ny)) continue;

                (int thisA, int thisB) = corners.EdgeCorners(dir);
                (int nA, int nB) = LayoutQueries.NeighborEdgeHeights(layout, x, y, dir);

                bool mine = byEdge.ContainsKey((x, y, dir));
                var opposite = LayoutQueries.Opposite(dir);
                bool theirs = byEdge.ContainsKey((nx, ny, opposite));

                bool oweMine = thisA > nA || thisB > nB;
                bool oweTheirs = nA > thisA || nB > thisB;

                if (mine != oweMine || theirs != oweTheirs)
                    defects.Add("count",
                        $"({x},{y}) {dir}: emitted {(mine ? 1 : 0)}+{(theirs ? 1 : 0)}, "
                        + $"owed {(oweMine ? 1 : 0)}+{(oweTheirs ? 1 : 0)} "
                        + $"[this ({thisA},{thisB}) vs neighbour ({nA},{nB})]");

                if (!mine || !theirs) continue;

                // The neighbour reads the shared edge the other way round, so its A is our B.
                var a = byEdge[(x, y, dir)];
                var b = byEdge[(nx, ny, opposite)];
                if (Overlaps(a.BottomA, a.TopA, b.BottomB, b.TopB)
                    || Overlaps(a.BottomB, a.TopB, b.BottomA, b.TopA))
                    defects.Add("twist",
                        $"({x},{y}) {dir}: [{a.BottomA}..{a.TopA}]/[{a.BottomB}..{a.TopB}] overlaps "
                        + $"[{b.BottomB}..{b.TopB}]/[{b.BottomA}..{b.TopA}]");
            }
        }
    }

    /// <summary>True when two closed intervals share more than a single point.</summary>
    private static bool Overlaps(int lo1, int hi1, int lo2, int hi2) =>
        Math.Min(hi1, hi2) - Math.Max(lo1, lo2) > 0;

    /// <summary>A tile that renders its own cliff walls: solid, and neither water nor bridge.</summary>
    private static bool IsPlainSolid(MapLayout layout, int x, int y)
    {
        if (!layout.IsInBounds(x, y)) return false;
        var role = layout.GetTile(x, y);
        return role != TileRole.Empty && role != TileRole.Water && role != TileRole.Bridge;
    }

    // ─────────────────────────── (d) tiling strips ───────────────────────────

    /// <summary>
    /// Strips are inset INWARD from the tile edge they mark, so each one lies inside its own tile's
    /// footprint. That is asserted first, which is what makes the per-tile overlap sweep below a
    /// complete proof: footprints in different tiles cannot reach each other.
    /// </summary>
    private static void CheckStripsTile(TerrainDebugFaces faces, Defects defects)
    {
        var byTile = new Dictionary<(int, int), List<TerrainDebugFaces.StripFace>>();

        foreach (var strip in faces.Strips)
        {
            bool inside = strip.MinX >= strip.X - Epsilon && strip.MaxX <= strip.X + 1f + Epsilon
                && strip.MinZ >= strip.Y - Epsilon && strip.MaxZ <= strip.Y + 1f + Epsilon;
            if (!inside)
                defects.Add("stray",
                    $"({strip.X},{strip.Y}) {strip.Dir}: x {strip.MinX:0.###}..{strip.MaxX:0.###}, "
                    + $"z {strip.MinZ:0.###}..{strip.MaxZ:0.###}");

            if (!byTile.TryGetValue((strip.X, strip.Y), out var list))
                byTile[(strip.X, strip.Y)] = list = new List<TerrainDebugFaces.StripFace>(4);
            list.Add(strip);
        }

        foreach (var (tile, list) in byTile)
        {
            for (int i = 0; i < list.Count; i++)
            for (int j = i + 1; j < list.Count; j++)
            {
                float area = list[i].OverlapArea(list[j]);
                if (area > Epsilon)
                    defects.Add("overlap",
                        $"({tile.Item1},{tile.Item2}): {list[i].Dir} and {list[j].Dir} share "
                        + $"{area:0.####} m²");
            }
        }
    }

    // ─────────────────────────── reporting ───────────────────────────

    /// <summary>Elevation range of a layout's solid tiles, in corner units — the plateau tell.</summary>
    private static string ElevationSpan(MapLayout layout)
    {
        int lo = int.MaxValue, hi = int.MinValue;
        for (int x = 0; x < layout.Width; x++)
        for (int y = 0; y < layout.Height; y++)
        {
            if (layout.GetTile(x, y) == TileRole.Empty) continue;
            var c = layout.GetCornerHeights(x, y);
            lo = Math.Min(lo, c.MinHeight);
            hi = Math.Max(hi, c.MaxHeight);
        }
        return lo > hi ? "none" : $"{lo}..{hi}";
    }

    /// <summary>
    /// Defect log keyed by assertion. Counting first and printing a handful of examples keeps a
    /// broken build to one readable page instead of thousands of lines.
    /// </summary>
    private sealed class Defects
    {
        private const int Examples = 3;

        private readonly Dictionary<string, int> _counts = new();
        private readonly Dictionary<string, List<string>> _examples = new();

        public void Add(string key, string detail)
        {
            _counts[key] = _counts.GetValueOrDefault(key) + 1;
            if (!_examples.TryGetValue(key, out var list))
                _examples[key] = list = new List<string>(Examples);
            if (list.Count < Examples) list.Add(detail);
        }

        /// <summary>True when nothing was logged under this key; prints the examples when it was.</summary>
        public bool Report(string key)
        {
            int count = _counts.GetValueOrDefault(key);
            if (count == 0) return true;
            GD.Print($"        · {count} defect(s):");
            foreach (string example in _examples[key]) GD.Print($"          - {example}");
            return false;
        }
    }
}
