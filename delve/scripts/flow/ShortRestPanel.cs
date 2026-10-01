using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>One simultaneous ten-minute schedule, submitted once for the whole party.</summary>
public partial class ShortRestPanel : ScreenFrame
{
    private sealed record Row(PF2eCharacter Actor, Dictionary<ShortRestKind, Button> Chips, OptionButton Target, Label Yield)
    {
        public ShortRestKind Kind => Chips.FirstOrDefault(c => c.Value.ButtonPressed).Key;
    }
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
    private string _scheduleTitle = "";
    private PairReport _report = null!;
    private Button _free = null!;
    public event Action<IReadOnlyList<RestAssignment>>? SchedulePicked;
    public event Action? Back;

    /// <summary>True when the last submitted schedule spends a banked free rest instead of ward.</summary>
    public bool UseFree { get; private set; }

    public override void _Ready()
    {
        _clockLabel = GetNode<Label>("%ClockLabel");
        _activityBox = GetNode<VBoxContainer>("%ActivityBox");
        _resultLabel = GetNode<Label>("%ResultLabel");
        _backButton = GetNode<Button>("%BackButton");
        _confirm = GetNode<Button>("%ConfirmButton");
        _scheduleTitle = Title;
        _report = GetNode<PairReport>("%Report");
        _backButton.Pressed += Close;
        _free = GetNode<Button>("%FreeButton");
        _confirm.Pressed += () => Submit(_confirm, useFree: false);
        _free.Pressed += () => Submit(_free, useFree: true);
        base._Ready();
        // Back, Esc and "Continue exploring" all hand the room back to the host.
        Closed += () => Back?.Invoke();
    }

    private void Submit(Button button, bool useFree)
    {
        if (_submitted || button.Disabled || !IsVisibleInTree()) return;
        _submitted = true;
        _confirm.Disabled = _free.Disabled = true;
        UseFree = useFree;
        SchedulePicked?.Invoke(Assignments());
    }

    public void Show(RunState state)
    {
        _state = state;
        _submitted = false;
        _activityBox.Visible = true;
        _confirm.Visible = true;
        _clockLabel.Visible = true;
        _resultLabel.Visible = true;
        _report.Visible = false;
        SetTitle(_scheduleTitle);
        _backButton.Visible = false;
        CloseButton.Visible = true;
        var ward = state.Wardstone;
        _clockLabel.Text = $"Day {state.Clock.Day}   Ward {ward.Ward} → {ward.WardAfterShortRest}"
            + (ward.UpshiftAfterShortRest > ward.Upshift ? $"   Threat +{ward.Upshift} → +{ward.UpshiftAfterShortRest}" : "");
        _clockLabel.TooltipText = $"{ScheduleRules}\n{WardLines.RestPreview(ward)}";
        // Both prices stay on offer: ward spent now may be refilled by the guardian, a banked rest is not.
        _confirm.Text = $"Rest · Ward {ward.Ward} → {ward.WardAfterShortRest}";
        _free.Visible = state.FreeRests > 0;
        _free.Text = $"Rest · Free rests {state.FreeRests} → {state.FreeRests - 1}";
        BuildRows();
        ValidateSchedule();
        OpenFrame();
        // Focus starts on the first row's activity, so Enter never spends ward by accident.
        UiFocus.Grab(_rows.Count > 0 ? _rows[0].Chips[_rows[0].Kind] : CloseButton);
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
        var suggested = ShortRest.Suggest(_state.Party);
        foreach (var member in living)
        {
            // One row per hero: name and HP, the activity, then the target when the activity needs one.
            var box = new HBoxContainer { CustomMinimumSize = new Vector2(0, RowHeight) };
            box.AddThemeConstantOverride("separation", 8);
            var who = new HBoxContainer { CustomMinimumSize = new Vector2(NameWidth, 0) };
            who.AddThemeConstantOverride("separation", 8);
            who.AddChild(new TextureRect { Texture = HeroPortraits.Face(member.Id), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                CustomMinimumSize = new Vector2(FaceSize, FaceSize), TextureFilter = TextureFilterEnum.Nearest,
                SizeFlagsVertical = SizeFlags.ShrinkCenter, MouseFilter = MouseFilterEnum.Ignore });
            who.AddChild(new Label { Text = $"{member.Name} {member.Health?.CurrentHP}/{member.Health?.MaxHP}",
                VerticalAlignment = VerticalAlignment.Center });
            int wounded = PartyLines.Wounded(member);
            if (wounded > 0)
            {
                var marks = new HBoxContainer { TooltipText = $"Wounded {wounded}", MouseFilter = MouseFilterEnum.Stop };
                marks.AddThemeConstantOverride("separation", 4);
                ConditionMarkRow.Fill(marks, new[] { new Delve.Combat.ConditionMarkView(
                    nameof(PF2e.Conditions.Condition.Wounded), $"Wounded {wounded}", wounded, "") }, Icons, 1, IconSize);
                who.AddChild(marks);
            }
            box.AddChild(who);
            // The activities as chips, all in view (OAG tavern rows): one press, no dropdown.
            var chips = new HBoxContainer { TooltipText = ScheduleRules };
            chips.AddThemeConstantOverride("separation", 4);
            var group = new ButtonGroup();
            var byKind = new Dictionary<ShortRestKind, Button>();
            foreach (var (kind, label) in Activities)
            {
                var chip = new Button { Text = label, ToggleMode = true, ButtonGroup = group, TooltipText = ScheduleRules,
                    CustomMinimumSize = new Vector2(0, RowHeight) };
                chip.Disabled = kind == ShortRestKind.Refocus && member.Spellcasting?.MaxFocusPoints is not > 0
                    || kind == ShortRestKind.RepairShield && !living.Any(m => m.Equipment?.Shield?.EquippedShield != null);
                chips.AddChild(chip);
                byKind[kind] = chip;
            }
            var target = new OptionButton { CustomMinimumSize = new Vector2(ChoiceWidth, RowHeight), Visible = false,
                TooltipText = ScheduleRules };
            target.AddItem("Choose target", -1);
            for (int i = 0; i < living.Count; i++) target.AddItem(living[i].Name, i);
            var yield = new Label { ThemeTypeVariation = ThemeNames.HintLabel, VerticalAlignment = VerticalAlignment.Center,
                SizeFlagsHorizontal = SizeFlags.ExpandFill, HorizontalAlignment = HorizontalAlignment.Right };
            box.AddChild(chips);
            box.AddChild(target);
            box.AddChild(yield);
            _activityBox.AddChild(box);
            var row = new Row(member, byKind, target, yield);
            _rows.Add(row);
            void ApplyActivity()
            {
                var kind = row.Kind;
                target.Visible = kind is ShortRestKind.TreatWounds or ShortRestKind.RepairShield;
                for (int i = 0; i < living.Count; i++)
                    target.SetItemDisabled(i + 1, kind == ShortRestKind.RepairShield && living[i].Equipment?.Shield?.EquippedShield == null);
                if (target.Selected > 0 && target.IsItemDisabled(target.Selected)) target.Select(0);
                ValidateSchedule();
            }
            foreach (var chip in byKind.Values) chip.Toggled += pressed => { if (pressed) ApplyActivity(); };
            target.ItemSelected += _ => ValidateSchedule();
            var pick = suggested.First(s => ReferenceEquals(s.Actor, member));
            byKind[pick.Kind].SetPressedNoSignal(true);
            if (pick.Target != null) target.Select(living.ToList().IndexOf(pick.Target) + 1);
            ApplyActivity();
        }
    }

    /// <summary>After the result, Esc continues exploring like the footer button.</summary>
    public override void _Input(InputEvent e)
    {
        if (IsVisibleInTree() && _backButton.Visible && !e.IsEcho() && e.IsActionPressed(InputNames.UiCancel))
        {
            GetViewport().SetInputAsHandled();
            Close();
            return;
        }
        base._Input(e);
    }

    /// <summary>Pick a row's activity, as a press on its chip would.</summary>
    public void SetActivity(int row, ShortRestKind kind) => _rows[row].Chips[kind].ButtonPressed = true;

    /// <summary>Pick a row's target by list index (0 is "Choose target"), as the dropdown would.</summary>
    public void SetTarget(int row, int index)
    {
        _rows[row].Target.Select(index);
        _rows[row].Target.EmitSignal(OptionButton.SignalName.ItemSelected, index);
    }

    /// <summary>What the schedule does to each row's hero, read on the row's right: the Treat Wounds
    /// success range on a patient ("HP 1 → 3–17 / 26"), a point of focus on a Refocus.</summary>
    public IReadOnlyList<string> Yields => _rows.Select(r => r.Yield.Text).ToList();

    private void RenderYields(IReadOnlyList<RestAssignment> assignments)
    {
        var rules = new RecoveryRules();
        foreach (var row in _rows)
        {
            var member = row.Actor;
            int hp = member.Health?.CurrentHP ?? 0, max = member.Health?.MaxHP ?? 0;
            string text = "";
            if (assignments.Any(a => a.Kind == ShortRestKind.TreatWounds && ReferenceEquals(a.Target, member)) && hp < max)
            {
                int low = Math.Min(max, hp + rules.TreatWoundsSuccessDice);
                int high = Math.Min(max, hp + rules.TreatWoundsSuccessDice * rules.TreatWoundsDie);
                text = $"HP {hp} → {low}–{high} / {max}";
            }
            else if (row.Kind == ShortRestKind.Refocus && member.Spellcasting is { } casting && casting.CurrentFocusPoints < casting.MaxFocusPoints)
                text = $"Focus {casting.CurrentFocusPoints} → {Math.Min(casting.MaxFocusPoints, casting.CurrentFocusPoints + rules.RefocusPoints)}";
            row.Yield.Text = text;
            row.Yield.TooltipText = text.StartsWith("HP") ? TreatWoundsOutcomes(rules) : "";
        }
    }

    private static string TreatWoundsOutcomes(RecoveryRules rules) =>
        $"Medicine against DC {rules.TreatWoundsDc}. Critical success: {rules.TreatWoundsCritSuccessDice}d{rules.TreatWoundsDie} HP. "
        + $"Success: {rules.TreatWoundsSuccessDice}d{rules.TreatWoundsDie} HP. Failure: nothing. "
        + $"Critical failure: {rules.TreatWoundsCritFailureDice}d{rules.TreatWoundsDie} damage. A success also removes Wounded.";

    public IReadOnlyList<RestAssignment> Assignments()
    {
        var living = _state.Party.Living();
        return _rows.Select(r => new RestAssignment(r.Actor, r.Kind,
            r.Target.Visible && r.Target.Selected > 0 ? living[r.Target.Selected - 1] : null)).ToArray();
    }

    private void ValidateSchedule()
    {
        var assignments = Assignments();
        RenderYields(assignments);
        string? reason = ShortRest.Validate(_state.Party, assignments);
        // Ward is the whole price of a rest, so a block where nobody does anything is refused.
        if (reason == null && assignments.All(a => a.Kind == ShortRestKind.Rest)) reason = NothingToDo;
        _free.Disabled = _submitted || reason != null || _state.FreeRests == 0;
        if (reason == null && !_state.Wardstone.CanAffordShortRest) reason = WardLines.RestUnavailable(_state.Wardstone);
        _confirm.Disabled = _submitted || reason != null;
        _resultLabel.Text = reason ?? "";
        _resultLabel.Visible = reason != null;
    }

    /// <summary>The schedule's rules, on the header and dropdown hovers.</summary>
    public const string ScheduleRules = "One activity per character. Everyone acts during the same ten minutes. "
        + "Treat Wounds needs a patient. Repair Shield needs a shield owner. Receiving treatment does not use your activity.";

    [Export] public float RowHeight { get; set; } = 44;
    [Export] public float NameWidth { get; set; } = 268;

    /// <summary>The row's face, twice the 22 px crop.</summary>
    [Export] public float FaceSize { get; set; } = 44;
    [Export] public float ChoiceWidth { get; set; } = 172;
    [Export] public ConditionIconSet? Icons { get; set; }
    [Export] public int IconSize { get; set; } = 22;

    /// <summary>"Rest done", the ward pair, then one pair row per hero whose values changed since <paramref name="before"/>.</summary>
    public void ShowResult(ShortRestResult result, RunState state, int wardBefore,
        IReadOnlyDictionary<string, PartyMemberSnapshot> before)
    {
        if (!result.Performed)
        {
            _submitted = false;
            ValidateSchedule();
            _resultLabel.Text = result.Reason ?? "The rest could not begin.";
            _resultLabel.Visible = true;
            return;
        }
        _submitted = true;
        _activityBox.Visible = false;
        _confirm.Visible = false;
        _free.Visible = false;
        _clockLabel.Visible = false;
        _resultLabel.Visible = false;
        SetTitle(DoneTitle);
        var figures = new List<Delve.Combat.FigureView>();
        if (CombatResults.Ward(wardBefore, state.Wardstone.Ward) is { } ward) figures.Add(ward);
        _report.Render(figures, CombatResults.RestMembers(state.Party.Living(), before));
        _backButton.Show();
        CloseButton.Hide();
        UiFocus.Grab(_backButton);
    }

    public const string DoneTitle = "Rest done";
    public const string NothingToDo = "Choose an activity for someone. Resting quietly alone recovers nothing and still costs ward.";
    public PairReport Report => _report;
}
