using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot melee impact spark, the workhorse hit read for ordinary strikes. It plays alongside
/// <see cref="ShieldFlash"/> (the block reaction) and <c>Delve.Combat.DamagePopup3D</c> (the numeric
/// callout). A handful of small bright quads burst outward from the impact point, biased away from the
/// attacker by <see cref="ImpactDirection"/>, rise briefly, settle under a light gravity pull and fade.
/// <see cref="Crit"/> doubles the shard count and size, and adds a brief expanding ring.
///
/// The caller tints the spark through <see cref="OneShotFx.Tint"/>. Use
/// <see cref="DamageColors.For"/> for a damage-type flavour, and leave the default for a plain hit.
/// </summary>
public partial class HitSpark : OneShotFx
{
    public HitSpark()
    {
        // Warm bright white: the neutral "steel on flesh or armor" spark.
        Tint = new Color(1f, 0.92f, 0.75f);
        Lifetime = 0.35f;
    }

    /// <summary>World-space direction FROM the attacker TOWARD the target (need not be normalized) —
    /// the burst leans this way so shards read as knocked off the target, not sucked toward the
    /// attacker. <see cref="Vector3.Zero"/> (the default) skips the bias and bursts as an even ring.</summary>
    [Export] public Vector3 ImpactDirection { get; set; } = Vector3.Zero;

    /// <summary>Doubles shard count (adds <see cref="CritExtraShards"/> on top of <see
    /// cref="BaseShards"/>), doubles shard size, and layers in the expanding ring. A crit also stretches
    /// the effective window to at least <see cref="CritMinLifetime"/>, because the ring needs the room.</summary>
    [Export] public bool Crit { get; set; } = false;

    /// <summary>Minimum lifetime once <see cref="Crit"/> is set, so a caller that forgets to bump
    /// <see cref="OneShotFx.Lifetime"/> for a crit still gets the ~0.5 s the extra ring needs.</summary>
    private const float CritMinLifetime = 0.5f;

    // Base shard burst: (angle in degrees off the away-from-attacker axis, outward distance m, quad
    // size m, rise height m, gravity settle-back m). Baked for FxScale = 1. Angles bias toward 0°
    // (straight away from the attacker) with a wide-ish spread so the burst still reads full-bodied
    // when ImpactDirection is unset (spread wraps most of the circle).
    // Sized to read at the combat camera's default 16 m orbit (OrbitCameraRig.FramingDistancePerTile) —
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

    // The crit shockwave ring, built by OneShotFx.BuildRing.
    private const int RingShards = 12;
    private const float RingRadius = 1.6f;
    private const float RingShardSize = 0.20f;
    private const float RingHeight = 0.05f;

    protected override void Build(Tween tween)
    {
        float life = Crit ? Mathf.Max(Lifetime, CritMinLifetime) : Lifetime;
        // Yaw of the "away from attacker" axis; zero (no bias) leaves the baked angles as authored.
        float forwardYaw = ImpactDirection.LengthSquared() > 0.0001f
            ? Mathf.Atan2(ImpactDirection.X, ImpactDirection.Z)
            : 0f;

        float popDuration = life * 0.18f;
        foreach (var shard in BaseShards)
            BuildShard(tween, shard, forwardYaw, life, popDuration);
        if (!Crit) return;

        foreach (var shard in CritExtraShards)
            BuildShard(tween, shard, forwardYaw, life, popDuration);

        float expandTime = life * 0.55f;
        float fadeTime = life - expandTime * 0.4f;
        BuildRing(tween, this, Tint, RingShards, RingRadius * FxScale, RingShardSize * FxScale,
            RingHeight, 0f, expandTime, expandTime * 0.5f, Tween.TransitionType.Sine,
            expandTime * 0.5f, fadeTime - expandTime * 0.5f);
    }

    private void BuildShard(Tween tween,
        (float AngleDeg, float Distance, float Size, float Rise, float Settle) shard,
        float forwardYaw, float life, float popDuration)
    {
        var quad = BillboardQuad(shard.Size * FxScale, Tint);
        quad.Position = Vector3.Zero;
        quad.Scale = NearZeroScale;
        AddChild(quad);

        float rad = Mathf.DegToRad(shard.AngleDeg) + forwardYaw;
        Vector3 outward = new Vector3(Mathf.Sin(rad), 0f, Mathf.Cos(rad)) * shard.Distance * FxScale;
        Vector3 peak = outward + new Vector3(0f, shard.Rise * FxScale, 0f);
        Vector3 settled = outward + new Vector3(0f, (shard.Rise - shard.Settle) * FxScale, 0f);

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
}
