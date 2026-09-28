using System.Threading.Tasks;
using Delve.Autoload;
using Delve.UI;
using Godot;

namespace Delve.Dev;

/// <summary>Visual review of shared controls and both result states at a compact window size.</summary>
public partial class FantasyUiSpike : SpikeBase
{
    protected override async Task RunSpikeAsync(DataManager data)
    {
        var root = new Control { Theme = GD.Load<Theme>("res://assets/ui/ui_theme.tres") };
        AddChild(root);
        root.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        var background = new ColorRect { Color = UiColors.Surface, MouseFilter = Control.MouseFilterEnum.Ignore };
        root.AddChild(background);
        background.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        var row = new HBoxContainer { Position = new Vector2(30, 25) };
        row.AddThemeConstantOverride("separation", 18);
        root.AddChild(row);
        row.AddChild(new Button { Text = "Character details" });
        row.AddChild(new Button { Text = "Embark", ThemeTypeVariation = "AccentButton" });
        row.AddChild(new Button { Text = "Unavailable", Disabled = true });
        var banner = GD.Load<PackedScene>("res://scenes/ui/victory_banner.tscn").Instantiate<VictoryBanner>();
        root.AddChild(banner);
        banner.ShowResult("Victory!", UiColors.Victory);
        banner.ShowRewards(new Delve.Flow.CombatResultsView
        {
            Figures = new[]
            {
                new Delve.Combat.FigureView("XP", "120") { Before = "40" },
                new Delve.Combat.FigureView("Ward", "100") { Before = "88" },
            },
            Notes = new[] { "A survivor is ready to join the party." },
            Progress = 80,
        });
        await Settle();
        Check("results fit inside viewport", root.GetGlobalRect().Encloses(banner.GetNode<Control>("%Frame").GetGlobalRect()));
        Capture("fantasy_victory.png");
        int continues = 0;
        banner.Continued += () => continues++;
        var button = banner.GetNode<Button>("%ContinueButton");
        button.EmitSignal(BaseButton.SignalName.Pressed);
        button.EmitSignal(BaseButton.SignalName.Pressed);
        Check("continue still fires once", continues == 1);
        banner.HideResult();
        banner.ShowResult("Defeat", UiColors.Defeat);
        banner.ShowRewards(new Delve.Flow.CombatResultsView());
        await Settle();
        Check("defeat hides absent progression", !banner.GetNode<ProgressBar>("%XpProgress").Visible);
        Capture("fantasy_defeat.png");
        banner.HideResult();
        await Settle();
        Capture("fantasy_buttons.png");
    }

    private async Task Settle()
    {
        await ToSignal(GetTree().CreateTimer(0.4), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
    }

    private void Capture(string filename)
    {
        Check(filename + " saved", SaveViewportCapture("user://dev_shots/" + filename) == Error.Ok);
    }
}
