using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Delve.Settings;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// The Esc menu: it opens only over a pause host and only when nothing else takes Esc, pauses the
/// tree, holds the modal stack, focuses Resume, persists its options and asks before quitting.
/// In combat, an open flyout and a targeting pick take Esc first.
/// </summary>
public partial class PauseMenuSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }

    /// <summary>The settings file the spike writes, so the player's own file stays untouched.</summary>
    [Export] public string SpikeSettingsPath { get; set; } = "user://pause_menu_spike_settings.cfg";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        string playerSettings = UserSettings.Path;
        UserSettings.Redirect(SpikeSettingsPath);
        ulong playerStamp = playerSettings.Length > 0 ? FileAccess.GetModifiedTime(playerSettings) : 0;
        try { await RunChecks(data); }
        finally
        {
            UserSettings.Redirect(playerSettings);
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SpikeSettingsPath));
        }
        Check($"the spike leaves the player's settings file alone ({playerSettings})",
            playerSettings.Length == 0 || FileAccess.GetModifiedTime(playerSettings) == playerStamp);
    }

    private async Task RunChecks(DataManager data)
    {
        var menu = PauseMenu.Instance;
        var modals = ModalStack.Instance;
        if (menu == null || modals == null) { AbortFail("[PauseMenu] autoloads missing."); return; }
        bool diceBefore = UserSettings.DiceReveal, fullBefore = UserSettings.Fullscreen;

        Check("the menu starts hidden", !menu.IsOpen);
        Esc();
        await Frames(2);
        Check("Esc without a pause host does nothing (camp, run end)", !menu.IsOpen && !GetTree().Paused);

        var host = new Control();
        host.AddToGroup(PauseMenu.HostGroup);
        AddChild(host);
        Esc();
        await Frames(3);
        Check("Esc over a host opens the menu and pauses the tree", menu.IsOpen && GetTree().Paused && modals.Holds(menu));
        Check("Resume has focus", menu.GetNode<Button>("%Resume").HasFocus());
        Capture("pause_menu.png");

        menu.GetNode<Button>("%Controls").EmitSignal(BaseButton.SignalName.Pressed);
        var legend = menu.GetNode<Control>("%ControlsPage").GetChildren().OfType<KeyLegend>().Single();
        Check($"Controls lists the help overlay's rows ({legend.GetChildCount() / 2} rows)",
            menu.GetNode<Control>("%ControlsPage").Visible && legend.GetChildCount() == legend.Rows.Length * 2);
        Esc();
        await Frames(1);
        Check("Esc on a sub-page goes back to the main page", menu.GetNode<Control>("%MainPage").Visible && menu.IsOpen);

        menu.GetNode<Button>("%Options").EmitSignal(BaseButton.SignalName.Pressed);
        var dice = menu.GetNode<Button>("%DiceReveal");
        var full = menu.GetNode<Button>("%Fullscreen");
        // A rendered run leaves the real window alone.
        bool toggleWindow = DisplayServer.GetName() == "headless";
        dice.ButtonPressed = !diceBefore;
        if (toggleWindow) full.ButtonPressed = !fullBefore;
        var saved = new ConfigFile();
        Check($"options persist to {UserSettings.Path}", saved.Load(UserSettings.Path) == Error.Ok
            && saved.GetValue("options", nameof(UserSettings.DiceReveal)).AsBool() == !diceBefore
            && saved.GetValue("options", nameof(UserSettings.Fullscreen)).AsBool() == (toggleWindow ? !fullBefore : fullBefore)
            && UserSettings.DiceReveal == !diceBefore);
        await Frames(3);
        Capture("pause_menu_options.png");
        dice.ButtonPressed = diceBefore;
        if (toggleWindow) full.ButtonPressed = fullBefore;
        Check("options restore", UserSettings.DiceReveal == diceBefore && UserSettings.Fullscreen == fullBefore);
        menu.GetNode<Button>("%OptionsBack").EmitSignal(BaseButton.SignalName.Pressed);

        menu.GetNode<Button>("%Quit").EmitSignal(BaseButton.SignalName.Pressed);
        Check("Quit asks for confirmation first", menu.GetNode<Control>("%QuitPage").Visible && menu.IsOpen);
        menu.GetNode<Button>("%QuitCancel").EmitSignal(BaseButton.SignalName.Pressed);
        Check("Cancel returns to the main page", menu.GetNode<Control>("%MainPage").Visible);

        Esc();
        await Frames(1);
        Check("Esc on the main page resumes and releases the modal", !menu.IsOpen && !GetTree().Paused && !modals.IsOpen);

        var other = new Node();
        AddChild(other);
        modals.Push(other);
        Esc();
        await Frames(1);
        Check("another modal takes precedence: Esc does not pause", !menu.IsOpen);
        other.QueueFree();
        await Frames(2);
        Check("a freed modal owner releases its entry", !modals.IsOpen);
        host.QueueFree();
        await Frames(1);

        if (CombatScene != null) await CheckCombatPrecedence(data, menu);
    }

    private async Task CheckCombatPrecedence(DataManager data, PauseMenu menu)
    {
        var scene = CombatScene!.Instantiate<CombatScene>();
        AddChild(scene);
        var goblin = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        scene.StartEncounter(new CombatSetup
        {
            GridWidth = 20, GridHeight = 10, RngSeed = 3,
            Party = { (PresetCharacters.BuildFenwick(level: 2, teamId: 1), new PF2eVec(3, 5)) },
            Enemies = { (CreatureFactory.Create(goblin, teamId: 2), new PF2eVec(4, 5)) },
        });
        for (float waited = 0; !scene.IsPlayerTurn && waited < 30; waited += 0.25f)
            await ToSignal(GetTree().CreateTimer(0.25), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(GetTree().CreateTimer(2.0), SceneTreeTimer.SignalName.Timeout);
        Check("a player turn begins", scene.IsPlayerTurn);
        var bar = scene.GetNode<ActionBar>("%ActionBar");

        bar._UnhandledInput(new InputEventAction { Action = InputNames.Spells, Pressed = true });
        await Frames(2);
        Esc();
        await Frames(2);
        Check("Esc closes an open flyout before the pause menu", !menu.IsOpen);

        bar._UnhandledInput(new InputEventAction { Action = InputNames.Action1, Pressed = true });
        await Frames(2);
        Esc();
        await Frames(2);
        Check("Esc cancels targeting before the pause menu", !menu.IsOpen);

        Esc();
        await Frames(3);
        Check("with nothing to close, Esc opens the pause menu in combat", menu.IsOpen && GetTree().Paused);
        Capture("pause_menu_combat.png");
        menu.Close();
        await Frames(1);
        await CheckEnemyTurnFreezes(scene, bar, menu);
        scene.QueueFree();
        await Frames(2);
    }

    /// <summary>Pausing mid enemy turn freezes combat at once: the log gains no entry for 2 s.</summary>
    private async Task CheckEnemyTurnFreezes(CombatScene scene, ActionBar bar, PauseMenu menu)
    {
        var log = scene.GetNode<CombatLogPanel>("%CombatLog");
        bar._UnhandledInput(new InputEventAction { Action = InputNames.EndTurn, Pressed = true });
        for (float waited = 0; scene.IsPlayerTurn && waited < 10; waited += 0.05f)
            await ToSignal(GetTree().CreateTimer(0.05), SceneTreeTimer.SignalName.Timeout);
        int before = log.EntryCount;
        for (float waited = 0; log.EntryCount == before && waited < 10; waited += 0.02f)
            await ToSignal(GetTree().CreateTimer(0.02), SceneTreeTimer.SignalName.Timeout);
        Check("an enemy turn is under way", !scene.IsPlayerTurn && log.EntryCount > before);
        menu.Open();
        await Frames(1);
        int paused = log.EntryCount;
        await ToSignal(GetTree().CreateTimer(2.0, processAlways: true), SceneTreeTimer.SignalName.Timeout);
        Check($"pausing mid enemy turn freezes combat: the log stays at {paused} entries for 2 s ({log.EntryCount})",
            menu.IsOpen && GetTree().Paused && log.EntryCount == paused);
        menu.Close();
        await Frames(2);
    }

    private void Esc()
    {
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, PhysicalKeycode = Key.Escape, Pressed = true }, true);
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, PhysicalKeycode = Key.Escape, Pressed = false }, true);
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private void Capture(string file)
    {
        if (DisplayServer.GetName() == "headless") return;
        Check($"{file} saved", SaveViewportCapture($"user://dev_shots/{file}") == Error.Ok);
    }
}
