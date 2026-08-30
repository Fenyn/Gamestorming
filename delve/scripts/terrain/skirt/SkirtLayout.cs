using System;
using System.Collections.Generic;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>A built skirt: the enlarged layout, the offset the original board sits at inside it —
/// board tile (x, y) is skirt tile (x + <see cref="Margin"/>, y + <see cref="Margin"/>) — and the
/// halo tiles (skirt coordinates) where an open biome's tree scatter stands. Trees are SPOTS, not
/// tiles: the ground under them is ordinary walkable-looking halo, and the renderer dresses each
/// spot with a billboard tree prop. Enclosed biomes return no spots.</summary>
public readonly record struct SkirtResult(
    MapLayout Layout, int Margin, IReadOnlyList<(int X, int Y)> Trees);

/// <summary>
/// Grows a halo of synthesized terrain around a generated battle map and hands back ONE layout that
/// contains both. The board is copied in verbatim — every per-tile field, so nothing about the
/// playable area can shift — and the halo around it is invented from the board's own edge: the same
/// surfaces, the same rivers carrying on outward, hills that rise and then settle back to the ground
/// plane, trees or vault walls per biome.
///
/// The point is that the result is a plain <see cref="MapLayout"/>: the ordinary terrain mesh
/// builder renders the outside world with the same passes as the inside, so the seam is a seam in
/// the data only. Deterministic from <c>board.Seed</c> alone (<see cref="MapHash"/> plus Perlin
/// offsets derived from it, no <c>System.Random</c>).
///
/// Feature work is split three ways: this file owns the frame (margin, copy, ring geometry),
/// <see cref="SkirtFeatures"/> owns what each halo tile IS, <see cref="SkirtHeights"/> owns how high.
/// </summary>
public static class SkirtLayout
{
    /// <summary>Largest step allowed between two adjacent vertices of the synthesized field, in
    /// corner units. 2 units = half an elevation, which reads as a gentle incline.</summary>
    internal const int SlopeLimitUnits = 2;

    private const int Units = TileCornerHeights.UnitsPerElevation;

    /// <summary>
    /// Build the skirt for <paramref name="board"/>. <paramref name="wallHeightUnits"/> is the
    /// biome's <c>BiomeDefinition.WallHeight</c> (forest 8, sewer 16): how far a tree or vault wall
    /// tile rises above the ground it stands on.
    /// </summary>
    public static SkirtResult Build(MapLayout board, SkirtStyle style, int wallHeightUnits)
    {
        ArgumentNullException.ThrowIfNull(board);
        ArgumentNullException.ThrowIfNull(style);

        int margin = MarginFor(board, style);
        var skirt = new MapLayout
        {
            Name = board.Name + "_skirt",
            Seed = board.Seed,
            BorderWidth = board.BorderWidth + margin,
        };
        skirt.Initialize(board.Width + 2 * margin, board.Height + 2 * margin);

        CopyBoard(board, skirt, margin);

        var waterUnits = new int[skirt.Width * skirt.Height];
        Array.Fill(waterUnits, NoWater);

        var trees = new List<(int X, int Y)>();
        SkirtFeatures.Paint(skirt, board, style, margin, waterUnits, trees);
        SkirtHeights.Apply(skirt, board, style, margin, waterUnits, wallHeightUnits);

        return new SkirtResult(skirt, margin, trees);
    }

    /// <summary>Marker for "this tile is not water" in the water-level side table.</summary>
    internal const int NoWater = int.MinValue;

    /// <summary>
    /// Halo width actually used: the requested margin, never below
    /// <see cref="SkirtStyle.MinMargin"/>, and never so small that the tallest board edge cannot
    /// walk down to the ground plane at <see cref="SlopeLimitUnits"/> per vertex. A board that
    /// leaves the map on a 6-elevation plateau needs 12 gentle steps; giving it fewer would force a
    /// cliff at the rim.
    /// </summary>
    public static int MarginFor(MapLayout board, SkirtStyle style)
    {
        ArgumentNullException.ThrowIfNull(board);
        ArgumentNullException.ThrowIfNull(style);

        int tallest = 0;
        for (int y = 0; y < board.Height; y++)
        {
            for (int x = 0; x < board.Width; x++)
            {
                if (x != 0 && y != 0 && x != board.Width - 1 && y != board.Height - 1) continue;
                var corners = GroundCorners(board, x, y);
                if (corners.MaxHeight > tallest) tallest = corners.MaxHeight;
            }
        }

        // The +5 is headroom past the bare minimum descent: with exactly enough rings the slope
        // limiter turns the whole halo into a maximum-rate staircase, and neither the hill swell
        // nor the contour sway survives it.
        int needed = tallest / SlopeLimitUnits + 5;
        return Math.Max(Math.Max(style.Margin, SkirtStyle.MinMargin), needed);
    }

    // ─────────────────────────── board copy ───────────────────────────

    /// <summary>Verbatim copy of every per-tile field into the centre of the skirt. Deployment zones
    /// stay null: they are board coordinates and the renderer does not read them.</summary>
    private static void CopyBoard(MapLayout board, MapLayout skirt, int margin)
    {
        for (int y = 0; y < board.Height; y++)
        {
            for (int x = 0; x < board.Width; x++)
            {
                int sx = x + margin, sy = y + margin;
                skirt.SetTile(sx, sy, board.GetTile(x, y));
                skirt.SetSurface(sx, sy, board.GetSurface(x, y));
                skirt.SetElevation(sx, sy, board.GetElevation(x, y));
                skirt.SetSlope(sx, sy, board.GetSlopeType(x, y), board.GetSlopeHeight(x, y));
                skirt.SetCornerHeights(sx, sy, board.GetCornerHeights(x, y));
                skirt.SetFeatureLabel(sx, sy, board.GetFeatureLabel(x, y));
                skirt.SetPlantTerrain(sx, sy, board.GetPlantTerrain(x, y));
                skirt.SetBalanceDC(sx, sy, board.GetBalanceDC(x, y));
            }
        }
    }

    // ─────────────────────────── ring geometry ───────────────────────────

    /// <summary>Chebyshev ring distance of a skirt TILE from the board rectangle: 0 inside the
    /// board, 1 for the first halo ring, up to the margin at the rim.</summary>
    internal static int TileRing(int sx, int sy, int margin, MapLayout board)
    {
        int dx = Math.Max(Math.Max(margin - sx, sx - (margin + board.Width - 1)), 0);
        int dy = Math.Max(Math.Max(margin - sy, sy - (margin + board.Height - 1)), 0);
        return Math.Max(dx, dy);
    }

    /// <summary>Ring distance of a skirt VERTEX from the board's vertex rectangle. Tile ring
    /// <c>d</c> has its corners on vertex rings <c>d - 1</c> and <c>d</c>.</summary>
    internal static int VertexRing(int vx, int vy, int margin, MapLayout board)
    {
        int dx = Math.Max(Math.Max(margin - vx, vx - (margin + board.Width)), 0);
        int dy = Math.Max(Math.Max(margin - vy, vy - (margin + board.Height)), 0);
        return Math.Max(dx, dy);
    }

    /// <summary>True where the ring distance comes from one axis only — the four straight sides,
    /// as opposed to the diagonal wedges off the board's corners.</summary>
    internal static bool OnStraightSide(int sx, int sy, int margin, MapLayout board)
    {
        int dx = Math.Max(Math.Max(margin - sx, sx - (margin + board.Width - 1)), 0);
        int dy = Math.Max(Math.Max(margin - sy, sy - (margin + board.Height - 1)), 0);
        return (dx > 0) ^ (dy > 0);
    }

    /// <summary>The board tile a halo tile takes after: its own position clamped into the board
    /// rectangle, so every halo tile has a nearest edge tile to inherit from.</summary>
    internal static (int x, int y) NearestBoardTile(int sx, int sy, int margin, MapLayout board)
    {
        int bx = Math.Clamp(sx - margin, 0, board.Width - 1);
        int by = Math.Clamp(sy - margin, 0, board.Height - 1);
        return (bx, by);
    }

    // ─────────────────────────── height references ───────────────────────────

    /// <summary>
    /// The GROUND a board tile presents to the halo. Walkable roles present their own corner
    /// heights; a wall, cover or bridge tile presents the flat elevation it stands on instead of the
    /// top of the prop, so the halo joins the forest floor rather than the canopy.
    /// </summary>
    internal static TileCornerHeights GroundCorners(MapLayout board, int x, int y)
    {
        var role = board.GetTile(x, y);
        bool walkableTop = role is TileRole.Ground or TileRole.DifficultTerrain or TileRole.Water;
        return walkableTop
            ? board.GetCornerHeights(x, y)
            : TileCornerHeights.Flat(board.GetElevation(x, y) * Units);
    }

    /// <summary>The two ground corners a board tile shows across the shared edge with the halo tile
    /// on the given side, in the halo tile's own corner order. The delta points FROM the halo tile
    /// TO the board tile.</summary>
    internal static (int a, int b) JoinCorners(MapLayout board, int bx, int by, int dx, int dy)
    {
        var c = GroundCorners(board, bx, by);
        if (dx > 0) return (c.NW, c.SW);   // board east of halo  → halo NE, SE
        if (dx < 0) return (c.NE, c.SE);   // board west of halo  → halo NW, SW
        if (dy > 0) return (c.SW, c.SE);   // board north of halo → halo NW, NE
        return (c.NW, c.NE);               // board south of halo → halo SW, SE
    }
}
