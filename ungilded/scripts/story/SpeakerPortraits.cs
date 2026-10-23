using Godot;
using Godot.Collections;

namespace Ungilded.Story;

/// <summary>Which edge of the dialogue box a speaker's portrait sits on.</summary>
public enum PortraitSide
{
    Left,
    Right,
}

/// <summary>
/// One speaker's portrait animations and where the box shows them. Each <see cref="Emotion"/> names
/// two animations in <see cref="Frames"/>: one while its text types out and one while it waits.
/// </summary>
[GlobalClass]
public partial class SpeakerPortraits : Resource
{
    /// <summary>Matches <see cref="DialogueLine.Speaker"/> exactly.</summary>
    [Export] public string Speaker { get; set; } = "";

    [Export] public PortraitSide Side { get; set; } = PortraitSide.Left;

    /// <summary>Mirror the art so the face turns toward the centre of the box.</summary>
    [Export] public bool FlipH { get; set; }

    [Export] public SpriteFrames? Frames { get; set; }

    /// <summary>Animation per emotion while the line waits. Neutral is the fallback.</summary>
    [Export] public Dictionary<Emotion, StringName> Resting { get; set; } = new();

    /// <summary>Animation per emotion while its text types out. Falls back to the resting one.</summary>
    [Export] public Dictionary<Emotion, StringName> Talking { get; set; } = new();

    /// <summary>Overlay frames per accessory id, with the same animation names as <see cref="Frames"/>.</summary>
    [Export] public Dictionary<StringName, SpriteFrames> Accessories { get; set; } = new();

    public StringName For(Emotion emotion) =>
        Resting.TryGetValue(emotion, out var name) && !string.IsNullOrEmpty(name) ? name
        : Resting.TryGetValue(Emotion.Neutral, out var neutral) ? neutral : "";

    public StringName TalkingFor(Emotion emotion) =>
        Talking.TryGetValue(emotion, out var name) && !string.IsNullOrEmpty(name) ? name : For(emotion);

    /// <summary>True when <paramref name="animation"/> exists in <see cref="Frames"/>.</summary>
    public bool Has(StringName animation) => Frames?.HasAnimation(animation) == true;
}
