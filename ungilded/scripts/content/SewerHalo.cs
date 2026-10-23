using System;
using PF2e.MapGen;
using Ungilded.Terrain;

namespace Ungilded.Content;

/// <summary>A board edge, named by the direction that leads off the board.</summary>
public enum BoardSide
{
    West,
    East,
    South,
    North,
}

/// <summary>
/// Paints the halo of an authored sewer board into a <see cref="HaloPlan"/>: open floor, water,
/// sludge, steps and footbridges outside the board, runs that carry a board edge on to the rim, and
/// dressing marks. Coordinates are board coordinates; a cell inside the board is a content error.
/// </summary>
internal sealed class SewerHalo
{
    private readonly MapLayout _board;
    private readonly int _waterLevel;

    public SewerHalo(MapLayout board, int waterLevel)
    {
        _board = board;
        _waterLevel = waterLevel;
    }

    public HaloPlan Plan { get; } = new();

    public void Floor(int x0, int y0, int x1, int y1, int floor)
        => Fill(x0, y0, x1, y1, new HaloCell(TileRole.Ground, SurfaceType.Stone, floor));

    public void Water(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, new HaloCell(TileRole.Water, SurfaceType.Water, _waterLevel));

    /// <summary>Masonry again where an earlier call opened the halo: a pier on a ledge.</summary>
    public void Wall(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, new HaloCell(TileRole.Wall, SurfaceType.Stone, 0));

    /// <summary>A stone deck one unit above the floor, over the channel it crosses.</summary>
    public void Bridge(int x0, int y0, int x1, int y1)
        => Fill(x0, y0, x1, y1, new HaloCell(TileRole.Bridge, SurfaceType.Stone, 1));

    /// <summary>
    /// Carries board edge tiles <paramref name="from"/>..<paramref name="to"/> (along the edge) out
    /// past the rim: floor stays floor, water and sludge keep their level, a wall edge tile stays
    /// closed. Reads the board as painted so far. A floor run rises
    /// <paramref name="rise"/> units per ring, a passage that climbs away from the board. The first
    /// halo tile of a water or sludge run gets a <see cref="SewerBoard.CulvertMark"/>.
    /// </summary>
    public void Run(BoardSide side, int from, int to, int rise)
    {
        for (int a = from; a <= to; a++)
        {
            var (ex, ey) = EdgeTile(side, a);
            var source = _board.GetTile(ex, ey);
            if (source == TileRole.Wall) continue;
            if (source is TileRole.Water or TileRole.DifficultTerrain)
            {
                var (mx, my) = Out(side, ex, ey, 1);
                Plan.Mark(SewerBoard.CulvertMark, mx, my);
            }
            for (int d = 1; d <= HaloPlan.Reach; d++)
            {
                var (x, y) = Out(side, ex, ey, d);
                Plan.Set(x, y, source switch
                {
                    TileRole.Water => new HaloCell(TileRole.Water, SurfaceType.Water, _waterLevel),
                    TileRole.DifficultTerrain => new HaloCell(TileRole.DifficultTerrain, _board.GetSurface(ex, ey), 0),
                    _ => new HaloCell(TileRole.Ground, SurfaceType.Stone, rise * d),
                });
            }
        }
    }

    public void Flow(BoardSide side) => Plan.Flow = Out(side, 0, 0, 1);

    public void Mark(string kind, int x, int y)
    {
        RequireOutside(x, y);
        Plan.Mark(kind, x, y);
    }

    private void Fill(int x0, int y0, int x1, int y1, HaloCell cell)
    {
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                RequireOutside(x, y);
                Plan.Set(x, y, cell);
            }
    }

    private void RequireOutside(int x, int y)
    {
        if (_board.IsInBounds(x, y))
            throw new ArgumentOutOfRangeException($"({x}, {y}) is on the board '{_board.Name}', not in its halo.");
    }

    private (int X, int Y) EdgeTile(BoardSide side, int along) => side switch
    {
        BoardSide.West => (0, along),
        BoardSide.East => (_board.Width - 1, along),
        BoardSide.South => (along, 0),
        _ => (along, _board.Height - 1),
    };

    private static (int X, int Y) Out(BoardSide side, int x, int y, int d) => side switch
    {
        BoardSide.West => (x - d, y),
        BoardSide.East => (x + d, y),
        BoardSide.South => (x, y - d),
        _ => (x, y + d),
    };
}
