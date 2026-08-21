using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot healing readout — a handful of soft green/gold motes drifting up from the healed unit's
/// base, deliberately gentle rather than explosive (the opposite energy from <see cref="HitSpark"/>
/// or <see cref="DeathPoof"/>): each mote blinks in, rises with a light horizontal sway, and fades
/// back out, on its own staggered start so the group reads as a small swirl rather than a synchronized
/// pop. The node then <see cref="Node.QueueFree"/>s itself.
///
/// Pure-Tween per house style (<see cref="WhiffPuff"/> precedent) — geometry built in code from a
/// baked per-mote table, no AnimationPlayer, no particle system. Unlike the harder-edged effects in
/// this library, motes fade via the material's OWN alpha (<c>albedo_color:a</c>, tweened on the
/// <see cref="StandardMaterial3D"/> resource itself) rather than shrinking to <see
/// cref="WhiffPuff.NearZeroScale"/>-style near-zero — a soft glow dimming out reads gentler than a
/// shard collapsing. Scale is still used for the initial "blink in" (popping from a near-zero start,
/// same discipline as every other effect here — see <see cref="Tween"/> setup below), it just never
/// animates back down again, so the near-zero-not-zero rule still applies without ever being tested
/// at the disappearing end.
///
/// <see cref="Tint"/>, <see cref="MoteScale"/> and <see cref="Lifetime"/> are exported so a caller can
/// configure the freshly instantiated node BEFORE <c>AddChild</c> (<see cref="Delve.Territory.
/// TerritoryScene.PlaceBeforeAdd"/>'s convention) — the caller positions the root at the healed unit's
/// BASE (feet, y=0, matching every billboarded actor in this codebase); motes rise from there.
/// </summary>
public partial class HealMotes : Node3D
{
    /// <summary>Group every spawned mote-set joins (spike introspection, mirrors <see
    /// cref="WhiffPuff.FxGroup"/>).</summary>
    public const string FxGroup = "Fx";

    /// <summary>Base mote colour (the "green" side of the green/gold mix below). Default: a soft
    /// spring green.</summary>
    [Export] public Color Tint { get; set; } = new Color(0.55f, 0.95f, 0.55f);

    /// <summary>Overall size/drift-distance multiplier — the mote table below is authored for 1.0.</summary>
    [Export] public float MoteScale { get; set; } = 1f;

    /// <summary>Total lifetime (seconds): every mote's blink-in, rise and fade fits inside this
    /// window (individually delayed per <see cref="Motes"/>'s DelayFrac), then the node frees itself.</summary>
    [Export] public float Lifetime { get; set; } = 0.9f;

    // Stand-in for "invisible" in a scale tween — see WhiffPuff.NearZeroScale for why this can never
    // be literally Vector3.Zero (renderer det==0 assertion on a singular billboard transform).
    private static readonly Vector3 NearZeroScale = Vector3.One * 0.001f;

    /// <summary>Warm accent each mote blends toward per its baked MixFactor — mixed with <see
    /// cref="Tint"/> so the group reads green-AND-gold without needing two exported colours.</summary>
    private static readonly Color GoldAccent = new Color(0.95f, 0.85f, 0.45f);

    // Six motes: (start delay as a fraction of Lifetime, initial X/Z offset from the base m, added
    // horizontal drift over the mote's life m, rise height m, quad size m, 0=Tint..1=GoldAccent mix).
    // Offsets keep every mote within a light spread of the unit's own footprint. Sized to read at the
    // combat camera's default 16 m orbit (OrbitCameraRig.InitialDistance) — realistically mote-sized
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

    public override void _Ready()
    {
        AddToGroup(FxGroup);

        var tween = CreateTween();
        tween.SetParallel(true);

        foreach (var mote in Motes)
            BuildMote(tween, mote);

        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }

    private void BuildMote(Tween tween,
        (float DelayFrac, float OffsetX, float OffsetZ, float DriftX, float DriftZ, float Rise, float Size,
            float Mix) mote)
    {
        Color color = Tint.Lerp(GoldAccent, mote.Mix);
        var material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            AlbedoColor = new Color(color.R, color.G, color.B, 0f),
            BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled,
        };
        var quad = new MeshInstance3D
        {
            Mesh = new QuadMesh { Size = Vector2.One * mote.Size * MoteScale },
            MaterialOverride = material,
            Position = new Vector3(mote.OffsetX, 0.05f, mote.OffsetZ) * MoteScale,
            Scale = NearZeroScale,
        };
        AddChild(quad);

        float delay = Lifetime * mote.DelayFrac;
        float remaining = Lifetime - delay;
        float popDuration = Mathf.Min(0.14f, remaining * 0.3f);
        float fadeOutDuration = remaining * 0.4f;
        Vector3 end = new Vector3(mote.OffsetX + mote.DriftX, mote.Rise, mote.OffsetZ + mote.DriftZ) * MoteScale;

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
