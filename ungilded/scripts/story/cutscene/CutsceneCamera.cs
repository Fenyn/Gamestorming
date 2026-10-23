using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>One camera pose as an orbit around <see cref="Target"/>: yaw and pitch in degrees,
/// distance in metres, vertical field of view in degrees, and the camera's in-plane shift.</summary>
public readonly record struct CameraShot(Vector3 Target, float Yaw, float Pitch, float Distance, float Fov, Vector2 Shift)
{
    /// <summary>Unit direction on the floor plane (x, z) from the target to the camera.</summary>
    public Vector2 Toward => new(Mathf.Sin(Mathf.DegToRad(Yaw)), Mathf.Cos(Mathf.DegToRad(Yaw)));

    public static CameraShot Lerp(CameraShot from, CameraShot to, float t) => new(
        from.Target.Lerp(to.Target, t),
        Mathf.RadToDeg(Mathf.LerpAngle(Mathf.DegToRad(from.Yaw), Mathf.DegToRad(to.Yaw), t)),
        Mathf.Lerp(from.Pitch, to.Pitch, t),
        Mathf.Lerp(from.Distance, to.Distance, t),
        Mathf.Lerp(from.Fov, to.Fov, t),
        from.Shift.Lerp(to.Shift, t));
}

/// <summary>
/// The set's camera. It holds one <see cref="CameraShot"/> and blends to the next by interpolating
/// the orbit, so a blend swings around the subject instead of cutting through it. Its own camera
/// attributes replace the look's, whose depth of field is tuned for the tactical camera's distance.
/// </summary>
public partial class CutsceneCamera : Camera3D
{
    private CameraShot _shot;
    private Tween? _tween;
    private TaskCompletionSource? _blend;

    public CameraShot Shot => _shot;

    /// <summary>True while a blend runs.</summary>
    public bool IsBlending => _blend != null;

    /// <summary>Fires as a cut or a blend starts, with the shot it ends on.</summary>
    public event System.Action<CameraShot>? ShotStarted;

    /// <summary>Move to <paramref name="to"/> over <paramref name="seconds"/>; zero, or no shot yet,
    /// cuts. A new blend starts from wherever the running one has reached and ends its task.</summary>
    public Task Blend(CameraShot to, float seconds, Tween.TransitionType transition, Tween.EaseType ease)
    {
        EndBlend();
        ShotStarted?.Invoke(to);
        if (seconds <= 0f || _shot.Distance <= 0f)
        {
            Apply(to);
            return Task.CompletedTask;
        }
        var from = _shot;
        var done = new TaskCompletionSource();
        _blend = done;
        var tween = CreateTween().SetTrans(transition).SetEase(ease);
        _tween = tween;
        tween.TweenMethod(Callable.From<float>(t => Apply(CameraShot.Lerp(from, to, t))), 0f, 1f, seconds);
        tween.Finished += () =>
        {
            if (_tween != tween) return;
            _tween = null;
            _blend = null;
            done.TrySetResult();
        };
        return done.Task;
    }

    public override void _ExitTree() => EndBlend();

    /// <summary>Shake frequency, cycles per second.</summary>
    [Export] public float ShakeHertz { get; set; } = 18f;

    /// <summary>Fires as a shake starts.</summary>
    public event System.Action? Shaken;

    /// <summary>Shakes so far.</summary>
    public int Shakes { get; private set; }

    private float _shakeAmplitude, _shakeSeconds, _shakeLeft;

    /// <summary>Jolt the camera in its own plane by up to <paramref name="amplitude"/> metres,
    /// easing out over <paramref name="seconds"/>. The shot itself does not move.</summary>
    public void Shake(float amplitude, float seconds)
    {
        _shakeAmplitude = amplitude;
        _shakeSeconds = _shakeLeft = Mathf.Max(seconds, 0.01f);
        Shakes++;
        Shaken?.Invoke();
    }

    public override void _Process(double delta)
    {
        if (_shakeLeft <= 0f) return;
        _shakeLeft = Mathf.Max(0f, _shakeLeft - (float)delta);
        float t = (_shakeSeconds - _shakeLeft) * ShakeHertz * Mathf.Tau;
        float reach = _shakeAmplitude * _shakeLeft / _shakeSeconds;
        HOffset = _shot.Shift.X + Mathf.Sin(t) * reach;
        VOffset = _shot.Shift.Y + Mathf.Sin(t * 1.37f + 1f) * reach;
    }

    private void EndBlend()
    {
        _tween?.Kill();
        _tween = null;
        var blend = _blend;
        _blend = null;
        blend?.TrySetResult();
    }

    private void Apply(CameraShot shot)
    {
        _shot = shot;
        float pitch = Mathf.DegToRad(shot.Pitch);
        var toward = shot.Toward * shot.Distance * Mathf.Cos(pitch);
        var offset = new Vector3(toward.X, shot.Distance * Mathf.Sin(pitch), toward.Y);
        GlobalPosition = shot.Target + offset;
        LookAt(shot.Target, Vector3.Up);
        Fov = shot.Fov;
        HOffset = shot.Shift.X;
        VOffset = shot.Shift.Y;
    }
}
