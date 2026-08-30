namespace Delve.Terrain;

/// <summary>
/// The one tile-decision hash the map dressing uses. Every scatter decision (edge scenery, tile
/// decor, ground-texture variant picks) reads from it, so the same layout seed always dresses a
/// board the same way. Pure integer math — no RNG object, no order dependency.
/// </summary>
public static class MapHash
{
    /// <summary>
    /// A value in [0, 1) for the (a, b, seed) triple. Distinct salts added to the seed give
    /// independent streams for different decisions on the same tile.
    /// </summary>
    public static float Hash01(int a, int b, int seed)
    {
        unchecked
        {
            uint h = (uint)seed * 374761393u + (uint)a * 668265263u + (uint)b * 974634321u;
            h = (h ^ (h >> 13)) * 1274126177u;
            h ^= h >> 16;
            return (h & 0xFFFFFFu) * (1f / 0x1000000);
        }
    }
}
