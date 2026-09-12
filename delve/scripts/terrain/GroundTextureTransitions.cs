using System;
using System.Collections.Generic;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>Pixel-sized, palette-matched encroachment where terrain surfaces physically meet.</summary>
internal static class GroundTextureTransitions
{
    internal static void Blend(Image atlas, MapLayout layout, SurfaceType[] surfaces, int tilePixels)
    {
        // Always sample the original paint: traversal order must not feed previous blends back in.
        using var original = (Image)atlas.Duplicate();
        int w = layout.Width, h = layout.Height;
        var neighbors = new List<(int Dx, int Dy, int X, int Y, int Priority)>();
        Span<float> coverage = stackalloc float[5];
        Span<int> donor = stackalloc int[5];
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            int priority = Priority(surfaces[y * w + x]);
            if (priority == 0) continue;
            neighbors.Clear();
            for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++)
            {
                int nx = x + dx, ny = y + dy;
                if (!layout.IsInBounds(nx, ny)) continue;
                int other = Priority(surfaces[ny * w + nx]);
                if (other <= priority || !Touches(layout, x, y, dx, dy)) continue;
                neighbors.Add((dx, dy, nx, ny, other));
            }
            if (neighbors.Count == 0) continue;
            neighbors.Sort((a, b) => a.Priority.CompareTo(b.Priority));
            for (int py = 0; py < tilePixels; py++)
            for (int px = 0; px < tilePixels; px++)
            {
                int gx = x * tilePixels + px, gy = y * tilePixels + py;
                float phase = (uint)layout.Seed % 997 * 0.013f;
                float waviness = MathF.Sin(gx * 0.085f + gy * 0.043f + phase)
                    + 0.5f * MathF.Sin(gy * 0.19f - gx * 0.11f + phase);
                float threshold = 0.25f + waviness * 0.045f
                    + (MapHash.Hash01(gx / 2, gy / 2, layout.Seed + 811) - 0.5f) * 0.09f;
                coverage.Clear();
                donor.Fill(-1);
                for (int i = 0; i < neighbors.Count; i++)
                {
                    var n = neighbors[i];
                    float ax = MathF.Abs(n.Dx + 0.5f - (px + 0.5f) / tilePixels);
                    float ay = MathF.Abs(n.Dy + 0.5f - (py + 0.5f) / tilePixels);
                    float weight = Math.Max(0, 1 - ax) * Math.Max(0, 1 - ay);
                    coverage[n.Priority] += weight;
                    if (weight > 0) donor[n.Priority] = i;
                }
                Color color = original.GetPixel(gx, gy);
                for (int p = priority + 1; p <= 4; p++)
                {
                    if (coverage[p] <= threshold || donor[p] < 0) continue;
                    var n = neighbors[donor[p]];
                    color = original.GetPixel(n.X * tilePixels + px, n.Y * tilePixels + py);
                }
                atlas.SetPixel(gx, gy, color);
            }
        }
    }

    private static int Priority(SurfaceType surface) => surface switch
    {
        SurfaceType.Grass => 4, SurfaceType.Dirt => 3,
        SurfaceType.Mud => 2, SurfaceType.Stone => 1, _ => 0
    };

    private static bool Touches(MapLayout layout, int x, int y, int dx, int dy)
    {
        if (dx == 0 && dy == 0) return false;
        if (dx != 0 && dy != 0)
        {
            // Diagonal growth only wraps a continuous ground corner, never a cliff or deck.
            return Touches(layout, x, y, dx, 0) && Touches(layout, x, y, 0, dy)
                && Touches(layout, x + dx, y, 0, dy)
                && Touches(layout, x, y + dy, dx, 0);
        }
        int nx = x + dx, ny = y + dy;
        if (!layout.IsInBounds(nx, ny) || !LayoutQueries.IsGroundish(layout, (x, y))
            || !LayoutQueries.IsGroundish(layout, (nx, ny))) return false;
        var direction = dx > 0 ? CardinalDirection.East : dx < 0 ? CardinalDirection.West
            : dy > 0 ? CardinalDirection.North : CardinalDirection.South;
        var (a, b) = layout.GetCornerHeights(x, y).EdgeCorners(direction);
        var (na, nb) = LayoutQueries.NeighborEdgeHeights(layout, x, y, direction);
        return a == na && b == nb;
    }
}
