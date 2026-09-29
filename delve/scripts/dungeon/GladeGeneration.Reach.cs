using System;
using System.Collections.Generic;
using System.Linq;
using PF2e;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class GladeGeneration
{
    private static readonly Vector2Int[] Steps = { new(1, 0), new(-1, 0), new(0, 1), new(0, -1) };

    /// <summary>Interior tiles a traveller reaches from the centre, stepping at most
    /// <see cref="MaxStep"/> elevations at a time.</summary>
    public static HashSet<Vector2Int> Reachable(MapLayout layout)
    {
        int n = layout.Width;
        var start = new Vector2Int(n / 2, n / 2);
        var seen = new HashSet<Vector2Int>();
        if (!Open(layout, start)) return seen;
        var queue = new Queue<Vector2Int>();
        seen.Add(start);
        queue.Enqueue(start);
        while (queue.TryDequeue(out var p))
            foreach (var d in Steps)
            {
                var q = new Vector2Int(p.x + d.x, p.y + d.y);
                if (!Open(layout, q) || seen.Contains(q)) continue;
                if (Math.Abs(layout.GetElevation(q.x, q.y) - layout.GetElevation(p.x, p.y)) > MaxStep) continue;
                seen.Add(q);
                queue.Enqueue(q);
            }
        return seen;
    }

    /// <summary>True when every mouth, the centre block and enough of the glade are reachable.</summary>
    public static bool Reached(MapLayout layout, IReadOnlyList<DoorSide> doors, out HashSet<Vector2Int> seen)
    {
        int n = layout.Width;
        seen = Reachable(layout);
        foreach (var side in doors)
            if (!seen.Contains(RoomGeneration.Inside(n, side))) return false;
        for (int i = 0; i < 4; i++)
            if (!seen.Contains(new Vector2Int(n / 2 + i % 2, n / 2 + i / 2))) return false;
        foreach (var tile in ZoneTiles(n))
            if (!seen.Contains(tile)) return false;
        return seen.Count >= (n - 2) * (n - 2) * MinOpenShare;
    }

    /// <summary>Every tile of both teams' deployment boxes, for either entry axis.</summary>
    private static IEnumerable<Vector2Int> ZoneTiles(int n)
    {
        foreach (var zone in RoomGeneration.Zones(n, DoorSide.West).Concat(RoomGeneration.Zones(n, DoorSide.North)))
            for (int y = Math.Min(zone.CornerA.y, zone.CornerB.y); y <= Math.Max(zone.CornerA.y, zone.CornerB.y); y++)
                for (int x = Math.Min(zone.CornerA.x, zone.CornerB.x); x <= Math.Max(zone.CornerA.x, zone.CornerB.x); x++)
                    yield return new Vector2Int(x, y);
    }

    private static bool Open(MapLayout layout, Vector2Int p)
    {
        int n = layout.Width;
        if (p.x < 1 || p.y < 1 || p.x >= n - 1 || p.y >= n - 1) return false;
        return layout.GetTile(p.x, p.y) is not (TileRole.Wall or TileRole.Water or TileRole.Empty);
    }

    /// <summary>Last resort: a two-wide trail from each mouth to the centre that ramps one step
    /// per tile, and an open centre block.</summary>
    private static void Carve(MapLayout layout, IReadOnlyList<DoorSide> doors)
    {
        int n = layout.Width, mid = n / 2;
        for (int i = 0; i < 4; i++)
        {
            int x = mid + i % 2, y = mid + i / 2;
            if (!Open(layout, new Vector2Int(x, y)))
                SetFlat(layout, x, y, TileRole.Ground, SurfaceType.Dirt, layout.GetElevation(x, y));
        }
        foreach (var side in doors)
        {
            var inside = RoomGeneration.Inside(n, side);
            var path = new List<Vector2Int>();
            for (var p = inside; ; )
            {
                path.Add(p);
                if (p.x == mid && p.y == mid) break;
                p = p.x != mid ? new Vector2Int(p.x + Math.Sign(mid - p.x), p.y) : new Vector2Int(p.x, p.y + Math.Sign(mid - p.y));
            }
            int previous = 0;
            foreach (var p in path)
            {
                int elevation = Math.Clamp(layout.GetElevation(p.x, p.y), previous - MaxStep, previous + MaxStep);
                var beside = side is DoorSide.North or DoorSide.South ? new Vector2Int(p.x + 1, p.y) : new Vector2Int(p.x, p.y + 1);
                SetFlat(layout, p.x, p.y, TileRole.Ground, SurfaceType.Dirt, elevation);
                SetFlat(layout, beside.x, beside.y, TileRole.Ground, SurfaceType.Dirt, elevation);
                previous = elevation;
            }
        }
    }

    /// <summary>Open tiles no traveller can reach become trees, so nothing on the board promises a
    /// place the party cannot stand.</summary>
    private static void Seal(MapLayout layout, IReadOnlyList<DoorSide> doors)
    {
        var seen = Reachable(layout);
        int n = layout.Width;
        for (int y = 1; y < n - 1; y++)
            for (int x = 1; x < n - 1; x++)
                if (Open(layout, new Vector2Int(x, y)) && !seen.Contains(new Vector2Int(x, y)))
                    SetFlat(layout, x, y, TileRole.Wall, SurfaceType.Dirt, layout.GetElevation(x, y));
    }

    /// <summary>Spike check: mouths at ground level, all reached, zones open.</summary>
    public static bool Valid(GeneratedRoom room)
    {
        var layout = room.Layout;
        int n = layout.Width;
        if (!Reached(layout, room.Doors, out _)) return false;
        foreach (var side in room.Doors)
            if (RoomGeneration.Threshold(n, side).Any(p => layout.GetElevation(p.x, p.y) != 0)) return false;
        return ZoneTiles(n).All(p => layout.IsWalkable(p.x, p.y));
    }
}
