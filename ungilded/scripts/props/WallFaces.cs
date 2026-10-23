using System;
using System.Collections.Generic;
using Godot;
using PF2e.MapGen;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>
/// One vertical wall face looking into open floor: the wall tile, the open tile in front of it
/// (both in skirt coordinates), the outward normal on the board's X/Z axes, and the face's floor
/// and top heights.
/// </summary>
public readonly record struct WallFace(
    PF2eVec Wall, PF2eVec Open, Vector2I Normal, int OpenRing, float FloorY, float TopY)
{
    /// <summary>World point at the foot of the face, centred on it, in BOARD world space.</summary>
    public Vector3 Foot(int margin) => new(
        Open.x - margin + 0.5f - Normal.X * 0.5f, FloorY, Open.y - margin + 0.5f - Normal.Y * 0.5f);

    /// <summary>Rotation that turns local +Z out of the face.</summary>
    public Basis Facing => Basis.LookingAt(new Vector3(-Normal.X, 0f, -Normal.Y), Vector3.Up);
}

/// <summary>Finds the wall faces of a built skirt that look into the chamber.</summary>
public static class WallFaces
{
    private static readonly Vector2I[] Cardinals = { new(1, 0), new(-1, 0), new(0, 1), new(0, -1) };

    /// <summary>
    /// Every face of a wall (halo masonry or the board's own outline) that looks onto an open tile
    /// no more than <paramref name="maxOpenRing"/> rings out and rises at least
    /// <paramref name="minHeight"/> metres above it, so a low pillar carries nothing. Stable order:
    /// grouped by normal, then along the wall.
    /// </summary>
    public static List<WallFace> Chamber(SkirtResult skirt, TerrainHeightMap heights, int maxOpenRing, float minHeight)
    {
        var layout = skirt.Layout;
        int boardW = layout.Width - 2 * skirt.Margin, boardH = layout.Height - 2 * skirt.Margin;
        var faces = new List<WallFace>();
        foreach (var n in Cardinals)
        {
            for (int sy = 0; sy < layout.Height; sy++)
            for (int sx = 0; sx < layout.Width; sx++)
            {
                if (layout.GetTile(sx, sy) != TileRole.Wall) continue;
                int ox = sx + n.X, oy = sy + n.Y;
                if (!layout.IsInBounds(ox, oy)) continue;
                var open = layout.GetTile(ox, oy);
                if (open is TileRole.Wall or TileRole.Empty) continue;
                int ring = Ring(ox, oy, skirt.Margin, boardW, boardH);
                if (ring > maxOpenRing) continue;

                var wallTile = new PF2eVec(sx, sy);
                var openTile = new PF2eVec(ox, oy);
                float floor = heights.CenterY(openTile), top = heights.Corners(wallTile).MaxHeight * heights.HeightScale;
                if (top - floor < minHeight) continue;
                faces.Add(new WallFace(wallTile, openTile, n, ring, floor, top));
            }
        }
        return faces;
    }

    /// <summary>Chebyshev ring of a skirt tile from the board rectangle; 0 on the board.</summary>
    public static int Ring(int sx, int sy, int margin, int boardW, int boardH)
    {
        int dx = Math.Max(Math.Max(margin - sx, sx - (margin + boardW - 1)), 0);
        int dy = Math.Max(Math.Max(margin - sy, sy - (margin + boardH - 1)), 0);
        return Math.Max(dx, dy);
    }
}
