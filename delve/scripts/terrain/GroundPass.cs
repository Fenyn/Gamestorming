using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// The pass every tile goes through: the top face of a solid tile, its share of the top-surface grid
/// lattice, and the canyon floor drawn under an Empty tile.
/// </summary>
internal static class GroundPass
{
    /// <summary>Lift of top-surface grid lines above the face they sit on. Z-fight margin, world units.</summary>
    private const float GridLineYOffset = 0.004f;

    /// <summary>Stone floor quad under one Empty tile. Neighbouring solids drop their walls to the same height.</summary>
    internal static void RenderVoidTile(TerrainBuildContext ctx, int x, int y)
    {
        float floorY = TerrainMeshBuilder.VoidFloorCornerHeight * ctx.HeightScale;
        var fSW = new Vector3(x, floorY, y);
        var fSE = new Vector3(x + 1, floorY, y);
        var fNW = new Vector3(x, floorY, y + 1);
        var fNE = new Vector3(x + 1, floorY, y + 1);
        TerrainGeometry.AddQuad(ctx.Palette.Top(SurfaceType.Stone), ctx.Collision, fSW, fSE, fNE, fNW);
    }

    /// <summary>The tile top and, where the theme asks for them, the grid lines that mark it.</summary>
    internal static void Render(
        TerrainBuildContext ctx, int x, int y, TileRole role, SurfaceType surface,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW)
    {
        TerrainGeometry.AddQuad(ctx.Palette.Top(surface), ctx.Collision, vSW, vSE, vNE, vNW);

        // Grid lines skip water (its own surface animates) and walls (a wall's "top" is at wall
        // height, so a lattice there would float above the playfield rather than mark it), and any
        // tile outside the playable rectangle — the halo around a skirted board is scenery, not
        // squares to count movement on.
        bool gridLines = ctx.Theme.EnableTopGridLines && ctx.Theme.TopGridLineWidth > 0f;
        if (gridLines && role != TileRole.Water && role != TileRole.Wall && ctx.GridLines.Contains(x, y))
            AddTileGridLines(ctx.Palette.Overlay(FaceKind.TopGridLine), ctx.GridLines, x, y,
                vSW, vSE, vNE, vNW, ctx.Theme.TopGridLineWidth);
    }

    /// <summary>
    /// The tile's share of the top-surface lattice. Each tile owns its N and E edges; the tiles on
    /// the lattice rectangle's own S and W boundary also own those edges, so the board gets a closed
    /// grid with no line drawn twice.
    /// </summary>
    private static void AddTileGridLines(
        MeshBuffer buffer, TileRect rect, int x, int y,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float lineWidth)
    {
        AddTopGridLine(buffer, CardinalDirection.North, vSW, vSE, vNE, vNW, lineWidth);
        AddTopGridLine(buffer, CardinalDirection.East, vSW, vSE, vNE, vNW, lineWidth);
        if (y == rect.Y) AddTopGridLine(buffer, CardinalDirection.South, vSW, vSE, vNE, vNW, lineWidth);
        if (x == rect.X) AddTopGridLine(buffer, CardinalDirection.West, vSW, vSE, vNE, vNW, lineWidth);
    }

    /// <summary>
    /// A thin strip along one tile edge, lying on the top face and lifted clear of it. Follows the
    /// corner heights, so it works on slopes as well as flats.
    /// </summary>
    private static void AddTopGridLine(
        MeshBuffer buffer, CardinalDirection dir,
        Vector3 vSW, Vector3 vSE, Vector3 vNE, Vector3 vNW, float lineWidth)
    {
        (Vector3 outerA, Vector3 outerB, Vector3 innerA, Vector3 innerB) =
            TerrainGeometry.InsetEdge(dir, vSW, vSE, vNE, vNW, lineWidth);
        TerrainGeometry.AddLiftedStrip(buffer, outerA, outerB, innerA, innerB, GridLineYOffset);
    }
}
