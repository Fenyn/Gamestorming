using Godot;

namespace Ungilded.Props;

/// <summary>One dressing sprite: the art, its world size, its weight when a rule picks one from a
/// list, and whether it lies flat on the floor (puddles, grates, bones) or stands as a Y billboard
/// (rubble).</summary>
[GlobalClass]
public partial class DecorSprite : Resource
{
    [Export] public Texture2D? Texture { get; set; }

    /// <summary>World height in metres of a standing sprite; for a flat one, its world width.</summary>
    [Export] public float Size { get; set; } = 0.5f;

    [Export] public float Weight { get; set; } = 1f;

    [Export] public bool Flat { get; set; }

    /// <summary>A puddle or slime: feet splash on its tile in cutscenes.</summary>
    [Export] public bool Wet { get; set; }
}
