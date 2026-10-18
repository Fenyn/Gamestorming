using Delve.UI;
using Godot;

namespace Delve.Dungeon;

/// <summary>Two small HUD beats: the ward's change floats off its number ("-5" on a crossing, "+40"
/// at a camp), and a room prompt that has just opened (Make camp, the way on) pulses once so the eye
/// finds it.</summary>
public partial class DungeonHud
{
    /// <summary>How far the ward change rises as it fades, and how long it takes.</summary>
    [Export] public float WardFloatRise { get; set; } = 28;

    [Export] public double WardFloatSeconds { get; set; } = 0.9;

    /// <summary>Scale a newly opened prompt swells to, and the length of one swell.</summary>
    [Export] public float PromptPulseScale { get; set; } = 1.08f;

    [Export] public double PromptPulseSeconds { get; set; } = 0.35;

    /// <summary>The last ward change that floated off the number, for spikes.</summary>
    public string LastWardFloat { get; private set; } = "";

    /// <summary>The ward change floats up from the ward number and fades.</summary>
    private void FloatWardChange(int delta)
    {
        if (delta == 0 || Instant || !_expedition.IsVisibleInTree()) return;
        LastWardFloat = delta > 0 ? $"+{delta}" : $"−{-delta}";
        var label = new Label
        {
            Text = LastWardFloat,
            ThemeTypeVariation = ThemeNames.HintRowLabel,
            Modulate = _wardValue.Modulate,
            MouseFilter = MouseFilterEnum.Ignore,
        };
        AddChild(label);
        var anchor = _wardValue.GetGlobalRect();
        label.ResetSize();
        label.GlobalPosition = new Vector2(anchor.Position.X - label.Size.X - 8, anchor.GetCenter().Y - label.Size.Y / 2);
        var tween = label.CreateTween().SetParallel(true);
        tween.TweenProperty(label, "position:y", label.Position.Y - WardFloatRise, WardFloatSeconds)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(label, "modulate:a", 0f, WardFloatSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        tween.Chain().TweenCallback(Callable.From(label.QueueFree));
    }

    /// <summary>Show or hide a prompt; one that has just opened swells twice.</summary>
    private void ShowPrompt(Control prompt, bool show)
    {
        bool opening = show && !prompt.Visible;
        prompt.Visible = show;
        if (!opening || Instant) return;
        PromptPulses++;
        prompt.PivotOffset = prompt.Size / 2;
        var tween = prompt.CreateTween();
        for (int swell = 0; swell < 2; swell++)
        {
            tween.TweenProperty(prompt, "scale", Vector2.One * PromptPulseScale, PromptPulseSeconds / 2)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
            tween.TweenProperty(prompt, "scale", Vector2.One, PromptPulseSeconds / 2)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.In);
        }
    }

    /// <summary>Prompts that have swelled on opening, for spikes.</summary>
    public int PromptPulses { get; private set; }
}
