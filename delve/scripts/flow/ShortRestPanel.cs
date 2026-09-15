using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>One simultaneous ten-minute schedule, submitted once for the whole party.</summary>
public partial class ShortRestPanel : Control
{
    private sealed record Row(PF2eCharacter Actor, OptionButton Activity, OptionButton Target);
    private static readonly (ShortRestKind Kind, string Label)[] Activities =
    {
        (ShortRestKind.Rest, "Rest quietly"),
        (ShortRestKind.TreatWounds, "Treat Wounds"),
        (ShortRestKind.Refocus, "Refocus"),
        (ShortRestKind.RepairShield, "Repair Shield"),
    };
    private readonly List<Row> _rows = new();
    private Label _clockLabel = null!;
    private VBoxContainer _activityBox = null!;
    private Label _resultLabel = null!;
    private Button _backButton = null!;
    private Button _confirm = null!;
    private RunState _state = null!;
    private bool _submitted;
    public event Action<IReadOnlyList<RestAssignment>>? SchedulePicked;
    public event Action? Back;

    public override void _Ready()
    {
        _clockLabel = GetNode<Label>("%ClockLabel");
        _activityBox = GetNode<VBoxContainer>("%ActivityBox");
        _resultLabel = GetNode<Label>("%ResultLabel");
        _backButton = GetNode<Button>("%BackButton");
        _confirm = GetNode<Button>("%ConfirmButton");
        _backButton.Pressed += () => Back?.Invoke();
        _confirm.Pressed += () =>
        {
            if (_submitted || _confirm.Disabled || !IsVisibleInTree()) return;
            _submitted = true;
            _confirm.Disabled = true;
            SchedulePicked?.Invoke(Assignments());
        };
    }

    public void Show(RunState state)
    {
        _state = state;
        _submitted = false;
        _activityBox.Visible = true;
        _confirm.Visible = true;
        _backButton.Text = "Cancel";
        var ward = state.Wardstone;
        _clockLabel.Text = $"Day {state.Clock.Day} | Ward {ward.Ward}/{ward.Rules.MaxWard}\nOne activity per character. Everyone acts during the same ten minutes.\n{WardLines.RestPreview(ward)}";
        _confirm.Text = $"Begin ten-minute rest - {ward.Rules.ShortRestBurn} ward total";
        BuildRows();
        ValidateSchedule();
        Visible = true;
    }

    private void BuildRows()
    {
        foreach (var child in _activityBox.GetChildren())
        {
            _activityBox.RemoveChild(child);
            child.QueueFree();
        }
        _rows.Clear();
        var living = _state.Party.Living();
        foreach (var member in living)
        {
            var box = new VBoxContainer();
            box.AddChild(new Label { Text = PartyLines.Describe(member) });
            var controls = new HBoxContainer();
            var activity = new OptionButton { CustomMinimumSize = new Vector2(220, 40) };
            foreach (var (kind, label) in Activities) activity.AddItem(label, (int)kind);
            activity.SetItemDisabled(2, member.Spellcasting?.MaxFocusPoints is not > 0);
            activity.SetItemDisabled(3, !living.Any(m => m.Equipment?.Shield?.EquippedShield != null));
            var target = new OptionButton { CustomMinimumSize = new Vector2(260, 40), Visible = false };
            target.AddItem("Choose target...", -1);
            for (int i = 0; i < living.Count; i++) target.AddItem(living[i].Name, i);
            controls.AddChild(activity);
            controls.AddChild(target);
            box.AddChild(controls);
            _activityBox.AddChild(box);
            var row = new Row(member, activity, target);
            _rows.Add(row);
            activity.ItemSelected += _ =>
            {
                var kind = (ShortRestKind)activity.GetSelectedId();
                target.Visible = kind is ShortRestKind.TreatWounds or ShortRestKind.RepairShield;
                for (int i = 0; i < living.Count; i++)
                    target.SetItemDisabled(i + 1, kind == ShortRestKind.RepairShield && living[i].Equipment?.Shield?.EquippedShield == null);
                if (target.Selected > 0 && target.IsItemDisabled(target.Selected)) target.Select(0);
                ValidateSchedule();
            };
            target.ItemSelected += _ => ValidateSchedule();
        }
    }

    public IReadOnlyList<RestAssignment> Assignments()
    {
        var living = _state.Party.Living();
        return _rows.Select(r => new RestAssignment(r.Actor, (ShortRestKind)r.Activity.GetSelectedId(),
            r.Target.Visible && r.Target.Selected > 0 ? living[r.Target.Selected - 1] : null)).ToArray();
    }

    private void ValidateSchedule()
    {
        string? reason = ShortRest.Validate(_state.Party, Assignments());
        if (!_state.Wardstone.CanAffordShortRest) reason = WardLines.RestUnavailable(_state.Wardstone);
        _confirm.Disabled = _submitted || reason != null;
        _resultLabel.Text = reason ?? "Treat Wounds needs a patient. Repair Shield needs a shield owner. Receiving treatment does not use your activity.";
    }

    public void ShowResult(ShortRestResult result, RunState state, int wardBefore)
    {
        if (!result.Performed)
        {
            _submitted = false;
            ValidateSchedule();
            _resultLabel.Text = result.Reason ?? "The rest could not begin.";
            return;
        }
        _submitted = true;
        _activityBox.Visible = false;
        _confirm.Visible = false;
        _clockLabel.Text = $"Ten minutes passed | Ward {state.Wardstone.Ward}/{state.Wardstone.Rules.MaxWard} | {wardBefore - state.Wardstone.Ward} ward spent";
        _backButton.Text = "Continue exploring";
        _resultLabel.Text = string.Join("\n", result.Lines) + "\n\n" + string.Join("\n", state.Party.Living().Select(PartyLines.Describe));
    }
}
