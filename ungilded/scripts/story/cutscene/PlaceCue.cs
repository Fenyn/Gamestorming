using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>Shows an actor on a tile at once, facing <see cref="Facing"/>. An actor stays hidden until
/// its first place cue.</summary>
[GlobalClass]
public partial class PlaceCue : StageCue
{
    /// <summary>A hero character id ("player", "friend") or a creature actor id of the set
    /// (<see cref="CutsceneSet.Creatures"/>).</summary>
    [Export] public StringName Actor { get; set; } = "";

    /// <summary>The actor's tile; for a creature wider than one tile, the low corner of its space.</summary>
    [Export] public Vector2I Tile { get; set; }

    /// <summary>Grid direction the actor looks: (-1, 0) is west, (1, 0) east.</summary>
    [Export] public Vector2I Facing { get; set; } = new(-1, 0);

    public override Task Play(CutsceneSet set)
    {
        var actor = set.Actor(Actor);
        actor.Place(Tile, set.StandPoint(Tile, actor.Width), Facing);
        return Task.CompletedTask;
    }
}
