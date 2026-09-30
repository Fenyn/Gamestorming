using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dungeon;
/// <summary>A dressing piece in room tiles. <paramref name="Raised"/> seats it on the ground under its
/// centre tile, for rooms whose floor is not level.</summary>
public sealed record RoomProp(string Kind, float X, float Y, float Width, float Depth, float Height, float Angle = 0, bool Raised = false);
/// <summary>The entrance's outer mouth: the side the party arrives through from off the floor, the prop
/// that shows where from, and how far out (tiles) that prop reaches.</summary>
public sealed record RoomArrival(DoorSide Side, string Prop, float Reach);
public sealed record GeneratedRoom(MapLayout Layout, IReadOnlyList<RoomProp> Props, IReadOnlyList<DoorSide> Doors, int ZoneHalf = RoomGeneration.ZoneHalf);
public sealed record RoomVariation(int MinPillarInset = 3, int MaxPillarInset = 4, int MinCover = 2, int MaxCover = 4, int DebrisCount = 8, int FeatureCount = 4, int LayoutVariant = -1, bool StationRooms = true);
/// <summary>Pure generation used by the prefab owning this profile. Cosmetic RNG cannot alter geometry.</summary>
public static partial class RoomGeneration
{
    public static GeneratedRoom Generate(RoomFamily family, int seed, int interior, IReadOnlyList<DoorSide> doors, bool openLayout = false, RoomVariation? variation = null, RoomPurpose? purpose = null, StationHistory history = StationHistory.Evacuated)
    {
        var profile = variation ?? new RoomVariation();
        if (interior < 8 || interior > 20 || interior % 2 != 0)
            throw new ArgumentOutOfRangeException(nameof(interior), "Room interiors must be even sizes from 8 through 20.");
        if (profile.MinPillarInset < 2 || profile.MaxPillarInset < profile.MinPillarInset || profile.MinCover < 0 || profile.MaxCover < profile.MinCover || profile.MaxCover > 20 || profile.DebrisCount < 0 || profile.DebrisCount > 100 || profile.FeatureCount < 0 || profile.FeatureCount > 12 || profile.LayoutVariant < -1 || profile.LayoutVariant > 2)
            throw new ArgumentException("Invalid room variation profile.");
        if (profile.StationRooms && !openLayout)
            return StationRooms.Generate(purpose ?? StationPlan.Default(family), seed, interior, doors, profile, history);
        if (openLayout)
            return Build(family, seed, interior, doors, 0, true, profile);
        for (int attempt = 0; attempt < 8; attempt++)
        {
            var result = Build(family, seed, interior, doors, attempt, false, profile);
            if (Validate(result))
                return result;
        }

        var fallback = Build(family, seed, interior, doors, 8, true, profile);
        if (!Validate(fallback))
            throw new InvalidOperationException("Room baseline is invalid.");
        return fallback;
    }

    private static GeneratedRoom Build(RoomFamily family, int seed, int interior, IReadOnlyList<DoorSide> doors, int attempt, bool baseline, RoomVariation profile)
    {
        int n = interior + 2, mid = n / 2;
        var layout = new MapLayout
        {
            Seed = seed,
            Name = $"{family}_{seed}",
            BorderWidth = 1
        };
        layout.Initialize(n, n);
        var rng = new Random(RunRng.StableSeed(seed, attempt, "room-structure"));
        var dress = new Random(RunRng.StableSeed(seed, 0, "room-dressing"));
        var props = new List<RoomProp>();
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                bool border = x == 0 || y == 0 || x == n - 1 || y == n - 1;
                Set(layout, x, y, border ? TileRole.Wall : TileRole.Ground, border ? 4 : 0);
            }

        // Door thresholds remain tactical walls. The scene renders them as floor under closed doors.
        foreach (var side in doors)
            foreach (var p in Threshold(n, side))
                Set(layout, p.x, p.y, TileRole.Wall, 0);
        bool combat = DungeonFloor.Kind(family)is NodeKind.Combat or NodeKind.Elite or NodeKind.Boss;
        if (combat && !baseline)
        {
            AddCombatLayout(layout, props, family, rng, profile, seed);
        }

        // Focal scenery occupies gameplay wall tiles, outside the central travel cross.
        if (!combat)
        {
            int fx = rng.Next(2) == 0 ? 2 : n - 3;
            int fy = rng.Next(2) == 0 ? 2 : n - 3;
            for (int y = fy; y < fy + 2; y++)
                for (int x = fx; x < fx + 2; x++)
                    Set(layout, x, y, TileRole.Wall, 0);
            string focal = family switch
            {
                RoomFamily.Shrine => "shrine",
                RoomFamily.Cache => "cache",
                RoomFamily.Collapse => "collapse",
                RoomFamily.Entrance => "entrance",
                _ => "camp"
            };
            float facing = Math.Abs(mid - fx - 1) > Math.Abs(mid - fy - 1)
                ? (fx + 1 < mid ? 90 : -90) : (fy + 1 < mid ? 0 : 180);
            props.Add(new(focal, fx + 1, fy + 1, 2, 2, 1.1f, facing));
            if (family == RoomFamily.Shrine)
                props.Add(new("sigil", mid + 0.5f, mid + 0.5f, 3, 3, 0.015f, dress.Next(4) * 90));
            if (family == RoomFamily.Entrance)
                props.Add(new("inscription", fx + 1, fy - 0.5f, 1.2f, 0.1f, 0.4f));
        }

        if (family == RoomFamily.Guardian)
        {
            for (int y = 2; y < 4; y++)
                for (int x = 2; x < 4; x++)
                    Set(layout, x, y, TileRole.Wall, 0);
            props.Add(new("stairs", 3, 3, 2, 2, 1));
        }

        AddFeatures(layout, props, family, seed, baseline, profile.FeatureCount);

        for (int i = 0; i < profile.DebrisCount; i++)
        {
            float x = 1.2f + (float)dress.NextDouble() * (n - 2.4f);
            float y = i % 2 == 0 ? 1.3f : n - 1.3f;
            if (Math.Abs(x - mid) < 2.5f)
                continue;
            props.Add(new("debris", x, y, 0.18f + (float)dress.NextDouble() * 0.2f, 0.25f, 0.12f, dress.Next(360)));
        }

        foreach (var x in new[]
        {
            2f,
            n - 2f
        }

        )
            props.Add(new("torch", x, 1.1f, 0.15f, 0.15f, 1.6f));
        layout.DeploymentZones = Zones(n, DoorSide.West);
        return new GeneratedRoom(layout, props, doors.ToArray());
    }

    private static void Set(MapLayout l, int x, int y, TileRole role, int height)
    {
        l.SetTile(x, y, role);
        l.SetSurface(x, y, SurfaceType.Stone);
        l.SetCornerHeights(x, y, TileCornerHeights.Flat(height));
        l.SetElevation(x, y, height / TileCornerHeights.UnitsPerElevation);
    }

    /// <summary>Tiles across every doorway and trail mouth.</summary>
    public const int DoorWidth = 3;

    public static IEnumerable<Vector2Int> Threshold(int n, DoorSide side)
    {
        for (int i = n / 2 - DoorWidth / 2; i <= n / 2 + DoorWidth / 2; i++)
            yield return side switch
            {
                DoorSide.North => new(i, 0),
                DoorSide.South => new(i, n - 1),
                DoorSide.West => new(0, i),
                _ => new(n - 1, i)};
    }

    public static Vector2Int Inside(int n, DoorSide side) => side switch
    {
        DoorSide.North => new(n / 2, 2),
        DoorSide.South => new(n / 2, n - 3),
        DoorSide.West => new(2, n / 2),
        _ => new(n - 3, n / 2)};
    /// <summary>Tiles from the room centre to the middle of each deployment box: the two front
    /// rows stand 2 x (half - 1) tiles apart.</summary>
    public const int ZoneHalf = 4;

    public static DeploymentZoneData[] Zones(int n, DoorSide entry, int half = ZoneHalf)
    {
        // Keep initial engagement distance near current compact battles even in a wider chamber.
        int near = Math.Max(2, n / 2 - half), far = Math.Min(n - 3, n / 2 + half);
        DeploymentZoneData Zone(DoorSide side, int team) => side switch
        {
            DoorSide.North => new()
            {
                TeamId = team,
                CornerA = new(n / 2 - 2, near - 1),
                CornerB = new(n / 2 + 2, near + 1)
            },
            DoorSide.South => new()
            {
                TeamId = team,
                CornerA = new(n / 2 - 2, far - 1),
                CornerB = new(n / 2 + 2, far + 1)
            },
            DoorSide.West => new()
            {
                TeamId = team,
                CornerA = new(near - 1, n / 2 - 2),
                CornerB = new(near + 1, n / 2 + 2)
            },
            _ => new()
            {
                TeamId = team,
                CornerA = new(far - 1, n / 2 - 2),
                CornerB = new(far + 1, n / 2 + 2)
            }
        };
        return new[]
        {
            Zone(entry, 0),
            Zone((DoorSide)(((int)entry + 2) % 4), 1)
        };
    }

}
