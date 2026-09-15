using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;

namespace Delve.Dungeon;
public enum RoomFamily
{
    Entrance,
    GuardHall,
    Barracks,
    Cistern,
    Collapse,
    Shrine,
    Cache,
    Camp,
    Elite,
    Guardian
}

public enum DoorSide
{
    North,
    East,
    South,
    West
}

public sealed record DungeonDoor(int A, int B, DoorSide SideA)
{
    public int Other(int room) => room == A ? B : A;
    public DoorSide Side(int room) => room == A ? SideA : (DoorSide)(((int)SideA + 2) % 4);
}

public sealed class DungeonRoom
{
    public required int Id { get; init; }
    public required int X { get; init; }
    public required int Y { get; init; }
    public required RoomFamily Family { get; init; }
    public required int Seed { get; init; }
    public RoomPurpose? PurposeOverride { get; init; }
    public RoomPurpose Purpose => PurposeOverride ?? StationPlan.Default(Family);
    public bool Discovered { get; set; }
    public bool Completed { get; set; }
    public bool Resolved { get; set; }
    public List<DungeonDoor> Doors { get; } = new();
}

/// <summary>Graph and spatial placement are independent of a prefab's internal generation.</summary>
public sealed class DungeonFloor
{
    public required IReadOnlyList<DungeonRoom> Rooms { get; init; }
    public required RunMap Map { get; init; }
    public StationHistory History { get; init; }
    public int EntranceId => 0;
    public int GuardianId => 11;

    public static DungeonFloor Generate(int seed)
    {
        var rng = new Random(RunRng.StableSeed(seed, 0, "dungeon-topology"));
        // Functional backbone: public entry, living wing, water service, and ward access.
        var edges = new List<(int A, int B)> { (0, 1), (1, 2), (2, 3), (3, 7), (7, 6), (0, 4), (4, 5), (5, 9), (9, 10), (10, 11), (8, 9) };
        // Alternate maintenance routes vary without breaking functional adjacency.
        for (int loop = 0; loop < 2; loop++)
        {
            var candidates = new List<(int A, int B)>();
            for (int a = 0; a < 11; a++)
                foreach (int b in Neighbors(a))
                    if (b > a && b != 11 && !edges.Any(e => e == (a, b) || e == (b, a))) candidates.Add((a, b));
            edges.Add(candidates[rng.Next(candidates.Count)]);
        }
        var families = new List<RoomFamily>
        {
            RoomFamily.Collapse,
            RoomFamily.Shrine,
            RoomFamily.Cache,
            RoomFamily.GuardHall,
            RoomFamily.Barracks,
            RoomFamily.Cistern,
            RoomFamily.GuardHall,
            RoomFamily.Barracks,
            RoomFamily.Elite
        };
        for (int i = families.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (families[i], families[j]) = (families[j], families[i]);
        }

        // Put the elite occupation deeper in the facility, beyond public access.
        var distances = Enumerable.Repeat(-1, 12).ToArray();
        distances[0] = 0;
        var frontier = new Queue<int>();
        frontier.Enqueue(0);
        while (frontier.TryDequeue(out int current))
            foreach (var edge in edges.Where(e => e.A == current || e.B == current))
            {
                int next = edge.A == current ? edge.B : edge.A;
                if (distances[next] >= 0) continue;
                distances[next] = distances[current] + 1;
                frontier.Enqueue(next);
            }
        int deepest = Enumerable.Range(1, 9).Max(i => distances[i]);
        var eliteSites = Enumerable.Range(1, 9).Where(i => distances[i] == deepest).ToArray();
        int eliteSite = eliteSites[rng.Next(eliteSites.Length)] - 1;
        int eliteIndex = families.IndexOf(RoomFamily.Elite);
        (families[eliteIndex], families[eliteSite]) = (families[eliteSite], families[eliteIndex]);

        var rooms = Enumerable.Range(0, 12).Select(id => new DungeonRoom { Id = id, X = id % 4, Y = id / 4, Family = id == 0 ? RoomFamily.Entrance : id == 10 ? RoomFamily.Camp : id == 11 ? RoomFamily.Guardian : families[id - 1], PurposeOverride = StationPlan.Functions[id], Seed = RunRng.StableSeed(seed, id, "room") }).ToArray();
        // Rotate the entire legal coarse layout; socket orientations follow the transformed cells.
        int turns = rng.Next(4);
        rooms = rooms.Select(r =>
        {
            int x = r.X, y = r.Y, w = 4, h = 3;
            for (int t = 0; t < turns; t++)
            {
                (x, y) = (h - 1 - y, x);
                (w, h) = (h, w);
            }

            return new DungeonRoom
            {
                Id = r.Id,
                X = x,
                Y = y,
                Family = r.Family,
                PurposeOverride = r.Purpose,
                Seed = r.Seed
            };
        }).ToArray();
        foreach (var(a, b)in edges)
        {
            var side = rooms[b].X > rooms[a].X ? DoorSide.East : rooms[b].X < rooms[a].X ? DoorSide.West : rooms[b].Y > rooms[a].Y ? DoorSide.South : DoorSide.North;
            var door = new DungeonDoor(a, b, side);
            rooms[a].Doors.Add(door);
            rooms[b].Doors.Add(door);
        }

        var depth = Enumerable.Repeat(-1, 12).ToArray();
        depth[0] = 0;
        var queue = new Queue<int>();
        queue.Enqueue(0);
        while (queue.TryDequeue(out int a))
            foreach (var d in rooms[a].Doors)
            {
                int b = d.Other(a);
                if (depth[b] >= 0)
                    continue;
                depth[b] = depth[a] + 1;
                queue.Enqueue(b);
            }

        var nodes = rooms.Select(r => new MapNode { Id = r.Id, Floor = depth[r.Id], Lane = r.X, Kind = Kind(r.Family) }).ToArray();
        foreach (var r in rooms)
            nodes[r.Id].Next.AddRange(r.Doors.Select(d => d.Other(r.Id)).OrderBy(id => id));
        return new DungeonFloor
        {
            History = StationPlan.History(seed),
            Rooms = rooms,
            Map = new RunMap(depth.Max() + 1, 4, nodes, new[] { 0 }, 11)
        };
    }

    public static NodeKind Kind(RoomFamily f) => f switch
    {
        RoomFamily.GuardHall or RoomFamily.Barracks or RoomFamily.Cistern => NodeKind.Combat,
        RoomFamily.Elite => NodeKind.Elite,
        RoomFamily.Guardian => NodeKind.Boss,
        RoomFamily.Camp => NodeKind.Rest,
        _ => NodeKind.Event
    };
    private static IEnumerable<int> Neighbors(int a)
    {
        if (a % 4 > 0)
            yield return a - 1;
        if (a % 4 < 3)
            yield return a + 1;
        if (a >= 4)
            yield return a - 4;
        if (a < 8)
            yield return a + 4;
    }
}
