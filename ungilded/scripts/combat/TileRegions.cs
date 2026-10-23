using System;
using System.Collections.Generic;
using System.Linq;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>An inclusive block of tiles at one surface height.</summary>
public readonly record struct TileBlock(int X0, int Y0, int X1, int Y1, float Height);

/// <summary>Splits a tile set into few rectangular blocks, each at one surface height, so a
/// cutout over many tiles needs one quad per block instead of one per tile.</summary>
public static class TileRegions
{
    /// <summary>Runs along each row, merged down while the next row has the same run at the same height.</summary>
    public static List<TileBlock> Blocks(IEnumerable<PF2eVec> tiles, Func<PF2eVec, float> height)
    {
        var set = new HashSet<PF2eVec>(tiles);
        var runs = new List<TileBlock>();
        foreach (var row in set.GroupBy(t => t.y).OrderBy(g => g.Key))
        {
            var xs = row.Select(t => t.x).OrderBy(x => x).ToArray();
            int start = 0;
            for (int i = 1; i <= xs.Length; i++)
            {
                bool breaks = i == xs.Length || xs[i] != xs[i - 1] + 1
                    || !SameHeight(height(new PF2eVec(xs[i], row.Key)), height(new PF2eVec(xs[start], row.Key)));
                if (!breaks) continue;
                runs.Add(new TileBlock(xs[start], row.Key, xs[i - 1], row.Key, height(new PF2eVec(xs[start], row.Key))));
                start = i;
            }
        }
        var blocks = new List<TileBlock>();
        foreach (var run in runs)
        {
            int index = blocks.FindIndex(b => b.X0 == run.X0 && b.X1 == run.X1 && b.Y1 == run.Y0 - 1 && SameHeight(b.Height, run.Height));
            if (index >= 0) blocks[index] = blocks[index] with { Y1 = run.Y1 };
            else blocks.Add(run);
        }
        return blocks;
    }

    /// <summary>One block around every tile, at their mean height: the fallback when a set splits
    /// into more blocks than a cutout can draw.</summary>
    public static TileBlock Bounds(IReadOnlyCollection<PF2eVec> tiles, Func<PF2eVec, float> height)
        => new(tiles.Min(t => t.x), tiles.Min(t => t.y), tiles.Max(t => t.x), tiles.Max(t => t.y), tiles.Average(height));

    private static bool SameHeight(float a, float b) => MathF.Abs(a - b) < HeightTolerance;

    /// <summary>Metres: surface heights closer than this count as one level.</summary>
    private const float HeightTolerance = 0.01f;
}
