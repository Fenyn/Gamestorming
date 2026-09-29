using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Delve.Dungeon;

/// <summary>A forest room: a generated forest board framed by a ring of trees, with a trail mouth
/// on every door side. Obeys the station room contract, so travel, zones and hosted fights read it
/// the same way: border ring is Wall, the 3 threshold tiles are Wall at ground level, and every
/// <see cref="RoomGeneration.Inside"/> tile reaches the centre.</summary>
public static partial class GladeGeneration
{
    public const string Biome = "forest";

    /// <summary>Largest elevation change a traveller takes in one step. Matches the forest biome's
    /// cliff threshold: two elevations or more is a cliff.</summary>
    public const int MaxStep = 1;

    /// <summary>Tiles inside a trail mouth kept at ground level before the land may rise.</summary>
    private const int MouthFlat = 2;

    private const int Attempts = 5;

    /// <summary>Share of the interior that must stay walkable, or the glade reads as a thicket.</summary>
    private const float MinOpenShare = 0.55f;

    private const int Units = TileCornerHeights.UnitsPerElevation;

    public static GeneratedRoom Generate(int seed, int interior, IReadOnlyList<DoorSide> doors)
    {
        if (interior < 8 || interior > 20 || interior % 2 != 0)
            throw new ArgumentOutOfRangeException(nameof(interior), "Glade interiors must be even sizes from 8 through 20.");
        MapLayout? layout = null;
        for (int attempt = 0; attempt < Attempts; attempt++)
        {
            layout = Frame(seed, attempt, interior, doors);
            if (Reached(layout, doors, out _)) break;
            if (attempt == Attempts - 1) Carve(layout, doors);
        }
        Seal(layout!, doors);
        layout!.DeploymentZones = RoomGeneration.Zones(layout.Width, DoorSide.West);
        return new GeneratedRoom(layout, Array.Empty<RoomProp>(), doors.ToArray());
    }

    /// <summary>One forest board copied inside a tree ring and shaped so every mouth meets its trail
    /// at ground level.</summary>
    private static MapLayout Frame(int seed, int attempt, int interior, IReadOnlyList<DoorSide> doors)
    {
        var parameters = MapGenRegistry.GetBiome(Biome).DefaultParams.WithSize(interior, interior);
        var board = MapGenerator.GenerateValidated(Biome, RunRng.StableSeed(seed, attempt, "glade"), parameters);
        int n = interior + 2;
        var layout = new MapLayout { Seed = board.Seed, Name = $"glade_{seed}", BorderWidth = 1 };
        layout.Initialize(n, n);
        int floor = int.MaxValue;
        for (int y = 0; y < interior; y++)
            for (int x = 0; x < interior; x++)
                floor = Math.Min(floor, board.GetElevation(x, y));
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                if (x == 0 || y == 0 || x == n - 1 || y == n - 1)
                {
                    SetFlat(layout, x, y, TileRole.Wall, SurfaceType.Dirt, 0);
                    continue;
                }
                CopyTile(board, layout, x - 1, y - 1, x, y, floor);
            }
        foreach (var side in doors)
            foreach (var p in RoomGeneration.Threshold(n, side))
                SetFlat(layout, p.x, p.y, TileRole.Wall, SurfaceType.Dirt, 0);
        CapRelief(layout, doors);
        ClearZones(layout);
        NaturalRelief.Refine(layout);
        return layout;
    }

    internal static void CopyTile(MapLayout from, MapLayout to, int fx, int fy, int x, int y, int floor)
    {
        to.SetTile(x, y, from.GetTile(fx, fy));
        to.SetSurface(x, y, from.GetSurface(fx, fy));
        to.SetElevation(x, y, from.GetElevation(fx, fy) - floor);
        to.SetSlope(x, y, from.GetSlopeType(fx, fy), from.GetSlopeHeight(fx, fy));
        var c = from.GetCornerHeights(fx, fy);
        int drop = floor * Units;
        to.SetCornerHeights(x, y, new TileCornerHeights { NW = c.NW - drop, NE = c.NE - drop, SE = c.SE - drop, SW = c.SW - drop });
        to.SetFeatureLabel(x, y, from.GetFeatureLabel(fx, fy));
        to.SetPlantTerrain(x, y, from.GetPlantTerrain(fx, fy));
        to.SetTerrainDifficulty(x, y, from.GetTerrainDifficulty(fx, fy));
        to.SetBalanceDC(x, y, from.GetBalanceDC(fx, fy));
    }

    /// <summary>Land rises one elevation per tile from the tree ring, and stays at ground level for
    /// <see cref="MouthFlat"/> tiles inside each mouth, so no trail ends at a cliff.</summary>
    private static void CapRelief(MapLayout layout, IReadOnlyList<DoorSide> doors)
    {
        int n = layout.Width;
        var mouths = doors.Select(side => RoomGeneration.Threshold(n, side).ToArray()).ToArray();
        for (int y = 1; y < n - 1; y++)
            for (int x = 1; x < n - 1; x++)
            {
                int edge = Math.Min(Math.Min(x, y), Math.Min(n - 1 - x, n - 1 - y));
                int cap = edge;
                foreach (var mouth in mouths)
                {
                    int d = mouth.Min(p => Math.Abs(p.x - x) + Math.Abs(p.y - y));
                    cap = Math.Min(cap, Math.Max(0, d - MouthFlat));
                }
                if (layout.GetElevation(x, y) <= cap) continue;
                var role = layout.GetTile(x, y);
                SetFlat(layout, x, y, role == TileRole.Water ? TileRole.Ground : role, layout.GetSurface(x, y), cap);
            }
    }

    /// <summary>Both teams' deployment boxes for every entry side stand on open ground.</summary>
    private static void ClearZones(MapLayout layout)
    {
        foreach (var p in ZoneTiles(layout.Width))
            if (layout.GetTile(p.x, p.y) is not (TileRole.Ground or TileRole.DifficultTerrain))
                SetFlat(layout, p.x, p.y, TileRole.Ground, SurfaceType.Grass, layout.GetElevation(p.x, p.y));
    }

    internal static void SetFlat(MapLayout layout, int x, int y, TileRole role, SurfaceType surface, int elevation)
    {
        layout.SetTile(x, y, role);
        layout.SetSurface(x, y, surface);
        layout.SetElevation(x, y, elevation);
        layout.SetSlope(x, y, SlopeType.Flat, 0);
        layout.SetCornerHeights(x, y, TileCornerHeights.Flat(elevation * Units));
        layout.SetFeatureLabel(x, y, null);
    }
}
