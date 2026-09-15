using System;
using System.Collections.Generic;
using System.Linq;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class RoomGeneration
{
    private sealed record FeatureRecipe(SurfaceType Patch, string[] Furnishings, bool Raised = false);
    private static readonly IReadOnlyDictionary<RoomFamily, FeatureRecipe> Features =
        new Dictionary<RoomFamily, FeatureRecipe>
        {
            [RoomFamily.Entrance] = new(SurfaceType.Dirt, new[] { "supplies", "rack" }),
            [RoomFamily.GuardHall] = new(SurfaceType.Stone, new[] { "rack", "brazier" }),
            [RoomFamily.Barracks] = new(SurfaceType.Wood, new[] { "supplies", "rack" }),
            [RoomFamily.Cistern] = new(SurfaceType.Mud, new[] { "pipe", "barrel" }),
            [RoomFamily.Collapse] = new(SurfaceType.Dirt, new[] { "rubble", "supplies" }),
            [RoomFamily.Shrine] = new(SurfaceType.Stone, new[] { "votive", "urn" }, true),
            [RoomFamily.Cache] = new(SurfaceType.Wood, new[] { "supplies", "barrel" }),
            [RoomFamily.Camp] = new(SurfaceType.Dirt, new[] { "barrel", "supplies" }),
            [RoomFamily.Elite] = new(SurfaceType.Stone, new[] { "brazier", "rack" }, true),
            [RoomFamily.Guardian] = new(SurfaceType.Stone, new[] { "votive", "urn" }, true)
        };

    private static void AddFeatures(MapLayout layout, List<RoomProp> props, RoomFamily family,
        int seed, bool baseline, int count)
    {
        int n = layout.Width, mid = n / 2;
        var recipe = Features[family];
        var rng = new Random(Delve.Run.RunRng.StableSeed(seed, 0, "room-features"));
        // Surface wear follows compact patches, leaving the central travel cross clean.
        int cornerX = rng.Next(2) == 0 ? 2 : n - 5;
        int cornerY = rng.Next(2) == 0 ? 2 : n - 5;
        var focal = props.FirstOrDefault(p => p.Kind is "shrine" or "cache" or "camp" or "collapse" or "entrance");
        if (focal != null)
        {
            cornerX = Math.Clamp((int)focal.X - 1, 2, n - 5);
            cornerY = Math.Clamp((int)focal.Y - 1, 2, n - 5);
        }
        for (int y = cornerY; y < cornerY + 3; y++)
            for (int x = cornerX; x < cornerX + 3; x++)
            {
                if (Math.Abs(x - mid) <= 2 || Math.Abs(y - mid) <= 2 || layout.GetTile(x, y) != TileRole.Ground) continue;
                layout.SetSurface(x, y, recipe.Patch);
                if (recipe.Raised && !baseline)
                {
                    layout.SetCornerHeights(x, y, TileCornerHeights.Flat(4));
                    layout.SetElevation(x, y, 1);
                }
            }

        if (baseline) return;
        // Every freestanding furnishing is contained in one reserved wall tile.
        var candidates = new List<(int X, int Y)>();
        for (int y = 1; y < n - 1; y++)
            for (int x = 1; x < n - 1; x++)
                if ((x == 1 || x == n - 2 || y == 1 || y == n - 2) &&
                    Math.Abs(x - mid) > 2 && Math.Abs(y - mid) > 2 && layout.GetTile(x, y) == TileRole.Ground)
                    candidates.Add((x, y));
        for (int i = 0; i < count && candidates.Count > 0; i++)
        {
            // Arrange two small groups instead of isolated props on random walls.
            int anchorX = i < (count + 1) / 2 ? cornerX : n - 1 - cornerX;
            int anchorY = i < (count + 1) / 2 ? cornerY : n - 1 - cornerY;
            candidates.Sort((a, b) =>
            {
                int distance = (Math.Abs(a.X - anchorX) + Math.Abs(a.Y - anchorY)).CompareTo(Math.Abs(b.X - anchorX) + Math.Abs(b.Y - anchorY));
                return distance != 0 ? distance : (a.Y * n + a.X).CompareTo(b.Y * n + b.X);
            });
            int index = rng.Next(Math.Min(4, candidates.Count));
            var (x, y) = candidates[index];
            candidates.RemoveAt(index);
            Set(layout, x, y, TileRole.Wall, 0);
            // A group must not fence off a corner floor tile. Reject this
            // furnishing rather than discarding the room's tactical layout.
            if (!Validate(new GeneratedRoom(layout, props, Array.Empty<DoorSide>())))
            {
                Set(layout, x, y, TileRole.Ground, 0);
                i--;
                continue;
            }
            props.Add(new(recipe.Furnishings[rng.Next(recipe.Furnishings.Length)], x + 0.5f, y + 0.5f,
                0.85f, 0.85f, 1.2f, x == 1 ? 90 : x == n - 2 ? -90 : y == 1 ? 0 : 180));
        }
    }
}
