using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// The FFT instruction pill at the top centre and the button-hint row along the bottom edge.
/// Renders a <see cref="CommandPrompt"/> and nothing else; the scene decides when to show it.
/// </summary>
public partial class CommandPromptView : Control
{
    [Export] public Control Pill { get; set; } = null!;
    [Export] public Label Instruction { get; set; } = null!;
    [Export] public HBoxContainer Hints { get; set; } = null!;

    public string InstructionText => Instruction.Text;
    public bool PillShown => Pill.Visible;

    private readonly List<string> _hintLabels = new();

    /// <summary>What each shown hint does ("Move", "Cancel"), in order; empty while hidden.</summary>
    public IReadOnlyList<string> HintLabels => _hintLabels;

    public void Render(CommandPrompt? prompt)
    {
        Visible = prompt != null;
        _hintLabels.Clear();
        if (prompt == null) return;
        Instruction.Text = prompt.Instruction;
        Pill.Visible = prompt.Instruction.Length > 0;
        foreach (var child in Hints.GetChildren())
        {
            Hints.RemoveChild(child);
            child.QueueFree();
        }
        foreach (var hint in prompt.Hints) AddHint(hint);
    }

    private void AddHint(KeyHint hint)
    {
        _hintLabels.Add(hint.Label);
        string key = hint.IsAction ? string.Join(" ", System.Array.ConvertAll(hint.Key.Split('+'), k => InputNames.KeyLabelFor(k))) : hint.Key;
        var keycap = new PanelContainer { ThemeTypeVariation = ThemeNames.HintKeycap, MouseFilter = MouseFilterEnum.Ignore };
        keycap.AddChild(new Label
        {
            Text = hint.MouseButton.Length > 0 ? $"{hint.MouseButton} {key}" : key,
            ThemeTypeVariation = ThemeNames.HintKeycapLabel,
            MouseFilter = MouseFilterEnum.Ignore,
        });
        Hints.AddChild(keycap);
        Hints.AddChild(new Label { Text = hint.Label, ThemeTypeVariation = ThemeNames.HintRowLabel, MouseFilter = MouseFilterEnum.Ignore });
    }
}
