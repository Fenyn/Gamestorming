using Bulwark.Data;
using PF2e.Grid;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat.Map;

/// <summary>
/// The elevation half of grid &lt;-&gt; world math: turns a generated <see cref="MapLayout"/>'s corner
/// heights into the world Y the 3D view places things at. Everything that has to stand on, hover over,
/// or look at terrain (unit tokens, highlight quads, movement tweens, the camera pivot) reads its Y
/// from here, so one instance is the single source of vertical truth for one encounter.
///
/// <b>An instance, never a static.</b> A process-wide height map would leak the previous encounter's
/// terrain into the next one and would quietly poison headless spikes that never build a map at all.
/// <see cref="CombatScene"/> constructs exactly one per encounter and threads it through.
///
/// <b><see cref="Flat"/> is the null object.</b> A flat board is not "no height map": it is the
/// all-zeros one. Call sites therefore take a NON-nullable <c>TerrainHeightMap</c> and never write
/// <c>?? 0</c>, which is the shape of bug that would otherwise appear at every new call site.
/// </summary>
public sealed class TerrainHeightMap
{
    /// <summary>
    /// The all-zeros height map for a flat board (no layout). Immutable and stateless, so a single
    /// shared instance is safe across encounters and threads.
    /// </summary>
    public static readonly TerrainHeightMap Flat = new();

    private readonly MapLayout? _layout;

    /// <param name="layout">The generated layout to read corner heights from.</param>
    /// <param name="heightScale">World Y per corner-height unit — <see cref="MapThemeDefinition.HeightScale"/>.</param>
    public TerrainHeightMap(MapLayout layout, float heightScale)
    {
        System.ArgumentNullException.ThrowIfNull(layout);
        _layout = layout;
        HeightScale = heightScale;
        MeanCenterY = ComputeMeanCenterY(layout, heightScale);
    }

    private TerrainHeightMap()
    {
        _layout = null;
        HeightScale = 0f;
        MeanCenterY = 0f;
    }

    /// <summary>False for <see cref="Flat"/>: there is no layout, every height is 0.</summary>
    public bool HasTerrain => _layout != null;

    /// <summary>World Y per corner-height unit. 0 for <see cref="Flat"/>.</summary>
    public float HeightScale { get; }

    /// <summary>
    /// Mean walkable centre height in world units — the camera pivot's Y, so the orbit stays level with
    /// the ground the fight happens on rather than with an arbitrary y = 0. 0 for <see cref="Flat"/>
    /// and for a layout with no walkable tiles.
    /// </summary>
    public float MeanCenterY { get; }

    /// <summary>
    /// World Y a unit standing on tile <paramref name="p"/> plants its feet at: the tile's mean corner
    /// height scaled to world units. Out-of-bounds tiles (and every tile of <see cref="Flat"/>) are 0 —
    /// the same answer <see cref="MapLayout.GetCornerHeights"/> gives, so off-board queries during
    /// deployment self-heal or a hover past the map edge degrade to ground level instead of throwing.
    /// </summary>
    public float CenterY(PF2eVec p)
    {
        if (_layout == null || !_layout.IsInBounds(p.x, p.y)) return 0f;
        return _layout.GetCornerHeights(p.x, p.y).CenterHeight * HeightScale;
    }

    /// <summary>
    /// The tile's four corner heights, in raw corner units (NOT world units — multiply by
    /// <see cref="HeightScale"/>). Out-of-bounds and <see cref="Flat"/> give a flat-zero tile, so a
    /// conforming overlay mesh built on one degrades to the horizontal quad it would have been.
    /// </summary>
    public TileCornerHeights Corners(PF2eVec p)
    {
        if (_layout == null || !_layout.IsInBounds(p.x, p.y)) return TileCornerHeights.Flat(0);
        return _layout.GetCornerHeights(p.x, p.y);
    }

    private static float ComputeMeanCenterY(MapLayout layout, float heightScale)
    {
        double sum = 0;
        int count = 0;
        for (int y = 0; y < layout.Height; y++)
        {
            for (int x = 0; x < layout.Width; x++)
            {
                // Walls and void are deliberately excluded: a chasm floor at -40 or a 16-unit wall cap
                // would drag the pivot off the ground the party actually fights on.
                if (!layout.IsWalkable(x, y)) continue;
                sum += layout.GetCornerHeights(x, y).CenterHeight;
                count++;
            }
        }
        return count == 0 ? 0f : (float)(sum / count) * heightScale;
    }
}
