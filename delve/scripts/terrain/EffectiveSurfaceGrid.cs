using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>
/// The surface grid the board is actually dressed from: the layout's own surfaces plus two
/// readability overrides. Computed once per build and handed to every consumer, so the ground
/// texture, the cliff materials and the top faces can never disagree about what a tile is.
/// </summary>
public static class EffectiveSurfaceGrid
{
    /// <summary>
    /// Build the effective-surface grid for a layout, row-major (index = y * Width + x).
    ///
    /// Override 1: cover blocks keep a clean grass top. Mapgen often surfaces them as dirt, and a
    /// lone fringed dirt blob on a raised square reads as a random splotch rather than a mossy
    /// boulder with grass on top.
    ///
    /// Override 2: grass at the waterline becomes bank dirt. The fringe machinery then paints the
    /// grass-to-dirt blend along every shore automatically — a continuous worn riverbank instead of
    /// grass butting straight into the water cliff.
    /// </summary>
    public static SurfaceType[] Build(MapLayout layout)
    {
        System.ArgumentNullException.ThrowIfNull(layout);

        int w = layout.Width, h = layout.Height;
        var eff = new SurfaceType[w * h];

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            var surface = layout.GetSurface(x, y);
            if (layout.GetTile(x, y) == TileRole.Cover &&
                surface is SurfaceType.Dirt or SurfaceType.Mud)
            {
                surface = SurfaceType.Grass;
            }
            eff[y * w + x] = surface;
        }

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            if (eff[y * w + x] != SurfaceType.Grass || layout.GetTile(x, y) != TileRole.Ground)
                continue;
            bool water =
                IsWater(layout, x, y - 1) || IsWater(layout, x, y + 1) ||
                IsWater(layout, x - 1, y) || IsWater(layout, x + 1, y);
            if (water)
                eff[y * w + x] = SurfaceType.Dirt;
        }

        return eff;

        static bool IsWater(MapLayout l, int x, int y) => l.SurfaceAt(x, y) == SurfaceType.Water;
    }
}
