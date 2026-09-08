using System;
using System.Collections.Generic;
using Delve.Run;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>
/// The ten-minute block taken from the map. One button per activity; Treat Wounds also takes a
/// target, picked from the member row (unpicked leaves the choice to the rules layer). The header
/// prices the block in ward, the only thing a rest costs. Passive -
/// <see cref="ShortRest.Perform"/> runs in the flow layer and its lines come back through
/// <see cref="ShowResult"/>.
/// </summary>
public partial class ShortRestPanel : Control
{
    /// <summary>Activity label per kind - the one place the panel names them.</summary>
    private static readonly (ShortRestKind Kind, string Label)[] Activities =
    {
        (ShortRestKind.TreatWounds, "Treat Wounds"),
        (ShortRestKind.Refocus, "Refocus"),
        (ShortRestKind.RepairShield, "Repair Shield"),
    };

    private readonly List<(PF2eCharacter Member, Button Button)> _targets = new();

    private Label _clockLabel = null!;
    private VBoxContainer _activityBox = null!;
    private HBoxContainer _targetRow = null!;
    private Label _targetHeading = null!;
    private Label _resultLabel = null!;
    private Button _backButton = null!;
    private ButtonGroup _targetGroup = new();
    private bool _submitted;

    public event Action<ShortRestKind, PF2eCharacter?>? ActivityPicked;

    public event Action? Back;

    public override void _Ready()
    {
        _clockLabel = GetNode<Label>("%ClockLabel");
        _activityBox = GetNode<VBoxContainer>("%ActivityBox");
        _targetRow = GetNode<HBoxContainer>("%TargetRow");
        _targetHeading = GetNode<Label>("%TargetHeading");
        _resultLabel = GetNode<Label>("%ResultLabel");
        _backButton = GetNode<Button>("%BackButton");
        _backButton.Pressed += () => Back?.Invoke();
    }

    /// <summary>Rebuild the activity and target rows for the party's current state.</summary>
    public void Show(RunState state)
    {
        _submitted = false;
        _activityBox.Visible = true;
        _targetRow.Visible = true;
        _targetHeading.Visible = true;
        _backButton.Text = "Back";
        var ward = state.Wardstone;
        _clockLabel.Text = $"Day {state.Clock.Day}      Ward {ward.Ward} / {ward.Rules.MaxWard}"
                           + $"\nChoose one activity · Costs {ward.Rules.ShortRestBurn} ward. {WardLines.RestPreview(ward)}";
        _resultLabel.Text = "";
        BuildTargets(state.Party);
        BuildActivities(ward);
        Visible = true;
    }

    /// <summary>Print what the block did, then let the player go back to the map.</summary>
    public void ShowResult(ShortRestResult result, RunState state, int wardBefore)
    {
        _submitted = true;
        _activityBox.Visible = false;
        _targetRow.Visible = false;
        _targetHeading.Visible = false;
        var ward = state.Wardstone;
        _clockLabel.Text = $"Ward {ward.Ward} / {ward.Rules.MaxWard} · {wardBefore - ward.Ward} ward spent"
            + "\nReturn to the map to start another short rest.";
        _backButton.Text = "Return to map";
        var text = new System.Text.StringBuilder();
        if (!result.Performed && result.Reason != null)
            text.Append(result.Reason);
        foreach (string line in result.Lines)
        {
            if (text.Length > 0) text.Append('\n');
            text.Append(line);
        }
        _resultLabel.Text = text.ToString();
    }

    private void BuildActivities(Wardstone ward)
    {
        FreeChildren(_activityBox);

        string cost = $"Costs {ward.Rules.ShortRestBurn} ward. {WardLines.RestPreview(ward)}";

        foreach (var (kind, label) in Activities)
        {
            var button = new Button
            {
                Text = label,
                Disabled = !ward.CanAffordShortRest,
                TooltipText = ward.CanAffordShortRest ? cost : WardLines.RestUnavailable(ward),
            };
            var picked = kind;
            button.Pressed += () =>
            {
                if (_submitted || button.Disabled || !IsVisibleInTree()) return;
                _submitted = true;
                ActivityPicked?.Invoke(picked, SelectedTarget());
            };
            _activityBox.AddChild(button);
        }
    }

    private void BuildTargets(Party party)
    {
        FreeChildren(_targetRow);
        _targets.Clear();
        _targetGroup = new ButtonGroup();

        foreach (var member in party.Members)
        {
            var button = new Button
            {
                Text = PartyLines.Describe(member),
                ToggleMode = true,
                ButtonGroup = _targetGroup,
            };
            _targetRow.AddChild(button);
            _targets.Add((member, button));
        }
    }

    private PF2eCharacter? SelectedTarget()
    {
        foreach (var (member, button) in _targets)
        {
            if (button.ButtonPressed) return member;
        }
        return null;
    }

    private static void FreeChildren(Node parent)
    {
        foreach (var child in parent.GetChildren())
        {
            parent.RemoveChild(child);
            child.QueueFree();
        }
    }
}
