using System.Collections.Generic;
using Delve.Data;
using Delve.Flow;
using Godot;

namespace Delve.Village;

/// <summary>
/// One resident in the village: runs its driver (a day's routine, or a march to the line-up) and
/// stands its sprite where the driver says, on the ground. A spawner configures it on spawn.
/// </summary>
public partial class ResidentFigure : Node3D
{
    [Export] public ResidentSprite Sprite { get; set; } = null!;

    public string Id { get; private set; } = "";
    public string Area { get; private set; } = "";
    public IResidentDriver? Driver { get; private set; }

    /// <summary>The day's routine, when the figure is at home in the village.</summary>
    public ResidentRoutine? Routine => Driver as ResidentRoutine;

    /// <summary>The village's movers; the figure's driver joins it, and leaves when the figure is freed.
    /// A spawner sets it before <see cref="Begin"/> or <see cref="March"/>.</summary>
    public VillageCrowd? Crowd { get; set; }

    private CampTerrain? _ground;

    /// <summary>Set up the body; the driver comes from <see cref="Begin"/> or <see cref="March"/>.</summary>
    private void Body(string id, string folder, Texture2D[] seatPoses, int seed, CampTerrain? ground)
    {
        Id = id;
        _ground = ground;
        Sprite.Configure(folder, seatPoses, seed % 97 * 0.13f);
    }

    public void Begin(string id, string area, string folder, Texture2D[] seatPoses, VillageActivity activity,
        IReadOnlyList<SpotPlace> spots, int seed, CampTerrain? ground, System.Func<Vector2, Vector2, IReadOnlyList<Vector2>>? route)
    {
        Body(id, folder, seatPoses, seed, ground);
        Area = area;
        Driver = new ResidentRoutine(activity, spots, seed, Sprite.CanSit, Sprite.RiseSeconds, route, Crowd);
        Crowd?.Join(Driver);
        Apply();
    }

    public void March(string id, string folder, MarchRoutine march, int seed, CampTerrain? ground)
    {
        Body(id, folder, System.Array.Empty<Texture2D>(), seed, ground);
        Driver = march;
        Crowd?.Join(Driver);
        Apply();
    }

    /// <summary>Leaves the crowd at once and frees the figure at the end of the frame.</summary>
    public void Retire()
    {
        if (Driver != null) Crowd?.Leave(Driver);
        QueueFree();
    }

    public override void _ExitTree()
    {
        if (Driver != null) Crowd?.Leave(Driver);
    }

    public override void _Process(double delta)
    {
        if (Driver == null) return;
        Driver.Tick((float)delta);
        Apply();
    }

    private void Apply()
    {
        var at = Driver!.Position;
        var spot = new Vector3(at.X, 0, at.Y);
        Position = spot with { Y = _ground?.HeightAt(spot) ?? 0 };
        Sprite.Pose = Driver.Pose;
        Sprite.Clip = Driver.Clip;
        Sprite.Cycle = Driver.Cycle;
        Sprite.Facing = Driver.Facing;
    }
}
