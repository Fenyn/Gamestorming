using Godot;

namespace Ungilded.Fx;

/// <summary>
/// One-shot Treat Wounds heal: a linen roll wraps two turns of bandage and a knot round the healed
/// unit's chest, and a few plain sparkles rise from the band once it is tied. An HD-2D effect like
/// <see cref="AcidSplash"/>: the scene (scenes/fx/treat_wounds.tscn) is written by
/// tools/vfx/treat_wounds/build_treat_wounds.gd, whose NOTES.md holds the round log and the hook
/// contract. This class only starts the scene.
///
/// <c>%Body</c> holds two sets, each drawn on its sprite's own pixel grid: <c>%Tall</c> (<c>%Wrap</c>,
/// <c>%Sparkles</c>) for a hero and <c>%Low</c> (<c>%WrapLow</c>, <c>%SparklesLow</c>) for a rat-sized
/// unit. <c>%Body</c> scales by <see cref="BodyPixelSize"/> over <see cref="FramePixelSize"/>, so each
/// wrap texel lands on a sprite pixel; <see cref="OneShotFx.FxScale"/> is unused. <c>%Anim</c> pulses
/// <c>%Light</c>, a faint lantern-coloured light, which moves toward the healer.
///
/// The caller places the root at the healed unit's FEET. <see cref="OneShotFx.Tint"/> is unused: the
/// frames carry their own locked palette.
/// </summary>
public partial class TreatWounds : OneShotFx
{
    public TreatWounds()
    {
        // The longest layer, the wrap, ends at 1.36 s.
        Lifetime = 1.4f;
    }

    /// <summary>The healed unit's sprite pixel size in metres. The presenter reads it off the unit.</summary>
    [Export] public float BodyPixelSize { get; set; } = 0.02f;

    /// <summary>Metres per texel of the frames at <c>%Body</c> scale 1.</summary>
    [Export] public float FramePixelSize { get; set; } = 0.028f;

    /// <summary>Plays the <c>%Low</c> set (the rat's wrap) in place of <c>%Tall</c>.</summary>
    [Export] public bool UseLowSet { get; set; }

    /// <summary>Horizontal direction from the healed unit toward the healer. Zero leaves the light
    /// above the head.</summary>
    [Export] public Vector3 HealerDirection { get; set; } = Vector3.Zero;

    /// <summary>Metres the light moves toward the healer at its own height, so the lantern light
    /// comes from the medic's side.</summary>
    [Export] public float LightTowardHealer { get; set; } = 0.6f;

    private const string PlayAnimation = "play";

    private static readonly string[] TallLayers = { "%Wrap", "%Sparkles" };
    private static readonly string[] LowLayers = { "%WrapLow", "%SparklesLow" };

    protected override void Build(Tween tween)
    {
        GetNode<Node3D>("%Body").Scale = Vector3.One * (BodyPixelSize / FramePixelSize);
        GetNode<Node3D>("%Tall").Visible = !UseLowSet;
        GetNode<Node3D>("%Low").Visible = UseLowSet;
        foreach (string layer in UseLowSet ? LowLayers : TallLayers)
            GetNode<GpuParticles3D>(layer).Restart();

        var toward = new Vector3(HealerDirection.X, 0f, HealerDirection.Z);
        if (toward.LengthSquared() > 0.0001f)
            GetNode<OmniLight3D>("%Light").Position += toward.Normalized() * LightTowardHealer;
        GetNode<AnimationPlayer>("%Anim").Play(PlayAnimation);

        tween.TweenInterval(Lifetime);
    }
}
