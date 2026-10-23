using System.Collections.Generic;
using Ungilded.Knowledge;
using Godot;

namespace Ungilded.UI;

/// <summary>A species' journal fields as labelled values in columns. Known values read in body ink,
/// unknown ones ("AC ?") dim. Shared by the combat journal and the outpost bestiary. A render with
/// the same number of facts updates the labels in place, so a running <see cref="Pulse"/> survives it.</summary>
public partial class JournalFactsGrid : GridContainer
{
    /// <summary>Seconds of one swing of a pulse, to the focus colour or back.</summary>
    [Export] public float PulseSeconds { get; set; } = 0.25f;

    /// <summary>How many times a pulse swings to the focus colour and back.</summary>
    [Export] public int PulseRepeats { get; set; } = 2;

    private const string FontColor = "font_color";
    private const string FontColorOverride = "theme_override_colors/font_color";

    public void Render(IReadOnlyList<JournalFact> facts)
    {
        if (GetChildCount() != facts.Count)
        {
            foreach (var child in GetChildren())
            {
                RemoveChild(child);
                child.QueueFree();
            }
            foreach (var _ in facts)
                AddChild(new Label
                {
                    AutowrapMode = TextServer.AutowrapMode.WordSmart,
                    SizeFlagsHorizontal = SizeFlags.ExpandFill,
                    MouseFilter = MouseFilterEnum.Ignore,
                });
        }
        for (int i = 0; i < facts.Count; i++)
        {
            var label = GetChild<Label>(i);
            label.Text = facts[i].Text;
            label.ThemeTypeVariation = facts[i].Known ? "" : ThemeNames.HintLabel;
        }
    }

    /// <summary>Swing the text colour of fact <paramref name="index"/> to the focus colour and back.
    /// The text does not change. False when there is no such fact.</summary>
    public bool Pulse(int index)
    {
        if (index < 0 || index >= GetChildCount() || GetChild(index) is not Label label) return false;
        label.RemoveThemeColorOverride(FontColor);
        var rest = label.GetThemeColor(FontColor);
        label.AddThemeColorOverride(FontColor, rest);
        var tween = label.CreateTween();
        for (int i = 0; i < PulseRepeats; i++)
        {
            tween.TweenProperty(label, FontColorOverride, UiColors.Focus, PulseSeconds);
            tween.TweenProperty(label, FontColorOverride, rest, PulseSeconds);
        }
        tween.TweenCallback(Callable.From(() => label.RemoveThemeColorOverride(FontColor)));
        return true;
    }
}
