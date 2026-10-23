using Godot;
using Godot.Collections;
using Ungilded.Story.Cutscene;

namespace Ungilded.Story;

/// <summary>Speaker mood for one line. It picks the portrait. Unity values map 0 Neutral, 1 Angry,
/// 2 Tired as Worried, 3 Amused, 4 Sad. The values from 5 up are Godot-only.</summary>
public enum Emotion
{
    Neutral,
    Angry,
    Worried,
    Amused,
    Sad,
    Determined,
    Smirk,
    Thinking,
    Shocked,
    Exasperated,
    Grin,
    Awe,
    Relieved,
    Suspicious,
    Solemn,
    Hurt,
}

/// <summary>One line of story text. Narration lines have no speaker and use the narration style.</summary>
[GlobalClass]
public partial class DialogueLine : Resource
{
    /// <summary>"The Player", "The Friend", or empty for narration.</summary>
    [Export] public string Speaker { get; set; } = "";

    /// <summary>The line as written. A blank line between paragraphs is "\n\n".</summary>
    [Export(PropertyHint.MultilineText)] public string Text { get; set; } = "";

    [Export] public Emotion Emotion { get; set; } = Emotion.Neutral;

    [Export] public bool IsNarration { get; set; }

    /// <summary>A <see cref="CrawlScenery"/> scene shown behind this narration page. Empty shows black.
    /// Consecutive pages with the same scene keep one instance.</summary>
    [Export] public PackedScene? Scenery { get; set; }

    /// <summary>On a narration page: the black behind the text fades out and the cutscene set of the
    /// next set-backdrop beat shows instead.</summary>
    [Export] public bool RevealsSet { get; set; }

    /// <summary>Applied as the line starts, before its portrait shows.</summary>
    [Export] public Array<AccessoryCue> AccessoryCues { get; set; } = new();

    /// <summary>Staging on the live cutscene set, started as the line starts. Ignored with no set.</summary>
    [Export] public Array<StageCue> StageCues { get; set; } = new();
}
