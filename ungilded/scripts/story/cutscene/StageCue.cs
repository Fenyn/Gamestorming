using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>
/// One piece of staging on a <see cref="CutsceneSet"/>, carried by a <see cref="DialogueLine"/> and
/// played as the line starts. Positions are board tiles of the set's Prologue board; tiles outside
/// the board stand in its halo. The subclasses are the cue kinds.
/// </summary>
[GlobalClass]
public partial class StageCue : Resource
{
    /// <summary>The line's text waits, with the dialogue box closed, until this cue ends.</summary>
    [Export] public bool Wait { get; set; }

    /// <summary>Seconds after the line starts before the cue plays.</summary>
    [Export] public float Delay { get; set; }

    /// <summary>Start the cue on <paramref name="set"/>. The task ends when the cue does.</summary>
    public virtual Task Play(CutsceneSet set) => Task.CompletedTask;
}
