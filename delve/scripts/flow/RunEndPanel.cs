using System;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// End of a run: the outcome, how deep the party got, and the way into the next run. No rewards or
/// scoring yet - the meta layer plugs in here.
/// </summary>
public partial class RunEndPanel : Control
{
    private Label _outcomeLabel = null!;
    private Label _detailLabel = null!;
    private Button _newRunButton = null!;

    public event Action? NewRunPressed;

    public override void _Ready()
    {
        _outcomeLabel = GetNode<Label>("%OutcomeLabel");
        _detailLabel = GetNode<Label>("%DetailLabel");
        _newRunButton = GetNode<Button>("%NewRunButton");
        _newRunButton.Pressed += () => NewRunPressed?.Invoke();
    }

    /// <summary>Show how the run ended. Colors come from the palette, never from a literal.</summary>
    public void Show(RunState state)
    {
        bool won = state.Outcome == RunOutcome.Victory;
        _outcomeLabel.Text = won ? "Victory" : "Defeat";
        _outcomeLabel.AddThemeColorOverride("font_color", won ? UiColors.Victory : UiColors.Defeat);

        int floorsCleared = state.CurrentNodeId == null ? 0 : state.Floor + 1;
        _detailLabel.Text = $"Floors reached {floorsCleared} of {state.Map.Floors}"
                            + $"      Day {state.Clock.Day}      Gold {state.Gold}";
        Visible = true;
    }
}
