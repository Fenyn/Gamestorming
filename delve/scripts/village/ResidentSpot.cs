using Godot;

namespace Delve.Village;

/// <summary>A place one resident can stand or sit. Spots with the same <see cref="Area"/> make one work area.</summary>
public partial class ResidentSpot : Marker3D
{
    [Export] public string Area { get; set; } = "";

    /// <summary>The first town tier at which this spot exists.</summary>
    [Export] public int From { get; set; } = 1;

    /// <summary>The last town tier at which this spot exists; a later building can take its ground.</summary>
    [Export] public int To { get; set; } = 3;

    /// <summary>Which way a resident faces here, in grid space (x along world X, y along world Z).</summary>
    [Export] public Vector2 Facing { get; set; } = new(0, 1);

    [Export] public bool Seated { get; set; }

    /// <summary>
    /// The work this spot is for, matching an activity step's place (block, pile, anvil, bed...). A
    /// work step only runs at a spot of its use, facing the prop the use names. Empty: no work here.
    /// </summary>
    [Export] public string Use { get; set; } = "";

    public bool Builds(int tier) => tier >= From && tier <= To;

    public SpotPlace Place => new(new Vector2(GlobalPosition.X, GlobalPosition.Z), Facing, Seated, Use);
}
