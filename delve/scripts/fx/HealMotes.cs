using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot healing readout. A handful of soft green/gold motes drift up from the healed unit's base,
/// gentle rather than explosive — the opposite energy from <see cref="HitSpark"/> or
/// <see cref="DeathPoof"/>. Each mote blinks in, rises with a light horizontal sway, and fades out on
/// its own staggered start, so the group reads as a small swirl rather than a synchronized pop.
///
/// Motes fade on the material's own alpha instead of shrinking away, because a dimming glow reads
/// gentler than a collapsing shard. Scale still runs the blink-in from
/// <see cref="OneShotFx.NearZeroScale"/>, and never animates back down.
///
/// The caller places the root at the healed unit's BASE (feet, y=0), and the motes rise from there.
/// </summary>
public partial class HealMotes : OneShotFx
{
    public HealMotes()
    {
        // The "green" side of the green/gold mix below: a soft spring green.
        Tint = new Color(0.55f, 0.95f, 0.55f);
        Lifetime = 0.9f;
    }

    /// <summary>Warm accent each mote blends toward per its baked MixFactor — mixed with
    /// <see cref="OneShotFx.Tint"/> so the group reads green-AND-gold without a second export.</summary>
    private static readonly Color GoldAccent = new Color(0.95f, 0.85f, 0.45f);

    // Six motes: (start delay as a fraction of Lifetime, initial X/Z offset from the base m, added
    // horizontal drift over the mote's life m, rise height m, quad size m, 0=Tint..1=GoldAccent mix).
    // Offsets keep every mote within a light spread of the unit's own footprint. Sized to read at the
    // combat camera's default 16 m orbit (OrbitCameraRig.FramingDistancePerTile) — realistically mote-sized
    // quads are invisible at that distance, so these are scaled well past life-size.
    private static readonly (float DelayFrac, float OffsetX, float OffsetZ, float DriftX, float DriftZ,
        float Rise, float Size, float Mix)[] Motes =
    {
        (0.00f, -0.35f, 0.10f, -0.20f, 0.16f, 0.95f, 0.30f, 0.15f),
        (0.08f, 0.30f, -0.20f, 0.23f, -0.10f, 1.05f, 0.33f, 0.70f),
        (0.15f, -0.10f, 0.35f, 0.12f, 0.20f, 0.85f, 0.27f, 0.40f),
        (0.05f, 0.39f, 0.23f, -0.16f, -0.20f, 1.00f, 0.30f, 0.90f),
        (0.20f, -0.30f, -0.30f, 0.20f, 0.12f, 0.90f, 0.24f, 0.20f),
        (0.12f, 0.04f, -0.10f, -0.10f, 0.23f, 1.10f, 0.29f, 0.55f),
    };

    protected override void Build(Tween tween)
    {
        foreach (var mote in Motes)
            BuildMote(tween, mote);
    }

    private void BuildMote(Tween tween,
        (float DelayFrac, float OffsetX, float OffsetZ, float DriftX, float DriftZ, float Rise, float Size,
            float Mix) mote)
    {
        Color color = Tint.Lerp(GoldAccent, mote.Mix);
        var quad = BillboardQuad(mote.Size * FxScale, new Color(color.R, color.G, color.B, 0f));
        var material = (StandardMaterial3D)quad.MaterialOverride;
        quad.Position = new Vector3(mote.OffsetX, 0.05f, mote.OffsetZ) * FxScale;
        quad.Scale = NearZeroScale;
        AddChild(quad);

        float delay = Lifetime * mote.DelayFrac;
        float remaining = Lifetime - delay;
        float popDuration = Mathf.Min(0.14f, remaining * 0.3f);
        float fadeOutDuration = remaining * 0.4f;
        Vector3 end = new Vector3(mote.OffsetX + mote.DriftX, mote.Rise, mote.OffsetZ + mote.DriftZ) * FxScale;

        tween.TweenProperty(quad, "scale", Vector3.One, popDuration)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(material, "albedo_color:a", color.A, popDuration)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(quad, "position", end, remaining)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(material, "albedo_color:a", 0f, fadeOutDuration)
            .SetDelay(Lifetime - fadeOutDuration).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
    }
}
