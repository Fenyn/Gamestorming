using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.MapGen;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>What an opening in the board outline is: a floor passage that runs on, a shallow
/// recess (a niche, a bay, the apse), or a culvert carrying water or sludge away.</summary>
public enum OpeningKind
{
    Passage,
    Recess,
    Culvert,
}

/// <summary>
/// An opening in the board's outline: a span of open first-ring halo tiles with wall on both ends.
/// <see cref="First"/> is the span's first first-ring tile (skirt coordinates), <see cref="Along"/>
/// steps along the board edge, <see cref="Out"/> leads off the board. A span with floor in it is a
/// passage when it runs at least the passage depth out and a recess when it stops short; a span
/// with no floor is a culvert.
/// </summary>
public sealed record SewerOpening(Vector2I First, Vector2I Along, Vector2I Out, int Width, int Depth, OpeningKind Kind)
{
    /// <summary>A passage or a culvert: a way in or out that a torch marks.</summary>
    public bool Mouth => Kind is OpeningKind.Passage or OpeningKind.Culvert;

    /// <summary>A mouth, or a recess at least <see cref="SewerWalls.BayDepth"/> deep (a bay, the
    /// apse): an opening whose jamb takes a torch. A one-tile niche takes none.</summary>
    public bool Lit => Mouth || Depth >= SewerWalls.BayDepth;

    /// <summary>Tile <paramref name="index"/> of the span, <paramref name="ring"/> rings off the board.</summary>
    public Vector2I At(int index, int ring) => First + Along * index + Out * (ring - 1);

    /// <summary>The board edge tile in front of span tile <paramref name="index"/>.</summary>
    public Vector2I Edge(int index) => First + Along * index - Out;

    /// <summary>The first-ring wall tiles just past each end of the span, lower end first.</summary>
    public (Vector2I Before, Vector2I After) Flanks => (First - Along, First + Along * Width);
}

/// <summary>
/// The places in a built sewer skirt that give a prop its reason: openings in the outline, the
/// ends of channels, wall feet, inside corners and dead ends. Skirt coordinates throughout.
/// </summary>
public static class SewerSites
{
    public static readonly Vector2I[] Cardinals = { new(1, 0), new(-1, 0), new(0, 1), new(0, -1) };

    public static TileRole Role(MapLayout layout, Vector2I t)
        => layout.IsInBounds(t.X, t.Y) ? layout.GetTile(t.X, t.Y) : TileRole.Wall;

    public static bool IsOpen(MapLayout layout, Vector2I t) => Role(layout, t) is not (TileRole.Wall or TileRole.Empty);

    public static int Ring(SkirtResult skirt, Vector2I t)
    {
        int margin = skirt.Margin;
        return WallFaces.Ring(t.X, t.Y, margin, skirt.Layout.Width - 2 * margin, skirt.Layout.Height - 2 * margin);
    }

    public static int Chebyshev(Vector2I a, Vector2I b) => Math.Max(Math.Abs(a.X - b.X), Math.Abs(a.Y - b.Y));

    /// <summary>Directions from <paramref name="t"/> to a cardinal wall neighbour (pillars count).</summary>
    public static List<Vector2I> WallSides(MapLayout layout, Vector2I t)
        => Cardinals.Where(d => Role(layout, t + d) == TileRole.Wall).ToList();

    /// <summary>Walled on three sides.</summary>
    public static bool IsDeadEnd(MapLayout layout, Vector2I t) => WallSides(layout, t).Count >= 3;

    /// <summary>Walled on two sides that meet.</summary>
    public static bool IsInsideCorner(MapLayout layout, Vector2I t)
    {
        var sides = WallSides(layout, t);
        return sides.Any(a => sides.Any(b => a.X * b.X + a.Y * b.Y == 0));
    }

    /// <summary>Every opening in the board outline. A span that reaches a board corner is the
    /// tunnel running on, not an opening.</summary>
    public static List<SewerOpening> Openings(SkirtResult skirt, int passageDepth)
    {
        var layout = skirt.Layout;
        int m = skirt.Margin, w = layout.Width - 2 * m, h = layout.Height - 2 * m;
        var found = new List<SewerOpening>();
        foreach (var (start, along, outward, length) in new[]
                 {
                     (new Vector2I(m - 1, m - 1), new Vector2I(0, 1), new Vector2I(-1, 0), h),
                     (new Vector2I(m + w, m - 1), new Vector2I(0, 1), new Vector2I(1, 0), h),
                     (new Vector2I(m - 1, m - 1), new Vector2I(1, 0), new Vector2I(0, -1), w),
                     (new Vector2I(m - 1, m + h), new Vector2I(1, 0), new Vector2I(0, 1), w),
                 })
        {
            // Scan from corner to corner of the first ring: positions 0 and length + 1 are the corners.
            int a = 0;
            while (a <= length + 1)
            {
                if (!IsOpen(layout, start + along * a)) { a++; continue; }
                int b = a;
                while (b + 1 <= length + 1 && IsOpen(layout, start + along * (b + 1))) b++;
                bool reachesCorner = a == 0 || b == length + 1;
                var first = start + along * a;
                int width = b - a + 1;
                bool floor = Enumerable.Range(0, width).Any(i => Role(layout, first + along * i) is TileRole.Ground or TileRole.Bridge);
                if (!reachesCorner)
                {
                    int depth = Enumerable.Range(0, width).Max(i => DepthFrom(layout, first + along * i, outward, passageDepth));
                    var kind = !floor ? OpeningKind.Culvert : depth >= passageDepth ? OpeningKind.Passage : OpeningKind.Recess;
                    found.Add(new SewerOpening(first, along, outward, width, depth, kind));
                }
                a = b + 1;
            }
        }
        return found;
    }

    private static int DepthFrom(MapLayout layout, Vector2I firstRing, Vector2I outward, int cap)
    {
        int depth = 0;
        while (depth < cap && IsOpen(layout, firstRing + outward * depth)) depth++;
        return depth;
    }

    /// <summary>Board channel tiles whose run stops at <paramref name="stop"/>: water on the far
    /// side of the tile too, so the channel runs into it. Returns each water tile with the step to
    /// the tile it stops at.</summary>
    public static IEnumerable<(Vector2I Water, Vector2I Step)> ChannelEnds(SkirtResult skirt, Func<TileRole, bool> stop)
    {
        var layout = skirt.Layout;
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                var t = new Vector2I(x, y);
                if (Role(layout, t) != TileRole.Water || Ring(skirt, t) != 0) continue;
                foreach (var d in Cardinals)
                    if (stop(Role(layout, t + d)) && Role(layout, t - d) == TileRole.Water)
                        yield return (t, d);
            }
    }
}
