using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot cool-blue protective flash for Raise Shield / Shield Block — deliberately reads
/// "warded/deflected", the opposite of <see cref="HitSpark"/>'s hot, scattering hit read. Two or
/// three concentric rings pop outward at chest height and fade; a bigger <see cref="BlockStrength"/>
/// (how much the block absorbed) makes every ring larger/brighter and unlocks a third, outermost
/// ring. The node then <see cref="Node.QueueFree"/>s itself.
///
/// Each "ring" is a dozen small quads spaced evenly around a circle rather than one ring-shaped
/// quad — house style keeps geometry to flat-colour, unshaded, alpha-blended QuadMeshes with no
/// textures/shaders to draw an annulus with, so a ring is built the same way <see cref="HitSpark"/>'s
/// crit ring is (see that class's doc). Full circles were chosen over true arcs on purpose: a
/// half-visible arc reads ambiguous from an arbitrary camera angle, where a full ring reads as a
/// shield pictogram from anywhere.
///
/// Pure-Tween per house style (<see cref="WhiffPuff"/> precedent) — geometry built in code from a
/// baked per-ring table, no AnimationPlayer, no particle system. <see cref="Tint"/>, <see
/// cref="FlashScale"/> and <see cref="BlockStrength"/> are exported so a caller can configure the
/// freshly instantiated node BEFORE <c>AddChild</c> (<see cref="Delve.Territory.TerritoryScene.
/// PlaceBeforeAdd"/>'s convention) — the caller positions the root at the blocking unit's BASE (feet,
/// y=0, matching every billboarded actor in this codebase); <see cref="ChestHeight"/> below is the
/// local offset that lifts the rings to chest level from there.
/// </summary>
public partial class ShieldFlash : Node3D
{
    /// <summary>Group every spawned flash joins (spike introspection, mirrors <see
    /// cref="WhiffPuff.FxGroup"/>).</summary>
    public const string FxGroup = "Fx";

    /// <summary>Ring colour. Default: a cool protective blue-white, distinct from HitSpark's warm
    /// default and any damage-type tint — a block is never "hurt" flavoured.</summary>
    [Export] public Color Tint { get; set; } = new Color(0.45f, 0.75f, 1f);

    /// <summary>Overall size multiplier — the ring radii below are authored for 1.0.</summary>
    [Export] public float FlashScale { get; set; } = 1f;

    /// <summary>Total lifetime (seconds): all rings pop, hold briefly and fade within this window.</summary>
    [Export] public float Lifetime { get; set; } = 0.4f;

    /// <summary>0-1: how much the block absorbed. Scales every ring's radius/size/brightness and, at
    /// or above <see cref="ThirdRingThreshold"/>, unlocks a third outer ring — a glancing block reads
    /// as a quick flick, a full save reads as a proper ward.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float BlockStrength { get; set; } = 0.5f;

    private const float ThirdRingThreshold = 0.5f;

    /// <summary>Local Y offset that lifts the rings from the caller-placed base (feet, y=0) to chest
    /// level — roughly mid-torso on the Mana Seed billboard scale this codebase's actors use.</summary>
    private const float ChestHeight = 1.1f;

    // Stand-in for "invisible" in a scale tween — see WhiffPuff.NearZeroScale for why this can never
    // be literally Vector3.Zero (renderer det==0 assertion on a singular billboard transform).
    private static readonly Vector3 NearZeroScale = Vector3.One * 0.001f;

    // Baked ring table: (start delay as a fraction of Lifetime, target radius m, shard count, shard
    // size m). Radius/size scale with both FlashScale and BlockStrength; delay staggers the rings so
    // they read as one ward popping outward in a quick beat rather than a single flat flash.
    // Sized to read at the combat camera's default 16 m orbit (OrbitCameraRig.InitialDistance) —
    // "realistic" small rings are invisible at that distance, so these are scaled well past life-size.
    private static readonly (float DelayFrac, float Radius, int Count, float Size)[] Rings =
    {
        (0.00f, 0.88f, 10, 0.26f),
        (0.08f, 1.36f, 12, 0.21f),
    };

    private static readonly (float DelayFrac, float Radius, int Count, float Size) ThirdRing =
        (0.16f, 1.76f, 14, 0.18f);

    public override void _Ready()
    {
        AddToGroup(FxGroup);

        float strengthMul = 0.7f + 0.5f * Mathf.Clamp(BlockStrength, 0f, 1f);
        var tween = CreateTween();
        tween.SetParallel(true);

        foreach (var ring in Rings)
            BuildRing(tween, ring, strengthMul);
        if (BlockStrength >= ThirdRingThreshold)
            BuildRing(tween, ThirdRing, strengthMul);

        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }

    private void BuildRing(Tween tween, (float DelayFrac, float Radius, int Count, float Size) ring,
        float strengthMul)
    {
        float delay = Lifetime * ring.DelayFrac;
        float remaining = Lifetime - delay;
        float expandTime = remaining * 0.45f;
        float holdTime = remaining * 0.1f;
        float fadeTime = remaining - expandTime - holdTime;
        float radius = ring.Radius * FlashScale * strengthMul;
        float size = ring.Size * FlashScale * strengthMul;

        for (int i = 0; i < ring.Count; i++)
        {
            float rad = Mathf.Tau * i / ring.Count;
            var dot = new MeshInstance3D
            {
                Mesh = new QuadMesh { Size = Vector2.One * size },
                MaterialOverride = new StandardMaterial3D
                {
                    ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
                    Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                    AlbedoColor = Tint,
                    BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
                    CullMode = BaseMaterial3D.CullModeEnum.Disabled,
                },
                Position = new Vector3(0f, ChestHeight, 0f),
                Scale = NearZeroScale,
            };
            AddChild(dot);

            Vector3 target = new Vector3(Mathf.Sin(rad), 0f, Mathf.Cos(rad)) * radius
                            + new Vector3(0f, ChestHeight, 0f);

            tween.TweenProperty(dot, "position", target, expandTime)
                .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(dot, "scale", Vector3.One, expandTime * 0.6f)
                .SetDelay(delay).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(dot, "scale", NearZeroScale, fadeTime)
                .SetDelay(delay + expandTime + holdTime)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        }
    }
}
