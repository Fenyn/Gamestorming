using System;
using System.Collections.Generic;
using System.Linq;
using PF2e;
using PF2e.MapGen;

namespace Delve.Run;

/// <summary>Grows the woodland around a forest board into its edge: trees that step in from the
/// edge, brush beside them, and optionally a few small clumps in the open. Crawl glades and generated
/// combat boards use the same step, so a fight looks like the forest it is in.</summary>
public static class Undergrowth
{
    /// <summary>Chance a tile on the first ring in from the edge holds a tree, and on the second.
    /// The edge then frays into the board instead of standing as a hedge.</summary>
    private const float StragglerNear = 0.4f, StragglerFar = 0.16f;

    /// <summary>Edge trees every board gets, however the rolls fall, while room remains.</summary>
    private const int MinStragglers = 3;

    /// <summary>Chance a free tile beside a tree is brush: difficult plant terrain the decor draws
    /// as tall grass and bushes.</summary>
    private const float BrushChance = 0.35f;

    /// <summary>Rings in from the edge that brush grows on.</summary>
    private const int BrushRings = 3;

    /// <summary>Clumps grown in the open when asked, trunks per clump, and the rings from the edge
    /// a clump keeps clear of.</summary>
    private const int MinClumps = 2, MaxClumps = 4, MaxTrunks = 2, ClumpClear = 2;

    private static readonly Vector2Int[] Steps = { new(1, 0), new(-1, 0), new(0, 1), new(0, -1) };

    /// <summary>Grow undergrowth on <paramref name="layout"/>. <paramref name="ring"/> is the first
    /// ring counted in from the board edge that may grow (1 when the edge itself is a tree wall).
    /// Nothing grows where <paramref name="keepOpen"/> says, or beside stone that stands up
    /// (landmarks, walls, cover rocks, raised stonework); a level stone path may run past trees. With
    /// <paramref name="keepConnected"/>, a tree that would cut off open ground from the rest is not
    /// planted; without it the caller validates the result.</summary>
    public static void Grow(MapLayout layout, int ring, Func<Vector2Int, bool> keepOpen, bool clumps, Random rng, bool keepConnected = false)
    {
        int w = layout.Width, h = layout.Height;
        int Depth(Vector2Int p) => Math.Min(Math.Min(p.x, p.y), Math.Min(w - 1 - p.x, h - 1 - p.y)) - ring;
        bool Inside(int x, int y) => x >= 0 && y >= 0 && x < w && y < h;
        bool NearStone(Vector2Int p) => Enumerable.Range(0, 9).Any(i =>
        {
            int x = p.x + i % 3 - 1, y = p.y + i / 3 - 1;
            return Inside(x, y) && layout.GetSurface(x, y) == SurfaceType.Stone
                && (layout.GetTile(x, y) is TileRole.Wall or TileRole.Cover || layout.GetElevation(x, y) > layout.GetElevation(p.x, p.y));
        });
        bool Free(Vector2Int p) => Depth(p) >= 0 && layout.GetTile(p.x, p.y) == TileRole.Ground && !keepOpen(p) && !NearStone(p);
        int reach = keepConnected ? Reached(layout, Start(layout)) : 0;
        bool Plant(Vector2Int p)
        {
            var role = layout.GetTile(p.x, p.y);
            var surface = layout.GetSurface(p.x, p.y);
            layout.SetTile(p.x, p.y, TileRole.Wall);
            layout.SetSurface(p.x, p.y, SurfaceType.Dirt);
            if (!keepConnected) return true;
            int now = Reached(layout, Start(layout));
            if (now >= reach - 1)
            {
                reach = now;
                return true;
            }
            layout.SetTile(p.x, p.y, role);
            layout.SetSurface(p.x, p.y, surface);
            return false;
        }

        var tiles = Enumerable.Range(0, w * h).Select(i => new Vector2Int(i % w, i / w)).ToArray();
        var trees = new List<Vector2Int>();
        var edge = tiles.Where(p => Depth(p) is 0 or 1 && Free(p)).ToArray();
        foreach (var p in edge)
            if (rng.NextDouble() < (Depth(p) == 0 ? StragglerNear : StragglerFar) && Plant(p))
                trees.Add(p);
        // A board whose rolls all missed still frays at its edge.
        foreach (var p in edge.Where(Free).OrderBy(_ => rng.Next()))
        {
            if (trees.Count >= MinStragglers) break;
            if (Plant(p)) trees.Add(p);
        }

        if (clumps)
        {
            var open = tiles.Where(p => Depth(p) >= ClumpClear && Free(p)).OrderBy(_ => rng.Next()).ToList();
            for (int clump = rng.Next(MinClumps, MaxClumps + 1); clump > 0 && open.Count > 0; clump--)
            {
                var trunk = open[0];
                for (int i = rng.Next(1, MaxTrunks + 1); i > 0; i--)
                {
                    if (!Plant(trunk)) break;
                    trees.Add(trunk);
                    var next = Steps.Select(d => new Vector2Int(trunk.x + d.x, trunk.y + d.y)).Where(Free).ToArray();
                    if (next.Length == 0) break;
                    trunk = next[rng.Next(next.Length)];
                }
                open.RemoveAll(p => layout.GetTile(p.x, p.y) != TileRole.Ground || Math.Abs(p.x - trunk.x) + Math.Abs(p.y - trunk.y) <= ClumpClear + 1);
            }
        }

        foreach (var tree in trees)
            foreach (var d in Steps)
            {
                var p = new Vector2Int(tree.x + d.x, tree.y + d.y);
                if (!Inside(p.x, p.y) || Depth(p) >= BrushRings || !Free(p) || rng.NextDouble() >= BrushChance) continue;
                layout.SetTile(p.x, p.y, TileRole.DifficultTerrain);
                layout.SetPlantTerrain(p.x, p.y, true);
            }
    }

    /// <summary>A walkable tile to count reach from: the middle of the first deployment zone, or
    /// the first walkable tile.</summary>
    private static Vector2Int Start(MapLayout layout)
    {
        if (layout.DeploymentZones is { Length: > 0 } zones && zones[0] is { } zone)
        {
            var mid = new Vector2Int((zone.CornerA.x + zone.CornerB.x) / 2, (zone.CornerA.y + zone.CornerB.y) / 2);
            if (layout.IsWalkable(mid.x, mid.y)) return mid;
        }
        for (int i = 0; i < layout.Width * layout.Height; i++)
            if (layout.IsWalkable(i % layout.Width, i / layout.Width)) return new Vector2Int(i % layout.Width, i / layout.Width);
        return new Vector2Int(0, 0);
    }

    /// <summary>Walkable tiles reached from <paramref name="start"/>, stepping at most one
    /// elevation at a time.</summary>
    private static int Reached(MapLayout layout, Vector2Int start)
    {
        if (!layout.IsWalkable(start.x, start.y)) return 0;
        var seen = new HashSet<Vector2Int> { start };
        var queue = new Queue<Vector2Int>();
        queue.Enqueue(start);
        while (queue.TryDequeue(out var p))
            foreach (var d in Steps)
            {
                var q = new Vector2Int(p.x + d.x, p.y + d.y);
                if (q.x < 0 || q.y < 0 || q.x >= layout.Width || q.y >= layout.Height || seen.Contains(q) || !layout.IsWalkable(q.x, q.y)) continue;
                if (Math.Abs(layout.GetElevation(q.x, q.y) - layout.GetElevation(p.x, p.y)) > 1) continue;
                seen.Add(q);
                queue.Enqueue(q);
            }
        return seen.Count;
    }
}
