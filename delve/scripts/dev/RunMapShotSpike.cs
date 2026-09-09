using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered smoke test for the run map (scenes/dev/run_map_shot_spike.tscn). Stands the map panel
/// up on its own canvas layer and captures the chart twice: fresh at the entrance with the start
/// row pulsing, then three floors in so the walked trail, the open choices and the party marker
/// are all on screen at once.
///
/// Captures go to user://dev_shots (a run artifact, never repo content); each save prints its
/// globalized OS path. Must run rendered, NOT --headless:
///   godot --path delve res://scenes/dev/run_map_shot_spike.tscn
/// </summary>
public partial class RunMapShotSpike : SpikeBase
{
    private const string OutDir = "user://dev_shots";

    /// <summary>Capture size, matching the other shot spikes' review grid.</summary>
    private const int ShotWidth = 1600;
    private const int ShotHeight = 900;

    /// <summary>Seed search start. The spike walks up from here to the first map that holds a
    /// Lair, so every generated kind is on screen and the shot stays comparable across passes.</summary>
    private const int BaseSeed = 1;

    /// <summary>Floors walked before the mid-run capture.</summary>
    private const int StepsIn = 3;

    /// <summary>The map screen. Assigned in run_map_shot_spike.tscn.</summary>
    [Export] public PackedScene? MapScene { get; set; }

    protected override string Banner => "==================== RUN MAP SHOT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (MapScene == null)
        {
            AbortFail("[mapshot] MapScene is not assigned - aborting.");
            return;
        }

        foreach (NodeKind kind in System.Enum.GetValues<NodeKind>())
            Check($"{kind} has a tooltip blurb", NodeKindInfo.Get(kind).Blurb.Length > 0);

        var layer = new CanvasLayer();
        AddChild(layer);
        var panel = MapScene.Instantiate<RunMapPanel>();
        layer.AddChild(panel);
        var sharedTheme = panel.Theme;
        var sharedWard = sharedTheme.GetStylebox("fill", "MapWardBar");

        var party = Party.Build(
            PresetCharacters.PlayerId, System.Array.Empty<string>(), new UnlockState(), Party.DefaultLevel);
        var cfg = new RunMapConfig();
        // The generator guarantees a Lair, so BaseSeed needs no search.
        var state = RunState.Start(BaseSeed, party, cfg);
        DirAccess.MakeDirRecursiveAbsolute(OutDir);

        panel.Render(state);
        await Settle();
        var frame = panel.GetNode<ScrollContainer>("%MapScroll").GetGlobalRect();
        var title = panel.GetNode<Label>("%FloorTitle").GetGlobalRect();
        var scenery = panel.GetNode<MapScenery>("%Scenery");
        Check("scenery fills the route viewport", scenery.GetGlobalRect().IsEqualApprox(frame));
        Check("scenery and fog cannot intercept route clicks", scenery.MouseFilter == Control.MouseFilterEnum.Ignore
            && scenery.GetNode<ColorRect>("%SceneryFog").MouseFilter == Control.MouseFilterEnum.Ignore);
        for (int stratum = 0; stratum < FloorThemes.Count; stratum++)
        {
            string id = FloorThemes.ForStratum(stratum).Id;
            var biome = System.Array.Find(scenery.Biomes, b => b.Id == id);
            Check($"{id} has ground and tree scenery", biome?.Ground != null && biome.Trees.Length > 0);
        }
        Check("map and title share the screen center",
            System.Math.Abs(frame.GetCenter().X - panel.GetGlobalRect().GetCenter().X) < 2
            && System.Math.Abs(title.GetCenter().X - frame.GetCenter().X) < 2);
        Capture("run_map_start.png");
        var mapArea = panel.GetNode<Control>("%MapArea");
        var originalPosition = mapArea.Position;
        mapArea.Position += new Vector2(57, 29);
        await Settle();
        Check("scenery follows a late map layout change",
            scenery.DrawnMapTransform.IsEqualApprox(scenery.GetGlobalTransform().AffineInverse() * mapArea.GetGlobalTransform()));
        mapArea.Position = originalPosition;
        await Settle();
        Check("scenery realigns after restoring map position",
            scenery.DrawnMapTransform.IsEqualApprox(scenery.GetGlobalTransform().AffineInverse() * mapArea.GetGlobalTransform()));
        int offered = 0;
        int picks = 0;
        panel.NodePicked += _ => picks++;
        foreach (var child in mapArea.GetChildren())
        {
            if (child is not MapNodeButton button || button.Disabled) continue;
            offered++;
            button.GrabFocus();
            Check("keyboard focus shows travel details", panel.GetNode<Label>("%DetailState").Text == "Click to travel.");
            button.EmitSignal(BaseButton.SignalName.Pressed);
        }
        Check("only reachable destinations are enabled", offered == state.Reachable().Count);
        Check("each activation forwards exactly one destination", picks == offered);
        var status = panel.GetNode<RunMapStatus>("%Status");
        var recovery = status.GetNode<RunMapRecovery>("%Recovery");
        var recoveryButton = recovery.GetNode<Button>("%ShortRestButton");
        var wardValue = status.GetNode<Label>("%WardValue");
        var restSegment = status.GetNode<Control>("%RestSegment");
        Check("ward preview is hidden at rest", wardValue.Text == "100 / 100" && !restSegment.Visible);
        recoveryButton.EmitSignal(Control.SignalName.MouseEntered);
        Check("hover previews the rest value and cost segment", wardValue.Text == "85 / 100"
            && restSegment.Visible && wardValue.ThemeTypeVariation == "MapWardPreviewValue");
        await Settle();
        Capture("run_map_rest_hover.png");
        recoveryButton.EmitSignal(Control.SignalName.MouseExited);
        Check("leaving rest restores the current ward", wardValue.Text == "100 / 100" && !restSegment.Visible
            && wardValue.ThemeTypeVariation == "MapWardValue");
        foreach (var (font, surface) in new[] {
            ("font_color", "normal"), ("font_hover_color", "hover"),
            ("font_pressed_color", "pressed"), ("font_hover_pressed_color", "pressed"),
            ("font_focus_color", "normal"), ("font_disabled_color", "disabled") })
        {
            var fill = (StyleBoxFlat)recoveryButton.GetThemeStylebox(surface);
            Check($"recovery {font} contrast >= 4.5:1",
                Contrast(recoveryButton.GetThemeColor(font), fill.BgColor) >= 4.5);
        }
        recoveryButton.GrabFocus();
        await Settle();
        Capture("run_map_recovery_focus.png");
        recoveryButton.ReleaseFocus();
        int restRequests = 0;
        panel.ShortRestPressed += () => restRequests++;
        recovery.GetNode<Button>("%ShortRestButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("recovery opens without spending ward or time", restRequests == 1
            && state.Wardstone.Ward == state.Wardstone.Rules.MaxWard && state.Clock.ShortRestsToday == 0);

        for (int i = 0; i < StepsIn; i++)
            Check($"step {i + 1} advances", state.Reachable().Count > 0 && state.Advance(state.Reachable()[0]));

        panel.Render(state);
        await Settle();
        Capture("run_map_mid.png");

        // One shot per remaining stratum, so all three backdrop moods sit side by side.
        for (int stratum = 2; stratum <= FloorThemes.Count; stratum++)
        {
            state.AdvanceStratum();
            panel.Render(state);
            await Settle();
            Capture($"run_map_stratum{stratum}.png");
        }

        var fullParty = Party.Build(PresetCharacters.PlayerId,
            new[] { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId },
            new UnlockState(), Party.DefaultLevel);
        fullParty.Members[1].Health.SetCurrentHP(1);
        var depleted = RunState.Start(BaseSeed, fullParty, cfg);
        // Burn down to the point where a rest would put the ward out and is refused.
        while (depleted.Wardstone.CanAffordShortRest)
        {
            depleted.Wardstone.BurnShortRest();
            depleted.Clock.SpendShortRest();
        }
        panel.Render(depleted);
        await Settle();
        Check("full party is shown", status.GetNode<VBoxContainer>("%PartyStatus").GetChildCount() == Party.MaxSize);
        var rest = recovery.GetNode<Button>("%ShortRestButton");
        var costLabel = recovery.GetNode<Label>("%RestCost");
        rest.EmitSignal(Control.SignalName.MouseEntered);
        Check("unavailable rest cannot preview", !restSegment.Visible && wardValue.Text == "10 / 100");
        rest.EmitSignal(Control.SignalName.MouseExited);
        Check("too little ward disables recovery and says why",
            rest.Disabled && rest.TooltipText.Contains("ward is left")
            && costLabel.Text.Contains("too little ward"));
        Check("depleted ward reports its threat effect", status.GetNode<Label>("%WardHint").Text.Contains("+3"));
        Check("recovery remains on screen with four members", rest.GetGlobalRect().End.Y < panel.GetGlobalRect().End.Y);
        var scroll = panel.GetNode<ScrollContainer>("%MapScroll");
        Check("map fits horizontally at reference size", scroll.GetHScrollBar().MaxValue <= scroll.GetHScrollBar().Page);
        Capture("run_map_depleted.png");

        depleted.Wardstone.BurnShortRest();
        panel.Render(depleted);
        await Settle();
        Check("a spent ward disables recovery and says why",
            rest.Disabled && rest.TooltipText.Contains("ward is out")
            && costLabel.Text.Contains("ward is out"));

        foreach (var def in CharacterCatalog.All)
        {
            var themedParty = Party.Build(def.Id, System.Array.Empty<string>(), new UnlockState(), Party.DefaultLevel);
            var themedRun = RunState.Start(BaseSeed, themedParty, cfg);
            panel.Render(themedRun);
            var accent = Delve.UI.UiColors.CharacterAccent(def.Id);
            var wardFill = (StyleBoxFlat)status.GetNode<ProgressBar>("%WardBar").GetThemeStylebox("fill");
            Check($"{def.Id} ward uses leader accent", wardFill.BgColor.IsEqualApprox(accent));
            Check($"{def.Id} recovery inherits the map theme",
                recoveryButton.GetThemeStylebox("normal") == panel.Theme.GetStylebox("normal", "MapRestButton"));
            foreach (var (font, surface) in new[] {
                ("font_color", "normal"), ("font_hover_color", "hover"),
                ("font_pressed_color", "pressed"), ("font_disabled_color", "disabled") })
                Check($"{def.Id} {surface} rest contrast >= 4.5:1",
                    Contrast(rest.GetThemeColor(font), ((StyleBoxFlat)rest.GetThemeStylebox(surface)).BgColor) >= 4.5);
            var localTheme = panel.Theme;
            panel.Render(themedRun);
            Check($"{def.Id} redraw reuses its theme", panel.Theme == localTheme);
            await Settle();
            Capture($"run_map_{def.Id}.png");
        }
        Check("leader changes leave the shared theme intact",
            sharedTheme.GetStylebox("fill", "MapWardBar") == sharedWard
            && sharedTheme != panel.Theme);

        panel.Render(state);
        await Settle();
        int travelId = state.Reachable()[0];
        int historyBefore = state.History.Count;
        var journey = panel.PlayTravel(travelId);
        Check("travel rejects a second selection", !await panel.PlayTravel(travelId));
        await ToSignal(GetTree().CreateTimer(0.3), SceneTreeTimer.SignalName.Timeout);
        await Settle();
        Capture("run_map_travel.png");
        Check("travel finishes without mutating run state", await journey && state.History.Count == historyBefore);
        panel.Render(state);
        var cancelled = panel.PlayTravel(travelId);
        panel.Hide();
        Check("hiding map cancels travel", !await cancelled);
        panel.Show();
        panel.Render(state);
        state.Wardstone.BurnShortRest();
        panel.Render(state);
        await ToSignal(GetTree().CreateTimer(0.25), SceneTreeTimer.SignalName.Timeout);
        await Settle();
        Capture("run_map_ward_drain.png");
        await ToSignal(GetTree().CreateTimer(0.7), SceneTreeTimer.SignalName.Timeout);
        Check("ward spend animation settles on the real ward",
            status.GetNode<ProgressBar>("%WardBar").Value == state.Wardstone.Ward
            && status.GetNode<Label>("%WardValue").Text == $"{state.Wardstone.Ward} / {state.Wardstone.Rules.MaxWard}");
    }

    private static double Contrast(Color foreground, Color background)
    {
        static double Linear(double c) => c <= 0.04045 ? c / 12.92 : System.Math.Pow((c + 0.055) / 1.055, 2.4);
        static double Luminance(Color c) => 0.2126 * Linear(c.R) + 0.7152 * Linear(c.G) + 0.0722 * Linear(c.B);
        double a = Luminance(foreground), b = Luminance(background);
        return (System.Math.Max(a, b) + 0.05) / (System.Math.Min(a, b) + 0.05);
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(ShotWidth, ShotHeight, Image.Interpolation.Bilinear);
        string path = $"{OutDir}/{file}";
        Error err = img.SavePng(path);
        GD.Print($"[mapshot] {file}: {err} ({ProjectSettings.GlobalizePath(path)})");
        Check($"{file} saved", err == Error.Ok);
    }

    /// <summary>Enough rendered frames for the layout to settle and the pulse animation to be
    /// visibly mid-swing.</summary>
    private async Task Settle()
    {
        for (int i = 0; i < 4; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        // Read the completed frame, after canvas redraws and layout changes reach the renderer.
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
    }
}
