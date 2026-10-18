using Godot;

namespace Delve.Village;

/// <summary>The camp's light at one time of day: sun, ambient light, exposure and the hearth fire.</summary>
[GlobalClass]
public partial class CampLight : Resource
{
    [Export] public Vector3 SunRotationDegrees { get; set; } = new(-42, -55, 0);
    [Export] public Color SunColor { get; set; } = Colors.White;
    [Export] public float SunEnergy { get; set; } = 1f;
    [Export] public Color AmbientColor { get; set; } = Colors.White;
    [Export] public float AmbientEnergy { get; set; } = 0.75f;
    [Export] public float Exposure { get; set; } = 1f;
    [Export] public float FireEnergy { get; set; } = 1f;

    /// <summary>Lamps, door lights and lit windows are on.</summary>
    [Export] public bool Evening { get; set; }
}
