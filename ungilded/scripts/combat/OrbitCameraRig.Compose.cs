using System.Collections.Generic;
using Godot;

namespace Ungilded.Combat;

/// <summary>
/// Shot composition on top of the orbit pose: a screen-space shift that puts the pivot somewhere
/// other than the screen's centre (the clear part of the view beside the HUD), a fit that sizes the
/// zoom to a set of points, and a dolly that pushes the camera in or out without touching the
/// player's zoom. The shift uses the camera's own lens offsets (<see cref="Camera3D.HOffset"/>,
/// <see cref="Camera3D.VOffset"/>), so picking and unprojection stay true.
/// </summary>
public partial class OrbitCameraRig
{
    private Vector2 _composition;
    private float _dolly = 1f;
    private Tween? _composeTween, _dollyTween, _distanceTween;

    /// <summary>Where the pivot sits on screen, as an offset from the centre in viewport heights
    /// (x right, y down).</summary>
    public Vector2 Composition => _composition;

    /// <summary>Multiplier on the zoom distance for a push in (below 1) or a pull out.</summary>
    public float Dolly => _dolly;

    /// <summary>The zoom distance from the pivot, before the dolly.</summary>
    public float Distance => _distance;

    /// <summary>The camera's distance from the pivot: the zoom times the dolly.</summary>
    public float ViewDistance => _distance * _dolly;

    /// <summary>Glide the pivot's screen position to <paramref name="shift"/> (viewport heights from
    /// the centre, y down). Zero seconds snaps.</summary>
    public void Compose(Vector2 shift, double seconds)
    {
        _composeTween?.Kill();
        _composeTween = null;
        if (seconds <= 0) { SetComposition(shift); return; }
        _composeTween = CreateTween();
        _composeTween.TweenMethod(Callable.From<Vector2>(SetComposition), _composition, shift, seconds)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    /// <summary>Move the camera to <paramref name="factor"/> times the zoom distance over
    /// <paramref name="seconds"/>; zero snaps.</summary>
    public void DollyTo(float factor, double seconds, Tween.EaseType ease = Tween.EaseType.InOut)
    {
        _dollyTween?.Kill();
        _dollyTween = null;
        if (seconds <= 0) { SetDolly(factor); return; }
        _dollyTween = CreateTween();
        _dollyTween.TweenMethod(Callable.From<float>(SetDolly), _dolly, factor, seconds)
            .SetTrans(Tween.TransitionType.Sine).SetEase(ease);
    }

    /// <summary>
    /// Frame <paramref name="points"/> inside <paramref name="clear"/> (a rect in viewport
    /// coordinates: the part of the screen the HUD leaves open) as seen from <paramref name="pivot"/>.
    /// The zoom backs off from the board's framing until the points fit (it never pushes closer than
    /// the framing, and a zoom the player chose on this camera wins), and the composition shift
    /// centres them in the rect. Measured by projecting the points,
    /// so the pitch's foreshortening and the perspective are both accounted for. The zoom glides from
    /// <paramref name="fromDistance"/> when given, so a new room's framing never pops.
    /// </summary>
    public void Fit(IReadOnlyList<Vector3> points, Rect2 clear, Vector3 pivot, double seconds, float? fromDistance = null)
    {
        if (_camera == null || points.Count == 0 || clear.Size.X <= 0 || clear.Size.Y <= 0) return;
        _composeTween?.Kill();
        _distanceTween?.Kill();
        var (composition, dolly, position) = (_composition, _dolly, GlobalPosition);
        _dolly = 1f;
        _composition = Vector2.Zero;
        GlobalPosition = pivot;
        UpdateCameraPose();
        if (!Settings.ViewPreferences.TryGetCameraDistance(ZoomSlot, out _))
            for (int pass = 0; pass < 2; pass++)
            {
                var bounds = Projected(points);
                float k = Mathf.Max(bounds.Size.X / clear.Size.X, bounds.Size.Y / clear.Size.Y);
                if (k <= 1f) break;
                _distance = Mathf.Clamp(_distance * k, ZoomMin, ZoomMax);
                UpdateCameraPose();
            }
        // The lens shift slides the whole image. The pivot aims for the rect's centre, and the shift
        // gives way only as far as it must to keep every point inside the rect.
        var view = GetViewport().GetVisibleRect();
        var placed = Projected(points);
        var want = clear.GetCenter() - view.GetCenter();
        var shift = new Vector2(
            Within(want.X, clear.Position.X - placed.Position.X, clear.End.X - placed.End.X),
            Within(want.Y, clear.Position.Y - placed.Position.Y, clear.End.Y - placed.End.Y)) / view.Size.Y;
        float distance = _distance;
        (_composition, _dolly, GlobalPosition) = (composition, dolly, position);
        if (fromDistance is { } from && seconds > 0)
        {
            _distance = from;
            _distanceTween = CreateTween();
            _distanceTween.TweenMethod(Callable.From<float>(SetDistance), from, distance, seconds)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        }
        UpdateCameraPose();
        Compose(shift, seconds);
    }

    /// <summary>Finish any composition, zoom or dolly glide now.</summary>
    public void FinishComposition()
    {
        foreach (var tween in new[] { _composeTween, _dollyTween, _distanceTween })
            if (tween?.IsValid() == true) tween.CustomStep(3600);
    }

    /// <summary><paramref name="value"/> held between the bounds; halfway when they cross (the points
    /// are wider than the rect, as under a zoom the player chose).</summary>
    private static float Within(float value, float low, float high)
        => low > high ? (low + high) / 2 : Mathf.Clamp(value, low, high);

    private Rect2 Projected(IReadOnlyList<Vector3> points)
    {
        var bounds = new Rect2(_camera.UnprojectPosition(points[0]), Vector2.Zero);
        for (int i = 1; i < points.Count; i++) bounds = bounds.Expand(_camera.UnprojectPosition(points[i]));
        return bounds;
    }

    private void SetComposition(Vector2 shift)
    {
        _composition = shift;
        ApplyComposition();
    }

    /// <summary>Set the dolly now. A caller's own tween can drive it, as the crawl's crossing does
    /// while the rig itself is paused.</summary>
    public void SetDolly(float factor)
    {
        _dolly = factor;
        UpdateCameraPose();
    }

    private void SetDistance(float distance)
    {
        _distance = distance;
        UpdateCameraPose();
    }

    /// <summary>Lens offsets for the shift at the pivot's depth: one viewport height there spans
    /// 2·d·tan(fov/2) metres.</summary>
    private void ApplyComposition()
    {
        if (_camera == null) return;
        float height = 2f * ViewDistance * Mathf.Tan(Mathf.DegToRad(_camera.Fov) / 2f);
        _camera.HOffset = -_composition.X * height;
        _camera.VOffset = _composition.Y * height;
    }
}
