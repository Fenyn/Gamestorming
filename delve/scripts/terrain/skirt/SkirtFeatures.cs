using System;
using System.Collections.Generic;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// Decides WHAT each halo tile is: role and surface, plus the level of any water it carries. Height
/// is <see cref="SkirtHeights"/>'s job and runs after, because a river's level freezes the vertices
/// under its banks.
///
/// Five passes, each one overriding the last where it applies:
///   1. Inherit  — every halo tile takes the role and surface of the nearest board edge tile,
///                 dissolving toward the biome's plain ground as the rings recede.
///   2. Patches  — a second-octave Perlin field scatters difficult terrain over open ground.
///   3. Rivers   — a run of water leaving the board edge carries on outward and tapers closed
///                 (<see cref="SkirtContinuations"/>).
///   4. Canyons  — a run of void leaving the board edge does the same.
///   5. Growth   — trees thicken outward (open biomes), or the vault seals shut around a few
///                 corridors (enclosed biomes).
/// </summary>
internal static class SkirtFeatures
{
    // Distinct hash / noise streams off the one layout seed.
    private const int TreeSalt = 0x5B17;
    private const int PatchSalt = 0x2C4D;
    private const int DissolveSalt = 0x6E2B;

    /// <summary>Rings that copy the board edge faithfully before the dissolve starts. The first
    /// ring must join exactly; the second keeps the join from reading as a one-tile picture frame.</summary>
    private const int FaithfulRings = 2;

    internal static void Paint(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, int[] waterUnits,
        List<(int X, int Y)> trees)
    {
        Inherit(skirt, board, style, margin);
        Patches(skirt, board, style, margin);
        SkirtContinuations.Rivers(skirt, board, style, margin, waterUnits);
        SkirtContinuations.Canyons(skirt, board, margin);
        Growth(skirt, board, style, margin, waterUnits, trees);
    }

    // ─────────────────────────── 1. inherit ───────────────────────────

    /// <summary>
    /// Base coat: the nearest board edge tile's role and surface continue outward. Only the four
    /// roles the halo is allowed to show survive — cover, bridges and void become open ground,
    /// because a boulder or a plank does not tile outward into the distance. Water is dropped here
    /// too: the river pass paints it, so it can meander instead of running dead straight.
    /// A board edge wall (a tree at the map's edge) continues for ONE ring only; past that the tree
    /// scatter decides, which keeps a board-edge tree line from streaking to the horizon.
    ///
    /// Past <see cref="FaithfulRings"/> the inheritance DISSOLVES: each tile rolls once against a
    /// chance that grows toward the rim, and a dissolved tile becomes the biome's plain ground. A
    /// stone plaza or a marsh at the board edge stays honest beside the board, then breaks up into
    /// ordinary terrain instead of streaking to the rim and being sliced by the mesh edge.
    /// </summary>
    private static void Inherit(MapLayout skirt, MapLayout board, SkirtStyle style, int margin)
    {
        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                int d = SkirtLayout.TileRing(sx, sy, margin, board);
                if (d == 0) continue;

                var (bx, by) = SkirtLayout.NearestBoardTile(sx, sy, margin, board);
                var source = board.GetTile(bx, by);

                TileRole role;
                SurfaceType surface;
                if (source == TileRole.DifficultTerrain)
                {
                    (role, surface) = (TileRole.DifficultTerrain, board.GetSurface(bx, by));
                }
                else if (source == TileRole.Wall && d == 1)
                {
                    (role, surface) = (TileRole.Wall, board.GetSurface(bx, by));
                }
                else if (source == TileRole.Ground)
                {
                    (role, surface) = (TileRole.Ground, board.GetSurface(bx, by));
                }
                else
                {
                    (role, surface) = (TileRole.Ground, style.GroundSurface);
                }

                if (role != TileRole.Wall && Dissolved(sx, sy, d, margin, board.Seed))
                    (role, surface) = (TileRole.Ground, style.GroundSurface);

                Set(skirt, sx, sy, role, surface);
            }
        }
    }

    /// <summary>One roll per tile: the chance of falling back to plain ground grows linearly from
    /// zero inside the faithful rings to certainty at the rim, so the rim always matches the
    /// backdrop's ground plane.</summary>
    private static bool Dissolved(int sx, int sy, int d, int margin, int seed)
    {
        if (d <= FaithfulRings) return false;
        float chance = (d - FaithfulRings) / (float)(margin - FaithfulRings);
        return MapHash.Hash01(sx, sy, seed + DissolveSalt) < chance;
    }

    // ─────────────────────────── 2. difficult patches ───────────────────────────

    private static void Patches(MapLayout skirt, MapLayout board, SkirtStyle style, int margin)
    {
        if (style.DifficultPatchChance <= 0f) return;

        float threshold = 1f - style.DifficultPatchChance;
        float frequency = Math.Max(2f, style.HillFrequency * 0.5f);
        float ox = Offset(board.Seed, PatchSalt, 0);
        float oy = Offset(board.Seed, PatchSalt, 1);

        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                if (SkirtLayout.TileRing(sx, sy, margin, board) == 0) continue;
                if (skirt.GetTile(sx, sy) != TileRole.Ground) continue;

                float n = MapGenMath.PerlinNoise(sx / frequency + ox, sy / frequency + oy);
                if (n > threshold) Set(skirt, sx, sy, TileRole.DifficultTerrain, style.DifficultSurface);
            }
        }
    }

    // ─────────────────────────── 5. trees / enclosure ───────────────────────────

    private static void Growth(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, int[] waterUnits,
        List<(int X, int Y)> trees)
    {
        if (style.WallRings > 0) Enclose(skirt, board, style, margin, waterUnits);
        else Trees(skirt, board, style, margin, trees);
    }

    /// <summary>
    /// Open biome: scatter tree SPOTS, thickening with distance. The tiles themselves stay what
    /// they are — the renderer stands a billboard tree prop on each spot, so the halo woodland is
    /// sprites over rolling ground instead of the raised wall blocks that read as burial mounds.
    /// Never on the first ring (the board keeps its sight lines), never beside water (a river stays
    /// a river instead of a tunnel), and never over a continued canyon.
    /// </summary>
    private static void Trees(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, List<(int X, int Y)> trees)
    {
        if (style.TreeDensityNear <= 0f && style.TreeDensityFar <= 0f) return;

        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                int d = SkirtLayout.TileRing(sx, sy, margin, board);
                if (d < 2) continue;

                var role = skirt.GetTile(sx, sy);
                if (role is not (TileRole.Ground or TileRole.DifficultTerrain)) continue;
                if (NearWater(skirt, sx, sy)) continue;

                float t = (float)d / margin;
                float chance = style.TreeDensityNear + (style.TreeDensityFar - style.TreeDensityNear) * t;
                if (MapHash.Hash01(sx, sy, board.Seed + TreeSalt) < chance)
                    trees.Add((sx, sy));
            }
        }
    }

    /// <summary>
    /// Enclosed biome: the halo is solid wall. The only openings are corridors continuing a board
    /// edge tile that is walkable or water — one tile wide, straight out, sealed after
    /// <c>WallRings + 1</c> rings so the eye reads passages leading away, not an open field.
    /// </summary>
    private static void Enclose(
        MapLayout skirt, MapLayout board, SkirtStyle style, int margin, int[] waterUnits)
    {
        int openRings = style.WallRings + 1;

        for (int sy = 0; sy < skirt.Height; sy++)
        {
            for (int sx = 0; sx < skirt.Width; sx++)
            {
                int d = SkirtLayout.TileRing(sx, sy, margin, board);
                if (d == 0) continue;

                if (d <= openRings && SkirtLayout.OnStraightSide(sx, sy, margin, board))
                {
                    var (bx, by) = SkirtLayout.NearestBoardTile(sx, sy, margin, board);
                    var source = board.GetTile(bx, by);
                    var here = skirt.GetTile(sx, sy);
                    bool corridor = source is TileRole.Ground or TileRole.Water
                                    && here is TileRole.Ground or TileRole.DifficultTerrain
                                        or TileRole.Water;
                    if (corridor) continue;
                }

                Set(skirt, sx, sy, TileRole.Wall, style.WallSurface);
                waterUnits[sy * skirt.Width + sx] = SkirtLayout.NoWater;
            }
        }
    }

    // ─────────────────────────── helpers ───────────────────────────

    private static bool NearWater(MapLayout skirt, int sx, int sy)
    {
        for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++)
                if (skirt.GetTile(sx + ox, sy + oy) == TileRole.Water) return true;
        return false;
    }

    private static void Set(MapLayout skirt, int sx, int sy, TileRole role, SurfaceType surface)
    {
        skirt.SetTile(sx, sy, role);
        skirt.SetSurface(sx, sy, surface);
    }

    /// <summary>A stable Perlin sample offset for one noise stream, so two biomes on the same seed
    /// do not sample the same hills. Kept off the lattice points, where Perlin returns 0.5.</summary>
    private static float Offset(int seed, int salt, int channel)
        => MapHash.Hash01(salt, channel, seed) * 251f + 0.37f;
}
