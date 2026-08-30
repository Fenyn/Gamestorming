using System;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>Map-edge cross-sections for a Water tile. See <see cref="Render"/>.</summary>
internal static class WaterPass
{
    /// <summary>Alpha 0 tells the water shader to leave this vertex where it is (see the .gdshader).</summary>
    private static readonly Color VertexWaveLocked = new(1f, 1f, 1f, 0f);

    /// <summary>
    /// Map-edge skirts for a water tile: a band of water cross-section (the animated water material,
    /// with its bottom row locked so the seam does not oscillate) over stone bedrock down to the abyss
    /// floor. Without it the river visibly spills off the end of the world, and the edge sits at a
    /// different depth from the plateau cliffs on the same boundary.
    ///
    /// Interior edges get nothing: the bank tile's own wall already runs
    /// <see cref="TerrainMeshBuilder.WaterWallDepth"/> below the water surface (see
    /// <see cref="CliffPass.AddEdgeWall"/>), so a water-side skirt there would only z-fight it.
    /// </summary>
    internal static void Render(
        TerrainBuildContext ctx, int x, int y, TileCornerHeights corners,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW)
    {
        var layout = ctx.Layout;

        bool northEdge = !layout.IsInBounds(x, y + 1);
        bool eastEdge = !layout.IsInBounds(x + 1, y);
        bool southEdge = !layout.IsInBounds(x, y - 1);
        bool westEdge = !layout.IsInBounds(x - 1, y);
        if (!northEdge && !eastEdge && !southEdge && !westEdge) return;

        float hs = ctx.HeightScale;
        int waterCorner = TerrainGeometry.RoundToInt(corners.CenterHeight);
        float edgeDrop = (waterCorner - TerrainMeshBuilder.VoidFloorCornerHeight) * hs;
        float waterBand = MathF.Min(TerrainMeshBuilder.WaterDepthCorners * hs, edgeDrop);

        var waterTop = ctx.Palette.Top(SurfaceType.Water);
        var bedrock = ctx.Palette.Wall(SurfaceType.Stone);

        if (northEdge) AddDeepEdgeSkirt(waterTop, bedrock, vNW, vNE, waterBand, edgeDrop);
        if (eastEdge) AddDeepEdgeSkirt(waterTop, bedrock, vNE, vSE, waterBand, edgeDrop);
        if (southEdge) AddDeepEdgeSkirt(waterTop, bedrock, vSE, vSW, waterBand, edgeDrop);
        if (westEdge) AddDeepEdgeSkirt(waterTop, bedrock, vSW, vNW, waterBand, edgeDrop);
    }

    /// <summary>
    /// One map-edge skirt: water band on top, bedrock below. The band's TOP row keeps vertex alpha 1 so
    /// it bobs with the surface it joins; its BOTTOM row is locked at alpha 0 so the water/rock seam
    /// stays put.
    /// </summary>
    private static void AddDeepEdgeSkirt(
        MeshBuffer waterTop, MeshBuffer bedrock, Vector3 a, Vector3 b, float waterBand, float edgeDrop)
    {
        var band = new Vector3(0, waterBand, 0);
        Vector3 waterBotA = a - band;
        Vector3 waterBotB = b - band;
        TerrainGeometry.AddWallQuad(waterTop, null, a, b, waterBotB, waterBotA,
            TerrainGeometry.VertexWhite, VertexWaveLocked);

        if (edgeDrop <= waterBand) return;

        var full = new Vector3(0, edgeDrop, 0);
        TerrainGeometry.AddWallQuad(bedrock, null, waterBotA, waterBotB, b - full, a - full);
    }
}
