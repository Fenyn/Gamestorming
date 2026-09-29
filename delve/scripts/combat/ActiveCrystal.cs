using Delve.UI;
using Godot;

namespace Delve.Combat;

/// <summary>
/// The FFT turn marker: a small glowing crystal that bobs and turns above the unit whose turn it
/// is. Knows nothing about units; the token shows it, hides it and sets its height.
/// </summary>
public partial class ActiveCrystal : Node3D
{
    /// <summary>Bob height, metres.</summary>
    [Export] public float BobAmplitude { get; set; } = 0.08f;

    /// <summary>Seconds per bob.</summary>
    [Export] public float BobPeriod { get; set; } = 1.2f;

    /// <summary>Turn speed, degrees per second.</summary>
    [Export] public float SpinDegreesPerSecond { get; set; } = 90f;

    /// <summary>Emission strength. Kept under the glow threshold unless the look wants bloom.</summary>
    [Export] public float EmissionEnergy { get; set; } = 0.5f;

    [Export] public MeshInstance3D[] Parts { get; set; } = System.Array.Empty<MeshInstance3D>();

    private float _time;
    private float _restY;

    public override void _Ready()
    {
        var color = UiColors.BoardCrystal;
        // Lit, so the four faces shade differently and read as a gem rather than a flat badge.
        var material = new StandardMaterial3D
        {
            AlbedoColor = color,
            Metallic = 0.4f,
            Roughness = 0.25f,
            EmissionEnabled = true,
            Emission = color,
            EmissionEnergyMultiplier = EmissionEnergy,
        };
        foreach (var part in Parts) part.MaterialOverride = material;
        _restY = Position.Y;
    }

    /// <summary>Place the crystal's rest height above the token origin.</summary>
    public void SetRestHeight(float y)
    {
        _restY = y;
        Position = Position with { Y = y };
    }

    public override void _Process(double delta)
    {
        if (!Visible) return;
        _time += (float)delta;
        Position = Position with { Y = _restY + BobAmplitude * Mathf.Sin(_time * Mathf.Tau / BobPeriod) };
        RotateY(Mathf.DegToRad(SpinDegreesPerSecond) * (float)delta);
    }
}
