using System;
using PF2e.Grid;
using PF2e.MapGen;

namespace Ungilded.Terrain;

/// <summary>
/// Paints an authored halo (<see cref="HaloPlan"/>) into a skirt in place of the synthesized one.
/// Every halo tile the plan names takes its role, surface and flat floor height; every other halo
/// tile is wall. A wall stands <c>wallHeightUnits</c> above the highest open floor beside it, so
/// the walls along a rising passage rise with it and a wall never ends below the floor it bounds.
/// </summary>
internal static class SkirtPlan
{
    internal static void Paint(MapLayout skirt, MapLayout board, HaloPlan plan, SkirtStyle style,
        int margin, int wallHeightUnits)
    {
        var floor = new int?[skirt.Width * skirt.Height];
        for (int sy = 0; sy < skirt.Height; sy++)
        for (int sx = 0; sx < skirt.Width; sx++)
        {
            int i = sy * skirt.Width + sx;
            if (SkirtLayout.TileRing(sx, sy, margin, board) == 0)
            {
                var role = skirt.GetTile(sx, sy);
                if (role is not (TileRole.Wall or TileRole.Empty))
                    floor[i] = skirt.GetCornerHeights(sx, sy).MinHeight;
                continue;
            }

            if (plan.Cells.TryGetValue((sx - margin, sy - margin), out var cell) && cell.Role != TileRole.Wall)
            {
                skirt.SetTile(sx, sy, cell.Role);
                skirt.SetSurface(sx, sy, cell.Surface);
                skirt.SetTerrainDifficulty(sx, sy, cell.Role == TileRole.DifficultTerrain
                    ? TerrainDifficulty.Difficult : TerrainDifficulty.Normal);
                floor[i] = cell.Floor;
            }
            else
            {
                skirt.SetTile(sx, sy, TileRole.Wall);
                skirt.SetSurface(sx, sy, style.WallSurface);
            }
        }

        for (int sy = 0; sy < skirt.Height; sy++)
        for (int sx = 0; sx < skirt.Width; sx++)
        {
            if (SkirtLayout.TileRing(sx, sy, margin, board) == 0) continue;
            int i = sy * skirt.Width + sx;
            int height = floor[i] ?? GroundBeside(skirt, floor, sx, sy) + wallHeightUnits;
            var corners = TileCornerHeights.Flat(height);
            skirt.SetCornerHeights(sx, sy, corners);
            skirt.SetElevation(sx, sy, TileCornerHeights.ToElevationsFloor(corners.MinHeight));
            skirt.SetSlope(sx, sy, SlopeType.Flat, 0);
        }
    }

    /// <summary>Highest open floor among the eight neighbours, or 0 inside the wall mass.</summary>
    private static int GroundBeside(MapLayout skirt, int?[] floor, int sx, int sy)
    {
        int ground = 0;
        for (int oy = -1; oy <= 1; oy++)
        for (int ox = -1; ox <= 1; ox++)
        {
            int nx = sx + ox, ny = sy + oy;
            if (!skirt.IsInBounds(nx, ny) || floor[ny * skirt.Width + nx] is not { } f) continue;
            ground = Math.Max(ground, f);
        }
        return ground;
    }
}
