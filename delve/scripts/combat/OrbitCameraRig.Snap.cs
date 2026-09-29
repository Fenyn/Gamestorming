using Delve.UI;
using Godot;

namespace Delve.Combat;

/// <summary>
/// Quarter-turn yaw snaps, as in FFT: the rotate actions turn the view 90 degrees around the
/// pivot, and a released drag eases to the nearest snap so the board always sits on a diagonal.
/// </summary>
public partial class OrbitCameraRig
{
    /// <summary>Yaw step of one rotate press, degrees.</summary>
    [Export] public float SnapStepDegrees { get; set; } = 90f;

    /// <summary>Seconds one snap takes.</summary>
    [Export] public double SnapSeconds { get; set; } = 0.25;

    /// <summary>Ease a released drag onto the nearest snap angle.</summary>
    [Export] public bool SnapOnRelease { get; set; } = true;

    private Tween? _snapTween;
    private float _snapTarget;

    /// <summary>Land a snap still in flight at once, so a camera move that starts now composes
    /// from the final yaw instead of fighting the tween.</summary>
    private void CompleteSnap()
    {
        if (_snapTween?.IsValid() != true) return;
        _snapTween.Kill();
        _snapTween = null;
        _yaw = _snapTarget;
        UpdateCameraPose();
    }

    /// <summary>Nearest snap angle to <paramref name="yaw"/>. Snaps sit at <see cref="InitialYawDegrees"/>
    /// plus whole steps, so the board keeps its diagonal.</summary>
    private float NearestSnap(float yaw) =>
        InitialYawDegrees + Mathf.Round((yaw - InitialYawDegrees) / SnapStepDegrees) * SnapStepDegrees;

    private void SnapYawTo(float target)
    {
        _snapTween?.Kill();
        RestorePlanningView(true);
        _snapTarget = target;
        _snapTween = CreateTween();
        _snapTween.TweenMethod(Callable.From<float>(yaw => { _yaw = yaw; UpdateCameraPose(); }),
            _yaw, target, SnapSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
    }

    /// <summary>Handle the rotate actions. Returns true when the event was a rotate press.</summary>
    private bool HandleSnapInput(InputEvent @event)
    {
        int direction = @event.IsActionPressed(InputNames.RotateLeft) ? -1
            : @event.IsActionPressed(InputNames.RotateRight) ? 1 : 0;
        if (direction == 0) return false;
        SnapYawTo(NearestSnap(_yaw) + direction * SnapStepDegrees);
        return true;
    }

    /// <summary>Called when an orbit drag ends.</summary>
    private void OnOrbitReleased()
    {
        if (SnapOnRelease) SnapYawTo(NearestSnap(_yaw));
    }
}
