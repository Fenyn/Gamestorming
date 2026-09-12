using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>Separate tile tops, without vertical faces bridging ledges. UVs outline each square.</summary>
public static class TerrainFootprintMesh
{
    public static ArrayMesh Build(PF2eVec anchor, int width, TerrainHeightMap heights)
    {
        var buffer = new MeshBuffer(withColor: false);
        for (int y = 0; y < width; y++)
            for (int x = 0; x < width; x++)
            {
                var c = heights.Corners(new PF2eVec(anchor.x + x, anchor.y + y));
                Vector3 sw = new(x, c.SW * heights.HeightScale + HighlightMeshes.SurfaceY, y);
                Vector3 se = new(x + 1, c.SE * heights.HeightScale + HighlightMeshes.SurfaceY, y);
                Vector3 ne = new(x + 1, c.NE * heights.HeightScale + HighlightMeshes.SurfaceY, y + 1);
                Vector3 nw = new(x, c.NW * heights.HeightScale + HighlightMeshes.SurfaceY, y + 1);
                int i = buffer.VertexCount;
                buffer.Add(sw, Vector3.Up, new Vector2(0, 0));
                buffer.Add(se, Vector3.Up, new Vector2(1, 0));
                buffer.Add(ne, Vector3.Up, new Vector2(1, 1));
                buffer.Add(nw, Vector3.Up, new Vector2(0, 1));
                if (TerrainGeometry.ShouldSplitAlternate(sw, se, ne, nw))
                {
                    buffer.AddIndices(i, i + 1, i + 2);
                    buffer.AddIndices(i, i + 2, i + 3);
                }
                else
                {
                    buffer.AddIndices(i, i + 1, i + 3);
                    buffer.AddIndices(i + 1, i + 2, i + 3);
                }
            }
        return buffer.ToArrayMesh("creature_footprint");
    }
}
