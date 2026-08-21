using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot defeat dissipation — a muted gray-violet puff of smoke the unit dissolves into, kept
/// somber rather than comedic (no bounce, no burst, no bright colour): a few soft quads spread across
/// the unit's silhouette height slowly GROW, drift upward and fade, instead of the hard pop/shrink
/// used by <see cref="HitSpark"/> or <see cref="ShieldFlash"/>. The node then <see
/// cref="Node.QueueFree"/>s itself.
///
/// Pure-Tween per house style (<see cref="WhiffPuff"/> precedent) — geometry built in code from a
/// baked per-puff table, no AnimationPlayer, no particle system. Puffs never pass through zero scale
/// (they GROW from a modest starting size rather than popping in from nothing), so <see
/// cref="WhiffPuff.NearZeroScale"/>'s workaround doesn't apply here — nothing here ever needs it —
/// and they fade via the material's own alpha (<c>albedo_color:a</c>, tweened on the <see
/// cref="StandardMaterial3D"/> resource itself), same technique as <see cref="HealMotes"/>.
///
/// <see cref="Tint"/>, <see cref="PoofScale"/> and <see cref="Lifetime"/> are exported so a caller can
/// configure the freshly instantiated node BEFORE <c>AddChild</c> (<see cref="Delve.Territory.
/// TerritoryScene.PlaceBeforeAdd"/>'s convention). <see cref="PoofScale"/> is the one that matters most
/// here: the caller sizes it to the defeated unit (a ~0.7 m rat vs. a ~1.6 m hero), which scales both
/// the puff spread and how far up the (feet, y=0) base each puff starts.
/// </summary>
public partial class DeathPoof : Node3D
{
    /// <summary>Group every spawned poof joins (spike introspection, mirrors <see
    /// cref="WhiffPuff.FxGroup"/>).</summary>
    public const string FxGroup = "Fx";

    /// <summary>Puff colour. Default: a muted gray-violet — deliberately desaturated, no red/black
    /// "gib" read.</summary>
    [Export] public Color Tint { get; set; } = new Color(0.5f, 0.45f, 0.55f);

    /// <summary>Unit-height multiplier — rats are ~0.7, heroes ~1.6 (see class doc). Scales both the
    /// puffs' spread and how high up the caller-placed base (feet, y=0) each one starts.</summary>
    [Export] public float PoofScale { get; set; } = 1f;

    /// <summary>Total lifetime (seconds): every puff's grow/drift/fade fits inside this window
    /// (individually delayed per <see cref="Puffs"/>'s DelayFrac), then the node frees itself.</summary>
    [Export] public float Lifetime { get; set; } = 0.6f;

    /// <summary>Cooler violet accent each puff blends toward per its baked MixFactor — mixed with
    /// <see cref="Tint"/> so the cloud reads gray-AND-violet without needing two exported colours.</summary>
    private static readonly Color VioletAccent = new Color(0.42f, 0.32f, 0.55f);

    // Five puffs spread across the unit's silhouette: (start delay as a fraction of Lifetime, angle
    // around the base in degrees, outward distance m, start/end quad size m, height up the body this
    // puff originates at (fraction of PoofScale's implied unit height), rise added on top of that
    // over its life m, starting alpha, 0=Tint..1=VioletAccent mix). Sizes/distances/heights/rise are
    // all further multiplied by PoofScale at spawn. Sized to read at the combat camera's default 16 m
    // orbit (OrbitCameraRig.InitialDistance) — realistically puff-sized quads are invisible at that
    // distance, so these are scaled well past life-size to read at gameplay range.
    private static readonly (float DelayFrac, float AngleDeg, float Distance, float StartSize, float EndSize,
        float BaseHeight, float Rise, float AlphaStart, float Mix)[] Puffs =
    {
        (0.00f, 0f, 0.00f, 1.28f, 3.90f, 0.50f, 0.50f, 0.95f, 0.30f),
        (0.05f, 60f, 0.38f, 0.78f, 2.64f, 0.25f, 0.65f, 0.90f, 0.60f),
        (0.03f, 150f, 0.34f, 0.71f, 2.45f, 0.70f, 0.55f, 0.90f, 0.15f),
        (0.08f, 240f, 0.36f, 0.84f, 2.84f, 0.15f, 0.70f, 0.88f, 0.70f),
        (0.02f, 300f, 0.29f, 0.65f, 2.25f, 0.45f, 0.45f, 0.92f, 0.40f),
    };

    public override void _Ready()
    {
        AddToGroup(FxGroup);

        var tween = CreateTween();
        tween.SetParallel(true);

        foreach (var puff in Puffs)
            BuildPuff(tween, puff);

        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(QueueFree));
    }

    private void BuildPuff(Tween tween,
        (float DelayFrac, float AngleDeg, float Distance, float StartSize, float EndSize, float BaseHeight,
            float Rise, float AlphaStart, float Mix) puff)
    {
        Color color = Tint.Lerp(VioletAccent, puff.Mix);
        var material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            AlbedoColor = new Color(color.R, color.G, color.B, puff.AlphaStart),
            BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled,
        };

        float rad = Mathf.DegToRad(puff.AngleDeg);
        Vector3 origin = new Vector3(Mathf.Sin(rad) * puff.Distance, puff.BaseHeight, Mathf.Cos(rad) * puff.Distance)
                        * PoofScale;

        var quad = new MeshInstance3D
        {
            Mesh = new QuadMesh { Size = Vector2.One * puff.StartSize * PoofScale },
            MaterialOverride = material,
            Position = origin,
            Scale = Vector3.One,
        };
        AddChild(quad);

        float delay = Lifetime * puff.DelayFrac;
        float remaining = Lifetime - delay;
        // Hold at full brightness through the first slice of the puff's life — growth still runs the
        // whole time, but the fade doesn't start eating alpha before the puff has actually grown into
        // something worth seeing (an immediate fade-from-frame-1 reads as "too faint" even mid-life).
        float holdTime = remaining * 0.35f;
        float fadeTime = remaining - holdTime;
        Vector3 end = origin + new Vector3(0f, puff.Rise * PoofScale, 0f);
        float endScaleFactor = puff.EndSize / puff.StartSize;

        tween.TweenProperty(quad, "position", end, remaining)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(quad, "scale", Vector3.One * endScaleFactor, remaining)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(material, "albedo_color:a", 0f, fadeTime)
            .SetDelay(delay + holdTime).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
    }
}
