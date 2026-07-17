using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.UI;
using Godot;

using Bulwark.Settings;
namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the pause menu + options panel build:
///  (A) ViewPreferences: the four new settings (Master/Music/Sfx volume, Fullscreen) round-trip
///      through user://settings.json across a simulated restart, clamp on set AND on load, and
///      fall back to defaults on a corrupt file.
///  (B) SettingsApplier: ApplyAll + the individual appliers run headless without throwing (bus
///      lookups may return -1 when no audio bus layout is loaded — must be skipped, not crash);
///      fullscreen apply is a harmless no-op with no real display server.
///  (C) OptionsPanel: instantiates, Open() loads the current persisted values into the controls
///      (no feedback-loop re-write), a slider/checkbox change writes ViewPreferences live, Closed
///      fires.
///  (D) PauseMenu: instantiates, Toggled fires open/close, Save Game raises SaveRequested and shows
///      the "Saved." feedback, the Quit-to-Title confirm flow swaps the button column (Cancel
///      restores it, Quit-without-saving fires only QuitToTitleRequested, Save-and-Quit fires
///      SaveRequested then QuitToTitleRequested in order), and the nested OptionsPanel hides/shows
///      the main buttons around itself.
///  (E) Esc priority: driven against the REAL outpost scene — CozyWorldScene's AnyModalOpen guard
///      keeps Esc from opening the pause menu while another panel is already visible, and opens it
///      once nothing else is.
/// The user's real user://settings.json is backed up before section (A) and restored in `finally`.
/// </summary>
public partial class PauseOptionsSpike : SpikeBase
{
    private const string SettingsPath = ViewPreferences.SettingsPath;

    private bool _settingsExisted;
    private string _settingsBackup = string.Empty;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== PAUSE + OPTIONS SPIKE ====================");

        BackupSettings();
        try
        {
            RunViewPreferencesSpike();      // (A)
            RunSettingsApplierSpike();      // (B)
            await RunOptionsPanelSpike();   // (C)
            await RunPauseMenuSpike();      // (D)
            await RunEscPrioritySpike();    // (E)
        }
        catch (Exception e)
        {
            GD.PushError($"[PauseOptionsSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSettings();
        }

        FinishAndQuit("PauseOptionsSpike");
    }

    // ─────────────────────────── (A) ViewPreferences: new settings ───────────────────────────

    private void RunViewPreferencesSpike()
    {
        GD.Print("-------------------- (A) ViewPreferences: new settings --------------------");

        DeleteSettings();
        ViewPreferences.ResetForReload();
        Check("(A) no file: MasterVolume defaults to 1.0", Mathf.IsEqualApprox(ViewPreferences.MasterVolume, ViewPreferences.VolumeDefault));
        Check("(A) no file: MusicVolume defaults to 1.0", Mathf.IsEqualApprox(ViewPreferences.MusicVolume, ViewPreferences.VolumeDefault));
        Check("(A) no file: SfxVolume defaults to 1.0", Mathf.IsEqualApprox(ViewPreferences.SfxVolume, ViewPreferences.VolumeDefault));
        Check("(A) no file: Fullscreen defaults to false", ViewPreferences.Fullscreen == ViewPreferences.FullscreenDefault);

        // Round-trip: set -> ResetForReload (simulated restart) -> re-read.
        ViewPreferences.MasterVolume = 0.6f;
        ViewPreferences.MusicVolume = 0.4f;
        ViewPreferences.SfxVolume = 0.8f;
        ViewPreferences.Fullscreen = true;
        ViewPreferences.ResetForReload();
        Check("(A) MasterVolume round-trips (0.6)", Mathf.IsEqualApprox(ViewPreferences.MasterVolume, 0.6f));
        Check("(A) MusicVolume round-trips (0.4)", Mathf.IsEqualApprox(ViewPreferences.MusicVolume, 0.4f));
        Check("(A) SfxVolume round-trips (0.8)", Mathf.IsEqualApprox(ViewPreferences.SfxVolume, 0.8f));
        Check("(A) Fullscreen round-trips (true)", ViewPreferences.Fullscreen);

        // Setter clamps out-of-range values.
        ViewPreferences.MasterVolume = 1.5f;
        Check("(A) setter clamps MasterVolume to max 1.0", Mathf.IsEqualApprox(ViewPreferences.MasterVolume, ViewPreferences.VolumeMax));
        ViewPreferences.MusicVolume = -0.5f;
        Check("(A) setter clamps MusicVolume to min 0.0", Mathf.IsEqualApprox(ViewPreferences.MusicVolume, ViewPreferences.VolumeMin));

        // Out-of-range values on disk clamp on load.
        WriteSettings("{\"masterVolume\": 5.0, \"musicVolume\": -3.0, \"sfxVolume\": 2.0, \"fullscreen\": true}");
        ViewPreferences.ResetForReload();
        Check("(A) disk MasterVolume clamps to max 1.0", Mathf.IsEqualApprox(ViewPreferences.MasterVolume, ViewPreferences.VolumeMax));
        Check("(A) disk MusicVolume clamps to min 0.0", Mathf.IsEqualApprox(ViewPreferences.MusicVolume, ViewPreferences.VolumeMin));
        Check("(A) disk SfxVolume clamps to max 1.0", Mathf.IsEqualApprox(ViewPreferences.SfxVolume, ViewPreferences.VolumeMax));
        Check("(A) disk Fullscreen loads true", ViewPreferences.Fullscreen);

        // Corrupt file -> defaults, no throw.
        WriteSettings("not valid json {{{");
        ViewPreferences.ResetForReload();
        Check("(A) corrupt file: MasterVolume falls back to default", Mathf.IsEqualApprox(ViewPreferences.MasterVolume, ViewPreferences.VolumeDefault));
        Check("(A) corrupt file: MusicVolume falls back to default", Mathf.IsEqualApprox(ViewPreferences.MusicVolume, ViewPreferences.VolumeDefault));
        Check("(A) corrupt file: SfxVolume falls back to default", Mathf.IsEqualApprox(ViewPreferences.SfxVolume, ViewPreferences.VolumeDefault));
        Check("(A) corrupt file: Fullscreen falls back to default", ViewPreferences.Fullscreen == ViewPreferences.FullscreenDefault);

        // A change after corruption rewrites a valid file that round-trips again.
        ViewPreferences.SfxVolume = 0.25f;
        ViewPreferences.ResetForReload();
        Check("(A) post-corruption save round-trips (0.25)", Mathf.IsEqualApprox(ViewPreferences.SfxVolume, 0.25f));
    }

    // ─────────────────────────── (B) SettingsApplier ───────────────────────────

    private void RunSettingsApplierSpike()
    {
        GD.Print("-------------------- (B) SettingsApplier --------------------");

        bool threw = false;
        try
        {
            SettingsApplier.ApplyAll();
            SettingsApplier.ApplyMasterVolume(0.5f);
            SettingsApplier.ApplyMusicVolume(0f); // exercises the mute branch (v <= 0.001)
            SettingsApplier.ApplySfxVolume(1f);
            SettingsApplier.ApplyFullscreen(true);
            SettingsApplier.ApplyFullscreen(false);
        }
        catch (Exception e)
        {
            threw = true;
            GD.PushError($"[PauseOptionsSpike] SettingsApplier threw: {e}");
        }
        Check("(B) ApplyAll + individual appliers run headless without throwing (incl. mute branch, fullscreen no-op)", !threw);

        int masterIdx = AudioServer.GetBusIndex("Master");
        Check("(B) Master bus always resolves (built-in bus 0)", masterIdx == 0);

        int musicIdx = AudioServer.GetBusIndex("Music");
        int sfxIdx = AudioServer.GetBusIndex("Sfx");
        GD.Print($"[PauseOptionsSpike] Music bus index = {musicIdx}, Sfx bus index = {sfxIdx} "
            + "(the -1/no-throw combination above is the missing-bus guard proof for a headless run).");

        // Restore audible defaults for anything sharing this process afterward.
        ViewPreferences.ResetForReload();
    }

    // ─────────────────────────── (C) OptionsPanel ───────────────────────────

    private async Task RunOptionsPanelSpike()
    {
        GD.Print("-------------------- (C) OptionsPanel --------------------");

        // Values chosen as exact multiples of the slider's step (0.05) — the HSlider itself snaps
        // an assigned Value to the nearest step, so an unaligned test value would make the slider's
        // displayed value differ from the exact persisted one (a display-rounding nuance, not a bug).
        ViewPreferences.ResetForReload();
        ViewPreferences.MasterVolume = 0.40f;
        ViewPreferences.MusicVolume = 0.35f;
        ViewPreferences.SfxVolume = 0.75f;
        ViewPreferences.Fullscreen = true;

        var packed = GD.Load<PackedScene>("res://scenes/ui/options_panel.tscn");
        Check("(C) options_panel.tscn loads", packed != null);
        if (packed == null) return;

        var panel = packed.Instantiate<OptionsPanel>();
        AddChild(panel);
        await Frames(2);

        Check("(C) %MasterSlider resolves", panel.GetNodeOrNull("%MasterSlider") != null);
        Check("(C) %MusicSlider resolves", panel.GetNodeOrNull("%MusicSlider") != null);
        Check("(C) %SfxSlider resolves", panel.GetNodeOrNull("%SfxSlider") != null);
        Check("(C) %FullscreenCheck resolves", panel.GetNodeOrNull("%FullscreenCheck") != null);
        Check("(C) %CloseButton resolves", panel.GetNodeOrNull("%CloseButton") != null);

        bool opened = false;
        panel.Opened += () => opened = true;
        panel.Open();
        Check("(C) Opened fires", opened);
        Check("(C) panel becomes visible", panel.Visible);

        var masterSlider = panel.GetNode<HSlider>("%MasterSlider");
        var musicSlider = panel.GetNode<HSlider>("%MusicSlider");
        var sfxSlider = panel.GetNode<HSlider>("%SfxSlider");
        var fullscreenCheck = panel.GetNode<CheckButton>("%FullscreenCheck");

        Check("(C) Open() loads the current master volume into the slider",
            Mathf.IsEqualApprox((float)masterSlider.Value, 0.40f, 0.001f));
        Check("(C) Open() loads the current music volume into the slider",
            Mathf.IsEqualApprox((float)musicSlider.Value, 0.35f, 0.001f));
        Check("(C) Open() loads the current sfx volume into the slider",
            Mathf.IsEqualApprox((float)sfxSlider.Value, 0.75f, 0.001f));
        Check("(C) Open() loads the current fullscreen flag into the checkbox", fullscreenCheck.ButtonPressed);

        // Loading values into the controls must not itself perturb the persisted file (no feedback loop).
        ViewPreferences.ResetForReload();
        Check("(C) opening did not re-write the persisted master volume",
            Mathf.IsEqualApprox(ViewPreferences.MasterVolume, 0.40f, 0.001f));

        // A slider drag live-writes ViewPreferences.
        masterSlider.EmitSignal(Godot.Range.SignalName.ValueChanged, 0.6);
        Check("(C) slider change writes ViewPreferences.MasterVolume", Mathf.IsEqualApprox(ViewPreferences.MasterVolume, 0.6f, 0.001f));

        fullscreenCheck.EmitSignal(CheckButton.SignalName.Toggled, false);
        Check("(C) checkbox change writes ViewPreferences.Fullscreen", !ViewPreferences.Fullscreen);

        bool closed = false;
        panel.Closed += () => closed = true;
        panel.Close();
        Check("(C) Closed fires", closed);
        Check("(C) panel hides", !panel.Visible);

        panel.QueueFree();
        await Frames(1);
    }

    // ─────────────────────────── (D) PauseMenu ───────────────────────────

    private async Task RunPauseMenuSpike()
    {
        GD.Print("-------------------- (D) PauseMenu --------------------");

        var packed = GD.Load<PackedScene>("res://scenes/ui/pause_menu.tscn");
        Check("(D) pause_menu.tscn loads", packed != null);
        if (packed == null) return;

        var menu = packed.Instantiate<PauseMenu>();
        AddChild(menu);
        await Frames(2);

        Check("(D) %MainButtons resolves", menu.GetNodeOrNull("%MainButtons") != null);
        Check("(D) %ConfirmButtons resolves", menu.GetNodeOrNull("%ConfirmButtons") != null);
        Check("(D) %ResumeButton resolves", menu.GetNodeOrNull("%ResumeButton") != null);
        Check("(D) %SaveButton resolves", menu.GetNodeOrNull("%SaveButton") != null);
        Check("(D) %OptionsButton resolves", menu.GetNodeOrNull("%OptionsButton") != null);
        Check("(D) %QuitButton resolves", menu.GetNodeOrNull("%QuitButton") != null);
        Check("(D) %SaveAndQuitButton resolves", menu.GetNodeOrNull("%SaveAndQuitButton") != null);
        Check("(D) %QuitWithoutSavingButton resolves", menu.GetNodeOrNull("%QuitWithoutSavingButton") != null);
        Check("(D) %CancelQuitButton resolves", menu.GetNodeOrNull("%CancelQuitButton") != null);
        Check("(D) %SavedLabel resolves", menu.GetNodeOrNull("%SavedLabel") != null);

        var toggles = new List<bool>();
        menu.Toggled += open => toggles.Add(open);

        Check("(D) starts closed", !menu.Visible);
        menu.Open();
        Check("(D) Open() shows the menu and fires Toggled(true)", menu.Visible && toggles.Count == 1 && toggles[0]);

        var mainButtons = menu.GetNode<Control>("%MainButtons");
        var confirmButtons = menu.GetNode<Control>("%ConfirmButtons");
        Check("(D) opens on the main button column", mainButtons.Visible && !confirmButtons.Visible);

        // Save Game raises SaveRequested and shows the "Saved." feedback.
        int saves = 0;
        menu.SaveRequested += () => saves++;
        menu.GetNode<Button>("%SaveButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) Save Game raises SaveRequested", saves == 1);
        Check("(D) Saved. feedback label shows", menu.GetNode<Label>("%SavedLabel").Visible);

        // Quit to Title swaps the button column for the inline confirm.
        menu.GetNode<Button>("%QuitButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) Quit to Title swaps to the confirm column", !mainButtons.Visible && confirmButtons.Visible);

        // Cancel restores the main buttons.
        menu.GetNode<Button>("%CancelQuitButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) Cancel restores the main button column", mainButtons.Visible && !confirmButtons.Visible);

        // Quit without saving fires ONLY QuitToTitleRequested.
        var quits = new List<string>();
        menu.QuitToTitleRequested += () => quits.Add("quit");
        menu.SaveRequested += () => quits.Add("save"); // ordering probe alongside the counter above
        int savesBefore = saves;
        menu.GetNode<Button>("%QuitButton").EmitSignal(BaseButton.SignalName.Pressed);
        menu.GetNode<Button>("%QuitWithoutSavingButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) Quit without Saving fires QuitToTitleRequested only",
            quits.Count == 1 && quits[0] == "quit" && saves == savesBefore);

        // Save and Quit fires SaveRequested then QuitToTitleRequested, in order.
        menu.Close();
        menu.Open();
        quits.Clear();
        menu.GetNode<Button>("%QuitButton").EmitSignal(BaseButton.SignalName.Pressed);
        menu.GetNode<Button>("%SaveAndQuitButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) Save and Quit fires SaveRequested then QuitToTitleRequested, in order",
            quits.Count == 2 && quits[0] == "save" && quits[1] == "quit");

        // Options: opens the nested panel and hides the main buttons; closing it restores them.
        menu.Close();
        menu.Open();
        var optionsPanel = menu.GetNode<OptionsPanel>("OptionsPanel");
        menu.GetNode<Button>("%OptionsButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) Options button opens the nested OptionsPanel", optionsPanel.Visible);
        Check("(D) pause menu hides its main buttons while Options is open", !mainButtons.Visible);
        optionsPanel.Close();
        Check("(D) closing Options returns the main buttons", mainButtons.Visible);

        // Close (Resume) fires Toggled(false).
        toggles.Clear();
        menu.Close();
        Check("(D) Close() hides and fires Toggled(false)", !menu.Visible && toggles.Count == 1 && !toggles[0]);

        menu.QueueFree();
        await Frames(1);
    }

    // ─────────────────────────── (E) Esc priority (AnyModalOpen) ───────────────────────────

    private async Task RunEscPrioritySpike()
    {
        GD.Print("-------------------- (E) Esc priority (AnyModalOpen) --------------------");

        var gs = GetNodeOrNull<GameState>("/root/GameState");
        bool clockWasPaused = gs?.Clock.IsPaused ?? false;
        if (gs != null)
            gs.Clock.SetPaused("spike", true); // freeze the loaded save's clock for the duration of this section

        var packed = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn");
        Check("(E) outpost.tscn loads", packed != null);
        if (packed == null)
        {
            if (gs != null) gs.Clock.SetPaused("spike", clockWasPaused);
            return;
        }

        var outpost = packed.Instantiate<OutpostScene>();
        AddChild(outpost);
        await PhysicsFrames(2);

        var pauseMenu = outpost.GetNodeOrNull<PauseMenu>("PauseMenu");
        var squadPanel = outpost.GetNodeOrNull<SquadPanel>("SquadPanel");
        Check("(E) outpost spawned its PauseMenu", pauseMenu != null);
        Check("(E) outpost spawned its SquadPanel", squadPanel != null);

        if (pauseMenu != null && squadPanel != null)
        {
            var esc = new InputEventAction { Action = "ui_cancel", Pressed = true };
            Check("(E) sanity: synthetic event reports ui_cancel pressed", esc.IsActionPressed("ui_cancel"));

            // With another panel visible, AnyModalOpen is true — Esc must not open the pause menu
            // (mirrors what would happen for real: the visible panel's own _UnhandledInput would
            // consume Esc to close itself before this handler ever sees it).
            squadPanel.Visible = true;
            outpost._UnhandledInput(esc);
            Check("(E) pause menu does NOT open while another modal is open", !pauseMenu.Visible);

            // Nothing else open — Esc opens the pause menu.
            squadPanel.Visible = false;
            outpost._UnhandledInput(esc);
            Check("(E) pause menu opens on Esc when no other modal is open", pauseMenu.Visible);

            // The pause menu counts as a modal too — a further Esc through this same handler must
            // not misbehave (in real play PauseMenu's own handler would consume it first).
            outpost._UnhandledInput(esc);
            Check("(E) already-open pause menu is not disturbed by a repeat unhandled Esc", pauseMenu.Visible);

            pauseMenu.Close();
        }

        outpost.QueueFree();
        await PhysicsFrames(1);
        if (gs != null)
            gs.Clock.SetPaused("spike", clockWasPaused);
    }

    // ─────────────────────────── helpers ───────────────────────────

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task PhysicsFrames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
    }

    // ─────────────────────────── settings.json backup/restore ───────────────────────────

    private void BackupSettings()
    {
        _settingsExisted = Godot.FileAccess.FileExists(SettingsPath);
        if (!_settingsExisted) return;
        using var file = Godot.FileAccess.Open(SettingsPath, Godot.FileAccess.ModeFlags.Read);
        if (file != null) _settingsBackup = file.GetAsText();
    }

    private void RestoreSettings()
    {
        if (_settingsExisted)
            WriteSettings(_settingsBackup);
        else
            DeleteSettings();
        ViewPreferences.ResetForReload();
    }

    private static void WriteSettings(string text)
    {
        using var file = Godot.FileAccess.Open(SettingsPath, Godot.FileAccess.ModeFlags.Write);
        file?.StoreString(text);
    }

    private static void DeleteSettings()
    {
        if (Godot.FileAccess.FileExists(SettingsPath))
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SettingsPath));
    }
}
