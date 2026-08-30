using System;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Gives the halo its shape. Works on a VERTEX field — one height per grid corner, shared by the
/// four tiles that meet there — because that is the only way adjacent tiles come out flush; deriving
/// each tile's corners independently is what makes a cliff pass draw walls between neighbours that
/// were meant to be one hillside.
///
/// <see cref="SkirtPins"/> nails the field down where it is not free to move — the board's own
/// boundary, the rim, a river's surface. What is left here is the shape in between: a falloff of the
/// board's edge height plus a Perlin swell that rises mid-halo and settles again, a slope limit that
/// walks every free vertex down until no two neighbours differ by more than
/// <see cref="SkirtLayout.SlopeLimitUnits"/>, and the read-out into tile corners.
/// </summary>
internal static class SkirtHeights
{
    private const int Units = TileCornerHeights.UnitsPerElevation;
    private const int HillSalt = 0x3F19;

    /// <summary>How far, as a fraction of the falloff, a contour may sway in or out. Without this
    /// the falloff descends at the same rate everywhere and a tall board edge turns the halo into
    /// dead-straight concentric terraces; with it the terrace lines wander like real contours.</summary>
    private const float ContourSway = 0.6f;

    internal static void Apply(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, int[] waterUnits,
        int wallHeightUnits)
    {
        int gw = skirt.Width + 1;
        int gh = skirt.Height + 1;
        var h = new int[gw * gh];
        var frozen = new bool[gw * gh];

        SkirtPins.Board(h, frozen, gw, board, margin);
        SkirtPins.Rim(h, frozen, gw, gh, board, margin);
        Target(h, frozen, gw, gh, board, style, margin);
        SkirtPins.Water(skirt, board, h, frozen, gw, margin, waterUnits);
        LimitSlopes(h, frozen, gw, gh);
        WriteTiles(skirt, board, h, gw, margin, waterUnits, wallHeightUnits);
    }

    // ─────────────────────────── the shape ───────────────────────────

    /// <summary>
    /// Target height for every free vertex: the board edge's height falling off to nothing over the
    /// margin, plus a hill swell that is zero at both ends and peaks halfway out. Both curves are
    /// driven by the same normalised distance, so a plateau leaving the board rolls down through the
    /// hills instead of ending on a step.
    /// </summary>
    private static void Target(
        int[] h, bool[] frozen, int gw, int gh, MapLayout board, SkirtStyle style, int margin)
    {
        float span = margin - 1;
        float amplitude = style.HillAmplitudeElevations * Units;
        float frequency = Math.Max(2f, style.HillFrequency);
        float ox = MapHash.Hash01(HillSalt, 0, board.Seed) * 251f + 0.37f;
        float oy = MapHash.Hash01(HillSalt, 1, board.Seed) * 251f + 0.37f;

        for (int vy = 0; vy < gh; vy++)
        {
            for (int vx = 0; vx < gw; vx++)
            {
                int i = vy * gw + vx;
                if (frozen[i]) continue;

                int cvx = Math.Clamp(vx, margin, margin + board.Width);
                int cvy = Math.Clamp(vy, margin, margin + board.Height);
                float edge = h[cvy * gw + cvx];

                // The sway samples a second noise channel (the offsets swapped) and is faded by
                // sin so t stays exact at the board edge and the rim — only the middle wanders.
                float ring = SkirtLayout.VertexRing(vx, vy, margin, board);
                float sway = (MapGenMath.PerlinNoise(vx / frequency + oy, vy / frequency + ox) - 0.5f)
                             * ContourSway;
                float t = Math.Clamp(ring / span + sway * MathF.Sin(MathF.PI * ring / span), 0f, 1f);
                float fall = 0.5f * (1f + MathF.Cos(MathF.PI * t));
                float ramp = MathF.Sin(MathF.PI * t);
                float noise = MapGenMath.PerlinNoise(vx / frequency + ox, vy / frequency + oy);

                float value = edge * fall + ramp * amplitude * (noise - 0.5f) * 2f;
                h[i] = Math.Max(0, (int)MathF.Round(value));
            }
        }
    }

    /// <summary>
    /// Walks free vertices DOWN until no vertex stands more than
    /// <see cref="SkirtLayout.SlopeLimitUnits"/> above any of its eight neighbours. Lowering only is
    /// what makes this terminate, and because the rule is applied to every ordered pair the fixpoint
    /// also bounds the difference the other way: between two free vertices the step is gentle in
    /// both directions. A pinned neighbour can still stand higher — that is the board's own cliff
    /// carrying on outward, which is the honest thing to draw.
    /// </summary>
    private static void LimitSlopes(int[] h, bool[] frozen, int gw, int gh)
    {
        int guard = 4 * (gw + gh);
        bool changed = true;

        while (changed && guard-- > 0)
        {
            changed = Sweep(h, frozen, gw, gh, forward: true)
                      | Sweep(h, frozen, gw, gh, forward: false);
        }
    }

    private static bool Sweep(int[] h, bool[] frozen, int gw, int gh, bool forward)
    {
        bool changed = false;
        for (int k = 0; k < gw * gh; k++)
        {
            int i = forward ? k : gw * gh - 1 - k;
            if (frozen[i]) continue;

            int vx = i % gw, vy = i / gw;
            int limit = int.MaxValue;
            for (int oy = -1; oy <= 1; oy++)
            {
                for (int ox = -1; ox <= 1; ox++)
                {
                    if (ox == 0 && oy == 0) continue;
                    int nx = vx + ox, ny = vy + oy;
                    if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
                    limit = Math.Min(limit, h[ny * gw + nx] + SkirtLayout.SlopeLimitUnits);
                }
            }

            limit = Math.Max(0, limit);   // synthesized ground never sinks below the ground plane
            if (limit >= h[i]) continue;
            h[i] = limit;
            changed = true;
        }
        return changed;
    }

    // ─────────────────────────── tiles ───────────────────────────

    /// <summary>
    /// Reads the finished vertex field into each halo tile. Water lies flat at its own level; a tree
    /// or vault wall is a flat block <paramref name="wallHeightUnits"/> above the ground it stands
    /// on, matching how the generator builds the board's own walls; everything else takes the four
    /// vertices it sits between. The first ring additionally takes its INNER corners straight from
    /// the board tile across the seam, so the join is exact even where two board edge tiles disagree
    /// at the vertex between them.
    /// </summary>
    private static void WriteTiles(
        MapLayout skirt, MapLayout board, int[] h, int gw, int margin, int[] waterUnits,
        int wallHeightUnits)
    {
        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                int d = SkirtLayout.TileRing(sx, sy, margin, board);
                if (d == 0) continue;

                var role = skirt.GetTile(sx, sy);
                TileCornerHeights corners;

                if (role == TileRole.Empty)
                {
                    // A continued canyon: the mesh builder draws its own floor and walls for a void
                    // tile, so the vertex field has nothing to say about it.
                    continue;
                }

                if (role == TileRole.Water)
                {
                    corners = TileCornerHeights.Flat(waterUnits[sy * skirt.Width + sx]);
                }
                else if (role == TileRole.Wall)
                {
                    int ground = Corners(h, gw, sx, sy).MaxHeight;
                    corners = TileCornerHeights.Flat(ground + wallHeightUnits);
                }
                else
                {
                    corners = Corners(h, gw, sx, sy);
                    if (d == 1) corners = Join(board, corners, sx, sy, margin);
                }

                skirt.SetCornerHeights(sx, sy, corners);
                skirt.SetElevation(sx, sy, TileCornerHeights.ToElevationsFloor(corners.MinHeight));
                skirt.SetSlope(sx, sy, SlopeType.Flat, 0);
            }
        }
    }

    private static TileCornerHeights Corners(int[] h, int gw, int sx, int sy) => new()
    {
        SW = h[sy * gw + sx],
        SE = h[sy * gw + sx + 1],
        NW = h[(sy + 1) * gw + sx],
        NE = h[(sy + 1) * gw + sx + 1],
    };

    /// <summary>Copies the board's ground corners across every shared edge of a first-ring tile.</summary>
    private static TileCornerHeights Join(
        MapLayout board, TileCornerHeights corners, int sx, int sy, int margin)
    {
        foreach (var (dx, dy) in Cardinals)
        {
            int nx = sx + dx, ny = sy + dy;
            if (SkirtLayout.TileRing(nx, ny, margin, board) != 0) continue;
            if (board.GetTile(nx - margin, ny - margin) == TileRole.Empty) continue;

            var (a, b) = SkirtLayout.JoinCorners(board, nx - margin, ny - margin, dx, dy);
            if (dx > 0) { corners.NE = a; corners.SE = b; }
            else if (dx < 0) { corners.NW = a; corners.SW = b; }
            else if (dy > 0) { corners.NW = a; corners.NE = b; }
            else { corners.SW = a; corners.SE = b; }
        }
        return corners;
    }

    private static readonly (int dx, int dy)[] Cardinals = { (1, 0), (-1, 0), (0, 1), (0, -1) };
}
