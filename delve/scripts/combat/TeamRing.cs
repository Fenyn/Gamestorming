using Godot;

namespace Delve.Combat;

/// <summary>
/// Ground ring under an entity. Its colour shows which side the entity is on, and a pop followed by a
/// continuous breath shows that the entity has the turn. It knows nothing about characters or rules.
///
/// SCALE OWNERSHIP. The pop tween hands off to the pulse tween and each keeps its own handle, so
/// <see cref="SetActive"/> can kill both. A deactivate during the pop can therefore never let the
/// finished-callback start a pulse on an entity whose turn has already passed.
/// </summary>
public partial class TeamRing : MeshInstance3D
{
    /// <summary>Ring colour while the entity has the turn.</summary>
    [Export] public Color ActiveColor { get; set; } = new(1f, 0.9f, 0.3f, 0.9f);

    /// <summary>Alpha of the team colour while the entity waits its turn.</summary>
    [Export] public float RestAlpha { get; set; } = 0.45f;

    // The pop scale overshoots the active scale, so the turn handover reads as a beat rather than as
    // a state change.
    [Export] public Vector3 ActiveScale { get; set; } = new(1.18f, 1f, 1.18f);
    [Export] public Vector3 PopScale { get; set; } = new(1.34f, 1f, 1.34f);
    [Export] public Vector3 PulseScale { get; set; } = new(1.26f, 1f, 1.26f);

    [Export] public float PopDuration { get; set; } = 0.11f;
    [Export] public float SettleDuration { get; set; } = 0.09f;
    [Export] public float PulseDuration { get; set; } = 0.65f;

    private StandardMaterial3D _mat = null!;
    private Color _teamColor = Colors.White;
    private bool _active;
    private Tween? _popTween;
    private Tween? _pulseTween;
    private Tween? _fadeTween;

    private Color RestColor => _teamColor with { A = RestAlpha };

    /// <summary>Set the team tint. The material is per-instance and built here, because
    /// <see cref="SetActive"/> and <see cref="FadeOut"/> both mutate it.</summary>
    public void SetTeamColor(Color color)
    {
        _teamColor = color;
        _mat = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            AlbedoColor = RestColor,
        };
        MaterialOverride = _mat;
    }

    public void SetActive(bool active)
    {
        _active = active;
        _mat.AlbedoColor = active ? ActiveColor : RestColor;

        // One writer at a time for scale: kill whichever of the two is live, then snap to rest.
        _popTween?.Kill();
        _popTween = null;
        _pulseTween?.Kill();
        _pulseTween = null;
        Scale = Vector3.One;
        if (!active) return;

        _popTween = CreateTween();
        _popTween.TweenProperty(this, "scale", PopScale, PopDuration)
            .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
        _popTween.TweenProperty(this, "scale", ActiveScale, SettleDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _popTween.TweenCallback(Callable.From(StartPulse));
    }

    private void StartPulse()
    {
        if (!_active) return;
        _pulseTween?.Kill();
        _pulseTween = CreateTween();
        _pulseTween.SetLoops();
        _pulseTween.TweenProperty(this, "scale", PulseScale, PulseDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        _pulseTween.TweenProperty(this, "scale", ActiveScale, PulseDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
    }

    /// <summary>Fade the ring away, for example when its entity dies.</summary>
    public void FadeOut(float duration)
    {
        _fadeTween?.Kill();
        _fadeTween = CreateTween();
        _fadeTween.TweenProperty(_mat, "albedo_color", _teamColor with { A = 0f }, duration);
    }
}
