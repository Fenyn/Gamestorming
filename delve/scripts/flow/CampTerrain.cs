using Godot;

namespace Delve.Flow;

/// <summary>Authored low-poly banks around a level gathering ground.</summary>
public partial class CampTerrain : MeshInstance3D
{
    [Export] public float Extent { get; set; } = 36;
    [Export] public float CellSize { get; set; } = 1;
    // Bank center X/Z, radius, rise. Broad slopes keep the camp floor usable.
    [Export] public Vector4[] Banks { get; set; } = System.Array.Empty<Vector4>();
    [Export] public NodePath[] GroundedProps { get; set; } = System.Array.Empty<NodePath>();

    public float HeightAt(Vector3 point)
    {
        float height = 0;
        foreach (var bank in Banks)
        {
            float distance = new Vector2(point.X - bank.X, (point.Z - bank.Y) * 1.35f).Length() / bank.Z;
            float rise = Mathf.SmoothStep(0, 1, Mathf.Clamp(1 - distance, 0, 1));
            height = Mathf.Max(height, rise * bank.W);
        }
        return height;
    }

    public override void _Ready()
    {
        var surface = new SurfaceTool();
        surface.Begin(Mesh.PrimitiveType.Triangles);
        for (float z = -Extent; z < Extent; z += CellSize)
        for (float x = -Extent; x < Extent; x += CellSize)
        {
            Vector3 a = Point(x, z), b = Point(x + CellSize, z);
            Vector3 c = Point(x, z + CellSize), d = Point(x + CellSize, z + CellSize);
            Triangle(surface, a, b, c);
            Triangle(surface, b, d, c);
        }
        Mesh = surface.Commit();
        foreach (var path in GroundedProps)
        {
            var prop = GetNode<Node3D>(path);
            prop.Position += Vector3.Up * HeightAt(prop.Position);
        }
    }

    private Vector3 Point(float x, float z)
    {
        var point = new Vector3(x, 0, z);
        return point + Vector3.Up * HeightAt(point);
    }

    private static void Triangle(SurfaceTool surface, Vector3 a, Vector3 b, Vector3 c)
    {
        Vector3 normal = (c - a).Cross(b - a).Normalized();
        foreach (var point in new[] { a, b, c })
        {
            surface.SetNormal(normal);
            surface.SetUV(new Vector2(point.X, point.Z));
            surface.AddVertex(point);
        }
    }
}
