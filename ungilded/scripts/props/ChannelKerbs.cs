using Godot;
using PF2e.Grid;
using PF2e.MapGen;
using Ungilded.Look;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>The size of a channel kerb, metres: how far it reaches in from the channel edge and how
/// far it stands above the floor.</summary>
public readonly record struct KerbShape(float Width, float Height);

/// <summary>
/// A low stone kerb along every floor edge that drops to a channel, on the board and in the halo
/// near it. Scenery only: a unit steps over it, and the gameplay layout never sees it.
/// </summary>
public static class ChannelKerbs
{
    public static void Place(Node3D parent, DressingContext context, Material? material, KerbShape shape, int maxRing)
    {
        if (material == null) return;
        var layout = context.Skirt.Layout;
        int m = context.Skirt.Margin;
        int boardW = context.Board.Width, boardH = context.Board.Height;
        float hs = context.HeightScale;
        var buffer = new MeshBuffer();
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                if (layout.GetTile(x, y) is not (TileRole.Ground or TileRole.DifficultTerrain)) continue;
                if (WallFaces.Ring(x, y, m, boardW, boardH) > maxRing) continue;
                int floor = layout.GetCornerHeights(x, y).MinHeight;
                foreach (var dir in LayoutQueries.Cardinals)
                {
                    var (nx, ny) = LayoutQueries.Step(x, y, dir);
                    if (!layout.IsInBounds(nx, ny) || layout.GetTile(nx, ny) != TileRole.Water) continue;
                    if (layout.GetCornerHeights(nx, ny).MaxHeight >= floor) continue;
                    AddKerb(buffer, x, y, dir, floor * hs, shape);
                }
            }
        if (buffer.IsEmpty) return;
        parent.AddChild(new MeshInstance3D
        {
            Name = "ChannelKerbs",
            Mesh = buffer.ToArrayMesh("channel_kerbs", material),
            Position = new Vector3(-m, 0f, -m),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        });
    }

    /// <summary>A kerb inside tile (x, y) along its edge toward <paramref name="dir"/>: the top, the
    /// face over the channel, and the face back toward the floor.</summary>
    private static void AddKerb(MeshBuffer buffer, int x, int y, CardinalDirection dir, float floor, KerbShape shape)
    {
        float top = floor + shape.Height;
        var (sx, sz) = LayoutQueries.Step(0, 0, dir);
        // The strip's footprint inside the tile, as world rectangle corners.
        float x0 = sx > 0 ? x + 1 - shape.Width : x, x1 = sx < 0 ? x + shape.Width : x + 1;
        float z0 = sz > 0 ? y + 1 - shape.Width : y, z1 = sz < 0 ? y + shape.Width : y + 1;
        TerrainGeometry.AddQuad(buffer, null,
            new Vector3(x0, top, z0), new Vector3(x1, top, z0), new Vector3(x1, top, z1), new Vector3(x0, top, z1));

        var (oTL, oTR, oBL, oBR) = LayoutQueries.GetEdgeWorldPositions(x, y, dir, 1, 1, 0, 0, 1f);
        var lift = new Vector3(0, floor, 0);
        var raise = new Vector3(0, shape.Height, 0);
        TerrainGeometry.AddWallQuad(buffer, null, oTL * Flat + lift + raise, oTR * Flat + lift + raise,
            oBR * Flat + lift, oBL * Flat + lift);

        var back = LayoutQueries.Opposite(dir);
        var (iTL, iTR, iBL, iBR) = LayoutQueries.GetEdgeWorldPositions(x, y, back, 1, 1, 0, 0, 1f);
        var shift = new Vector3(sx, 0, sz) * (1f - shape.Width);
        TerrainGeometry.AddWallQuad(buffer, null, iTL * Flat + shift + lift + raise, iTR * Flat + shift + lift + raise,
            iBR * Flat + shift + lift, iBL * Flat + shift + lift);
    }

    /// <summary>Drops the y of an edge position, so the unit heights passed to the edge query only
    /// pick the corners.</summary>
    private static readonly Vector3 Flat = new(1f, 0f, 1f);
}
