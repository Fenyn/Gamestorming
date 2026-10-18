using System.Collections.Generic;
using Godot;

namespace Delve.Village;

/// <summary>
/// The village camera: a fixed yaw, framed on one <see cref="CameraStop"/> at a time, easing from
/// stop to stop. Pieces standing between the camera and the stop's target are hidden while it is
/// framed, as the crawl's tree fader does; trees go sooner than props.
/// </summary>
public partial class VillageCamera : Camera3D
{
    [Export] public float YawDegrees { get; set; } = 15f;
    [Export] public float EaseSeconds { get; set; } = 0.6f;

    /// <summary>Category nodes whose pieces (direct children, or children of a TierGate) can block a view.</summary>
    [Export] public Node3D[] PropRoots { get; set; } = System.Array.Empty<Node3D>();
    [Export] public Node3D[] TreeRoots { get; set; } = System.Array.Empty<Node3D>();

    [Export] public float TreeHalfWidth { get; set; } = 22f;

    public CameraStop? Stop { get; private set; }
    public bool Moving => _tween != null && _tween.IsRunning();

    private Tween? _tween;
    private Vector3 _target;
    private float _pitch, _distance;

    /// <summary>Cuts straight to a stop.</summary>
    public void Frame(CameraStop stop)
    {
        _tween?.Kill();
        Stop = stop;
        Look(stop.GlobalPosition, stop.Pitch, stop.Distance);
        Occlude(stop);
    }

    /// <summary>Eases from the current view to a stop.</summary>
    public void EaseTo(CameraStop stop)
    {
        if (Stop == null)
        {
            Frame(stop);
            return;
        }
        _tween?.Kill();
        var (target, pitch, distance) = (_target, _pitch, _distance);
        Stop = stop;
        Occlude(stop);
        _tween = CreateTween().SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _tween.TweenMethod(Callable.From<float>(t => Look(target.Lerp(stop.GlobalPosition, t),
            Mathf.Lerp(pitch, stop.Pitch, t), Mathf.Lerp(distance, stop.Distance, t))), 0f, 1f, EaseSeconds);
    }

    private void Look(Vector3 target, float pitchDegrees, float distance)
    {
        (_target, _pitch, _distance) = (target, pitchDegrees, distance);
        float yaw = Mathf.DegToRad(YawDegrees), pitch = Mathf.DegToRad(pitchDegrees);
        var direction = new Vector3(Mathf.Sin(yaw) * Mathf.Cos(pitch), Mathf.Sin(pitch), Mathf.Cos(yaw) * Mathf.Cos(pitch));
        Position = target + direction * distance;
        LookAt(target);
    }

    private void Occlude(CameraStop stop)
    {
        var target = stop.GlobalPosition;
        foreach (var piece in Pieces(PropRoots))
            piece.Visible = !InFront(piece, target, stop.OccludeDepth, stop.OccludeHalfWidth);
        foreach (var piece in Pieces(TreeRoots))
            piece.Visible = !InFront(piece, target, stop.TreeOccludeDepth, TreeHalfWidth);
    }

    private static bool InFront(Node3D piece, Vector3 target, float depth, float halfWidth) =>
        piece.GlobalPosition.Z > target.Z + depth && Mathf.Abs(piece.GlobalPosition.X - target.X) < halfWidth;

    private static IEnumerable<Node3D> Pieces(Node3D[] roots)
    {
        foreach (var root in roots)
            foreach (var child in root.GetChildren())
                if (child is TierGate gate)
                {
                    foreach (var inner in gate.GetChildren())
                        if (inner is Node3D piece) yield return piece;
                }
                else if (child is Node3D piece) yield return piece;
    }
}
