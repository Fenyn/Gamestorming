using System;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// The vertices of the skirt's height field that are NOT free to move, and why. Three pins hold the
/// halo in place: the board's own boundary on the inside (the join has to be exact or the cliff pass
/// invents a wall along the seam), zero at the rim (past it the backdrop's ground plane takes over),
/// and a river's surface wherever one runs (water is level, so its banks come down to meet it).
///
/// Everything between the pins is <see cref="SkirtHeights"/>'s to shape.
/// </summary>
internal static class SkirtPins
{
    /// <summary>
    /// Pins every vertex of the board's own rectangle. The perimeter ones are the join: each takes
    /// the LOWEST ground corner of the board edge tiles that meet there, so the halo never pokes up
    /// through a ledge. VOID edge tiles contribute nothing — a chasm mouth sits on the canyon floor
    /// ten elevations down, and joining that would drag the whole halo into the pit; those vertices
    /// take the nearest real ground along the perimeter instead, so the halo closes over the chasm.
    /// Interior board vertices are pinned only to keep them out of the relaxation; no halo tile
    /// reads them.
    /// </summary>
    internal static void Board(int[] h, bool[] frozen, int gw, MapLayout board, int margin)
    {
        int x0 = margin, y0 = margin, x1 = margin + board.Width, y1 = margin + board.Height;

        for (int vy = y0; vy <= y1; vy++)
            for (int vx = x0; vx <= x1; vx++)
            {
                frozen[vy * gw + vx] = true;
                h[vy * gw + vx] = int.MaxValue;
            }

        for (int by = 0; by < board.Height; by++)
        {
            for (int bx = 0; bx < board.Width; bx++)
            {
                if (bx != 0 && by != 0 && bx != board.Width - 1 && by != board.Height - 1) continue;
                if (board.GetTile(bx, by) == TileRole.Empty) continue;

                var c = SkirtLayout.GroundCorners(board, bx, by);
                int vx = margin + bx, vy = margin + by;
                Lowest(h, gw, vx, vy, x0, y0, x1, y1, c.SW);
                Lowest(h, gw, vx + 1, vy, x0, y0, x1, y1, c.SE);
                Lowest(h, gw, vx, vy + 1, x0, y0, x1, y1, c.NW);
                Lowest(h, gw, vx + 1, vy + 1, x0, y0, x1, y1, c.NE);
            }
        }

        BridgeVoid(h, gw, x0, y0, x1, y1);

        for (int vy = y0; vy <= y1; vy++)
            for (int vx = x0; vx <= x1; vx++)
                if (h[vy * gw + vx] == int.MaxValue) h[vy * gw + vx] = 0;
    }

    /// <summary>Min-assign, but only on the board's vertex perimeter — the ring the halo joins.</summary>
    private static void Lowest(
        int[] h, int gw, int vx, int vy, int x0, int y0, int x1, int y1, int value)
    {
        if (!OnPerimeter(vx, vy, x0, y0, x1, y1)) return;
        int i = vy * gw + vx;
        if (value < h[i]) h[i] = value;
    }

    private static bool OnPerimeter(int vx, int vy, int x0, int y0, int x1, int y1)
        => vx >= x0 && vx <= x1 && vy >= y0 && vy <= y1
           && (vx == x0 || vx == x1 || vy == y0 || vy == y1);

    /// <summary>Carries real ground across a chasm mouth: a perimeter vertex left unset by the void
    /// takes the lowest value set beside it, walking along the perimeter until the gap closes.</summary>
    private static void BridgeVoid(int[] h, int gw, int x0, int y0, int x1, int y1)
    {
        bool changed = true;
        while (changed)
        {
            changed = false;
            for (int vy = y0; vy <= y1; vy++)
            {
                for (int vx = x0; vx <= x1; vx++)
                {
                    if (!OnPerimeter(vx, vy, x0, y0, x1, y1)) continue;
                    if (h[vy * gw + vx] != int.MaxValue) continue;

                    int best = int.MaxValue;
                    for (int oy = -1; oy <= 1; oy++)
                        for (int ox = -1; ox <= 1; ox++)
                        {
                            if (!OnPerimeter(vx + ox, vy + oy, x0, y0, x1, y1)) continue;
                            best = Math.Min(best, h[(vy + oy) * gw + vx + ox]);
                        }

                    if (best == int.MaxValue) continue;
                    h[vy * gw + vx] = best;
                    changed = true;
                }
            }
        }
    }

    /// <summary>Pins the outermost two vertex rings at zero. Both are needed: the last tile ring has
    /// corners on rings <c>margin - 1</c> AND <c>margin</c>, and it has to come out dead flat at the
    /// ground plane's own height.</summary>
    internal static void Rim(int[] h, bool[] frozen, int gw, int gh, MapLayout board, int margin)
    {
        for (int vy = 0; vy < gh; vy++)
            for (int vx = 0; vx < gw; vx++)
            {
                if (SkirtLayout.VertexRing(vx, vy, margin, board) < margin - 1) continue;
                int i = vy * gw + vx;
                h[i] = 0;
                frozen[i] = true;
            }
    }

    /// <summary>A river's surface is level, so its vertices are pinned at its own height and the
    /// banks are relaxed down to meet them.</summary>
    internal static void Water(
        MapLayout skirt, MapLayout board, int[] h, bool[] frozen, int gw, int margin, int[] waterUnits)
    {
        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, margin, board) == 0) continue;
                int level = waterUnits[sy * skirt.Width + sx];
                if (level == SkirtLayout.NoWater) continue;

                PinWater(h, frozen, gw, sx, sy, margin, board, level);
                PinWater(h, frozen, gw, sx + 1, sy, margin, board, level);
                PinWater(h, frozen, gw, sx, sy + 1, margin, board, level);
                PinWater(h, frozen, gw, sx + 1, sy + 1, margin, board, level);
            }
        }
    }

    private static void PinWater(
        int[] h, bool[] frozen, int gw, int vx, int vy, int margin, MapLayout board, int level)
    {
        int ring = SkirtLayout.VertexRing(vx, vy, margin, board);
        if (ring == 0 || ring >= margin - 1) return;   // the board's join and the rim outrank a river

        int i = vy * gw + vx;
        h[i] = frozen[i] ? Math.Min(h[i], level) : level;
        frozen[i] = true;
    }
}
