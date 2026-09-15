using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dungeon;

/// <summary>Construct a usable facility room, then apply its history.</summary>
public static partial class StationRooms
{
    public static GeneratedRoom Generate(RoomPurpose purpose, int seed, int interior, IReadOnlyList<DoorSide> doors,
        RoomVariation profile, StationHistory history)
    {
        int variant = profile.LayoutVariant >= 0 ? profile.LayoutVariant : new Random(RunRng.StableSeed(seed, 0, "station-arrangement")).Next(3);
        var b = new Builder(interior + 2, seed, doors, variant);
        // Ward access faces the installation, with stairs off the approach aisle.
        if (purpose == RoomPurpose.WardChamber && doors.Count == 1) b.Turns = ((int)doors[0] + 2) % 4;
        Furnish(b, purpose, variant);
        TellHistory(b, purpose, history);
        var room = b.Result();
        if (!RoomGeneration.Validate(room)) throw new InvalidOperationException($"Invalid station room {purpose}/{seed}/{interior}/{variant}.");
        return room;
    }

    private sealed class Builder
    {
        public int N { get; }
        public int Mid => N / 2;
        public int Turns { get; set; }
        public MapLayout Layout { get; }
        public readonly List<RoomProp> Props = new();
        private readonly IReadOnlyList<DoorSide> _doors;
        private readonly HashSet<(int, int)> _protected = new();

        public Builder(int n, int seed, IReadOnlyList<DoorSide> doors, int turns)
        {
            N = n; Turns = turns; _doors = doors;
            Layout = new MapLayout { Seed = seed, Name = "Ward station", BorderWidth = 1 };
            Layout.Initialize(n, n);
            for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++) Set(x, y, x == 0 || y == 0 || x == n - 1 || y == n - 1 ? TileRole.Wall : TileRole.Ground, x == 0 || y == 0 || x == n - 1 || y == n - 1 ? 4 : 0);
            for (int y = Mid - 1; y <= Mid + 2; y++)
                for (int x = Mid - 1; x <= Mid + 2; x++) _protected.Add((x, y));
            foreach (var side in doors)
            {
                foreach (var tile in RoomGeneration.Threshold(n, side)) Set(tile.x, tile.y, TileRole.Wall, 0);
                for (int depth = 1; depth <= 3; depth++)
                    for (int across = Mid - 1; across <= Mid + 1; across++)
                        _protected.Add(side switch { DoorSide.North => (across, depth), DoorSide.South => (across, n - 1 - depth), DoorSide.West => (depth, across), _ => (n - 1 - depth, across) });
            }
        }
        private void Set(int x, int y, TileRole tile, int height)
        {
            Layout.SetTile(x, y, tile); Layout.SetSurface(x, y, SurfaceType.Stone);
            Layout.SetCornerHeights(x, y, TileCornerHeights.Flat(height)); Layout.SetElevation(x, y, height / 4);
        }
        public (int X, int Y, int W, int H) Rect(int x, int y, int w, int h)
        {
            for (int i = 0; i < Turns; i++) (x, y, w, h) = (N - y - h, x, h, w);
            return (x, y, w, h);
        }
        public bool Place(string kind, int x, int y, int w, int h, float height = 1, bool solid = true)
        {
            if (w < 1 || h < 1) return false;
            var r = Rect(x, y, w, h);
            for (int yy = r.Y; yy < r.Y + r.H; yy++)
                for (int xx = r.X; xx < r.X + r.W; xx++)
                    if (xx < 1 || yy < 1 || xx >= N - 1 || yy >= N - 1 || Layout.GetTile(xx, yy) != TileRole.Ground || solid && _protected.Contains((xx, yy))) return false;
            if (solid)
            {
                for (int yy = r.Y; yy < r.Y + r.H; yy++)
                    for (int xx = r.X; xx < r.X + r.W; xx++) Layout.SetTile(xx, yy, TileRole.Wall);
                if (!RoomGeneration.Validate(Result()))
                {
                    for (int yy = r.Y; yy < r.Y + r.H; yy++)
                        for (int xx = r.X; xx < r.X + r.W; xx++) Layout.SetTile(xx, yy, TileRole.Ground);
                    return false;
                }
            }
            Props.Add(new(kind, r.X + r.W / 2f, r.Y + r.H / 2f, w - 0.12f, h - 0.12f, height, Turns * 90));
            return true;
        }
        public bool Main(string kind, int x, int y, int w, int h, float height = 1)
        {
            if (Place(kind, x, y, w, h, height)) return true;
            foreach (var (cx, cy) in new[] { (1,1), (N-w-1,1), (1,N-h-1), (N-w-1,N-h-1) })
                if (Place(kind, cx, cy, w, h, height)) return true;
            return Place(kind, 1, 1, 2, 2, height);
        }
        public void Surface(int x, int y, int w, int h, SurfaceType surface)
        {
            var r = Rect(x, y, w, h);
            for (int yy = r.Y; yy < r.Y + r.H; yy++)
                for (int xx = r.X; xx < r.X + r.W; xx++)
                    if (xx > 0 && yy > 0 && xx < N - 1 && yy < N - 1 && Layout.GetTile(xx, yy) == TileRole.Ground) Layout.SetSurface(xx, yy, surface);
        }
        public void Reservoir(int x, int y, int w, int h)
        {
            var r = Rect(x, y, w, h);
            for (int yy = r.Y; yy < r.Y + r.H; yy++)
                for (int xx = r.X; xx < r.X + r.W; xx++)
                {
                    if (_protected.Contains((xx, yy))) { Layout.SetSurface(xx, yy, SurfaceType.Wood); continue; }
                    Layout.SetTile(xx, yy, TileRole.Water); Layout.SetSurface(xx, yy, SurfaceType.Water);
                }
            for (int yy = r.Y; yy < r.Y + r.H; yy++)
                for (int xx = r.X; xx < r.X + r.W; xx++)
                    if (Layout.GetTile(xx, yy) == TileRole.Water)
                        foreach (var (dx, dy) in new[] { (1, 0), (-1, 0), (0, 1), (0, -1) })
                            if (Layout.GetTile(xx + dx, yy + dy) != TileRole.Water)
                                Props.Add(new("water_rim", xx + 0.5f + dx * 0.46f, yy + 0.5f + dy * 0.46f, 0.92f, 0.08f, 0.18f, dx == 0 ? 0 : 90));
        }
        public GeneratedRoom Result()
        {
            Layout.DeploymentZones = RoomGeneration.Zones(N, DoorSide.West);
            return new(Layout, Props, _doors.ToArray());
        }
    }
}
