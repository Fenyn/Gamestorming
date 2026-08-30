using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot defeat dissipation. A muted gray-violet puff of smoke the unit dissolves into, kept somber
/// rather than comedic: no bounce, no burst, no bright colour. A few soft quads spread across the
/// unit's silhouette height, slowly GROW, drift upward and fade. That is the opposite of the hard
/// pop/shrink in <see cref="HitSpark"/> and <see cref="ShieldFlash"/>.
///
/// Puffs never pass through zero scale, so <see cref="OneShotFx.NearZeroScale"/> is not needed here.
/// They fade on the material's own alpha, the same way <see cref="HealMotes"/> fades.
///
/// <see cref="OneShotFx.FxScale"/> matters most here. The caller sizes it to the defeated unit, which
/// scales both the puff spread and how far up the base each puff starts.
/// </summary>
public partial class DeathPoof : OneShotFx
{
    public DeathPoof()
    {
        // Deliberately desaturated gray-violet: no red or black "gib" read.
        Tint = new Color(0.5f, 0.45f, 0.55f);
        Lifetime = 0.6f;
    }

    /// <summary>Cooler violet accent each puff blends toward per its baked MixFactor — mixed with
    /// <see cref="OneShotFx.Tint"/> so the cloud reads gray-AND-violet without a second export.</summary>
    private static readonly Color VioletAccent = new Color(0.42f, 0.32f, 0.55f);

    // Five puffs spread across the unit's silhouette: (start delay as a fraction of Lifetime, angle
    // around the base in degrees, outward distance m, start/end quad size m, height up the body this
    // puff originates at (fraction of FxScale's implied unit height), rise added on top of that
    // over its life m, starting alpha, 0=Tint..1=VioletAccent mix). Sizes/distances/heights/rise are
    // all further multiplied by FxScale at spawn. Sized to read at the combat camera's default 16 m
    // orbit (OrbitCameraRig.FramingDistancePerTile) — realistically puff-sized quads are invisible at that
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

    protected override void Build(Tween tween)
    {
        foreach (var puff in Puffs)
            BuildPuff(tween, puff);
    }

    private void BuildPuff(Tween tween,
        (float DelayFrac, float AngleDeg, float Distance, float StartSize, float EndSize, float BaseHeight,
            float Rise, float AlphaStart, float Mix) puff)
    {
        Color color = Tint.Lerp(VioletAccent, puff.Mix);
        var quad = BillboardQuad(puff.StartSize * FxScale,
            new Color(color.R, color.G, color.B, puff.AlphaStart));
        var material = (StandardMaterial3D)quad.MaterialOverride;

        float rad = Mathf.DegToRad(puff.AngleDeg);
        Vector3 origin = new Vector3(Mathf.Sin(rad) * puff.Distance, puff.BaseHeight, Mathf.Cos(rad) * puff.Distance)
                        * FxScale;
        quad.Position = origin;
        quad.Scale = Vector3.One;
        AddChild(quad);

        float delay = Lifetime * puff.DelayFrac;
        float remaining = Lifetime - delay;
        // Hold at full brightness through the first slice of the puff's life — growth still runs the
        // whole time, but the fade doesn't start eating alpha before the puff has actually grown into
        // something worth seeing (an immediate fade-from-frame-1 reads as "too faint" even mid-life).
        float holdTime = remaining * 0.35f;
        float fadeTime = remaining - holdTime;
        Vector3 end = origin + new Vector3(0f, puff.Rise * FxScale, 0f);
        float endScaleFactor = puff.EndSize / puff.StartSize;

        tween.TweenProperty(quad, "position", end, remaining)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(quad, "scale", Vector3.One * endScaleFactor, remaining)
            .SetDelay(delay).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(material, "albedo_color:a", 0f, fadeTime)
            .SetDelay(delay + holdTime).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
    }
}
