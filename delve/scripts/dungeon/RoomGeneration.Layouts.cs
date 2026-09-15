using System;
using System.Collections.Generic;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class RoomGeneration
{
    private static void AddCombatLayout(MapLayout layout, List<RoomProp> props, RoomFamily family,
        Random rng, RoomVariation profile, int seed)
    {
        int n = layout.Width, mid = n / 2;
        int variant = profile.LayoutVariant >= 0 ? profile.LayoutVariant :
            new Random(Delve.Run.RunRng.StableSeed(seed, 0, "room-arrangement")).Next(3);
        int inset = Math.Clamp(rng.Next(profile.MinPillarInset, profile.MaxPillarInset + 1), 2, mid - 2);
        bool transpose = rng.Next(2) == 0;
        bool Flank(int x, int y) => x >= 2 && y >= 2 && x < n - 2 && y < n - 2 &&
            Math.Abs(x - mid) > 2 && Math.Abs(y - mid) > 2 &&
            !(family == RoomFamily.Guardian && x < 4 && y < 4);

        // Colonnade, broken gallery, or split court. Every layout keeps the
        // doorway cross open, but changes the sight lines and flanking space.
        foreach (int x in new[] { inset, n - 1 - inset })
            foreach (int y in new[] { inset, n - 1 - inset })
            {
                if (!Flank(x, y)) continue;
                bool diagonal = (x < mid) == (y < mid);
                if (variant == 1 && diagonal == transpose || variant == 2 && !diagonal) continue;
                if (family == RoomFamily.Barracks)
                {
                    int dx = transpose ? (x < mid ? -1 : 1) : 0, dy = transpose ? 0 : (y < mid ? -1 : 1);
                    if (!Flank(x + dx, y + dy)) continue;
                    Set(layout, x, y, TileRole.Wall, 0);
                    Set(layout, x + dx, y + dy, TileRole.Wall, 0);
                    props.Add(new("bed", x + 0.5f + dx * 0.5f, y + 0.5f + dy * 0.5f, 0.9f, 1.8f, 0.4f, transpose ? 90 : 0));
                }
                else
                {
                    Set(layout, x, y, TileRole.Wall, 12);
                    props.Add(new("column", x + 0.5f, y + 0.5f, 1, 1, 1.5f));
                }
            }

        if (family == RoomFamily.Cistern)
        {
            for (int y = 3; y < n - 3; y++)
                for (int x = 3; x < n - 3; x++)
                {
                    bool basin = variant switch
                    {
                        0 => x >= mid - 1 && x <= mid && Math.Abs(y - mid) > 2,
                        1 => Flank(x, y) && (x < mid) == (y < mid) && x >= 3 && y >= 3,
                        _ => y >= mid - 1 && y <= mid && Math.Abs(x - mid) > 2
                    };
                    if (transpose) basin = variant == 0
                        ? y >= mid - 1 && y <= mid && Math.Abs(x - mid) > 2 : basin;
                    if (!basin || layout.GetTile(x, y) != TileRole.Ground) continue;
                    Set(layout, x, y, TileRole.Water, 0);
                    layout.SetSurface(x, y, SurfaceType.Water);
                }
            for (int y = 1; y < n - 1; y++)
                for (int x = 1; x < n - 1; x++)
                    if (layout.GetTile(x, y) == TileRole.Water)
                        foreach (var (dx, dy) in new[] { (1, 0), (-1, 0), (0, 1), (0, -1) })
                            if (layout.GetTile(x + dx, y + dy) != TileRole.Water)
                                props.Add(new("water_rim", x + 0.5f + dx * 0.46f, y + 0.5f + dy * 0.46f,
                                    0.92f, 0.08f, 0.12f, dx == 0 ? 0 : 90));
            return;
        }

        // A raised flank offers an alternate route around the low obstacles.
        if (variant == 2)
            for (int y = 2; y < n - 2; y++)
                for (int x = 2; x < n - 2; x++)
                    if (Flank(x, y) && (x < mid) != (y < mid) && layout.GetTile(x, y) == TileRole.Ground)
                    {
                        Set(layout, x, y, TileRole.Ground, 4);
                        if (family == RoomFamily.Barracks) layout.SetSurface(x, y, SurfaceType.Wood);
                    }

        // Sample legal candidates without replacement. The old random attempts
        // often produced no cover at all because they landed in protected lanes.
        var candidates = new List<(int X, int Y)>();
        for (int y = 2; y < n - 2; y++)
            for (int x = 2; x < n - 2; x++)
                if (Flank(x, y) && layout.GetTile(x, y) == TileRole.Ground && layout.GetElevation(x, y) == 0)
                    candidates.Add((x, y));
        int count = rng.Next(profile.MinCover, profile.MaxCover + 1);
        for (int i = 0; i < count && candidates.Count > 0; i++)
        {
            int index = rng.Next(candidates.Count);
            var (x, y) = candidates[index];
            candidates.RemoveAt(index);
            Set(layout, x, y, TileRole.Cover, 4);
            props.Add(new("cover_trim", x + 0.5f, y + 0.5f, 1, 1, 0.5f, rng.Next(4) * 90));
        }
    }
}
