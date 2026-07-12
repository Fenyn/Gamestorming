using Godot;

namespace Bulwark.Props;

/// <summary>
/// Looping ambient prop (lamp flame, fireplace fire). While on, plays the "on" loop and enables
/// the optional %Light (PointLight2D), gently flickering its energy for a live-fire feel. While
/// off, shows the "off" animation when the SpriteFrames has one (unlit lamp art), otherwise pauses
/// the loop on its first frame. Toggle from scene code via <see cref="SetOn"/> — e.g. light lamps
/// at dusk from the day cycle. Standalone-safe.
/// </summary>
public partial class AmbientProp : Node2D
{
    /// <summary>Starting state, applied on ready.</summary>
    [Export] public bool IsOn { get; set; } = true;

    /// <summary>Light energy flicker amplitude as a fraction of base energy; 0 disables.</summary>
    [Export] public float Flicker { get; set; } = 0.12f;

    private AnimatedSprite2D _sprite = null!;
    private PointLight2D? _light;
    private float _baseEnergy;
    private double _time;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("%Sprite");
        _light = GetNodeOrNull<PointLight2D>("%Light");
        _baseEnergy = _light?.Energy ?? 0f;
        Apply();
    }

    public override void _Process(double delta)
    {
        if (_light == null || !IsOn || Flicker <= 0f)
            return;

        // Layered incommensurate sines read as organic flame flicker without RNG state.
        _time += delta;
        float t = (float)_time;
        float noise = (Mathf.Sin(t * 7.3f) + 0.5f * Mathf.Sin(t * 13.1f) + 0.3f * Mathf.Sin(t * 3.7f)) / 1.8f;
        _light.Energy = _baseEnergy * (1f + Flicker * noise);
    }

    public void SetOn(bool on)
    {
        if (IsOn == on)
            return;
        IsOn = on;
        Apply();
    }

    private void Apply()
    {
        if (IsOn)
        {
            _sprite.Play("on");
        }
        else if (_sprite.SpriteFrames.HasAnimation("off"))
        {
            _sprite.Play("off");
        }
        else
        {
            _sprite.Stop();
            _sprite.Animation = "on";
            _sprite.Frame = 0;
        }

        if (_light != null)
        {
            _light.Enabled = IsOn;
            _light.Energy = _baseEnergy;
        }
    }
}
