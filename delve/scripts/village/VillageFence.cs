using Godot;

namespace Delve.Village;

/// <summary>
/// A straight fence run built on load: split-rail posts and two rails, or a pointed log palisade.
/// Posts stand on the camp terrain and vary a little in height, as if set by hand.
/// </summary>
public partial class VillageFence : Node3D
{
    [Export] public Vector2 Start { get; set; }
    [Export] public Vector2 End { get; set; }
    [Export] public bool Palisade { get; set; }
    [Export] public Material? Wood { get; set; }
    [Export] public Delve.Flow.CampTerrain? Terrain { get; set; }

    [Export] public float RailSpacing { get; set; } = 1.1f;
    [Export] public float PalisadeSpacing { get; set; } = 0.34f;
    [Export] public float RailPostHeight { get; set; } = 1.0f;
    [Export] public float PalisadeHeight { get; set; } = 2.2f;
    [Export] public float[] RailHeights { get; set; } = { 0.45f, 0.82f };

    public override void _Ready()
    {
        var span = End - Start;
        int count = Mathf.Max(2, Mathf.RoundToInt(span.Length() / (Palisade ? PalisadeSpacing : RailSpacing)) + 1);
        var post = Palisade
            ? new CylinderMesh { TopRadius = 0.17f, BottomRadius = 0.17f, Height = PalisadeHeight, RadialSegments = 6, Material = Wood }
            : new CylinderMesh { TopRadius = 0.07f, BottomRadius = 0.08f, Height = RailPostHeight, RadialSegments = 6, Material = Wood };
        var tip = new CylinderMesh { TopRadius = 0f, BottomRadius = 0.17f, Height = 0.4f, RadialSegments = 6, Material = Wood };
        for (int i = 0; i < count; i++)
        {
            var at = Start + span * (i / (float)(count - 1));
            float ground = GroundAt(at);
            // Hand-set posts: uneven heights, a little more on the palisade.
            float jitter = (i * 37 % 5) * (Palisade ? 0.06f : 0.03f) - (Palisade ? 0f : 0.05f);
            AddChild(new MeshInstance3D { Mesh = post, Position = new Vector3(at.X, ground + post.Height / 2f + jitter, at.Y) });
            if (Palisade)
                AddChild(new MeshInstance3D { Mesh = tip, Position = new Vector3(at.X, ground + post.Height + jitter + tip.Height / 2f, at.Y) });
        }
        if (Palisade) return;
        var rail = new BoxMesh { Size = new Vector3(span.Length(), 0.09f, 0.07f), Material = Wood };
        var middle = Start + span / 2f;
        float yaw = -Mathf.Atan2(span.Y, span.X);
        float mid = GroundAt(middle);
        foreach (float height in RailHeights)
            AddChild(new MeshInstance3D { Mesh = rail, Position = new Vector3(middle.X, mid + height, middle.Y), Rotation = new Vector3(0, yaw, 0) });
    }

    private float GroundAt(Vector2 at) => Terrain?.HeightAt(new Vector3(at.X, 0, at.Y)) ?? 0f;
}
