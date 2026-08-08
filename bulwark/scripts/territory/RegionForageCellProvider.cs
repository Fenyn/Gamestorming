using System.Collections.Generic;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Engine-aware <see cref="IForageCellProvider"/> over a 3D territory's AUTHORED walkable region —
/// the seam that keeps Godot types out of <see cref="ForageSystem"/>. It replaces the old painted-
/// tilemap adapter: with the 3D pivot there are no tiles to probe, so the scene hands over the
/// ground rectangle it authored (the %Ground floor collider's XZ footprint, in cells) plus the cells
/// its own world objects occupy.
///
/// Valid spawn cell = inside the ground rect shrunk by <see cref="EdgeMarginCells"/> (spawns never
/// hug the perimeter wall) AND not an occupied cell. Occupancy is scene knowledge — trigger
/// footprints, authored obstacle bodies and their <see cref="BlockMarginCells"/> ring — computed by
/// the territory scene and passed in. Reserved cells (node views, roamer markers) and trail cells
/// (exit trigger, entry spawn — clearance is pass-specific: forage 2, debris 1) are supplied the
/// same way; the system enforces the spacing.
///
/// GRID: one cell is ONE METRE. Cell (x, y) covers world X ∈ [x, x+1), Z ∈ [y, y+1).
/// </summary>
public sealed class RegionForageCellProvider : IForageCellProvider
{
    /// <summary>Cells trimmed off every edge of the authored ground rect (the old "painted rect
    /// shrunk by one ring" rule) so nothing spawns against the perimeter.</summary>
    public const int EdgeMarginCells = 1;

    /// <summary>Cells of clearance added around every occupied cell the scene reports.</summary>
    public const int BlockMarginCells = 1;

    private readonly (int X0, int Y0, int X1, int Y1) _rect;
    private readonly HashSet<(int X, int Y)> _blocked = new();
    private readonly List<(int X, int Y)> _reserved;
    private readonly List<(int X, int Y)> _trail;

    /// <param name="groundCells">The walkable ground rectangle in CELLS (position inclusive, end
    /// exclusive — <see cref="Rect2I"/> semantics).</param>
    /// <param name="occupiedCells">Cells claimed by world objects (trigger footprints, authored
    /// obstacle bodies). Each is blocked together with its <see cref="BlockMarginCells"/> ring.</param>
    public RegionForageCellProvider(
        Rect2I groundCells,
        IEnumerable<(int X, int Y)> occupiedCells,
        IEnumerable<(int X, int Y)> reservedCells,
        IEnumerable<(int X, int Y)> trailCells)
    {
        _rect = (
            groundCells.Position.X + EdgeMarginCells,
            groundCells.Position.Y + EdgeMarginCells,
            groundCells.End.X - 1 - EdgeMarginCells,
            groundCells.End.Y - 1 - EdgeMarginCells);

        foreach (var (x, y) in occupiedCells)
            for (int dx = -BlockMarginCells; dx <= BlockMarginCells; dx++)
                for (int dy = -BlockMarginCells; dy <= BlockMarginCells; dy++)
                    _blocked.Add((x + dx, y + dy));

        _reserved = new List<(int, int)>(reservedCells);
        _trail = new List<(int, int)>(trailCells);
    }

    public (int X0, int Y0, int X1, int Y1) PlayableRect => _rect;

    public IReadOnlyCollection<(int X, int Y)> ReservedCells => _reserved;

    public IReadOnlyCollection<(int X, int Y)> TrailCells => _trail;

    public bool IsOpenGround(int x, int y)
        => x >= _rect.X0 && x <= _rect.X1 && y >= _rect.Y0 && y <= _rect.Y1
           && !_blocked.Contains((x, y));
}
