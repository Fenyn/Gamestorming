using System;
using Delve.Run;
using Godot;

namespace Delve.Flow;

/// <summary>
/// A Campsite node: the party's state before the night, and one button to take it. The rules run in
/// <see cref="PartyRecovery.LongRest"/>; this only shows and signals.
/// </summary>
public partial class RestPanel : Control
{
    private Label _partyLabel = null!;
    private Label _clockLabel = null!;
    private Button _restButton = null!;

    public event Action? RestPressed;

    public override void _Ready()
    {
        _partyLabel = GetNode<Label>("%PartyLabel");
        _clockLabel = GetNode<Label>("%ClockLabel");
        _restButton = GetNode<Button>("%RestButton");
        _restButton.Pressed += () => RestPressed?.Invoke();
    }

    /// <summary>Show the party's HP and Wounded before the night's rest.</summary>
    public void Show(RunState state)
    {
        _clockLabel.Text = $"Day {state.Clock.Day} ends here.";
        _partyLabel.Text = string.Join("\n", PartyLines.Lines(state.Party));
        Visible = true;
    }
}
