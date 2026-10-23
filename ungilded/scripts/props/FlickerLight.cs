using Godot;

namespace Ungilded.Props;

/// <summary>
/// Flame breathing on a light: energy and range drift around their authored values on two slow
/// summed sines, and now and then the flame gutters in a short eased dip. Phase and gutter timing
/// come from the light's position, so neighbouring torches never breathe together.
/// </summary>
public partial class FlickerLight : OmniLight3D
{
    /// <summary>Largest energy swing, as a fraction of the authored energy.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float EnergySwing { get; set; } = 0.08f;

    /// <summary>Largest range swing, as a fraction of the authored range.</summary>
    [Export(PropertyHint.Range, "0,0.5,0.01")] public float RangeSwing { get; set; } = 0.02f;

    /// <summary>Breathing rate in cycles per second.</summary>
    [Export] public float Rate { get; set; } = 0.9f;

    /// <summary>Rate of the slow drift wave as a fraction of <see cref="Rate"/>.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float DriftRatio { get; set; } = 0.37f;

    /// <summary>Share of the swing the drift wave carries.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float DriftShare { get; set; } = 0.4f;

    /// <summary>Energy lost at the bottom of a gutter, as a fraction of the authored energy.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float GutterDepth { get; set; } = 0.14f;

    /// <summary>Length of one gutter, seconds.</summary>
    [Export] public float GutterSeconds { get; set; } = 1.2f;

    /// <summary>Shortest and longest wait between gutters, seconds.</summary>
    [Export] public Vector2 GutterInterval { get; set; } = new(6f, 14f);

    /// <summary>Sprite whose alpha follows the light energy, such as the flame's glow. Optional.</summary>
    [Export] public SpriteBase3D? Glow { get; set; }

    /// <summary>Share of the light that burns, 0 to 1; an owner fades the flame out with it.</summary>
    public float Level { get; set; } = 1f;

    private readonly RandomNumberGenerator _rng = new();
    private float _energy;
    private float _range;
    private float _phase;
    private float _driftPhase;
    private float _time;
    private float _gutterStart = float.NegativeInfinity;
    private float _nextGutter;
    private Color _glow;

    public override void _Ready()
    {
        _energy = LightEnergy;
        _range = OmniRange;
        _rng.Seed = (uint)GD.Hash(GlobalPosition);
        _phase = _rng.RandfRange(0f, Mathf.Tau);
        _driftPhase = _rng.RandfRange(0f, Mathf.Tau);
        _nextGutter = _rng.RandfRange(0f, GutterInterval.Y);
        if (Glow != null) _glow = Glow.Modulate;
    }

    public override void _Process(double delta)
    {
        _time += (float)delta;
        float t = _time * Rate * Mathf.Tau;
        float wave = (1f - DriftShare) * Mathf.Sin(t + _phase) + DriftShare * Mathf.Sin(t * DriftRatio + _driftPhase);
        if (_time >= _nextGutter)
        {
            _gutterStart = _nextGutter;
            _nextGutter += GutterSeconds + _rng.RandfRange(GutterInterval.X, GutterInterval.Y);
        }
        float u = (_time - _gutterStart) / GutterSeconds;
        float gutter = u is >= 0f and < 1f ? Mathf.Pow(Mathf.Sin(Mathf.Pi * u), 2f) : 0f;
        float level = (1f + EnergySwing * wave - GutterDepth * gutter) * Level;
        LightEnergy = _energy * level;
        OmniRange = _range * (1f + RangeSwing * wave);
        if (Glow != null) Glow.Modulate = _glow with { A = _glow.A * level };
    }
}
