using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>Turns an actor toward another actor, or to a grid direction.</summary>
[GlobalClass]
public partial class FaceCue : StageCue
{
    [Export] public StringName Actor { get; set; } = "";

    /// <summary>The actor to look at. Empty uses <see cref="Facing"/>.</summary>
    [Export] public StringName Toward { get; set; } = "";

    [Export] public Vector2I Facing { get; set; } = new(-1, 0);

    public override Task Play(CutsceneSet set)
    {
        var actor = set.Actor(Actor);
        if (Toward.IsEmpty) actor.Face(Facing);
        else
        {
            var other = set.Actor(Toward).Destination;
            actor.Face(new Vector2(other.X - actor.Destination.X, other.Z - actor.Destination.Z));
        }
        return Task.CompletedTask;
    }
}
