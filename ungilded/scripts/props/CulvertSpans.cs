using System.Collections.Generic;
using System.Linq;
using Ungilded.Content;
using Ungilded.Look;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>
/// One mouth where a channel or the sludge leaves the board: the first-ring halo tiles of the run
/// (skirt coordinates, in order along the board edge), whether that edge runs along x, which way
/// along the other axis is outward, and the coordinate of the mouth's board-side edge on that axis.
/// </summary>
public sealed record CulvertSpan(List<(int X, int Y)> Tiles, bool AlongX, int OutwardSign, float InnerEdge)
{
    /// <summary>The tiles just past each end of the span along the board edge.</summary>
    public ((int X, int Y) Before, (int X, int Y) After) Flanks()
    {
        var (sx, sy) = AlongX ? (1, 0) : (0, 1);
        return ((Tiles[0].X - sx, Tiles[0].Y - sy), (Tiles[^1].X + sx, Tiles[^1].Y + sy));
    }

    /// <summary>The flank tiles on both sides of the mouth across <paramref name="depth"/> rings,
    /// outward from the first: the masonry an arch of that depth springs from.</summary>
    public IEnumerable<(int X, int Y)> Jambs(int depth)
    {
        var (before, after) = Flanks();
        var (ox, oy) = AlongX ? (0, OutwardSign) : (OutwardSign, 0);
        for (int d = 0; d < depth; d++)
        {
            yield return (before.X + ox * d, before.Y + oy * d);
            yield return (after.X + ox * d, after.Y + oy * d);
        }
    }

    /// <summary>One bit per camera quadrant (<see cref="CutawayMap.Quadrant"/>) whose camera sits on
    /// the board side of the mouth, looking out through it.</summary>
    public int InwardQuadrants()
    {
        int bits = 0;
        for (int q = 0; q < 4; q++)
        {
            int side = AlongX ? ((q & 2) != 0 ? -1 : 1) : ((q & 1) != 0 ? -1 : 1);
            if (side != OutwardSign) bits |= 1 << q;
        }
        return bits;
    }
}

/// <summary>Groups the <see cref="SewerBoard.CulvertMark"/> marks of an authored halo into mouths.</summary>
public static class CulvertSpans
{
    public static IEnumerable<CulvertSpan> Find(DressingContext context)
    {
        if (context.Skirt.Plan is not { } plan) yield break;
        int m = context.Skirt.Margin, w = context.Board.Width, h = context.Board.Height;
        var marks = plan.Marks.Where(k => k.Kind == SewerBoard.CulvertMark);
        foreach (var side in marks.GroupBy(k => k.Y < 0 ? 0 : k.Y >= h ? 1 : k.X < 0 ? 2 : 3))
        {
            bool alongX = side.Key < 2;
            int sign = side.Key is 0 or 2 ? -1 : 1;
            var tiles = side.Select(k => (X: k.X + m, Y: k.Y + m)).OrderBy(t => alongX ? t.X : t.Y).ToList();
            var span = new List<(int X, int Y)>();
            foreach (var tile in tiles)
            {
                if (span.Count > 0 && (alongX ? tile.X : tile.Y) != (alongX ? span[^1].X : span[^1].Y) + 1)
                {
                    yield return Make(span, alongX, sign);
                    span = new List<(int X, int Y)>();
                }
                span.Add(tile);
            }
            if (span.Count > 0) yield return Make(span, alongX, sign);
        }
    }

    private static CulvertSpan Make(List<(int X, int Y)> tiles, bool alongX, int sign)
    {
        int depthCoord = alongX ? tiles[0].Y : tiles[0].X;
        return new CulvertSpan(tiles, alongX, sign, sign < 0 ? depthCoord + 1 : depthCoord);
    }
}
