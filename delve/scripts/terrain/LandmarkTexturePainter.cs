using System.Collections.Generic;
using Godot;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>Continuous stone details across a whole fallen column. Flutes and a fracture
/// follow the construction's axis rather than restarting at each tactical square.</summary>
internal sealed class LandmarkTexturePainter
{
    private readonly Dictionary<string, Rect2I> _columns = new();

    internal LandmarkTexturePainter(MapLayout layout)
    {
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                string? label = layout.GetFeatureLabel(x, y);
                if (label == null || !label.StartsWith("ruined_foundation@", System.StringComparison.Ordinal)) continue;
                var tile = new Rect2I(x, y, 1, 1);
                _columns[label] = _columns.TryGetValue(label, out var bounds) ? bounds.Merge(tile) : tile;
            }
    }

    internal void Paint(Image image, MapLayout layout, int x, int y, int tilePixels)
    {
        string? label = layout.GetFeatureLabel(x, y);
        if (label == null || !_columns.TryGetValue(label, out var bounds)
            || layout.GetSurface(x, y) != SurfaceType.Stone) return;
        bool alongX = bounds.Size.X >= bounds.Size.Y;
        for (int py = 0; py < tilePixels; py++)
            for (int px = 0; px < tilePixels; px++)
            {
                int gx = (x - bounds.Position.X) * tilePixels + px;
                int gy = (y - bounds.Position.Y) * tilePixels + py;
                int along = alongX ? gx : gy, across = alongX ? gy : gx;
                int groove = across % (tilePixels * 2 / 3);
                int fracture = System.Math.Abs(along - tilePixels * 8 + across / 9);
                float grain = MapHash.Hash01(gx / 2, gy / 2, layout.Seed + 719) * 0.055f;
                float shade = groove < 3 ? -0.12f : groove < 5 ? 0.075f : 0;
                if (fracture < 3) shade = -0.19f;
                image.SetPixel(x * tilePixels + px, y * tilePixels + py,
                    new Color(0.57f + grain + shade, 0.56f + grain + shade, 0.49f + grain + shade));
            }
    }
}
