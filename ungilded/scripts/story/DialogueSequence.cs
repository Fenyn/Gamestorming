using Godot;
using Godot.Collections;

namespace Ungilded.Story;

/// <summary>What sits behind a dialogue sequence: the black overlay, the encounter board, or a
/// cutscene set.</summary>
public enum DialogueBackdrop
{
    Black,
    Board,
    Set,
}

/// <summary>An ordered run of lines played in one dialogue box or narration screen.</summary>
[GlobalClass]
public partial class DialogueSequence : Resource
{
    /// <summary>Stable id, taken from the Unity asset name in snake case.</summary>
    [Export] public string Id { get; set; } = "";

    [Export] public Array<DialogueLine> Lines { get; set; } = new();

    [Export] public DialogueBackdrop Backdrop { get; set; } = DialogueBackdrop.Black;

    /// <summary>The <see cref="Cutscene.CutsceneSet"/> scene a <see cref="DialogueBackdrop.Set"/>
    /// backdrop plays on. Consecutive beats with the same scene share one instance.</summary>
    [Export] public PackedScene? CutsceneSet { get; set; }
}
