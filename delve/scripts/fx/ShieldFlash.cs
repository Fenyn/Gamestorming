using Godot;

namespace Delve.Fx;

/// <summary>
/// One-shot cool-blue protective flash for Raise Shield and Shield Block. It reads as "warded" or
/// "deflected", the opposite of <see cref="HitSpark"/>'s hot, scattering hit read. Two concentric
/// rings pop outward at chest height and fade. A bigger <see cref="BlockStrength"/> makes both rings
/// larger and brighter.
///
/// Full circles were chosen over true arcs on purpose. A half-visible arc reads ambiguous from an
/// arbitrary camera angle, where a full ring reads as a shield pictogram from anywhere.
///
/// The caller places the root at the blocking unit's BASE (feet, y=0), and
/// <see cref="ChestHeight"/> lifts the rings to chest level from there.
/// </summary>
public partial class ShieldFlash : OneShotFx
{
    public ShieldFlash()
    {
        // Cool protective blue-white, distinct from HitSpark's warm default and any damage-type tint.
        // A block is never "hurt" flavoured.
        Tint = new Color(0.45f, 0.75f, 1f);
        Lifetime = 0.4f;
    }

    /// <summary>0-1: how much the block absorbed. Scales every ring's radius, size and brightness, so
    /// a glancing block reads as a quick flick and a full save reads as a proper ward.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float BlockStrength { get; set; } = 0.5f;

    /// <summary>Local Y offset that lifts the rings from the caller-placed base (feet, y=0) to chest
    /// level — roughly mid-torso on the Mana Seed billboard scale this codebase's actors use. Scaled
    /// by <see cref="OneShotFx.FxScale"/>, so a rat's ward sits at a rat's chest.</summary>
    private const float ChestHeight = 1.1f;

    // Baked ring table: (start delay as a fraction of Lifetime, target radius m, shard count, shard
    // size m). Radius/size scale with both FxScale and BlockStrength; delay staggers the rings so
    // they read as one ward popping outward in a quick beat rather than a single flat flash.
    // Sized to read at the combat camera's default 16 m orbit (OrbitCameraRig.FramingDistancePerTile) —
    // "realistic" small rings are invisible at that distance, so these are scaled well past life-size.
    private static readonly (float DelayFrac, float Radius, int Count, float Size)[] Rings =
    {
        (0.00f, 0.88f, 10, 0.26f),
        (0.08f, 1.36f, 12, 0.21f),
    };

    protected override void Build(Tween tween)
    {
        float strengthMul = 0.7f + 0.5f * Mathf.Clamp(BlockStrength, 0f, 1f);
        foreach (var ring in Rings)
        {
            float delay = Lifetime * ring.DelayFrac;
            float remaining = Lifetime - delay;
            float expandTime = remaining * 0.45f;
            float holdTime = remaining * 0.1f;
            float fadeTime = remaining - expandTime - holdTime;

            BuildRing(tween, this, Tint, ring.Count, ring.Radius * FxScale * strengthMul,
                ring.Size * FxScale * strengthMul, ChestHeight * FxScale, delay, expandTime,
                expandTime * 0.6f, Tween.TransitionType.Back, delay + expandTime + holdTime, fadeTime);
        }
    }
}
