using System;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Carries the board's linear edge features on into the halo: a river that leaves the board keeps
/// flowing, a canyon that leaves the board keeps yawning. A WIDE feature — a real river, a chasm —
/// runs at full width all the way to the rim and off into the fog, because an obstacle the player
/// is meant to cross must never look like something a short walk goes around. Only a brook of one
/// or two tiles tapers out into a marshy head: petering out is the honest read for those, and
/// nobody plans a route around a brook.
///
/// Split out of <see cref="SkirtFeatures"/>, which owns the area passes (inherit, patches, growth);
/// this file owns the run passes. Same contract: paint roles and surfaces only, heights are
/// <see cref="SkirtHeights"/>'s job.
/// </summary>
internal static class SkirtContinuations
{
    private const int MeanderSalt = 0x71A3;

    /// <summary>Rings over which a run narrows to a 1-tile tip before it ends.</summary>
    private const int TaperRings = 3;

    /// <summary>Rings a short water span (a pond lip rather than a river) runs before its taper.</summary>
    private const int LakeRings = 3;

    /// <summary>Rings a tapering brook keeps clear at the rim, so its marshy head sits inside the
    /// halo. Wide rivers and canyons ignore this: they run to the very rim on purpose.</summary>
    internal const int DryRim = 2;

    /// <summary>Board edge, one per side, as the direction pointing out of the board.</summary>
    private static readonly (int dx, int dy)[] Sides = { (-1, 0), (1, 0), (0, -1), (0, 1) };

    // ─────────────────────────── rivers ───────────────────────────

    /// <summary>
    /// Continues every run of water that reaches a board edge. A wide run (3+) keeps its full width
    /// to the very rim, its level ramping gently down to the ground plane so an elevated river never
    /// hangs above the descending halo. A narrow run is a brook: it tapers to a tip over its last
    /// rings and ends in a difficult-ground verge (its marshy head). Either way the centre drifts
    /// sideways by a Perlin meander that is zero at the first ring (a straight, flush join) and
    /// never jumps more than one tile between rings, so the channel stays connected.
    /// </summary>
    internal static void Rivers(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, int[] waterUnits)
    {
        float ox = Offset(board.Seed, MeanderSalt, 0);
        float oy = Offset(board.Seed, MeanderSalt, 1);

        for (int s = 0; s < Sides.Length; s++)
        {
            int len = Sides[s].dx != 0 ? board.Height : board.Width;

            int a = 0;
            while (a < len)
            {
                if (EdgeRole(board, s, a) != TileRole.Water) { a++; continue; }

                int run = 0;
                int level = int.MaxValue;
                while (a + run < len && EdgeRole(board, s, a + run) == TileRole.Water)
                {
                    var (bx, by) = EdgeTile(board, s, a + run);
                    level = Math.Min(level, board.GetCornerHeights(bx, by).MinHeight);
                    run++;
                }

                bool wide = run >= 3;
                int reach = wide ? margin : Math.Min(LakeRings + TaperRings, margin - DryRim - 1);
                float key = (s * 41 + a * 7) * 0.137f;
                int shift = 0;

                for (int d = 1; d <= reach + 1; d++)
                {
                    if (d > 1 && style.RiverMeander > 0f)
                    {
                        float n = MapGenMath.PerlinNoise(d * 0.23f + ox, key + oy) - 0.5f;
                        int want = (int)MathF.Round(n * 2f * style.RiverMeander * d / margin);
                        shift = Math.Clamp(want, shift - 1, shift + 1);
                    }

                    int width = wide ? run : TaperedWidth(run, d, reach);
                    int start = a + shift + (run - width) / 2;

                    if (d <= reach)
                    {
                        int rung = wide ? RampedLevel(level, d, margin) : level;
                        for (int i = 0; i < width; i++)
                            PaintWater(skirt, board, margin, s, start + i, d, rung, waterUnits);
                    }
                    else if (!wide)
                    {
                        for (int i = -1; i <= width; i++)
                            PaintVerge(skirt, board, style, margin, s, start + i, d);
                    }
                }

                a += run;
            }
        }
    }

    /// <summary>A wide river's level at ring <paramref name="d"/>: a board river above the ground
    /// plane steps down to it across the halo (mild rapids), one already at or below it stays flat.
    /// Without this an elevated river would reach the rim as a slab of water hanging over the
    /// descended ground.</summary>
    private static int RampedLevel(int level, int d, int margin)
        => level <= 0 ? level : level - (int)MathF.Round(level * d / (float)margin);

    /// <summary>A brook's width at ring <paramref name="d"/>: full until the taper, then narrowing
    /// to a 1-tile tip on the run's last ring.</summary>
    private static int TaperedWidth(int run, int d, int reach)
    {
        int over = d - (reach - TaperRings);
        if (over <= 0) return run;
        return Math.Max(1, (int)MathF.Round(run * (TaperRings - over) / (float)TaperRings));
    }

    private static void PaintWater(
        MapLayout skirt, MapLayout board, int margin, int side, int along, int d, int level,
        int[] waterUnits)
    {
        var (sx, sy) = HaloTile(board, margin, side, along, d);
        if (!skirt.IsInBounds(sx, sy)) return;
        if (SkirtLayout.TileRing(sx, sy, margin, board) != d) return;

        skirt.SetTile(sx, sy, TileRole.Water);
        skirt.SetSurface(sx, sy, SurfaceType.Water);
        int idx = sy * skirt.Width + sx;
        waterUnits[idx] = waterUnits[idx] == SkirtLayout.NoWater
            ? level
            : Math.Min(waterUnits[idx], level);
    }

    /// <summary>The marshy seep a stream rises from: a short difficult-ground band past the tip.
    /// Only open ground takes it — it never stomps water, trees or a canyon.</summary>
    private static void PaintVerge(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, int side, int along, int d)
    {
        var (sx, sy) = HaloTile(board, margin, side, along, d);
        if (!skirt.IsInBounds(sx, sy)) return;
        if (SkirtLayout.TileRing(sx, sy, margin, board) != d) return;
        if (skirt.GetTile(sx, sy) != TileRole.Ground) return;

        skirt.SetTile(sx, sy, TileRole.DifficultTerrain);
        skirt.SetSurface(sx, sy, style.DifficultSurface);
    }

    // ─────────────────────────── canyons ───────────────────────────

    /// <summary>
    /// Continues every run of void that reaches a board edge — the canyon_crossing shape drives its
    /// chasm through both board edges, and sealing the mouth with terrain reads as the canyon
    /// hitting a glass wall. The continuation runs straight out (a drifting chasm reads as an
    /// error, not a meander) at FULL width to the very rim: the chasm is the obstacle the bridge
    /// exists for, and a chasm that pinches closed a few steps off the board is a chasm you walk
    /// around.
    /// </summary>
    internal static void Canyons(MapLayout skirt, MapLayout board, int margin)
    {
        for (int s = 0; s < Sides.Length; s++)
        {
            int len = Sides[s].dx != 0 ? board.Height : board.Width;

            int a = 0;
            while (a < len)
            {
                if (EdgeRole(board, s, a) != TileRole.Empty) { a++; continue; }

                int run = 0;
                while (a + run < len && EdgeRole(board, s, a + run) == TileRole.Empty) run++;

                for (int d = 1; d <= margin; d++)
                {
                    for (int i = 0; i < run; i++)
                    {
                        var (sx, sy) = HaloTile(board, margin, s, a + i, d);
                        if (!skirt.IsInBounds(sx, sy)) continue;
                        if (SkirtLayout.TileRing(sx, sy, margin, board) != d) continue;
                        skirt.SetTile(sx, sy, TileRole.Empty);
                    }
                }

                a += run;
            }
        }
    }

    // ─────────────────────────── edge geometry ───────────────────────────

    /// <summary>Board tile at index <paramref name="along"/> on one edge.</summary>
    private static (int x, int y) EdgeTile(MapLayout board, int side, int along)
    {
        var (dx, dy) = Sides[side];
        int bx = dx > 0 ? board.Width - 1 : dx < 0 ? 0 : along;
        int by = dy > 0 ? board.Height - 1 : dy < 0 ? 0 : along;
        return (bx, by);
    }

    private static TileRole EdgeRole(MapLayout board, int side, int along)
    {
        var (bx, by) = EdgeTile(board, side, along);
        return board.GetTile(bx, by);
    }

    /// <summary>Halo tile <paramref name="d"/> rings out from edge index <paramref name="along"/>.
    /// Out-of-range indices are returned as-is and rejected by the caller's bounds test.</summary>
    private static (int x, int y) HaloTile(MapLayout board, int margin, int side, int along, int d)
    {
        var (dx, dy) = Sides[side];
        int sx = margin + (dx > 0 ? board.Width - 1 + d : dx < 0 ? -d : along);
        int sy = margin + (dy > 0 ? board.Height - 1 + d : dy < 0 ? -d : along);
        return (sx, sy);
    }

    /// <summary>A stable Perlin sample offset for one noise stream, so two biomes on the same seed
    /// do not sample the same hills. Kept off the lattice points, where Perlin returns 0.5.</summary>
    private static float Offset(int seed, int salt, int channel)
        => MapHash.Hash01(salt, channel, seed) * 251f + 0.37f;
}
