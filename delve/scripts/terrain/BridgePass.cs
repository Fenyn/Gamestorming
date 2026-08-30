using System;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>Everything a Bridge tile owns below its deck. See <see cref="Render"/>.</summary>
internal static class BridgePass
{
    /// <summary>Inward thickness of a bridge pillar box, in world units.</summary>
    private const float PillarInset = 0.28f;

    /// <summary>
    /// Everything a Bridge tile owns below its deck: the slab underside, side faces on exposed slab
    /// edges, boxed pillars down to the floor where the deck overhangs a bank, and the fill (canyon
    /// floor or water surface) that stops the abyss showing through the gaps.
    ///
    /// None of it joins the collision mesh. The deck's top face already went in with every other tile
    /// top, which is the only bridge surface a creature stands on or a pick ray should ever hit; adding
    /// undersides and pillars would put a second, lower hit under the same tile column for no gain.
    /// </summary>
    internal static void Render(
        TerrainBuildContext ctx, int x, int y, TileCornerHeights corners, SurfaceType surface,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW)
    {
        var layout = ctx.Layout;
        float hs = ctx.HeightScale;

        var drop = new Vector3(0, TerrainMeshBuilder.BridgeSlabThickness * hs, 0);
        Vector3 uSW = vSW - drop;
        Vector3 uSE = vSE - drop;
        Vector3 uNW = vNW - drop;
        Vector3 uNE = vNE - drop;

        var slab = ctx.Palette.Wall(surface);

        TerrainGeometry.AddQuad(slab, null, uSW, uSE, uNE, uNW, faceDown: true);

        AddBridgeSideFace(layout, x, y, CardinalDirection.North, corners, vNW, vNE, uNW, uNE, slab);
        AddBridgeSideFace(layout, x, y, CardinalDirection.East, corners, vNE, vSE, uNE, uSE, slab);
        AddBridgeSideFace(layout, x, y, CardinalDirection.South, corners, vSE, vSW, uSE, uSW, slab);
        AddBridgeSideFace(layout, x, y, CardinalDirection.West, corners, vSW, vNW, uSW, uNW, slab);

        int floorH = LayoutQueries.FindBridgeFloorHeight(layout, x, y);
        foreach (var dir in LayoutQueries.Cardinals)
            AddBridgePillarWall(layout, x, y, dir, corners, floorH, hs, slab);

        if (LayoutQueries.IsBridgeOverVoid(layout, x, y))
        {
            float floorY = TerrainMeshBuilder.VoidFloorCornerHeight * hs;
            TerrainGeometry.AddFillQuad(ctx.Palette.Top(SurfaceType.Stone), floorY, vSW, vSE, vNE, vNW);
            return;
        }

        // Under-span water. Unity drew it at the neighbouring water's rest level, which coincides with
        // the deck on a flush span (sewer grates sit AT water level) and z-fights it. Clamping to the
        // slab underside leaves a real river untouched — its surface is already well below the deck —
        // and turns the flush case into a visible 0.25 m recess instead of a flickering seam.
        int waterCornerH = Math.Min(
            LayoutQueries.FindAdjacentWaterCornerHeight(layout, x, y),
            TerrainGeometry.RoundToInt(corners.CenterHeight) - TerrainMeshBuilder.BridgeSlabThickness);
        TerrainGeometry.AddFillQuad(ctx.Palette.Top(SurfaceType.Water), waterCornerH * hs, vSW, vSE, vNE, vNW);
    }

    /// <summary>
    /// The exposed vertical edge of a bridge slab, drawn double-sided (a 0.25 m slab seen edge-on from
    /// under the span needs a face on both sides). Skipped where a neighbouring bridge continues the
    /// deck at roughly the same height. Adjacent solid tiles cover their own side of the gap through
    /// <see cref="CliffPass.AddEdgeWall"/>'s bridge-floor handling.
    /// </summary>
    private static void AddBridgeSideFace(
        MapLayout layout, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        Vector3 topA, Vector3 topB, Vector3 botA, Vector3 botB, MeshBuffer buffer)
    {
        (int nx, int ny) = LayoutQueries.Step(x, y, dir);
        if (layout.IsInBounds(nx, ny) && layout.GetTile(nx, ny) == TileRole.Bridge)
        {
            var neighbor = layout.GetCornerHeights(nx, ny);
            if (MathF.Abs(corners.CenterHeight - neighbor.CenterHeight)
                <= TerrainMeshBuilder.BridgeSlabThickness) return;
        }

        // AddWallQuad derives its outward normal from the argument order, so the same four points wound
        // both ways give one front face per side — Unity's hand-rolled +normal/-normal pair, reused.
        TerrainGeometry.AddWallQuad(buffer, null, topA, topB, botB, botA);
        TerrainGeometry.AddWallQuad(buffer, null, topB, topA, botA, botB);
    }

    /// <summary>
    /// A boxed pillar from the slab underside down to the floor, on one edge of a bridge tile.
    ///
    /// Only at corner pockets: an approach edge is skipped (the ground tile's own cliff wall already
    /// covers the full gap, and a second face there would z-fight), and an open river-facing span is
    /// left open on purpose so the span reads as spanning. What is left is the edge where the deck
    /// overhangs a bank, detected by a ground-ish neighbour on a perpendicular edge.
    /// </summary>
    private static void AddBridgePillarWall(
        MapLayout layout, int x, int y, CardinalDirection dir, TileCornerHeights corners,
        int floorH, float hs, MeshBuffer buffer)
    {
        (int nx, int ny) = LayoutQueries.Step(x, y, dir);
        if (layout.IsInBounds(nx, ny))
        {
            var neighborRole = layout.GetTile(nx, ny);
            if (neighborRole == TileRole.Bridge) return;
            if (neighborRole is TileRole.Ground or TileRole.DifficultTerrain
                or TileRole.Cover or TileRole.Wall) return;
        }

        if (!LayoutQueries.HasPerpendicularGround(layout, x, y, dir)) return;

        (int topA, int topB) = corners.EdgeCorners(dir);
        topA -= TerrainMeshBuilder.BridgeSlabThickness;
        topB -= TerrainMeshBuilder.BridgeSlabThickness;
        if (topA <= floorH && topB <= floorH) return;

        (Vector3 oTL, Vector3 oTR, Vector3 oBL, Vector3 oBR) =
            LayoutQueries.GetEdgeWorldPositions(x, y, dir, topA, topB, floorH, floorH, hs);

        if (oTL.DistanceTo(oBL) < 0.001f && oTR.DistanceTo(oBR) < 0.001f) return;

        Vector3 inward = dir switch
        {
            CardinalDirection.North => new Vector3(0, 0, -PillarInset),
            CardinalDirection.South => new Vector3(0, 0, PillarInset),
            CardinalDirection.East => new Vector3(-PillarInset, 0, 0),
            _ => new Vector3(PillarInset, 0, 0),
        };

        Vector3 iTL = oTL + inward, iTR = oTR + inward, iBL = oBL + inward, iBR = oBR + inward;

        TerrainGeometry.AddWallQuad(buffer, null, oTL, oTR, oBR, oBL);   // outer face
        TerrainGeometry.AddWallQuad(buffer, null, iTR, iTL, iBL, iBR);   // inner face (L/R swapped = reversed)
        TerrainGeometry.AddWallQuad(buffer, null, iTL, oTL, oBL, iBL);   // side
        TerrainGeometry.AddWallQuad(buffer, null, oTR, iTR, iBR, oBR);   // side
        // Bottom cap. Unity listed it outer-left → outer-right → inner-right → inner-left, which traces
        // the box CLOCKWISE seen from above (the outer edge runs left-to-right as seen from OUTSIDE the
        // tile) and so already front-faced downward there. AddQuad's faceDown path flips a CCW footprint
        // to face down, so handing it Unity's order would flip an already-down face back up — leaving the
        // cap invisible from below, which is the one place it is ever seen. Reversed to CCW.
        TerrainGeometry.AddQuad(buffer, null, oBL, iBL, iBR, oBR, faceDown: true);
    }
}
