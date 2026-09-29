using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class RoomGeneration
{
    public static bool Validate(GeneratedRoom room)
    {
        var l = room.Layout;
        int n = l.Width;
        var seen = new HashSet<Vector2Int>();
        var queue = new Queue<Vector2Int>();
        var start = new Vector2Int(n / 2, n / 2);
        seen.Add(start);
        queue.Enqueue(start);
        while (queue.TryDequeue(out var p))
            foreach (var d in new[]
            {
                new Vector2Int(1, 0),
                new Vector2Int(-1, 0),
                new Vector2Int(0, 1),
                new Vector2Int(0, -1)
            }

            )
            {
                var q = new Vector2Int(p.x + d.x, p.y + d.y);
                if (q.x < 1 || q.y < 1 || q.x >= n - 1 || q.y >= n - 1 || l.GetTile(q.x, q.y)is TileRole.Wall or TileRole.Water || !seen.Add(q))
                    continue;
                queue.Enqueue(q);
            }

        for (int y = 1; y < n - 1; y++)
            for (int x = 1; x < n - 1; x++)
                if (l.GetTile(x, y)is TileRole.Ground or TileRole.Cover && !seen.Contains(new(x, y)))
                    return false;
        foreach (var side in room.Doors)
            if (!seen.Contains(Inside(n, side)))
                return false;
        for (int i = 0; i < 4; i++)
            if (!seen.Contains(new(n / 2 + i % 2, n / 2 + i / 2)))
                return false;
        return seen.Count >= (n - 2) * (n - 2) * 0.65;
    }

    public static IReadOnlyList<Vector2Int> Route(MapLayout l, Vector2Int start, Vector2Int end)
    {
        var previous = new Dictionary<Vector2Int, Vector2Int>();
        var q = new Queue<Vector2Int>();
        q.Enqueue(start);
        previous[start] = start;
        while (q.TryDequeue(out var p))
        {
            if (p == end)
                break;
            foreach (var d in new[]
            {
                new Vector2Int(1, 0),
                new Vector2Int(-1, 0),
                new Vector2Int(0, 1),
                new Vector2Int(0, -1)
            }

            )
            {
                var next = new Vector2Int(p.x + d.x, p.y + d.y);
                if (next.x < 1 || next.y < 1 || next.x >= l.Width - 1 || next.y >= l.Height - 1 || l.GetTile(next.x, next.y)is TileRole.Wall or TileRole.Water || previous.ContainsKey(next))
                    continue;
                // Travellers walk up and down one step at a time, never up a cliff.
                if (Math.Abs(l.GetElevation(next.x, next.y) - l.GetElevation(p.x, p.y)) > GladeGeneration.MaxStep)
                    continue;
                previous[next] = p;
                q.Enqueue(next);
            }
        }

        if (!previous.ContainsKey(end))
            throw new InvalidOperationException("No room travel route.");
        var route = new List<Vector2Int>
        {
            end
        };
        while (route[^1] != start)
            route.Add(previous[route[^1]]);
        route.Reverse();
        return route;
    }
}
