using System;
using System.Collections.Generic;
using System.Linq;
using PF2e;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class GladeGeneration
{
    /// <summary>Tiles a landmark's footprint covers on each side.</summary>
    private const int LandmarkSize = 2;

    /// <summary>Height of a landmark for the prop builder, metres.</summary>
    private const float LandmarkHeight = 1.4f;

    /// <summary>Place the recipe's landmarks on level 2x2 ground away from the mouths, boxes and
    /// lanes, the first one farthest from every mouth. Each footprint blocks like a wall.</summary>
    private static List<RoomProp> Landmarks(MapLayout layout, IReadOnlyList<DoorSide> doors, GladeShape shape, Random rng)
    {
        var placed = new List<RoomProp>();
        if (shape.Recipe.Props.Count == 0) return placed;
        int n = layout.Width, mid = n / 2;
        var zones = ZoneTiles(n, doors, shape.ZoneHalf).ToHashSet();
        var mouths = MouthTiles(n, doors).ToArray();
        var taken = new HashSet<Vector2Int>();
        IEnumerable<Vector2Int> Footprint(Vector2Int corner) =>
            Enumerable.Range(0, LandmarkSize * LandmarkSize).Select(i => new Vector2Int(corner.x + i % LandmarkSize, corner.y + i / LandmarkSize));
        bool Fits(Vector2Int corner)
        {
            var tiles = Footprint(corner).ToArray();
            int level = layout.GetElevation(corner.x, corner.y);
            return tiles.All(p => p.x > 1 && p.y > 1 && p.x < n - 2 && p.y < n - 2
                && layout.GetTile(p.x, p.y) == TileRole.Ground && layout.GetElevation(p.x, p.y) == level
                && !zones.Contains(p) && Math.Abs(p.x - mid) > 1 && Math.Abs(p.y - mid) > 1
                && mouths.All(m => Math.Abs(m.x - p.x) + Math.Abs(m.y - p.y) > MouthClear)
                && !taken.Any(t => Math.Max(Math.Abs(t.x - p.x), Math.Abs(t.y - p.y)) <= 1));
        }
        int Distance(Vector2Int corner) => mouths.Length == 0 ? 0 : mouths.Min(m => Math.Abs(m.x - corner.x) + Math.Abs(m.y - corner.y));

        var corners = Enumerable.Range(0, n * n).Select(i => new Vector2Int(i % n, i / n))
            .OrderByDescending(Distance).ThenBy(_ => rng.Next()).ToList();
        foreach (string kind in shape.Recipe.Props)
        {
            var corner = corners.FirstOrDefault(Fits, new Vector2Int(-1, -1));
            if (corner.x < 0) continue;
            foreach (var p in Footprint(corner))
            {
                taken.Add(p);
                SetFlat(layout, p.x, p.y, TileRole.Wall, SurfaceType.Stone, layout.GetElevation(p.x, p.y));
            }
            float facing = Math.Abs(mid - corner.x) > Math.Abs(mid - corner.y) ? (corner.x < mid ? 90 : -90) : (corner.y < mid ? 0 : 180);
            placed.Add(new RoomProp(kind, corner.x + 1, corner.y + 1, LandmarkSize, LandmarkSize, LandmarkHeight, facing, Raised: true));
        }
        return placed;
    }

    /// <summary>Put the landmarks' footprints back after a fallback flattened the glade.</summary>
    private static MapLayout Block(MapLayout layout, IReadOnlyList<RoomProp> props)
    {
        foreach (var prop in props)
            for (int i = 0; i < LandmarkSize * LandmarkSize; i++)
            {
                int x = (int)prop.X - 1 + i % LandmarkSize, y = (int)prop.Y - 1 + i / LandmarkSize;
                SetFlat(layout, x, y, TileRole.Wall, SurfaceType.Stone, layout.GetElevation(x, y));
            }
        return layout;
    }

    /// <summary>Tiles under a landmark, which the renderer keeps free of trees.</summary>
    public static IEnumerable<(int X, int Y)> LandmarkTiles(IReadOnlyList<RoomProp> props)
    {
        foreach (var prop in props)
            for (int i = 0; i < LandmarkSize * LandmarkSize; i++)
                yield return ((int)prop.X - 1 + i % LandmarkSize, (int)prop.Y - 1 + i / LandmarkSize);
    }
}
