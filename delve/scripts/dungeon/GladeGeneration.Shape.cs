using System;
using System.Collections.Generic;
using System.Linq;
using PF2e;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Delve.Dungeon;

public static partial class GladeGeneration
{
    /// <summary>Tree clumps a fight glade gains, and trunks per clump.</summary>
    private const int MinClumps = 2, MaxClumps = 4, MinTrunks = 1, MaxTrunks = 3;

    /// <summary>Tiles from the tree ring a clump or rock keeps, so it stands in the open glade.</summary>
    private const int RingClear = 2;

    /// <summary>How strongly a clump prefers the middle of its quarter over a random open tile.</summary>
    private const int QuarterPull = 3;

    /// <summary>Landmark kind for a broad tree standing on a 2x2 block.</summary>
    public const string BigTree = "big_tree";

    /// <summary>Tiles off the centre, on both axes, of the gaps between the deployment boxes.</summary>
    private const int Between = 2;

    /// <summary>Rocks placed in those gaps before the rest go near the boxes.</summary>
    private const int ForwardCover = 2;

    /// <summary>One clump in this many is a broad tree after the first.</summary>
    private const int BigTreeOdds = 2;

    /// <summary>Waist-high rocks a fight glade gains, each within <see cref="CoverReach"/> tiles
    /// of a deployment box.</summary>
    private const int MinCover = 3, MaxCover = 6, CoverReach = 2;

    /// <summary>Tiles around a mouth kept free of clumps, so the trail stays open.</summary>
    private const int MouthClear = 2;

    /// <summary>The tiles a traveller crosses between a mouth and its <see cref="RoomGeneration.Inside"/>
    /// tile are open ground at the trail's level.</summary>
    private static void OpenMouths(MapLayout layout, IReadOnlyList<DoorSide> doors)
    {
        foreach (var p in MouthTiles(layout.Width, doors))
            if (layout.GetTile(p.x, p.y) is not (TileRole.Ground or TileRole.DifficultTerrain) || layout.GetElevation(p.x, p.y) != 0)
                SetFlat(layout, p.x, p.y, TileRole.Ground, SurfaceType.Dirt, 0);
    }

    /// <summary>The three-wide strip inside each mouth, <see cref="MouthFlat"/> tiles deep.</summary>
    internal static IEnumerable<Vector2Int> MouthTiles(int n, IReadOnlyList<DoorSide> doors)
    {
        foreach (var side in doors)
            foreach (var p in RoomGeneration.Threshold(n, side))
                for (int depth = 1; depth <= MouthFlat; depth++)
                    yield return side switch
                    {
                        DoorSide.North => new Vector2Int(p.x, p.y + depth),
                        DoorSide.South => new Vector2Int(p.x, p.y - depth),
                        DoorSide.West => new Vector2Int(p.x + depth, p.y),
                        _ => new Vector2Int(p.x - depth, p.y)
                    };
    }

    /// <summary>Both teams' deployment boxes on every axis a door opens on.</summary>
    internal static IEnumerable<Vector2Int> ZoneTiles(int n, IReadOnlyList<DoorSide> doors, int half)
    {
        var entries = doors.Select(side => side is DoorSide.East or DoorSide.West ? DoorSide.West : DoorSide.North).Distinct();
        foreach (var zone in entries.SelectMany(entry => RoomGeneration.Zones(n, entry, half)))
            for (int y = Math.Min(zone.CornerA.y, zone.CornerB.y); y <= Math.Max(zone.CornerA.y, zone.CornerB.y); y++)
                for (int x = Math.Min(zone.CornerA.x, zone.CornerB.x); x <= Math.Max(zone.CornerA.x, zone.CornerB.x); x++)
                    yield return new Vector2Int(x, y);
    }

    private static void ClearZones(MapLayout layout, IReadOnlyList<DoorSide> doors, int half)
    {
        foreach (var p in ZoneTiles(layout.Width, doors, half))
            if (layout.GetTile(p.x, p.y) is not (TileRole.Ground or TileRole.DifficultTerrain))
                SetFlat(layout, p.x, p.y, TileRole.Ground, SurfaceType.Grass, layout.GetElevation(p.x, p.y));
    }

    /// <summary>Give a fight glade trunks that block sight and rocks to crouch behind, and return its
    /// broad trees as 2x2 landmarks the shell draws. Both stay off
    /// the three-wide lanes between the boxes and off the mouths, so every box keeps a clear line to
    /// the other and the party can always walk in.</summary>
    private static List<RoomProp> Dress(MapLayout layout, IReadOnlyList<DoorSide> doors, int half, Random rng)
    {
        int n = layout.Width, mid = n / 2;
        var zones = ZoneTiles(n, doors, half).ToHashSet();
        var mouths = MouthTiles(n, doors).ToArray();
        bool Lane(Vector2Int p) => Math.Abs(p.x - mid) <= 1 || Math.Abs(p.y - mid) <= 1;
        bool Free(Vector2Int p) => p.x >= RingClear && p.y >= RingClear && p.x < n - RingClear && p.y < n - RingClear && !Lane(p) && !zones.Contains(p)
            && layout.GetTile(p.x, p.y) == TileRole.Ground
            && mouths.All(m => Math.Abs(m.x - p.x) + Math.Abs(m.y - p.y) > MouthClear);
        int Near(Vector2Int p) => zones.Count == 0 ? int.MaxValue : zones.Min(z => Math.Max(Math.Abs(z.x - p.x), Math.Abs(z.y - p.y)));

        var open = Enumerable.Range(0, n * n).Select(i => new Vector2Int(i % n, i / n)).Where(Free).ToList();
        // The gaps diagonal to the centre lie between the two boxes on either axis: rocks there are
        // cover on the way in, not behind the party.
        var between = new[] { new Vector2Int(mid - Between, mid - Between), new Vector2Int(mid + Between, mid - Between), new Vector2Int(mid - Between, mid + Between), new Vector2Int(mid + Between, mid + Between) };
        var forward = between.Where(p => open.Contains(p)).OrderBy(_ => rng.Next()).Take(ForwardCover);
        var cover = forward.Concat(open.Where(p => Near(p) <= CoverReach).OrderBy(_ => rng.Next()))
            .Distinct().Take(rng.Next(MinCover, MaxCover + 1)).ToList();
        foreach (var p in cover)
        {
            SetFlat(layout, p.x, p.y, TileRole.Cover, SurfaceType.Stone, layout.GetElevation(p.x, p.y));
            layout.SetCornerHeights(p.x, p.y, TileCornerHeights.Flat(layout.GetElevation(p.x, p.y) * Units + MapGenRegistry.GetBiome(Biome).CoverHeight));
        }
        // Clumps stand in the same gaps between the boxes, where they split the approach, not
        // against the ring, where they read as more of it.
        int quarter = Between;
        int FromQuarter(Vector2Int p) => Math.Abs(Math.Abs(p.x - mid) - quarter) + Math.Abs(Math.Abs(p.y - mid) - quarter);
        var trunkSites = open.Where(p => !cover.Contains(p) && Near(p) > 1)
            .Select(p => (Site: p, Rank: FromQuarter(p) * QuarterPull + rng.Next(QuarterPull))).OrderBy(s => s.Rank).Select(s => s.Site).ToList();
        int clumps = rng.Next(MinClumps, MaxClumps + 1);
        var bigTrees = new List<RoomProp>();
        // A broad tree fills a 2x2 block like a Large creature. Every fight glade gets the first
        // block that fits; later clumps are broad trees one time in BigTreeOdds.
        Vector2Int[] Block(Vector2Int corner) => new[] { corner, new(corner.x + 1, corner.y), new(corner.x, corner.y + 1), new(corner.x + 1, corner.y + 1) };
        bool Fits(Vector2Int corner) => Block(corner).All(p => Free(p) && Near(p) > 1 && layout.GetElevation(p.x, p.y) == layout.GetElevation(corner.x, corner.y));
        void Plant(Vector2Int corner)
        {
            foreach (var p in Block(corner)) SetFlat(layout, p.x, p.y, TileRole.Wall, SurfaceType.Dirt, layout.GetElevation(corner.x, corner.y));
            bigTrees.Add(new RoomProp(BigTree, corner.x + 1, corner.y + 1, 2, 2, 0, 0, Raised: true));
        }
        var first = trunkSites.FirstOrDefault(Fits, new Vector2Int(-1, -1));
        if (first.x >= 0)
        {
            Plant(first);
            clumps--;
        }
        foreach (var seed in trunkSites)
        {
            if (clumps == 0) break;
            if (layout.GetTile(seed.x, seed.y) != TileRole.Ground) continue;
            clumps--;
            if (rng.Next(BigTreeOdds) == 0 && Fits(seed))
            {
                Plant(seed);
                continue;
            }
            var trunk = seed;
            for (int i = rng.Next(MinTrunks, MaxTrunks + 1); i > 0; i--)
            {
                SetFlat(layout, trunk.x, trunk.y, TileRole.Wall, SurfaceType.Dirt, layout.GetElevation(trunk.x, trunk.y));
                var next = Steps.Select(d => new Vector2Int(trunk.x + d.x, trunk.y + d.y)).Where(p => Free(p) && Near(p) > 1).ToArray();
                if (next.Length == 0) break;
                trunk = next[rng.Next(next.Length)];
            }
        }
        return bigTrees;
    }
}
