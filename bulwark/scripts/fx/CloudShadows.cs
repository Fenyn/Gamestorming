using Godot;

namespace Bulwark.Fx;

/// <summary>
/// Drifting cloud-shadow overlay: slides its child Sprite2D shadows across a wrap region so a
/// handful of hand-painted Winlu cloud shadows read as endless passing clouds. Place the node at
/// the center of the playable area and size <see cref="Region"/> to cover it (children wrap when
/// they leave the region, re-entering from the opposite edge). Standalone-safe, no autoload deps.
/// </summary>
public partial class CloudShadows : Node2D
{
    /// <summary>Drift velocity in pixels/second applied to every child shadow.</summary>
    [Export] public Vector2 DriftSpeed { get; set; } = new(8f, 2f);

    /// <summary>Wrap region size, centered on this node; children leaving it wrap around.</summary>
    [Export] public Vector2 Region { get; set; } = new(1400f, 900f);

    public override void _Process(double delta)
    {
        Vector2 step = DriftSpeed * (float)delta;
        Vector2 half = Region * 0.5f;

        foreach (Node child in GetChildren())
        {
            if (child is not Sprite2D sprite)
                continue;

            Vector2 pos = sprite.Position + step;
            if (pos.X > half.X) pos.X -= Region.X;
            else if (pos.X < -half.X) pos.X += Region.X;
            if (pos.Y > half.Y) pos.Y -= Region.Y;
            else if (pos.Y < -half.Y) pos.Y += Region.Y;
            sprite.Position = pos;
        }
    }
}
