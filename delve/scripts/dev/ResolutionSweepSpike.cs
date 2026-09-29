using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered sweep over window sizes. At each size it shows the camp, the combat HUD with and
/// without the journal, the dungeon HUD, the results, the pause menu and the short rest modal,
/// checks that the key controls sit on screen and that no label or rich text spills out of its box,
/// and saves one capture per screen. Must run WITHOUT --headless.
/// </summary>
public partial class ResolutionSweepSpike : SpikeBase
{
    [Export] public PackedScene CampScene { get; set; } = null!;
    [Export] public PackedScene CombatTestScene { get; set; } = null!;
    [Export] public PackedScene ModalScene { get; set; } = null!;
    [Export] public PackedScene DungeonScene { get; set; } = null!;
    [Export] public PackedScene VictoryScene { get; set; } = null!;
    [Export] public Theme UiTheme { get; set; } = null!;
    [Export] public Godot.Collections.Array<Vector2I> Sizes { get; set; } =
        [new(1280, 720), new(1280, 800), new(1920, 1080), new(2560, 1440), new(3440, 1440)];
    [Export] public float SettleSeconds { get; set; } = 0.6f;
    [Export] public float PlayerTurnWaitSeconds { get; set; } = 30f;

    protected override string Banner => "==================== RESOLUTION SWEEP SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (DisplayServer.GetName() == "headless") { AbortFail("[sweep] needs a window; run without --headless."); return; }
        GD.Print($"[sweep] screen {DisplayServer.ScreenGetSize()}");
        await SweepCamp();
        await SweepCombat();
        await SweepDungeon();
        await SweepModal();
        GetWindow().Size = Sizes[0];
    }

    private async Task SweepCamp()
    {
        var layer = new CanvasLayer();
        AddChild(layer);
        var panel = CampScene.Instantiate<HeroSelectPanel>();
        layer.AddChild(panel);
        var campaign = new CampaignProgress();
        panel.Setup(campaign.Unlocks, campaign);
        foreach (string id in new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId })
            panel.Pick(id);
        foreach (var size in Sizes)
        {
            if (!await Resize(size)) continue;
            CheckLayout("camp", size, panel, "%EmbarkButton", "%ClearPartyButton", "%DetailsButton", "%RecruitmentButton");
            Capture("camp", size);
        }
        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task SweepCombat()
    {
        var test = CombatTestScene.Instantiate();
        AddChild(test);
        await Seconds(SettleSeconds);
        var scene = test.GetChildren().OfType<CombatScene>().FirstOrDefault();
        if (scene == null) { Check("the combat test scene holds a CombatScene", false); return; }
        bool wasPlaying = scene.IntroPlaying;
        GetViewport().PushInput(new InputEventAction { Action = InputNames.Confirm, Pressed = true });
        for (int i = 0; i < 4; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check($"confirm skips the fight intro (playing before: {wasPlaying})", wasPlaying && !scene.IntroPlaying);
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var menu = PauseMenu.Instance;
        foreach (var size in Sizes)
        {
            if (!await Resize(size)) continue;
            for (float waited = 0; !scene.IsPlayerTurn && waited < PlayerTurnWaitSeconds; waited += 0.25f)
                await Seconds(0.25f);
            await Seconds(SettleSeconds);
            var hud = scene.GetNode<Control>("%HudRoot");
            CheckLayout("combat HUD", size, hud, bar.BarPanel, scene.GetNode<Control>("%UnitInspect"),
                scene.GetNode<TurnOrderBar>("%TurnOrderBar").Row, scene.GetNode<CombatLogPanel>("%CombatLog"),
                scene.GetNode<Control>("%JournalButton"));
            CheckMenuBesideActor(scene, bar, size);
            Capture("combat_hud", size);

            scene.JournalPanel.Toggle();
            await Seconds(SettleSeconds);
            CheckLayout("combat journal", size, scene.JournalPanel, scene.JournalPanel);
            Capture("combat_journal", size);
            scene.JournalPanel.Toggle();

            if (menu == null) continue;
            menu.Open();
            await Seconds(SettleSeconds);
            var page = menu.GetNode<Control>("Center");
            CheckLayout("pause menu", size, page, "%Resume", "%Quit");
            Capture("pause_menu", size);
            menu.Close();
        }
        test.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task SweepDungeon()
    {
        var dungeon = DungeonScene.Instantiate<DungeonDirector>();
        AddChild(dungeon);
        await Seconds(2 * SettleSeconds);
        var hud = dungeon.GetNode<DungeonHud>("%DungeonHud");
        foreach (var size in Sizes)
        {
            if (!await Resize(size)) continue;
            CheckLayout("dungeon HUD", size, hud, hud.PartyStrip, hud.GetNode<Control>("%Expedition"));
            var menu = hud.PartyMenu.GetGlobalRect();
            Check($"{size.X}x{size.Y} the party menu is on screen and clear of the party cards ({menu})",
                hud.PartyMenu.IsVisibleInTree() && GetViewport().GetVisibleRect().Grow(1).Encloses(menu)
                && !menu.Intersects(hud.PartyStrip.GetGlobalRect()));
            Capture("dungeon_hud", size);
        }
        dungeon.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task SweepModal()
    {
        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId,
            PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
        var state = RunState.Start(314, party, new RunMapConfig());
        var layer = new CanvasLayer();
        AddChild(layer);
        var surface = new Control { Theme = UiTheme };
        surface.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        layer.AddChild(surface);
        var panel = ModalScene.Instantiate<ShortRestPanel>();
        surface.AddChild(panel);
        panel.Show(state);
        foreach (var size in Sizes)
        {
            if (!await Resize(size)) continue;
            CheckLayout("short rest modal", size, panel, "%ConfirmButton", "%BackButton");
            Capture("short_rest", size);
        }
        panel.Hide();
        var victory = VictoryScene.Instantiate<VictoryBanner>();
        surface.AddChild(victory);
        var start = PartyChangeSummary.Capture(party);
        party.Members[0].Health.SetCurrentHP(1);
        victory.ShowResult("Victory", UiColors.Victory);
        victory.ShowRewards(new CombatResultsView
        {
            Figures = new[] { new FigureView("XP", "80") { Before = "40" }, CombatResults.Ward(60, 100)! },
            Members = CombatResults.Members(party.Members, start),
            Party = party.Members,
        });
        foreach (var size in Sizes)
        {
            if (!await Resize(size)) continue;
            CheckLayout("results", size, victory, victory);
            Capture("results", size);
        }
        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task<bool> Resize(Vector2I size)
    {
        GetWindow().Size = size;
        await Seconds(SettleSeconds);
        var actual = GetWindow().Size;
        Check($"the window takes {size.X}x{size.Y} (got {actual.X}x{actual.Y})", actual == size);
        return actual == size;
    }

    /// <summary>The FFT command menu opens beside the actor at every window size: its main panel's
    /// near edge sits within reach of the actor's screen point, and the actor is not under it.</summary>
    private void CheckMenuBesideActor(CombatScene scene, ActionBar bar, Vector2I size)
    {
        Node3D? crystal = null;
        foreach (var node in scene.GetNode<Node3D>("%UnitLayer").FindChildren("Crystal", "", true, false))
            if (node is Node3D { Visible: true } shown) crystal = shown;
        if (crystal == null || !bar.MenuShown) return;
        var unit = scene.ActiveCamera.UnprojectPosition(crystal.GlobalPosition);
        var menu = bar.BarPanel.GetGlobalRect();
        float gap = Mathf.Min(Mathf.Abs(menu.Position.X - unit.X), Mathf.Abs(unit.X - menu.End.X));
        Check($"{size.X}x{size.Y} the command menu opens beside the active unit ({gap:F0} px, unit {unit}, menu {menu})",
            gap < 260f && !menu.HasPoint(unit));
    }

    private void CheckLayout(string screen, Vector2I size, Control root, params string[] keys)
        => CheckLayout(screen, size, root, keys.Select(k => root.GetNode<Control>(k)).ToArray());

    private void CheckLayout(string screen, Vector2I size, Control root, params Control[] keys)
    {
        var view = GetViewport().GetVisibleRect().Grow(1);
        string tag = $"{size.X}x{size.Y} {screen}";
        var off = keys.Where(k => !k.IsVisibleInTree() || !view.Encloses(k.GetGlobalRect())).Select(k => $"{k.Name} {k.GetGlobalRect()}").ToList();
        Check($"{tag}: {keys.Length} key controls are on screen{(off.Count > 0 ? $" (off: {string.Join(", ", off)})" : "")}", off.Count == 0);
        var spills = new List<string>();
        foreach (var label in root.FindChildren("*", nameof(Label), true, false).OfType<Label>())
        {
            if (!label.IsVisibleInTree() || label.Text.Length == 0 || label.GetParent() is not Control parent) continue;
            var rect = label.GetGlobalRect();
            bool scrolled = HasScrollAncestor(label);
            if (!parent.GetGlobalRect().Grow(1).Encloses(rect) || !scrolled && !view.Encloses(rect))
                spills.Add($"{label.Name} '{label.Text.Split('\n')[0]}' {rect} in {parent.Name} {parent.GetGlobalRect()}");
        }
        foreach (var rich in root.FindChildren("*", nameof(RichTextLabel), true, false).OfType<RichTextLabel>())
        {
            if (!rich.IsVisibleInTree() || rich.GetParsedText().Length == 0) continue;
            if (rich.GetContentWidth() > rich.Size.X + 1)
                spills.Add($"{rich.Name} '{rich.GetParsedText().Split('\n')[0]}' content {rich.GetContentWidth()} px in {rich.Size.X:0} px");
        }
        Check($"{tag}: no label or rich text spills out of its box{(spills.Count > 0 ? $" ({string.Join("; ", spills.Take(6))})" : "")}", spills.Count == 0);
    }

    private static bool HasScrollAncestor(Node node)
    {
        for (var parent = node.GetParent(); parent != null; parent = parent.GetParent())
            if (parent is ScrollContainer) return true;
        return false;
    }

    private void Capture(string screen, Vector2I size)
        => Check($"{size.X}x{size.Y} {screen} captured",
            SaveViewportCapture($"user://dev_shots/resolution_{size.X}x{size.Y}_{screen}.png") == Error.Ok);

    private async Task Seconds(float seconds)
        => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
}
