using Godot;

namespace Delve.Flow;

/// <summary>An extruded broken masonry outline, including its exposed wall thickness.</summary>
public partial class CampRuin : MeshInstance3D
{
    [Export] public Vector2[] Outline { get; set; } = System.Array.Empty<Vector2>();
    [Export] public float Thickness { get; set; } = 0.9f;

    public override void _Ready()
    {
        var surface = new SurfaceTool();
        surface.Begin(Mesh.PrimitiveType.Triangles);
        int[] indices = Geometry2D.TriangulatePolygon(Outline);
        foreach (int side in new[] { -1, 1 })
        for (int i = 0; i < indices.Length; i += 3)
        for (int j = 0; j < 3; j++)
        {
            Vector2 p = Outline[indices[i + (side == 1 ? 2 - j : j)]];
            surface.SetNormal(Vector3.Back * side);
            surface.SetUV(p);
            surface.AddVertex(new Vector3(p.X, p.Y, side * Thickness / 2));
        }
        for (int i = 0; i < Outline.Length; i++)
        {
            Vector2 a = Outline[i], b = Outline[(i + 1) % Outline.Length];
            Vector3 normal = new Vector3(a.Y - b.Y, b.X - a.X, 0).Normalized();
            Vector3[] corners = { new(a.X, a.Y, -Thickness / 2), new(b.X, b.Y, -Thickness / 2),
                new(a.X, a.Y, Thickness / 2), new(b.X, b.Y, Thickness / 2) };
            foreach (int corner in new[] { 0, 2, 1, 1, 2, 3 })
            {
                surface.SetNormal(normal);
                surface.SetUV(new Vector2(corner % 2 == 0 ? 0 : a.DistanceTo(b), corner < 2 ? 0 : Thickness));
                surface.AddVertex(corners[corner]);
            }
        }
        Mesh = surface.Commit();
    }
}
