using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>
/// A pulsing light an actor carries (the spectacles' violet in the Prologue): a light on the scenery,
/// a soft halo drawn over the sprite and a few sparkles. <see cref="Set"/> fades it in or out.
/// </summary>
public partial class CutsceneGlow : Node3D
{
    /// <summary>Light energy at the top of a pulse.</summary>
    [Export] public float MaxEnergy { get; set; } = 1.2f;

    /// <summary>Halo opacity at the top of a pulse.</summary>
    [Export] public float MaxHaloAlpha { get; set; } = 0.3f;

    [Export] public float PulseSeconds { get; set; } = 1.6f;

    /// <summary>Lowest point of a pulse, as a share of the top.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float PulseFloor { get; set; } = 0.45f;

    [Export] public float FadeSeconds { get; set; } = 0.6f;

    /// <summary>Metres the halo stands toward the camera, so it draws over the sprite it sits on.</summary>
    [Export] public float TowardCamera { get; set; } = 0.15f;

    public bool On { get; private set; }

    private OmniLight3D _light = null!;
    private Sprite3D _halo = null!;
    private GpuParticles3D _sparkles = null!;
    private float _strength;
    private float _time;
    private Tween? _fade;

    public override void _Ready()
    {
        _light = GetNode<OmniLight3D>("%Light");
        _halo = GetNode<Sprite3D>("%Halo");
        _sparkles = GetNode<GpuParticles3D>("%Sparkles");
        Apply();
    }

    /// <summary>Fade the glow in or out, <paramref name="height"/> metres above the carrier's feet.</summary>
    public void Set(bool on, float height)
    {
        On = on;
        Position = Vector3.Up * height;
        _sparkles.Emitting = on;
        _fade?.Kill();
        _fade = CreateTween();
        _fade.TweenProperty(this, nameof(Strength), on ? 1f : 0f, FadeSeconds);
    }

    /// <summary>0 out, 1 fully lit. Tweened by <see cref="Set"/>.</summary>
    public float Strength
    {
        get => _strength;
        set
        {
            _strength = value;
            Apply();
        }
    }

    public override void _Process(double delta)
    {
        if (_strength <= 0f) return;
        _time += (float)delta;
        Apply();
        if (GetViewport().GetCamera3D() is { } camera)
        {
            var toward = camera.GlobalPosition - GlobalPosition;
            _halo.Position = ToLocal(GlobalPosition + toward.Normalized() * TowardCamera);
        }
    }

    private void Apply()
    {
        if (_light == null) return;
        float wave = 0.5f + 0.5f * Mathf.Sin(_time * Mathf.Tau / Mathf.Max(PulseSeconds, 0.01f));
        float level = _strength * Mathf.Lerp(PulseFloor, 1f, wave);
        _light.LightEnergy = MaxEnergy * level;
        _light.Visible = level > 0f;
        _halo.Modulate = new Color(1f, 1f, 1f, MaxHaloAlpha * level);
        _halo.Visible = level > 0f;
    }
}
