using Godot;

namespace Delve.Combat;

public partial class OrbitCameraRig
{
    [Export] public float PlanningDistanceCap { get; set; } = 0;
    [Export] public double TacticalBlendSeconds { get; set; } = 0.3;
    private Transform3D? _planningPose;
    private Vector3 _overviewCenter;
    private float _overviewDistance;
    private Tween? _tacticalTween;
    private bool _restoring;
    private Vector3? _framedPoint;
    public bool TacticalFraming => _planningPose.HasValue;

    /// <summary>True while the whole-board overview is up.</summary>
    public bool InOverview { get; private set; }

    /// <summary>The world point the view is about: the pivot, or the centre of a framed action or
    /// of the overview. Depth of field focuses here.</summary>
    public Vector3 FocusPoint => _framedPoint ?? GlobalPosition;

    /// <summary>Keep the planning view intact while framing a committed action or a staged target.</summary>
    public void FrameAction(Vector3 actor, Vector3 target)
    {
        if (IntroPlaying || _userPanned) return;
        CompleteSnap();
        _planningPose ??= Camera.Transform;
        _restoring = false;
        KillFocus();
        _tacticalTween?.Kill();
        var from = Camera.GlobalTransform;
        var midpoint = actor.Lerp(target, 0.5f);
        _framedPoint = midpoint;
        float span = actor.DistanceTo(target);
        var direction = (Camera.GlobalPosition - GlobalPosition).Normalized();
        var position = midpoint + direction * Mathf.Max(_distance * 0.85f, span * 1.25f + 4f);
        var to = new Transform3D(Basis.Identity, position).LookingAt(midpoint, Vector3.Up);
        _tacticalTween = CreateTween();
        _tacticalTween.TweenMethod(Callable.From<float>(t => Camera.GlobalTransform = from.InterpolateWith(to, t)),
            0f, 1f, TacticalBlendSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    public void RestorePlanningView(bool immediate = false)
    {
        if (_restoring && !immediate) return;
        _tacticalTween?.Kill();
        _tacticalTween = null;
        _restoring = false;
        _framedPoint = null;
        InOverview = false;
        if (_planningPose is not { } pose) return;
        if (immediate) { Camera.Transform = pose; _planningPose = null; return; }
        _restoring = true;
        var from = Camera.Transform;
        _tacticalTween = CreateTween();
        _tacticalTween.TweenMethod(Callable.From<float>(t => Camera.Transform = from.InterpolateWith(pose, t)),
            0f, 1f, TacticalBlendSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _tacticalTween.TweenCallback(Callable.From(() => { _planningPose = null; _restoring = false; _tacticalTween = null; }));
    }

    public void FocusForInspection(Vector3 target)
    {
        RestorePlanningView(true);
        _userPanned = false;
        FocusOn(target, FocusSeconds, false);
        _userPanned = true;
    }

    public void ToggleOverview()
    {
        if (IntroPlaying) return;
        if (_planningPose.HasValue) { RestorePlanningView(); return; }
        CompleteSnap();
        KillFocus();
        _planningPose = Camera.Transform;
        _restoring = false;
        _framedPoint = _overviewCenter;
        InOverview = true;
        var direction = (Camera.GlobalPosition - GlobalPosition).Normalized();
        var to = new Transform3D(Basis.Identity, _overviewCenter + direction * _overviewDistance)
            .LookingAt(_overviewCenter, Vector3.Up);
        var from = Camera.GlobalTransform;
        _tacticalTween?.Kill();
        _tacticalTween = CreateTween();
        _tacticalTween.TweenMethod(Callable.From<float>(t => Camera.GlobalTransform = from.InterpolateWith(to, t)),
            0f, 1f, TacticalBlendSeconds);
    }
}
