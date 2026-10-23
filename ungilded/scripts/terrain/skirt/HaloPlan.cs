using System.Collections.Generic;
using PF2e.MapGen;

namespace Ungilded.Terrain;

/// <summary>One authored halo tile: what it is and the corner height of its floor (for water, the
/// surface; for a wall, the ground it stands on).</summary>
public readonly record struct HaloCell(TileRole Role, SurfaceType Surface, int Floor);

/// <summary>A dressing marker in board coordinates: a named prop the look places at that tile
/// ("outfall", "grate", "skeleton").</summary>
public readonly record struct HaloMark(string Kind, int X, int Y);

/// <summary>
/// An authored halo: the tiles around a board, in board coordinates (x &lt; 0, y &lt; 0, x ≥ width
/// or y ≥ height). Every halo tile the plan does not name is wall. A run that should reach the rim
/// is painted out to <see cref="Reach"/>; <see cref="SkirtLayout"/> keeps what fits its margin.
/// Engine-free, like <see cref="SkirtStyle"/>.
/// </summary>
public sealed class HaloPlan
{
    /// <summary>Rings a run to the rim is painted out to. Larger than any skirt margin.</summary>
    public const int Reach = 24;

    private readonly Dictionary<(int X, int Y), HaloCell> _cells = new();
    private readonly List<HaloMark> _marks = new();

    public IReadOnlyDictionary<(int X, int Y), HaloCell> Cells => _cells;

    public IReadOnlyList<HaloMark> Marks => _marks;

    /// <summary>The one board-coordinate step every run of water and sludge on the board flows
    /// along, or (0, 0) when the map authors none.</summary>
    public (int X, int Y) Flow { get; set; }

    public void Set(int x, int y, HaloCell cell) => _cells[(x, y)] = cell;

    public void Mark(string kind, int x, int y) => _marks.Add(new HaloMark(kind, x, y));
}
