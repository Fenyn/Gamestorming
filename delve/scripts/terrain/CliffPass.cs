using System;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// The four cardinal edges of a solid tile: the cliff wall where the tile stands above its neighbour,
/// the mortar bands that overlay that wall, and the lip strip that marks its top edge.
///
/// One predicate — <see cref="TryEdgeDrop"/> — decides whether an edge has a cliff and how deep it
/// runs. Wall, bands and lip strip all read it, so the three can never disagree about what is a cliff
/// (they used to: the strip counted a void neighbour as height 0 and the wall dropped it to the
/// canyon floor).
/// </summary>
internal static class CliffPass
{
    /// <summary>Lift of cliff-lip edge strips above the top face. Slightly above the grid lines.</summary>
    private const float EdgeStripYOffset = 0.005f;

    /// <summary>Push of cliff bands along the wall normal, away from the face they overlay.</summary>
    private const float CliffBandOffset = 0.003f;

    /// <summary>
    /// The cliff on one tile edge: the two bottom corner heights of its wall, in the same A/B order
    /// <c>TileCornerHeights.EdgeCorners</c> reads the edge, plus what kind of neighbour set them.
    /// </summary>
    internal readonly record struct EdgeDrop(
        int BottomA, int BottomB, bool NeighborIsVoid, bool NeighborIsWater);

    /// <summary>Walls, bands and lip strips on all four edges of one solid tile.</summary>
    internal static void Render(
        TerrainBuildContext ctx, int x, int y, TileCornerHeights corners, SurfaceType surface,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW)
    {
        var theme = ctx.Theme;
        bool cliffBands = theme.EnableCliffBands && theme.CliffBandThickness > 0f;
        bool edgeStrips = theme.EnableCliffEdgeStrips && theme.CliffEdgeStripWidth > 0f;

        var wallBuffer = ctx.Palette.Wall(surface);
        var bandBuffer = cliffBands ? ctx.Palette.Overlay(FaceKind.CliffBand) : null;

        // Indexed by (int)CardinalDirection — North 0, East 1, South 2, West 3.
        Span<bool> hasCliff = stackalloc bool[4];
        foreach (var dir in LayoutQueries.Cardinals)
        {
            bool cliff = TryEdgeDrop(ctx, x, y, dir, corners, out var drop);
            hasCliff[(int)dir] = cliff && !drop.NeighborIsWater;
            if (cliff)
                AddEdgeWall(ctx, x, y, dir, corners, drop, wallBuffer, bandBuffer, theme.CliffBandThickness);
        }

        // Shoreline edges get no lip strip: a hard dark line at the water boundary reads as a defect
        // rather than as depth.
        if (!edgeStrips) return;

        var stripBuffer = ctx.Palette.Overlay(FaceKind.EdgeStrip);
        float width = theme.CliffEdgeStripWidth;
        bool n = hasCliff[(int)CardinalDirection.North];
        bool e = hasCliff[(int)CardinalDirection.East];
        bool s = hasCliff[(int)CardinalDirection.South];
        bool w = hasCliff[(int)CardinalDirection.West];

        // Two strips meeting at a convex corner used to overlap on the corner square and z-fight.
        // North and South run the full tile width; East and West give up their end where a
        // north/south strip already covers it, so the two tile without overlapping.
        if (n) AddEdgeStrip(ctx, x, y, CardinalDirection.North, vSW, vSE, vNE, vNW, width, stripBuffer, false, false);
        if (s) AddEdgeStrip(ctx, x, y, CardinalDirection.South, vSW, vSE, vNE, vNW, width, stripBuffer, false, false);
        if (e) AddEdgeStrip(ctx, x, y, CardinalDirection.East, vSW, vSE, vNE, vNW, width, stripBuffer, n, s);
        if (w) AddEdgeStrip(ctx, x, y, CardinalDirection.West, vSW, vSE, vNE, vNW, width, stripBuffer, s, n);
    }

    /// <summary>
    /// Is there a cliff on this tile edge, and how deep does its wall run?
    ///
    /// The bottom of each end is the CARDINAL neighbour's corner on that same shared edge, never lower
    /// than the canyon floor and never higher than this tile's own corner above it. Two consequences,
    /// both load-bearing:
    ///
    /// · A wall lands exactly on the ledge it drops to. Reading a min-corner vertex grid instead (as
    ///   this did) let a DIAGONAL tile pull one end of the wall below the neighbour it faces, which
    ///   cut a slanted trapezoid through the neighbouring ledge.
    /// · A twisted edge (this tile higher at one end, lower at the other) emits from BOTH tiles, but
    ///   each covers only its own rising half — the quad degenerates to a triangle at the end where
    ///   the neighbour is higher. The two used to overlap as a pair of doubled, z-fighting quads.
    ///
    /// Void and off-map neighbours drop to the canyon floor, so the cliff reads as a clean chasm wall;
    /// the void tile's other solid neighbours close the corner with their own walls. Water and
    /// over-water bridge neighbours push the bottom a further
    /// <see cref="TerrainMeshBuilder.WaterWallDepth"/> below their surface so a wave dipping DOWN
    /// reveals wall rather than a slice of sky — they emit no wall of their own, so this face covers
    /// the whole gap. That extra depth is also why a bank flush with the water still gets a face.
    /// </summary>
    internal static bool TryEdgeDrop(
        TerrainBuildContext ctx, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        out EdgeDrop drop)
    {
        var layout = ctx.Layout;

        // EdgeCorners returns the pair left-to-right facing outward — the same mapping as Unity's
        // GetEdgeCornerHeights (N: NW,NE — E: NE,SE — S: SE,SW — W: SW,NW).
        (int thisA, int thisB) = corners.EdgeCorners(dir);
        (int nx, int ny) = LayoutQueries.Step(x, y, dir);

        int floor = TerrainMeshBuilder.VoidFloorCornerHeight;
        if (!layout.IsInBounds(nx, ny) || layout.GetTile(nx, ny) == TileRole.Empty)
        {
            drop = new EdgeDrop(Math.Min(thisA, floor), Math.Min(thisB, floor), true, false);
            return thisA > drop.BottomA || thisB > drop.BottomB;
        }

        TileRole role = layout.GetTile(nx, ny);
        (int neighborA, int neighborB) = LayoutQueries.NeighborEdgeHeights(layout, x, y, dir);

        bool underWater = role == TileRole.Water
            || (role == TileRole.Bridge && !LayoutQueries.IsBridgeOverVoid(layout, nx, ny));
        if (underWater)
        {
            neighborA -= TerrainMeshBuilder.WaterWallDepth;
            neighborB -= TerrainMeshBuilder.WaterWallDepth;
        }

        drop = new EdgeDrop(
            Math.Max(Math.Min(thisA, neighborA), floor),
            Math.Max(Math.Min(thisB, neighborB), floor),
            false,
            role == TileRole.Water);
        return thisA > drop.BottomA || thisB > drop.BottomB;
    }

    /// <summary>One cliff face on a tile edge, with the mortar bands that overlay it.</summary>
    private static void AddEdgeWall(
        TerrainBuildContext ctx, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        EdgeDrop drop, MeshBuffer buffer, MeshBuffer? bandBuffer, float bandThickness)
    {
        (int thisA, int thisB) = corners.EdgeCorners(dir);

        (Vector3 topLeft, Vector3 topRight, Vector3 bottomLeft, Vector3 bottomRight) =
            LayoutQueries.GetEdgeWorldPositions(
                x, y, dir, thisA, thisB, drop.BottomA, drop.BottomB, ctx.HeightScale);

        TerrainGeometry.AddWallQuad(buffer, ctx.Collision, topLeft, topRight, bottomRight, bottomLeft);
        ctx.Debug?.Walls.Add(new TerrainDebugFaces.WallFace(
            x, y, dir, thisA, thisB, drop.BottomA, drop.BottomB));

        if (bandBuffer != null && bandThickness > 0f)
            AddCliffBands(bandBuffer, topLeft, topRight, bottomRight, bottomLeft,
                ctx.HeightScale, bandThickness);
    }

    /// <summary>
    /// A darker, wider strip along a cliff LIP: the same inset band as a grid line, but only on edges
    /// where the tile actually stands above its neighbour.
    ///
    /// <paramref name="trimA"/> / <paramref name="trimB"/> pull an end back by one strip width, for the
    /// end a perpendicular strip on the same tile already covers. The strip runs from the A corner of
    /// the edge to its B corner, so trimming is a lerp of both the outer and the inner point toward the
    /// other end — both taken from the untrimmed pair, so trimming both ends stays symmetric.
    /// </summary>
    private static void AddEdgeStrip(
        TerrainBuildContext ctx, int x, int y, CardinalDirection dir,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW,
        float stripWidth, MeshBuffer buffer, bool trimA, bool trimB)
    {
        (Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB) =
            TerrainGeometry.InsetEdge(dir, vSW, vSE, vNE, vNW, stripWidth);

        if (trimA || trimB)
        {
            (Vector3 oA, Vector3 oB, Vector3 iA, Vector3 iB) = (outerA, outerB, innerA, innerB);
            if (trimA) { outerA = oA.Lerp(oB, stripWidth); innerA = iA.Lerp(iB, stripWidth); }
            if (trimB) { outerB = oB.Lerp(oA, stripWidth); innerB = iB.Lerp(iA, stripWidth); }
        }

        TerrainGeometry.AddLiftedStrip(buffer, outerA, outerB, innerA, innerB, EdgeStripYOffset);
        ctx.Debug?.Strips.Add(TerrainDebugFaces.StripFace.Around(x, y, dir, outerA, outerB, innerA, innerB));
    }

    /// <summary>
    /// Thin horizontal bands across a cliff face at every cubic-unit boundary it spans, plus one
    /// vertical band on the quad's left edge. The horizontals read as mortar joints between stacked
    /// blocks — a player can count how many elevations a drop is worth — and the verticals mark the
    /// tile boundary. Band heights come from a world-Y grid, not from the quad, so bands on adjacent
    /// wall segments line up regardless of per-corner slope.
    /// </summary>
    private static void AddCliffBands(
        MeshBuffer buffer, Vector3 topLeft, Vector3 topRight, Vector3 bottomRight, Vector3 bottomLeft,
        float hs, float bandThickness)
    {
        // One cubic unit in world Y: 2 elevations, which is exactly one tile of horizontal size.
        float cubeWorldY = TileCornerHeights.UnitsPerElevation * hs * 2f;
        if (cubeWorldY <= 0f) return;

        float topY = MathF.Max(topLeft.Y, topRight.Y);
        float botY = MathF.Min(bottomLeft.Y, bottomRight.Y);
        if (topY - botY < bandThickness) return;

        if (TerrainGeometry.WallNormal(topLeft, topRight, bottomRight, bottomLeft) is not { } normal) return;

        Vector3 outward = normal * CliffBandOffset;
        float halfT = bandThickness * 0.5f;
        float skip = halfT + 0.001f;

        float firstBand = MathF.Floor((topY - skip) / cubeWorldY) * cubeWorldY;
        for (float bandY = firstBand; bandY > botY + skip; bandY -= cubeWorldY)
        {
            if (topY - bandY < skip) continue;

            Vector3 leftAtY = TerrainGeometry.InterpolateY(topLeft, bottomLeft, bandY);
            Vector3 rightAtY = TerrainGeometry.InterpolateY(topRight, bottomRight, bandY);
            if ((rightAtY - leftAtY).LengthSquared() < 1e-6f) continue;

            var up = new Vector3(0, halfT, 0);
            TerrainGeometry.AddOverlayQuad(buffer,
                leftAtY + up + outward, rightAtY + up + outward,
                rightAtY - up + outward, leftAtY - up + outward, normal);
        }

        // Vertical tile-boundary line. Each wall quad spans exactly one tile horizontally, so its LEFT
        // edge is a shared boundary; the neighbour's left-edge line covers the other one. A wall on the
        // map boundary gets a single line, which is correct. A twisted edge emits from both tiles, but
        // the two quads read the shared edge from opposite ends, so each end still gets one line.
        Vector3 horiz = topRight - topLeft;
        float tileWidth = horiz.Length();
        if (tileWidth <= 0.0001f) return;

        Vector3 inward = horiz / tileWidth * (bandThickness * 0.5f);
        Vector3 tOuter = topLeft + outward;
        Vector3 bOuter = bottomLeft + outward;
        if ((tOuter - bOuter).LengthSquared() <= 1e-6f) return;

        TerrainGeometry.AddOverlayQuad(buffer, tOuter, tOuter + inward, bOuter + inward, bOuter, normal);
    }
}
