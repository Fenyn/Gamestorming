using System;
using System.Collections.Generic;
using System.Linq;

namespace Delve.Dungeon;

public readonly record struct RoomBounds(int X, int Y, int Width)
{
    public int Right => X + Width;
    public int Bottom => Y + Width;
}

/// <summary>Compacts aligned sockets after prefabs choose their dimensions.</summary>
public static class DungeonPlacement
{
    public static IReadOnlyDictionary<int, RoomBounds> Pack(DungeonFloor floor, IReadOnlyDictionary<int, int> widths)
    {
        int spacing = widths.Values.Max();
        var xs = Enumerable.Range(0, floor.Rooms.Max(r => r.X) + 1).Select(i => i * spacing).ToArray();
        var ys = Enumerable.Range(0, floor.Rooms.Max(r => r.Y) + 1).Select(i => i * spacing).ToArray();
        Dictionary<int, RoomBounds> Bounds() => floor.Rooms.ToDictionary(r => r.Id,
            r => new RoomBounds(xs[r.X] - widths[r.Id] / 2, ys[r.Y] - widths[r.Id] / 2, widths[r.Id]));

        // Move a whole row/column boundary one tile at a time. Centered sockets
        // stay aligned, including loops. Check diagonals and passage walls too.
        bool changed;
        do
        {
            changed = false;
            foreach (var axis in new[] { xs, ys })
                for (int boundary = 1; boundary < axis.Length; boundary++)
                    while (axis[boundary] > axis[boundary - 1] + 1)
                    {
                        for (int i = boundary; i < axis.Length; i++) axis[i]--;
                        if (IsLegal(floor, Bounds())) { changed = true; continue; }
                        for (int i = boundary; i < axis.Length; i++) axis[i]++;
                        break;
                    }
        } while (changed);
        var packed = Bounds();
        // Disconnected socket lines can slide independently. This closes the
        // leftover gaps around small event rooms without disturbing a loop.
        var groups = new List<(bool Horizontal, HashSet<int> Rooms)>();
        foreach (bool horizontal in new[] { true, false })
        {
            var remaining = floor.Rooms.Select(r => r.Id).ToHashSet();
            while (remaining.Count > 0)
            {
                var group = new HashSet<int>();
                var queue = new Queue<int>();
                queue.Enqueue(remaining.Min());
                while (queue.TryDequeue(out int id))
                {
                    if (!remaining.Remove(id)) continue;
                    group.Add(id);
                    foreach (var door in floor.Rooms[id].Doors)
                        if ((door.SideA is DoorSide.North or DoorSide.South) == horizontal)
                            queue.Enqueue(door.Other(id));
                }
                groups.Add((horizontal, group));
            }
        }
        int Cost() => floor.Rooms.Sum(r => r.Doors.Where(d => d.A == r.Id).Sum(d =>
            Math.Abs(packed[d.A].X + packed[d.A].Width / 2 - packed[d.B].X - packed[d.B].Width / 2) +
            Math.Abs(packed[d.A].Y + packed[d.A].Width / 2 - packed[d.B].Y - packed[d.B].Width / 2)));
        int cost = Cost();
        do
        {
            changed = false;
            foreach (var (horizontal, group) in groups)
                foreach (int sign in new[] { -1, 1 })
                    while (true)
                    {
                        void Shift(int delta)
                        {
                            foreach (int id in group)
                            {
                                var b = packed[id];
                                packed[id] = horizontal ? b with { X = b.X + delta } : b with { Y = b.Y + delta };
                            }
                        }
                        Shift(sign);
                        int next = Cost();
                        if (next < cost && IsLegal(floor, packed)) { cost = next; changed = true; continue; }
                        Shift(-sign);
                        break;
                    }
        } while (changed);
        return packed;
    }

    public static bool IsLegal(DungeonFloor floor, IReadOnlyDictionary<int, RoomBounds> bounds)
    {
        static bool Overlap(float x, float y, float right, float bottom, RoomBounds b) =>
            x < b.Right && right > b.X && y < b.Bottom && bottom > b.Y;
        foreach (var room in floor.Rooms)
        {
            var a = bounds[room.Id];
            foreach (var other in floor.Rooms.Where(r => r.Id > room.Id))
                if (Overlap(a.X, a.Y, a.Right, a.Bottom, bounds[other.Id])) return false;
            foreach (var door in room.Doors.Where(d => d.A == room.Id))
            {
                var b = bounds[door.B];
                bool horizontal = door.SideA is DoorSide.East or DoorSide.West;
                float x, y, right, bottom;
                if (horizontal)
                {
                    if (a.Y + a.Width / 2 != b.Y + b.Width / 2) return false;
                    if (door.SideA == DoorSide.East ? a.Right > b.X : b.Right > a.X) return false;
                    x = Math.Min(a.Right, b.Right); right = Math.Max(a.X, b.X);
                    y = a.Y + a.Width / 2f - 1.5f; bottom = y + 4;
                }
                else
                {
                    if (a.X + a.Width / 2 != b.X + b.Width / 2) return false;
                    if (door.SideA == DoorSide.South ? a.Bottom > b.Y : b.Bottom > a.Y) return false;
                    y = Math.Min(a.Bottom, b.Bottom); bottom = Math.Max(a.Y, b.Y);
                    x = a.X + a.Width / 2f - 1.5f; right = x + 4;
                }
                if (right <= x || bottom <= y) continue; // Abutting wall rings.
                foreach (var other in floor.Rooms.Where(r => r.Id != door.A && r.Id != door.B))
                    if (Overlap(x, y, right, bottom, bounds[other.Id])) return false;
            }
        }
        return true;
    }
}
