using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Conditions;

namespace Delve.Dev;

public partial class RestPresentationSpike : SpikeBase
{
    [Export] public PackedScene PanelScene { get; set; } = null!;
    [Export] public PackedScene UnitScene { get; set; } = null!;
    [Export] public Theme UiTheme { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId,
            PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), 2);
        var state = RunState.Start(137, party, new RunMapConfig());
        var patient = party.Members[1];
        patient.Health.SetCurrentHP(1);
        patient.Conditions.AddCondition(ConditionDatabase.Instance.Wounded, value: 2);
        var camera = new Camera3D { Position = new Vector3(3, 3, 4), Current = true };
        AddChild(camera);
        camera.LookAt(Vector3.Up);
        var token = UnitVisual3D.Spawn(UnitScene, patient);
        AddChild(token);
        var panel = PanelScene.Instantiate<ShortRestPanel>();
        panel.Theme = UiTheme;
        AddChild(panel);
        panel.Show(state);
        int submits = 0, backs = 0;
        panel.Back += () => backs++;
        panel.SchedulePicked += choices =>
        {
            submits++;
            int before = state.Wardstone.Ward;
            var snapshot = PartyChangeSummary.Capture(party);
            var result = ShortRest.PerformSchedule(party, state.Clock, choices, new RecoveryRules(), state.Wardstone, 0);
            panel.ShowResult(result, state, before, snapshot);
            token.UpdateHealthBar();
        };
        var rows = panel.GetNode<VBoxContainer>("%ActivityBox");
        Check("one activity row per party member", rows.GetChildCount() == 4);
        var controls = rows.GetChild<HBoxContainer>(0);
        var activity = controls.GetChild<HBoxContainer>(1);
        var target = controls.GetChild<OptionButton>(2);
        var confirm = panel.GetNode<Button>("%ConfirmButton");
        await Wait();
        var frame = panel.FramePanel;
        Check($"the schedule is one 44 px row per hero, activities as chips, inside the frame cap ({controls.Size}, {frame.Size.X})",
            rows.GetChildren().OfType<HBoxContainer>().All(r => Mathf.Abs(r.Size.Y - 44) <= 0.5f)
            && activity.GetChildren().OfType<Button>().Count() == 4 && frame.Size.X <= panel.MaxSize.X);
        var header = panel.GetNode<Label>("%ClockLabel").Text;
        Check($"the header reads as pairs, the rules sit on the hover ('{header}')",
            header.Contains($"Ward {state.Wardstone.Ward} → {state.Wardstone.WardAfterShortRest}") && !header.Contains('.')
            && activity.TooltipText.Length > 0);
        Check($"Begin rest is a 280x44 button, not a banner ({confirm.Size})", confirm.Size.X >= 279.5f && confirm.Size.X < 400);
        var opening = panel.Assignments();
        Check($"the schedule opens on a valid suggestion, not on four quiet rests ({string.Join(", ", opening.Select(a => a.Kind))})",
            !confirm.Disabled && opening.Any(a => a.Kind != ShortRestKind.Rest) && ShortRest.Validate(party, opening) == null);
        // The manual path below starts from quiet rests, as a player clearing the suggestion would.
        for (int i = 0; i < rows.GetChildCount(); i++) panel.SetActivity(i, ShortRestKind.Rest);
        panel.SetActivity(0, ShortRestKind.TreatWounds);
        panel.SetTarget(0, 0);
        Check("Treat Wounds reveals a required target", target.Visible && confirm.Disabled);
        panel.SetTarget(0, 2);
        Check("selecting the patient enables the schedule without spending ward", !confirm.Disabled && state.Clock.ShortRestsToday == 0);
        int patientHp = patient.Health.CurrentHP, patientMax = patient.Health.MaxHP;
        string yield = panel.Yields[1];
        Check($"the patient's row shows the Treat Wounds success range as a pair ('{yield}')",
            yield == $"HP {patientHp} → {Mathf.Min(patientMax, patientHp + 2)}–{Mathf.Min(patientMax, patientHp + 16)} / {patientMax}");
        await Wait();
        var marks = SquadMemberViews.From(patient).Conditions;
        Check($"the chip marks Wounded with its value and the token shows no condition mark ({string.Join(", ", marks.Select(m => m.Label))})",
            marks.Count == 1 && marks[0].Label == "Wounded 2" && marks[0].Value == 2 && !token.Dying.Visible);
        Capture("rest_schedule");
        confirm.EmitSignal(Button.SignalName.Pressed);
        confirm.EmitSignal(Button.SignalName.Pressed);
        await Wait();
        Check("double submit resolves only one shared window", submits == 1 && state.Clock.ShortRestsToday == 1);
        Check("post-rest HP bar matches healed health", Mathf.IsEqualApprox(token.GetNode<WorldHpBar>("%HpBar").Fill.Scale.X,
            (float)patient.Health.CurrentHP / patient.Health.MaxHP));
        marks = SquadMemberViews.From(patient).Conditions;
        Check($"removed wounded condition removes the chip mark (left: {string.Join(", ", marks.Select(m => m.Label))}; patient wounded {patient.Conditions.GetConditionValue(Condition.Wounded)})",
            marks.Count == 0);
        var report = panel.Report;
        var ward = report.FigureLabels.FirstOrDefault();
        Check($"rest result is titled '{ShortRestPanel.DoneTitle}' with the ward pair ({ward?.CaptionText} {ward?.BeforeText} → {ward?.ValueText})",
            panel.TitleText == ShortRestPanel.DoneTitle && ward != null && ward.CaptionText == "Ward"
            && ward.BeforeText == (state.Wardstone.Ward + state.Wardstone.Rules.ShortRestBurn).ToString()
            && ward.ValueText == state.Wardstone.Ward.ToString());
        var patientRow = report.MemberRows.FirstOrDefault(r => r.MemberName == patient.Name);
        var hp = patientRow?.FigureLabels.FirstOrDefault(f => f.CaptionText == "HP");
        Check($"rest report shows the patient's HP as a pair ({hp?.BeforeText} → {hp?.ValueText})",
            hp != null && hp.BeforeText == "1" && hp.ValueText == patient.Health.CurrentHP.ToString());
        Check("rest report has rows only for changed heroes", report.MemberRows.All(r => r.FigureLabels.Count > 0)
            && report.MemberRows.Count < 4);
        Capture("rest_results");
        panel._Input(new InputEventAction { Action = Delve.UI.InputNames.UiCancel, Pressed = true });
        Check($"Esc on the result continues exploring ({backs} back)", backs == 1 && !panel.Visible);
        panel.Hide();
        patient.Conditions.AddCondition(ConditionDatabase.Instance.Frightened, value: 2);
        patient.Conditions.AddCondition(ConditionDatabase.Instance.Prone);
        await Wait();
        marks = SquadMemberViews.From(patient).Conditions;
        Check($"new statuses and derived conditions reach the chip, not the token ({string.Join(", ", marks.Select(m => m.Label))})",
            marks.Any(m => m.Label == "Frightened 2") && marks.Any(m => m.Label == "Prone") && !token.Dying.Visible);
        patient.Conditions.SetConditionValue(ConditionDatabase.Instance.Frightened, 1);
        Check("condition value changes refresh the mark",
            SquadMemberViews.From(patient).Conditions.Any(m => m.Label == "Frightened 1" && m.Value == 1));
        patient.Conditions.AddCondition(ConditionDatabase.Instance.Dying, value: 2);
        await Wait();
        Check($"Dying shows on the token with its value ({token.Dying.Value})", token.Dying.Visible && token.Dying.Value == 2);
        Capture("dying_badge");
        token.Hide();
        await Wait();
        Check("hidden tokens hide their Dying badge", !token.Dying.IsVisibleInTree());
    }

    private async Task Wait() => await ToSignal(GetTree().CreateTimer(0.35), SceneTreeTimer.SignalName.Timeout);
    private void Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        Check(name + " capture", SaveViewportCapture($"res://.godot/{name}.png") == Error.Ok);
    }
}
