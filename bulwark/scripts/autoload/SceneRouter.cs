using System;
using Bulwark.Data;
using Godot;

namespace Bulwark.Autoload;

/// <summary>
/// Owns top-level mode transitions and swaps the active scene. Thin adapter: it changes scenes and
/// toggles the shared day clock — running in the Outpost and Territory modes, paused in Combat
/// (attrition-time freezes in battle). Combat routes to the encounter assembler scene, which builds
/// the real combat scene from GameState's pending territory encounter.
/// </summary>
public partial class SceneRouter : Node
{
    public static SceneRouter Instance { get; private set; } = null!;

    public enum Mode
    {
        Outpost,
        Territory,
        Combat,
        Intro,
        TitleScreen,
        NameEntry,
    }

    private const string OutpostScene = "res://scenes/outpost/outpost.tscn";

    // Assembler that consumes GameState.Territory.PendingEncounter and runs combat.tscn with it.
    private const string EncounterScene = "res://scenes/combat/encounter.tscn";

    private const string IntroScene = "res://scenes/intro/road.tscn";

    private const string TitleScene = "res://scenes/ui/title_screen.tscn";
    private const string NameEntryScene = "res://scenes/ui/name_entry.tscn";

    public Mode CurrentMode { get; private set; } = Mode.Outpost;

    /// <summary>Raised after a mode transition completes. No subscribers yet — kept deliberately as
    /// the future co-op/analytics seam (mode-scoped systems hook transitions here).</summary>
    public event Action<Mode>? ModeChanged;

    public override void _Ready() => Instance = this;

    /// <summary>Enter the cozy outpost. Resumes the day clock.</summary>
    public void GoToOutpost()
    {
        CurrentMode = Mode.Outpost;
        SetClockPaused(false);
        GetTree().ChangeSceneToFile(OutpostScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter a territory map (data-driven scene path). The day clock keeps running —
    /// exploration shares the outpost clock.</summary>
    public void GoToTerritory(string territoryId)
    {
        if (!Territories.TryGet(territoryId, out var territory))
        {
            GD.PushError($"[SceneRouter] Unknown territory '{territoryId}'.");
            return;
        }

        CurrentMode = Mode.Territory;
        SetClockPaused(false);
        GetTree().ChangeSceneToFile(territory.ScenePath);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>
    /// Enter the pending combat encounter (parameterized via GameState.Territory.PendingEncounter,
    /// staged by the BeginTerritoryEncounter command). Pauses the day clock.
    /// </summary>
    public void GoToCombat()
    {
        CurrentMode = Mode.Combat;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(EncounterScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the intro cutscene sequence. Pauses the day clock.</summary>
    public void GoToIntro()
    {
        CurrentMode = Mode.Intro;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(IntroScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the title screen. Pauses the day clock.</summary>
    public void GoToTitleScreen()
    {
        CurrentMode = Mode.TitleScreen;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(TitleScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the name entry screen. Pauses the day clock.</summary>
    public void GoToNameEntry()
    {
        CurrentMode = Mode.NameEntry;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(NameEntryScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    private static void SetClockPaused(bool paused)
    {
        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = paused;
    }
}
