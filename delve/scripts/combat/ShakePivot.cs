using Godot;

namespace Delve.Combat;

/// <summary>
/// Trauma-driven camera shake, sitting between <see cref="OrbitCameraRig"/> and the combat Camera3D
/// (rig &gt; ShakePivot &gt; Camera3D in scenes/combat/combat.tscn). The two compose instead of fighting
/// because they write DIFFERENT transforms: the rig keeps writing the camera's own orbit position and
/// look-at, this node only ever writes its OWN local position, and the camera rides both.
///
/// Trauma model: callers <see cref="AddTrauma"/> per punchy beat — a crit, a death — and it decays
/// linearly at <see cref="DecayPerSecond"/>, with the offset scaling LINEARLY off the remaining
/// trauma. The textbook version squares the trauma, and it was tried first: with the small per-beat
/// amounts this game wants (a crit is not an explosion) squaring collapsed a critical hit to about
/// three millimetres of camera travel — invisible at any framing. Linear keeps the small end alive
/// while stacking still escalates, and the ceiling is guarded by the clamp on trauma rather than by
/// the curve.
///
/// The wobble is deterministic (three out-of-phase sines at incommensurate frequencies) rather than
/// random: it costs nothing, reads identically, and lets a headless spike assert the decay curve.
/// This is the ONLY writer of this node's transform — nothing else may tween or set its position, or
/// the two writers would stutter against each other.
/// </summary>
public partial class ShakePivot : Node3D
{
    /// <summary>Trauma removed per second: a crit's kick is spent in ~0.32 s, a death's in ~0.5 s.
    /// Fast enough that the board settles between beats, slow enough that the kick actually spans the
    /// impact it belongs to — at 1.6/s a crit was over in a fifth of a second, before its own spark had
    /// finished bursting.</summary>
    [Export] public float DecayPerSecond { get; set; } = 1.1f;

    /// <summary>Camera offset (metres) at full trauma. Nothing in normal play reaches full trauma —
    /// the heaviest single beat (<see cref="DeathTrauma"/>) buys about 0.12 m — so this is the guard
    /// rail for a pile-up, not the everyday amplitude. The combat camera orbits 16 m out; larger than
    /// this reads as nausea rather than impact.</summary>
    [Export] public float MaxOffset { get; set; } = 0.22f;

    /// <summary>Wobble speed multiplier. The three axes run at different multiples of this so the
    /// motion never resolves into a straight line.</summary>
    [Export] public float Frequency { get; set; } = 1f;

    /// <summary>Trauma for a critical hit — a ~0.08 m kick, spent in ~0.32 s.</summary>
    public const float CritTrauma = 0.35f;

    /// <summary>Trauma for a unit dying — the heaviest beat in a normal round, ~0.12 m over ~0.5 s.</summary>
    public const float DeathTrauma = 0.55f;

    private float _trauma;
    private float _phase;

    /// <summary>Current trauma, 0-1 (spike introspection).</summary>
    public float Trauma => _trauma;

    /// <summary>Add trauma, clamped to 1. Stacking is deliberate: a crit that also kills shakes harder
    /// than either beat alone.</summary>
    public void AddTrauma(float amount) => _trauma = Mathf.Clamp(_trauma + amount, 0f, 1f);

    public override void _Process(double delta)
    {
        if (_trauma <= 0f)
        {
            // Rest exactly at zero rather than at a tiny leftover offset, so a settled board is
            // pixel-identical to one that has never been shaken.
            if (Position != Vector3.Zero) Position = Vector3.Zero;
            return;
        }

        _trauma = Mathf.Max(0f, _trauma - DecayPerSecond * (float)delta);
        _phase += (float)delta * Frequency;

        float shake = _trauma;
        Position = new Vector3(
            Mathf.Sin(_phase * 47f) * MaxOffset * shake,
            Mathf.Sin(_phase * 39f + 1.3f) * MaxOffset * shake * 0.6f,
            Mathf.Sin(_phase * 53f + 2.7f) * MaxOffset * shake);
    }
}
