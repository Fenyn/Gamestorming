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
        int submits = 0;
        panel.SchedulePicked += choices =>
        {
            submits++;
            int before = state.Wardstone.Ward;
            var result = ShortRest.PerformSchedule(party, state.Clock, choices, new RecoveryRules(), state.Wardstone, 0);
            panel.ShowResult(result, state, before);
            token.UpdateHealthBar();
        };
        var rows = panel.GetNode<VBoxContainer>("%ActivityBox");
        Check("one activity row per party member", rows.GetChildCount() == 4);
        var controls = rows.GetChild(0).GetChild<HBoxContainer>(1);
        var activity = controls.GetChild<OptionButton>(0);
        var target = controls.GetChild<OptionButton>(1);
        var confirm = panel.GetNode<Button>("%ConfirmButton");
        activity.Select(1);
        activity.EmitSignal(OptionButton.SignalName.ItemSelected, 1);
        Check("Treat Wounds reveals a required target", target.Visible && confirm.Disabled);
        target.Select(2);
        target.EmitSignal(OptionButton.SignalName.ItemSelected, 2);
        Check("selecting the patient enables the schedule without spending ward", !confirm.Disabled && state.Clock.ShortRestsToday == 0);
        await Wait();
        var conditions = token.GetNode<UnitConditions>("%Conditions");
        var badges = conditions.GetChild<HBoxContainer>(0);
        Check("wounded badge shows current value and description", badges.GetChildCount() == 1
            && badges.GetChild<TextureRect>(0).TooltipText.StartsWith("Wounded 2"));
        Capture("rest_schedule");
        confirm.EmitSignal(Button.SignalName.Pressed);
        confirm.EmitSignal(Button.SignalName.Pressed);
        await Wait();
        Check("double submit resolves only one shared window", submits == 1 && state.Clock.ShortRestsToday == 1);
        Check("post-rest HP bar matches healed health", Mathf.IsEqualApprox(token.GetNode<WorldHpBar>("%HpBar").Fill.Scale.X,
            (float)patient.Health.CurrentHP / patient.Health.MaxHP));
        Check("removed wounded condition removes the badge", badges.GetChildCount() == 0);
        Check("rest report includes updated patient HP", panel.GetNode<Label>("%ResultLabel").Text.Contains(PartyLines.Describe(patient)));
        Capture("rest_results");
        panel.Hide();
        patient.Conditions.AddCondition(ConditionDatabase.Instance.Frightened, value: 2);
        patient.Conditions.AddCondition(ConditionDatabase.Instance.Prone);
        await Wait();
        Check("new statuses and derived conditions appear outside combat events", badges.GetChildCount() >= 2
            && badges.GetChildren().OfType<TextureRect>().Any(b => b.TooltipText.StartsWith("Frightened 2"))
            && badges.GetChildren().OfType<TextureRect>().Any(b => b.TooltipText.StartsWith("Prone")));
        patient.Conditions.SetConditionValue(ConditionDatabase.Instance.Frightened, 1);
        await Wait();
        Check("condition value changes refresh the badge", badges.GetChildren().OfType<TextureRect>()
            .Any(b => b.TooltipText.StartsWith("Frightened 1") && b.GetChild<Label>(0).Text == "1"));
        Capture("condition_badges");
        token.Hide();
        await Wait();
        Check("hidden tokens hide their condition indicators", !badges.Visible);
    }

    private async Task Wait() => await ToSignal(GetTree().CreateTimer(0.35), SceneTreeTimer.SignalName.Timeout);
    private void Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        using var image = GetViewport().GetTexture().GetImage();
        Check(name + " capture", image.SavePng($"res://.godot/{name}.png") == Error.Ok);
    }
}
