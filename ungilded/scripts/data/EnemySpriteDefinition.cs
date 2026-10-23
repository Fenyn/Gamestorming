using Godot;

namespace Ungilded.Data;

/// <summary>Artist-authored animation library and placement for a side-view unit: every enemy, and
/// the heroes whose folder holds one (<see cref="HeroSpriteMap.IsAuthored"/>).</summary>
[GlobalClass]
public partial class EnemySpriteDefinition : Resource
{
    [Export] public SpriteFrames? Frames { get; set; }
    [Export] public StringName IdleAnimation { get; set; } = "";
    /// <summary>Empty or unavailable means keep the idle clip while moving.</summary>
    [Export] public StringName MoveAnimation { get; set; } = "";
    /// <summary>Optional non-looping attack. Missing art uses the presenter's lunge.</summary>
    [Export] public StringName AttackAnimation { get; set; } = "";
    /// <summary>Zero-based contact frame; delay derives from the clip's FPS and frame holds.</summary>
    [Export] public int AttackImpactFrame { get; set; }
    [Export] public PackedScene? AttackEffect { get; set; }
    [Export] public float PixelSize { get; set; } = 0.02f;
    [Export] public float FootMarginPixels { get; set; }
    /// <summary>Horizontal ground anchor in the unflipped frame, measured from its left edge.
    /// Negative uses the canvas center. Set explicitly when a long tail makes the canvas asymmetric.</summary>
    [Export] public float GroundAnchorX { get; set; } = -1f;
    [Export] public bool FacesRight { get; set; } = true;
    /// <summary>Head crop of the first idle frame for timeline tiles and unit cards. Empty uses the
    /// square at the top of the figure.</summary>
    [Export] public Rect2I FaceRect { get; set; }
    /// <summary>Whole-figure crop of the first idle frame for party chips. Empty uses the figure's
    /// opaque bounds.</summary>
    [Export] public Rect2I PortraitRect { get; set; }
}
