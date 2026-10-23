using System.Linq;
using System.Threading.Tasks;
using Godot;
using Godot.Collections;

namespace Ungilded.Story.Cutscene;

/// <summary>Walks an actor from where it stands through <see cref="Path"/>, one tile after another,
/// facing each step. Diagonal steps are allowed.</summary>
[GlobalClass]
public partial class WalkCue : StageCue
{
    [Export] public StringName Actor { get; set; } = "";

    /// <summary>The tiles to walk through, in order, ending where the actor stops. A creature wider
    /// than one tile walks the low corner of its space through them.</summary>
    [Export] public Array<Vector2I> Path { get; set; } = new();

    /// <summary>Direction to face after the last step. Zero keeps the last step's direction.</summary>
    [Export] public Vector2I EndFacing { get; set; }

    /// <summary>Seconds per tile. Zero uses the actor's own pace.</summary>
    [Export] public float SecondsPerTile { get; set; }

    /// <summary>Hold the facing the actor has when the walk starts, as in a step back.</summary>
    [Export] public bool KeepFacing { get; set; }

    public override Task Play(CutsceneSet set) =>
        set.Actor(Actor).Walk(Path.Select(tile => set.Step(Actor, tile)).ToList(), EndFacing, SecondsPerTile, KeepFacing);
}
