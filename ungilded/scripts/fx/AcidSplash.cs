using Godot;

namespace Ungilded.Fx;

/// <summary>
/// One-shot acid flask impact: the flask shatters on the creature and green acid splashes over it and
/// onto the squares beside it. Unlike <see cref="HitSpark"/> it is an HD-2D effect: the scene
/// (scenes/fx/acid_splash.tscn) is written by tools/vfx/acid_splash/build_acid_splash.gd, whose NOTES.md
/// holds the round log and the layer lifetimes. This class only starts the scene.
///
/// The layers sit in two groups. <c>%Body</c> (droplets, splat, glass, bubbles, flash) lands on the
/// creature: it moves up to <see cref="ImpactHeight"/> and scales with the unit. <c>%Ground</c> (ring,
/// puddles) keeps its drawn size and stays unrotated, because it draws a splat on each of the eight
/// neighbour tile centres: its one-tile reach is the splash rule, not a unit size.
/// <c>%Anim</c> pulses <c>%Light</c>. <see cref="Minor"/> plays only the acid on the body. Each layer
/// is named here: a layer the build script adds or removes must be added to or removed from
/// <see cref="BodyLayers"/> or <see cref="DirectLayers"/>.
///
/// The caller places the root at the struck unit's FEET. <see cref="OneShotFx.Tint"/> is unused: the
/// frames carry their own locked palette.
/// </summary>
public partial class AcidSplash : OneShotFx
{
    public AcidSplash()
    {
        // The longest layer, Puddles, ends at 1.44 s.
        Lifetime = 1.6f;
    }

    /// <summary>Metres above the feet where the flask breaks. The presenter reads it off the unit's HP bar.</summary>
    [Export] public float ImpactHeight { get; set; }

    /// <summary>Acid that reached the creature without a flask breaking on it: the splash on a creature
    /// beside the target, a persistent acid tick, an acid spell. Only the splat, droplets and bubbles
    /// play. The flash, the glass, the light and the floor layers stay off, so the creature the flask
    /// hit keeps the only shatter. The body keeps its scale, because a smaller scale would make its
    /// texels finer than the sprite's pixels.</summary>
    [Export] public bool Minor { get; set; }

    /// <summary>Multiplies <see cref="OneShotFx.FxScale"/> on <c>%Body</c>. The frames are drawn at
    /// 0.028 m a texel. 1.08 brings them to the 0.02 m pixels of the Prologue sprites on a unit at
    /// the presenter's FxScale floor of 0.66, which is every creature that takes acid in the Prologue
    /// (the rats and the Tyrant). A Prologue hero (FxScale about 0.71) gets texels 7 percent larger.</summary>
    [Export] public float BodyPixelScale { get; set; } = 1.08f;

    private const string PlayAnimation = "play";

    // Layers every splash plays.
    private static readonly string[] BodyLayers = { "%Splat", "%Droplets", "%Bubbles" };

    // Layers only a flask breaking on this creature plays: the break and the splash across the floor.
    private static readonly string[] DirectLayers = { "%Flash", "%Glass", "%Ring", "%Puddles" };

    protected override void Build(Tween tween)
    {
        var body = GetNode<Node3D>("%Body");
        body.Position = new Vector3(0f, ImpactHeight, 0f);
        body.Scale = Vector3.One * (FxScale * BodyPixelScale);

        foreach (string layer in BodyLayers) GetNode<GpuParticles3D>(layer).Restart();
        foreach (string layer in DirectLayers)
        {
            var particles = GetNode<GpuParticles3D>(layer);
            if (Minor) particles.Hide();
            else particles.Restart();
        }

        if (Minor) GetNode<OmniLight3D>("%Light").Hide();
        else GetNode<AnimationPlayer>("%Anim").Play(PlayAnimation);

        tween.TweenInterval(Lifetime);
    }
}
