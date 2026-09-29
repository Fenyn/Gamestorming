using Godot;

namespace Delve.Dungeon;

/// <summary>
/// The FFT interior light: one warm spot pool on the room's middle, so the floor under the party
/// is lit and the walls and corners fall away into the dark.
/// </summary>
public partial class DungeonRoomPrefab
{
    [Export] public bool LightPool { get; set; } = true;

    /// <summary>Height of the pool light above the floor, metres.</summary>
    [Export] public float PoolHeight { get; set; } = 9f;

    /// <summary>Cone half-angle, degrees. The pool radius on the floor follows from the height.</summary>
    [Export] public float PoolAngle { get; set; } = 34f;

    [Export] public float PoolEnergy { get; set; } = 6f;

    /// <summary>Cone edge softness, 0 hard to 1 very soft.</summary>
    [Export] public float PoolSoftness { get; set; } = 0.6f;

    /// <summary>Degrees the pool leans off straight down, and the compass direction it comes from. A
    /// raking light catches the far walls' faces as well as the floor, where a vertical cone leaves
    /// every wall black.</summary>
    [Export] public float PoolTiltDegrees { get; set; } = 28f;
    [Export] public float PoolYawDegrees { get; set; } = 45f;

    private SpotLight3D? _pool;

    private void AddLightPool()
    {
        if (!LightPool) return;
        var rotation = new Vector3(PoolTiltDegrees - 90f, PoolYawDegrees, 0f);
        var forward = -Basis.FromEuler(rotation * Mathf.Pi / 180f).Z;
        // Keep the cone's axis on the room's centre at the authored height above it.
        var centre = new Vector3(Width * 0.5f, 0f, Width * 0.5f);
        _pool = new SpotLight3D
        {
            Name = "LightPool",
            Position = centre - forward * (PoolHeight / Mathf.Max(0.1f, -forward.Y)),
            RotationDegrees = rotation,
            SpotAngle = PoolAngle,
            SpotAngleAttenuation = PoolSoftness,
            SpotRange = PoolHeight * 1.6f,
            LightEnergy = PoolEnergy,
            LightColor = PaletteTint("pool_light"),
            ShadowEnabled = true,
        };
        AddChild(_pool);
    }
}
