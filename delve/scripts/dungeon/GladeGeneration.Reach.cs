using System;
using System.Collections.Generic;
using System.Linq;
using PF2e;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class GladeGeneration
{
    internal static readonly Vector2Int[] Steps = { new(1, 0), new(-1, 0), new(0, 1), new(0, -1) };

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

    /// <summary>True when every mouth, the centre block, both deployment boxes and enough of the
    /// glade are reachable. Water counts as open ground for the share, though nobody walks it.</summary>
    public static bool Reached(MapLayout layout, IReadOnlyList<DoorSide> doors, int half, out HashSet<Vector2Int> seen)
    {
        int n = layout.Width;
        seen = Reachable(layout);
        foreach (var side in doors)
            if (!seen.Contains(RoomGeneration.Inside(n, side))) return false;
        for (int i = 0; i < 4; i++)
            if (!seen.Contains(new Vector2Int(n / 2 + i % 2, n / 2 + i / 2))) return false;
        foreach (var tile in ZoneTiles(n, doors, half).Concat(MouthTiles(n, doors)))
            if (!seen.Contains(tile)) return false;
        int water = layout.Tiles.Count(t => t == TileRole.Water);
        return seen.Count + water >= (n - 2) * (n - 2) * MinOpenShare;
    }

    private static bool Open(MapLayout layout, Vector2Int p)
    {
        int n = layout.Width;
        if (p.x < 1 || p.y < 1 || p.x >= n - 1 || p.y >= n - 1) return false;
        return layout.GetTile(p.x, p.y) is not (TileRole.Wall or TileRole.Water or TileRole.Empty or TileRole.Cover);
    }

    /// <summary>Last resort: flatten the centre block to one height and ramp a two-wide trail up
    /// to it from each mouth. When even that fails, the glade is open level ground.</summary>
    private static MapLayout Carve(MapLayout layout, IReadOnlyList<DoorSide> doors, int half)
    {
        int n = layout.Width, mid = n / 2;
        int shortest = doors.Min(side => Math.Abs(RoomGeneration.Inside(n, side).x - mid) + Math.Abs(RoomGeneration.Inside(n, side).y - mid));
        int top = Math.Min(layout.GetElevation(mid, mid), shortest);
        for (int i = 0; i < 4; i++)
            SetFlat(layout, mid + i % 2, mid + i / 2, TileRole.Ground, SurfaceType.Dirt, top);
        foreach (var side in doors)
        {
            int step = 0;
            for (var p = RoomGeneration.Inside(n, side); p.x != mid || p.y != mid; step++)
            {
                var beside = side is DoorSide.North or DoorSide.South ? new Vector2Int(p.x + 1, p.y) : new Vector2Int(p.x, p.y + 1);
                SetFlat(layout, p.x, p.y, TileRole.Ground, SurfaceType.Dirt, Math.Min(step, top));
                SetFlat(layout, beside.x, beside.y, TileRole.Ground, SurfaceType.Dirt, Math.Min(step, top));
                p = p.x != mid ? new Vector2Int(p.x + Math.Sign(mid - p.x), p.y) : new Vector2Int(p.x, p.y + Math.Sign(mid - p.y));
            }
        }
        if (Reached(layout, doors, half, out _)) return layout;
        for (int y = 1; y < n - 1; y++)
            for (int x = 1; x < n - 1; x++)
                SetFlat(layout, x, y, TileRole.Ground, SurfaceType.Grass, 0);
        return layout;
    }

    /// <summary>Open tiles no traveller can reach become trees, so nothing on the board promises a
    /// place the party cannot stand. Water stays water.</summary>
    private static void Seal(MapLayout layout)
    {
        var seen = Reachable(layout);
        int n = layout.Width;
        for (int y = 1; y < n - 1; y++)
            for (int x = 1; x < n - 1; x++)
                if (layout.GetTile(x, y) is TileRole.Ground or TileRole.DifficultTerrain or TileRole.Bridge && !seen.Contains(new Vector2Int(x, y)))
                    SetFlat(layout, x, y, TileRole.Wall, SurfaceType.Dirt, layout.GetElevation(x, y));
    }

    /// <summary>Spike check: mouths at ground level, all reached, zones open.</summary>
    public static bool Valid(GeneratedRoom room)
    {
        var layout = room.Layout;
        int n = layout.Width;
        if (!Reached(layout, room.Doors, room.ZoneHalf, out _)) return false;
        foreach (var side in room.Doors)
            if (RoomGeneration.Threshold(n, side).Any(p => layout.GetElevation(p.x, p.y) != 0)) return false;
        return ZoneTiles(n, room.Doors, room.ZoneHalf).All(p => layout.IsWalkable(p.x, p.y));
    }
}
