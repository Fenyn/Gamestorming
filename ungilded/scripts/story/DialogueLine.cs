using Godot;

namespace Ungilded.Story;

/// <summary>Speaker mood for one line. It picks the portrait. Unity values map 0 Neutral, 1 Angry,
/// 2 Tired as Worried, 3 Amused, 4 Sad as Afraid.</summary>
public enum Emotion
{
    Neutral,
    Angry,
    Worried,
    Amused,
    Afraid,
}

/// <summary>One line of story text. Narration lines have no speaker and render in italics.</summary>
[GlobalClass]
public partial class DialogueLine : Resource
{
    /// <summary>"The Player", "The Friend", or empty for narration.</summary>
    [Export] public string Speaker { get; set; } = "";

    /// <summary>The line as written. A blank line between paragraphs is "\n\n".</summary>
    [Export(PropertyHint.MultilineText)] public string Text { get; set; } = "";

    [Export] public Emotion Emotion { get; set; } = Emotion.Neutral;

    [Export] public bool IsNarration { get; set; }
}
