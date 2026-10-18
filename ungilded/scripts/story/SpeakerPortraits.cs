using Godot;

namespace Ungilded.Story;

/// <summary>Which edge of the dialogue box a speaker's portrait sits on.</summary>
public enum PortraitSide
{
    Left,
    Right,
}

/// <summary>One speaker's portrait per <see cref="Emotion"/>, and where the box shows it.</summary>
[GlobalClass]
public partial class SpeakerPortraits : Resource
{
    /// <summary>Matches <see cref="DialogueLine.Speaker"/> exactly.</summary>
    [Export] public string Speaker { get; set; } = "";

    [Export] public PortraitSide Side { get; set; } = PortraitSide.Left;

    /// <summary>Mirror the art so the face turns toward the centre of the box.</summary>
    [Export] public bool FlipH { get; set; }

    [Export] public Texture2D? Neutral { get; set; }
    [Export] public Texture2D? Angry { get; set; }
    [Export] public Texture2D? Worried { get; set; }
    [Export] public Texture2D? Amused { get; set; }
    [Export] public Texture2D? Afraid { get; set; }

    /// <summary>The portrait for <paramref name="emotion"/>, falling back to Neutral when it is unset.</summary>
    public Texture2D? For(Emotion emotion) => (emotion switch
    {
        Emotion.Angry => Angry,
        Emotion.Worried => Worried,
        Emotion.Amused => Amused,
        Emotion.Afraid => Afraid,
        _ => Neutral,
    }) ?? Neutral;
}
