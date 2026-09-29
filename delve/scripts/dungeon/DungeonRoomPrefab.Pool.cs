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

    private SpotLight3D? _pool;

    private void AddLightPool()
    {
        if (!LightPool) return;
        _pool = new SpotLight3D
        {
            Name = "LightPool",
            Position = new Vector3(Width * 0.5f, PoolHeight, Width * 0.5f),
            RotationDegrees = new Vector3(-90f, 0f, 0f),
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
