using Godot;
using PF2e.Data;

namespace Delve.Fx;

/// <summary>
/// One-shot melee impact spark — the workhorse hit read for ordinary strikes, alongside <see
/// cref="ShieldFlash"/> (block/ward reaction) and <see cref="Delve.Combat.DamagePopup3D"/> (the
/// numeric callout that rides along with it). A handful of small bright unshaded billboard shards
/// burst outward from the impact point, biased away from the attacker via <see
/// cref="ImpactDirection"/>, rise briefly then settle under a light gravity pull, and fade out.
/// <see cref="Crit"/> doubles the shard count/size and layers in a brief expanding "ring" — built,
/// like everything else here, from small quads rather than a texture (see <see cref="RingShards"/>)
/// — then <see cref="Node.QueueFree"/>s itself.
///
/// Pure-Tween per house style (<see cref="WhiffPuff"/> precedent) — geometry built in code from baked
/// per-shard tables, no AnimationPlayer, no particle system, no textures/shaders. <see cref="Tint"/>,
/// <see cref="ImpactDirection"/>, <see cref="SparkScale"/> and <see cref="Crit"/> are exported so a
/// caller can configure the freshly instantiated node BEFORE <c>AddChild</c> (<see cref="Delve.
/// Territory.TerritoryScene.PlaceBeforeAdd"/>'s convention) — <see cref="_Ready"/> reads them once to
/// build geometry off the node's own transform, which the caller has already positioned at the
/// impact point.
///
/// Damage-type tinting is the CALLER's job via <see cref="Tint"/>; <see cref="TintFor"/> is a
/// convenience for callers that only have a <c>DamageType</c> handy. It MIRRORS <see cref="Delve.
/// Combat.DamagePopup3D.Create"/>'s per-damage-type popup palette — that switch lives inside the
/// popup's private static factory, so this is a duplicated table, not a shared one. Treat
/// DamagePopup3D.Create as the source of truth if the two ever need to diverge.
/// </summary>
public partial class HitSpark : Node3D
{
    /// <summary>Group every spawned spark joins (spike introspection, mirrors <see
    /// cref="WhiffPuff.FxGroup"/>).</summary>
    public const string FxGroup = "Fx";

    /// <summary>Shard colour. Default: warm bright white, the neutral "steel on flesh/armor" spark —
    /// callers wanting a damage-type flavor pass <see cref="TintFor"/>'s result instead.</summary>
    [Export] public Color Tint { get; set; } = new Color(1f, 0.92f, 0.75f);

    /// <summary>World-space direction FROM the attacker TOWARD the target (need not be normalized) —
    /// the burst leans this way so shards read as knocked off the target, not sucked toward the
    /// attacker. <see cref="Vector3.Zero"/> (the default) skips the bias and bursts as an even ring.</summary>
    [Export] public Vector3 ImpactDirection { get; set; } = Vector3.Zero;

    /// <summary>Overall size/distance multiplier — the shard tables below are authored for 1.0.</summary>
    [Export] public float SparkScale { get; set; } = 1f;

    /// <summary>Total lifetime (seconds) for the base (non-crit) burst. <see cref="Crit"/> stretches
    /// the effective window to at least <see cref="CritMinLifetime"/> regardless of this value, since
    /// the crit adds a ring pass that needs the extra room (see <see cref="_Ready"/>'s <c>life</c>
    /// computation).</summary>
    [Export] public float Lifetime { get; set; } = 0.35f;

    /// <summary>Doubles shard count (adds <see cref="CritExtraShards"/> on top of <see
    /// cref="BaseShards"/>), doubles shard size, and layers in the expanding ring.</summary>
    [Export] public bool Crit { get; set; } = false;

    // Stand-in for "invisible" in a scale tween — see WhiffPuff.NearZeroScale for why this can never
    // be literally Vector3.Zero (renderer det==0 assertion on a singular billboard transform).
    private static readonly Vector3 NearZeroScale = Vector3.One * 0.001f;

    /// <summary>Minimum lifetime once <see cref="Crit"/> is set, so a caller that forgets to bump
    /// <see cref="Lifetime"/> for a crit still gets the full ~0.5s the extra ring needs to read.</summary>
    private const float CritMinLifetime = 0.5f;

    // Base shard burst: (angle in degrees off the away-from-attacker axis, outward distance m, quad
    // size m, rise height m, gravity settle-back m). Baked for SparkScale = 1. Angles bias toward 0°
    // (straight away from the attacker) with a wide-ish spread so the burst still reads full-bodied
    // when ImpactDirection is unset (spread wraps most of the circle).
    // Sized to read at the combat camera's default 16 m orbit (OrbitCameraRig.InitialDistance) —
    // "realistic" hand-sized shards are invisible at that distance, so these are pushed well past
    // life-size. At the player's CLOSEST legal zoom (OrbitCameraRig.ZoomMin) they still have to stay
    // small/spread enough not to overlap into one opaque slab that hides the creature being hit — the
    // burst has to frame the target, not replace it — while staying large enough to read at 16 m. Sizes
    // here are the hero baseline; the presenter scales the whole burst down for smaller creatures
    // (GodotPresenter3D.UnitSizeFactor).
    private static readonly (float AngleDeg, float Distance, float Size, float Rise, float Settle)[] BaseShards =
    {
        (-115f, 0.67f, 0.21f, 0.18f, 0.08f),
        (-65f, 1.01f, 0.27f, 0.42f, 0.18f),
        (-25f, 1.15f, 0.32f, 0.34f, 0.16f),
        (-6f, 1.29f, 0.34f, 0.22f, 0.10f),
        (10f, 1.21f, 0.32f, 0.35f, 0.16f),
        (35f, 1.07f, 0.27f, 0.46f, 0.21f),
        (75f, 0.94f, 0.27f, 0.29f, 0.13f),
        (125f, 0.63f, 0.21f, 0.16f, 0.08f),
    };

    // Layered on top of BaseShards only when Crit is set — same shape, offset angles so the two
    // tables interleave instead of overlapping, distances/sizes pushed further for a bigger burst.
    private static readonly (float AngleDeg, float Distance, float Size, float Rise, float Settle)[] CritExtraShards =
    {
        (-140f, 0.81f, 0.18f, 0.21f, 0.10f),
        (-90f, 1.27f, 0.26f, 0.48f, 0.22f),
        (-45f, 1.47f, 0.29f, 0.42f, 0.18f),
        (0f, 1.61f, 0.30f, 0.29f, 0.13f),
        (22f, 1.53f, 0.29f, 0.48f, 0.21f),
        (55f, 1.39f, 0.26f, 0.56f, 0.26f),
        (95f, 1.17f, 0.23f, 0.38f, 0.16f),
        (155f, 0.72f, 0.17f, 0.16f, 0.08f),
    };

    // The crit "ring" — not a single ring-shaped quad (house style is flat-colour QuadMeshes, no
    // textures/shaders to draw an annulus), but a dozen small quads spaced evenly around a circle at a
    // fixed radius that pop and expand together, reading as a shockwave ring at gameplay distance.
    private const int RingShards = 12;
    private const float RingRadius = 1.6f;
    private const float RingShardSize = 0.20f;

    /// <summary>Per-damage-type spark tint — MIRRORS DamagePopup3D.Create's popup palette (see class
    /// doc for why this can't just reference it). Unmapped types (Bludgeoning/Piercing/Slashing/
    /// Sonic/Force/Vitality/Void/Spirit/Bleed/Precision/Untyped) and null fall back to the default
    /// warm-white spark.</summary>
    public static Color TintFor(DamageType? damageType) => damageType switch
    {
        DamageType.Fire => new Color(1f, 0.45f, 0.12f),
        DamageType.Cold => new Color(0.4f, 0.75f, 1f),
        DamageType.Electricity => new Color(1f, 1f, 0.45f),
        DamageType.Acid => new Color(0.5f, 1f, 0.3f),
        DamageType.Poison => new Color(0.65f, 0.3f, 0.85f),
        DamageType.Mental => new Color(0.82f, 0.4f, 1f),
        _ => new Color(1f, 0.92f, 0.75f),
    };

    public override void _Ready()
    {
        AddToGroup(FxGroup);

        float life = Crit ? Mathf.Max(Lifetime, CritMinLifetime) : Lifetime;
        // Yaw of the "away from attacker" axis; zero (no bias) leaves the baked angles as authored.
        float forwardYaw = ImpactDirection.LengthSquared() > 0.0001f
            ? Mathf.Atan2(ImpactDirection.X, ImpactDirection.Z)
            : 0f;

        var tween = CreateTween();
        tween.SetParallel(true);

        float popDuration = life * 0.18f;
        foreach (var shard in BaseShards)
            BuildShard(tween, shard, forwardYaw, life, popDuration);
        if (Crit)
        {
            foreach (var shard in CritExtraShards)
                BuildShard(tween, shard, forwardYaw, life, popDuration);
            BuildRing(tween, life);
        }

        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }

    private void BuildShard(Tween tween,
        (float AngleDeg, float Distance, float Size, float Rise, float Settle) shard,
        float forwardYaw, float life, float popDuration)
    {
        var quad = new MeshInstance3D
        {
            Mesh = new QuadMesh { Size = Vector2.One * shard.Size * SparkScale },
            MaterialOverride = new StandardMaterial3D
            {
                ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
                Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                AlbedoColor = Tint,
                BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
                CullMode = BaseMaterial3D.CullModeEnum.Disabled,
            },
            Position = Vector3.Zero,
            Scale = NearZeroScale,
        };
        AddChild(quad);

        float rad = Mathf.DegToRad(shard.AngleDeg) + forwardYaw;
        Vector3 outward = new Vector3(Mathf.Sin(rad), 0f, Mathf.Cos(rad)) * shard.Distance * SparkScale;
        Vector3 peak = outward + new Vector3(0f, shard.Rise * SparkScale, 0f);
        Vector3 settled = outward + new Vector3(0f, (shard.Rise - shard.Settle) * SparkScale, 0f);

        float riseTime = life * 0.35f;
        float fallTime = life - riseTime;

        tween.TweenProperty(quad, "scale", Vector3.One, popDuration)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(quad, "position", peak, riseTime)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(quad, "position", settled, fallTime)
            .SetDelay(riseTime).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        tween.TweenProperty(quad, "scale", NearZeroScale, fallTime * 0.8f)
            .SetDelay(riseTime + fallTime * 0.2f).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
    }

    private void BuildRing(Tween tween, float life)
    {
        float expandTime = life * 0.55f;
        float fadeTime = life - expandTime * 0.4f;

        for (int i = 0; i < RingShards; i++)
        {
            float rad = Mathf.Tau * i / RingShards;
            var dot = new MeshInstance3D
            {
                Mesh = new QuadMesh { Size = Vector2.One * RingShardSize * SparkScale },
                MaterialOverride = new StandardMaterial3D
                {
                    ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
                    Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                    AlbedoColor = Tint,
                    BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
                    CullMode = BaseMaterial3D.CullModeEnum.Disabled,
                },
                Position = new Vector3(0f, 0.05f, 0f),
                Scale = NearZeroScale,
            };
            AddChild(dot);

            Vector3 target = new Vector3(Mathf.Sin(rad), 0f, Mathf.Cos(rad)) * RingRadius * SparkScale
                            + new Vector3(0f, 0.05f, 0f);

            tween.TweenProperty(dot, "position", target, expandTime)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(dot, "scale", Vector3.One, expandTime * 0.5f)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(dot, "scale", NearZeroScale, fadeTime - expandTime * 0.5f)
                .SetDelay(expandTime * 0.5f).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        }
    }
}
