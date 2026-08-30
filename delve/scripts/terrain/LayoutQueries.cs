using System;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Layout reads for the terrain passes: neighbour stepping, edge-corner lookups and the derived
/// heights (bridge floor, spanned water) the passes need. Nothing here writes mesh geometry.
/// </summary>
internal static class LayoutQueries
{
    internal static readonly CardinalDirection[] Cardinals =
    {
        CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West,
    };

    internal static (int x, int y) Step(int x, int y, CardinalDirection dir) => dir switch
    {
        CardinalDirection.North => (x, y + 1),
        CardinalDirection.South => (x, y - 1),
        CardinalDirection.East => (x + 1, y),
        CardinalDirection.West => (x - 1, y),
        _ => (x, y),
    };

    internal static CardinalDirection Opposite(CardinalDirection dir) => dir switch
    {
        CardinalDirection.North => CardinalDirection.South,
        CardinalDirection.South => CardinalDirection.North,
        CardinalDirection.East => CardinalDirection.West,
        CardinalDirection.West => CardinalDirection.East,
        _ => dir,
    };

    /// <summary>True when a ground-ish tile sits on either edge perpendicular to <paramref name="dir"/>.</summary>
    internal static bool HasPerpendicularGround(MapLayout layout, int x, int y, CardinalDirection dir)
    {
        (CardinalDirection a, CardinalDirection b) =
            dir is CardinalDirection.North or CardinalDirection.South
                ? (CardinalDirection.East, CardinalDirection.West)
                : (CardinalDirection.North, CardinalDirection.South);

        return IsGroundish(layout, Step(x, y, a)) || IsGroundish(layout, Step(x, y, b));
    }

    internal static bool IsGroundish(MapLayout layout, (int x, int y) tile) =>
        layout.IsInBounds(tile.x, tile.y)
        && layout.GetTile(tile.x, tile.y)
            is TileRole.Ground or TileRole.DifficultTerrain or TileRole.Cover;

    /// <summary>
    /// Heights of the neighbouring tile's corners on the shared edge, in the same A/B order this
    /// tile reads the edge. The shared edge is traversed the other way round from the neighbour's
    /// side, so the pair comes back swapped. A bridge neighbour reports its FLOOR, not its deck: the
    /// approach tile then cuts a cliff face through the whole under-span gap. The caller must know
    /// the neighbour is in bounds and not Empty.
    /// </summary>
    internal static (int a, int b) NeighborEdgeHeights(
        MapLayout layout, int x, int y, CardinalDirection dir)
    {
        (int nx, int ny) = Step(x, y, dir);
        if (layout.GetTile(nx, ny) == TileRole.Bridge)
        {
            int bridgeFloor = FindBridgeFloorHeight(layout, nx, ny);
            return (bridgeFloor, bridgeFloor);
        }

        (int nA, int nB) = layout.GetCornerHeights(nx, ny).EdgeCorners(Opposite(dir));
        return (nB, nA);
    }

    /// <summary>World corners of a wall face on a tile edge. No centering offset: tile (0,0) starts at the origin.</summary>
    internal static (Vector3 topLeft, Vector3 topRight, Vector3 bottomLeft, Vector3 bottomRight)
        GetEdgeWorldPositions(int x, int y, CardinalDirection dir,
            int topA, int topB, int bottomA, int bottomB, float hs)
    {
        float wx = x;
        float wz = y;

        return dir switch
        {
            CardinalDirection.North => (
                new Vector3(wx, topA * hs, wz + 1),
                new Vector3(wx + 1, topB * hs, wz + 1),
                new Vector3(wx, bottomA * hs, wz + 1),
                new Vector3(wx + 1, bottomB * hs, wz + 1)),
            CardinalDirection.South => (
                new Vector3(wx + 1, topA * hs, wz),
                new Vector3(wx, topB * hs, wz),
                new Vector3(wx + 1, bottomA * hs, wz),
                new Vector3(wx, bottomB * hs, wz)),
            CardinalDirection.East => (
                new Vector3(wx + 1, topA * hs, wz + 1),
                new Vector3(wx + 1, topB * hs, wz),
                new Vector3(wx + 1, bottomA * hs, wz + 1),
                new Vector3(wx + 1, bottomB * hs, wz)),
            CardinalDirection.West => (
                new Vector3(wx, topA * hs, wz),
                new Vector3(wx, topB * hs, wz + 1),
                new Vector3(wx, bottomA * hs, wz),
                new Vector3(wx, bottomB * hs, wz + 1)),
            _ => (Vector3.Zero, Vector3.Zero, Vector3.Zero, Vector3.Zero),
        };
    }

    /// <summary>
    /// Height beneath a bridge tile: the lowest relevant cardinal neighbour, or the canyon floor when
    /// the span crosses void. In corner-height units. Sizes both the pillars and the cliff faces of the
    /// tiles that approach the span.
    ///
    /// "Crosses void" means the same thing here as in <see cref="IsBridgeOverVoid"/> — an Empty tile ON
    /// the map. Off-map neighbours are skipped: the floor this returns has to meet the fill
    /// <see cref="BridgePass.RenderBridge"/> draws under the same deck, and that fill is the canyon floor
    /// only when the neighbouring void tiles render one at
    /// <see cref="TerrainMeshBuilder.VoidFloorCornerHeight"/> to match. Nothing is rendered past the
    /// boundary, so an off-map neighbour contributes no floor to reach for. (Unity tested bounds in one
    /// method and not the other; taken literally that gives a map-edge bridge over WATER a floor of -40,
    /// which <see cref="CliffPass.AddEdgeWall"/> then drops another
    /// <see cref="TerrainMeshBuilder.WaterWallDepth"/> below the deepest surface in the world.)
    /// </summary>
    internal static int FindBridgeFloorHeight(MapLayout layout, int x, int y)
    {
        var bridgeCorners = layout.GetCornerHeights(x, y);
        int slabBottom = TerrainGeometry.RoundToInt(bridgeCorners.CenterHeight)
            - TerrainMeshBuilder.BridgeSlabThickness;

        bool overVoid = false;
        int lowestNeighbor = slabBottom;

        foreach (var dir in Cardinals)
        {
            (int nx, int ny) = Step(x, y, dir);
            if (!layout.IsInBounds(nx, ny)) continue;

            var role = layout.GetTile(nx, ny);
            if (role == TileRole.Empty)
            {
                overVoid = true;
                continue;
            }

            if (role == TileRole.Bridge) continue;

            int neighborMin = layout.GetCornerHeights(nx, ny).MinHeight;
            if (neighborMin < lowestNeighbor) lowestNeighbor = neighborMin;
        }

        return overVoid
            ? Math.Min(lowestNeighbor, TerrainMeshBuilder.VoidFloorCornerHeight)
            : lowestNeighbor;
    }

    /// <summary>
    /// Corner height of the water a bridge spans, for the fill drawn under its slab. Searches outward
    /// on each cardinal, crossing further bridge tiles, because a mid-span tile can be several tiles
    /// from the nearest open water. Falls back to four units below the deck.
    /// </summary>
    internal static int FindAdjacentWaterCornerHeight(MapLayout layout, int x, int y)
    {
        int bridgeH = TerrainGeometry.RoundToInt(layout.GetCornerHeights(x, y).CenterHeight);
        int fallback = Math.Max(0, bridgeH - 4);

        foreach (var dir in Cardinals)
        {
            (int nx, int ny) = Step(x, y, dir);
            for (int step = 0; step < 8; step++)
            {
                if (!layout.IsInBounds(nx, ny)) break;
                var role = layout.GetTile(nx, ny);
                if (role == TileRole.Water)
                    return TerrainGeometry.RoundToInt(layout.GetCornerHeights(nx, ny).CenterHeight);
                if (role != TileRole.Bridge) break;
                (nx, ny) = Step(nx, ny, dir);
            }
        }

        return fallback;
    }

    /// <summary>
    /// True when any cardinal neighbour of (x, y) is an Empty tile. Off-map neighbours do not count:
    /// the caller uses this to decide whether the span's under-deck fill continues the canyon floor the
    /// neighbouring void tiles render, and no tile renders one past the boundary.
    /// <see cref="FindBridgeFloorHeight"/> follows the same rule.
    /// </summary>
    internal static bool IsBridgeOverVoid(MapLayout layout, int x, int y)
    {
        foreach (var dir in Cardinals)
        {
            (int nx, int ny) = Step(x, y, dir);
            if (!layout.IsInBounds(nx, ny)) continue;
            if (layout.GetTile(nx, ny) == TileRole.Empty) return true;
        }
        return false;
    }
}
