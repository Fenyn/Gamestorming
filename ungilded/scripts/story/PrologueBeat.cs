using Godot;

namespace Ungilded.Story;

public enum BeatKind
{
    /// <summary>Full-screen narration pages over black.</summary>
    Narration,
    /// <summary>Dialogue box over the sequence's <see cref="DialogueSequence.Backdrop"/>.</summary>
    Dialogue,
    /// <summary>One encounter through the <see cref="IEncounterRunner"/>.</summary>
    Encounter,
}

/// <summary>One step of the Prologue, run in order by <see cref="PrologueDirector"/>.</summary>
[GlobalClass]
public partial class PrologueBeat : Resource
{
    [Export] public BeatKind Kind { get; set; }

    /// <summary>The lines for a Narration or Dialogue beat.</summary>
    [Export] public DialogueSequence? Sequence { get; set; }

    /// <summary>The encounter for an Encounter beat.</summary>
    [Export(PropertyHint.Range, "1,4,1")] public int Encounter { get; set; } = 1;

    /// <summary>Short label for logs and checks: "narration:id", "dialogue:id:board",
    /// "dialogue:id:set", "encounter:2".</summary>
    public string Describe() => Kind switch
    {
        BeatKind.Narration => $"narration:{Sequence?.Id}",
        BeatKind.Dialogue => $"dialogue:{Sequence?.Id}:{Sequence?.Backdrop.ToString().ToLowerInvariant()}",
        _ => $"encounter:{Encounter}",
    };
}
