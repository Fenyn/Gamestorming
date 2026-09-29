using System.Collections.Generic;
using Godot;
using PF2e.Grid;

namespace Delve.Terrain;

/// <summary>Clips a rectangular overlay against the terrain diagonal so every emitted triangle
/// lies on one ground face, including narrow strips crossing a non-planar tile. UVs run 0..1
/// across the rectangle, the same as a flat QuadMesh, so one marker shader serves both boards.</summary>
internal static class SurfacePatch
{
    internal static ArrayMesh Build(TileCornerHeights corners, float scale, float lift,
        float u0, float u1, float v0, float v1)
    {
        var rectangle = new List<Vector2> { new(u0, v0), new(u1, v0), new(u1, v1), new(u0, v1) };
        bool alternate = System.Math.Abs(corners.SW - corners.NE) <= System.Math.Abs(corners.SE - corners.NW);
        var buffer = new MeshBuffer(withColor: false);
        float center = corners.SampleSurfaceHeight(0.5f, 0.5f) * scale;
        Emit(Clip(rectangle, 1));
        Emit(Clip(rectangle, -1));
        return buffer.ToArrayMesh("surface_patch");

        float Distance(Vector2 p) => alternate ? p.X - p.Y : p.X + p.Y - 1f;

        List<Vector2> Clip(List<Vector2> polygon, int side)
        {
            var result = new List<Vector2>();
            Vector2 previous = polygon[^1];
            float a = Distance(previous) * side;
            foreach (var current in polygon)
            {
                float b = Distance(current) * side;
                if ((a < 0) != (b < 0)) result.Add(previous.Lerp(current, a / (a - b)));
                if (b >= 0) result.Add(current);
                previous = current;
                a = b;
            }
            return result;
        }

        Vector2 Uv(Vector2 p) => new((p.X - u0) / (u1 - u0), (p.Y - v0) / (v1 - v0));

        Vector3 Point(Vector2 p) => new(p.X - 0.5f,
            corners.SampleSurfaceHeight(p.X, p.Y) * scale - center + lift, p.Y - 0.5f);

        void Emit(List<Vector2> polygon)
        {
            for (int i = 1; i + 1 < polygon.Count; i++)
            {
                var a = Point(polygon[0]);
                var b = Point(polygon[i]);
                var c = Point(polygon[i + 1]);
                if ((b - a).Cross(c - a).LengthSquared() < 1e-12f) continue;
                TerrainGeometry.AddTriangle(buffer, null, a, c, b, Vector3.Up,
                    Uv(polygon[0]), Uv(polygon[i + 1]), Uv(polygon[i]));
            }
        }
    }
}
