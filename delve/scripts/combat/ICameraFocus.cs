using Godot;

namespace Delve.Combat;

/// <summary>
/// The camera seam the presenter drives: land on the unit whose turn starts, track a unit while it
/// walks. The rig decides how (tween, clamp, whether a manual pan has overridden following); the
/// presenter only says where and how fast. Optional on the presenter, so a headless spike runs
/// without a camera at all.
/// </summary>
public interface ICameraFocus
{
    /// <summary>How long a turn-start focus takes; the presenter holds its turn gate at least this long.</summary>
    float FocusSeconds { get; }

    /// <summary>
    /// Move the view to <paramref name="target"/> over <paramref name="seconds"/>.
    /// <paramref name="turnStart"/> marks a new actor: it always applies and clears any manual
    /// override, while a follow (false) is ignored once the player has panned this turn.
    /// </summary>
    void FocusOn(Vector3 target, float seconds, bool turnStart);
}
