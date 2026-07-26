using System;
using Bulwark.Data;
using Bulwark.UI;
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
        HomesteadExterior,
        HomesteadInterior,
        TitleScreen,
        NameEntry,
    }

    private const string OutpostScene = "res://scenes/outpost/outpost.tscn";

    // Assembler that consumes GameState.Territory.PendingEncounter and runs combat.tscn with it.
    private const string EncounterScene = "res://scenes/combat/encounter.tscn";

    // The intro's homestead half is two hosted cutscene scenes: the road/ford (Scene 0) hands off to the
    // homestead EXTERIOR (Scene 1a — ford/yard/camp), which hands off to the homestead INTERIOR (Scene 1b
    // — the hearth beat onward), splitting the old single homestead scene along the top-down exterior /
    // interior map convention.
    private const string IntroScene = "res://scenes/intro/road.tscn";
    private const string HomesteadExteriorScene = "res://scenes/intro/homestead_exterior.tscn";
    private const string HomesteadInteriorScene = "res://scenes/intro/homestead_interior.tscn";

    private const string TitleScene = "res://scenes/ui/title_screen.tscn";
    private const string NameEntryScene = "res://scenes/ui/name_entry.tscn";

    public Mode CurrentMode { get; private set; } = Mode.Outpost;

    /// <summary>Raised after a mode transition completes. GameState.WireWarehouseAccess subscribes —
    /// warehouse reachability is Outpost-only, so it flips on every transition — and it remains the
    /// mode-scoped seam future co-op/analytics systems hook.</summary>
    public event Action<Mode>? ModeChanged;

    /// <summary>Source key for the scene-mode pause reason on the shared day clock (see
    /// <see cref="DayClock.SetPaused"/>). One key covers every transition: Outpost/Territory drop it so
    /// the clock runs, Combat/Intro/Homestead/title/name-entry raise it — independent of the cozy host's modal
    /// pause, so a panel close can never resume a clock a mode transition froze.</summary>
    private const string ClockPauseSource = "scene_mode";

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

    /// <summary>Enter the intro cutscene sequence at the road/ford scene (Scene 0). Pauses the day clock.</summary>
    public void GoToIntro()
    {
        CurrentMode = Mode.Intro;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(IntroScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the homestead EXTERIOR cutscene scene (intro Scene 1a — ford/yard/camp) — the road
    /// scene routes here when Scene 0 finishes, and Continue resumes here on a mid-intro quit with Scene 0
    /// done and Scene 1a pending. Pauses the day clock.</summary>
    public void GoToHomesteadExterior()
    {
        CurrentMode = Mode.HomesteadExterior;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(HomesteadExteriorScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the homestead INTERIOR cutscene scene (intro Scene 1b — the hearth beat onward) — the
    /// exterior scene routes here when Scene 1a finishes, and Continue resumes here on a mid-intro quit with
    /// Scene 1a done and Scene 1 pending. Pauses the day clock.</summary>
    public void GoToHomesteadInterior()
    {
        CurrentMode = Mode.HomesteadInterior;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(HomesteadInteriorScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the title screen. Pauses the day clock. The title screen is passive — it only
    /// raises intent events — so this is also the front-end wiring seam: once the new scene is live
    /// (deferred; see <see cref="HookTitleScreen"/>) the router subscribes those events to the
    /// New Game / Continue transitions and sets the Continue button's save-dependent visibility.</summary>
    public void GoToTitleScreen()
    {
        CurrentMode = Mode.TitleScreen;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(TitleScene);
        HookWhenReady<TitleScreen>(Mode.TitleScreen, HookTitleScreen);
        ModeChanged?.Invoke(CurrentMode);
    }

    /// <summary>Enter the name entry screen. Pauses the day clock. Wires the confirmed-name event to
    /// StartNewGame → intro once the scene is live (see <see cref="HookNameEntry"/>).</summary>
    public void GoToNameEntry()
    {
        CurrentMode = Mode.NameEntry;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(NameEntryScene);
        HookWhenReady<NameEntryScreen>(Mode.NameEntry, HookNameEntry);
        ModeChanged?.Invoke(CurrentMode);
    }

    // ===================== Front-end wiring (title → name entry → intro / outpost) =====================
    //
    // Event hygiene: the AUTOLOAD subscribes to the freed-on-swap SCREEN (not the reverse), so each
    // screen owns its own subscription and drops it when it leaves the tree — nothing accumulates on
    // this router across visits (the opposite of Hd2dStack, where a world scene subscribes to the
    // autoload and MUST unsubscribe in _ExitTree to avoid leaking itself). The TreeExiting hooks below
    // are belt-and-suspenders: they detach before the screen tears down, so a stale invoke can never
    // fire mid-free and re-entrancy from the same instance is impossible.

    /// <summary>
    /// Run <paramref name="wire"/> against the freshly swapped-in screen ONCE it is actually live.
    /// <see cref="SceneTree.ChangeSceneToFile"/> swaps deferred and — critically — the swap is NOT
    /// guaranteed to have flushed by the next message-queue drain, so a single Callable.CallDeferred
    /// can (and does) run while GetTree().CurrentScene is still the OLD scene, silently no-op'ing the
    /// hookup and leaving the title screen a dead end. Polling the tree's once-per-frame signal is the
    /// reliable seam: it fires after the swap flush lands. One-shot — detaches the moment it wires, or
    /// if the router mode changes first (a newer transition superseded this one), so no waiter lingers.
    /// Deliberately tiny; not a screen-controller framework.
    /// </summary>
    private void HookWhenReady<T>(Mode forMode, Action<T> wire) where T : Node
    {
        var tree = GetTree();
        void OnFrame()
        {
            if (tree.CurrentScene is T scene)
            {
                tree.ProcessFrame -= OnFrame;
                wire(scene);
            }
            else if (CurrentMode != forMode)
            {
                tree.ProcessFrame -= OnFrame; // superseded by a later transition — stop waiting
            }
        }
        tree.ProcessFrame += OnFrame;
    }

    /// <summary>Wire the live title screen: reflect save existence onto the Continue button and route
    /// its intent events (unsubscribing when the screen leaves the tree).</summary>
    private void HookTitleScreen(TitleScreen title)
    {
        title.SetContinueVisible(GameState.Instance?.SaveExists() ?? false);

        title.NewGameRequested += OnNewGameRequested;
        title.ContinueRequested += OnContinueRequested;
        title.TreeExiting += () =>
        {
            title.NewGameRequested -= OnNewGameRequested;
            title.ContinueRequested -= OnContinueRequested;
        };
    }

    /// <summary>Wire the live name-entry screen: on confirm, start the new game with the chosen name
    /// and enter the intro.</summary>
    private void HookNameEntry(NameEntryScreen entry)
    {
        void OnConfirmed(string name)
        {
            GameState.Instance?.StartNewGame(name);
            GoToIntro();
        }

        entry.NameConfirmed += OnConfirmed;
        entry.TreeExiting += () => entry.NameConfirmed -= OnConfirmed;
    }

    /// <summary>New Game: go to name entry (which, on confirm, calls StartNewGame → intro).</summary>
    private void OnNewGameRequested() => GoToNameEntry();

    /// <summary>
    /// Continue: load the existing save, then resume at the right place. The intro is a four-scene
    /// sequence with three save checkpoints across three hosted scenes — the road scene sets intro_scene_0
    /// (after Scene 0) then routes to the homestead exterior, which sets intro_scene_1a (after Scene 1a)
    /// then routes to the homestead interior, which sets intro_scene_1 (after Scene 1b); the outpost sets
    /// intro_complete when Scene 2 finishes. A mid-intro quit must resume where it left off rather than
    /// soft-locking:
    ///
    ///   intro_complete set                          -> Outpost            (intro already finished)
    ///   intro_scene_1 set,   intro_complete unset    -> Outpost            (both homestead cutscenes done;
    ///                                                                       scene 2 is still pending and
    ///                                                                       OutpostScene.TryPlayIntroScene2
    ///                                                                       fires it there)
    ///   intro_scene_1a set,  intro_scene_1 unset      -> HomesteadInterior  (Scene 1a done, Scene 1b pending)
    ///   intro_scene_0 set,   intro_scene_1a unset     -> HomesteadExterior  (Scene 0 done, Scene 1a pending)
    ///   intro_scene_0 unset                          -> Intro road         (nothing played yet — Scene 0)
    ///
    /// The four flags collapse to <see cref="ResumeRoute"/>. The Continue button is hidden when no save
    /// exists (HookTitleScreen), so this only runs with a real save; the ContinueGame guard degrades to a
    /// fresh seed if somehow reached without one.
    /// </summary>
    private void OnContinueRequested()
    {
        var gs = GameState.Instance;
        gs?.ContinueGame();
        if (gs == null)
        {
            GoToOutpost();
            return;
        }

        switch (ResumeRoute(
                    gs.HasStoryFlag("intro_complete"),
                    gs.HasStoryFlag("intro_scene_0"),
                    gs.HasStoryFlag("intro_scene_1a"),
                    gs.HasStoryFlag("intro_scene_1")))
        {
            case Mode.Intro:
                GoToIntro();
                break;
            case Mode.HomesteadExterior:
                GoToHomesteadExterior();
                break;
            case Mode.HomesteadInterior:
                GoToHomesteadInterior();
                break;
            default:
                GoToOutpost();
                break;
        }
    }

    /// <summary>The Continue resume route (extracted pure decision — see <see cref="OnContinueRequested"/>
    /// for the full table). <see cref="Mode.Outpost"/> once the intro is finished or both homestead
    /// cutscenes are done (a pending Scene 2 triggers there); <see cref="Mode.HomesteadInterior"/> when
    /// Scene 1a is done but Scene 1b is pending; <see cref="Mode.HomesteadExterior"/> when Scene 0 is done
    /// but Scene 1a is pending; otherwise <see cref="Mode.Intro"/> (the road scene, nothing played yet).
    /// Kept static and side-effect-free so the intro spike can assert it headless.</summary>
    public static Mode ResumeRoute(bool introComplete, bool scene0Done, bool scene1aDone, bool scene1Done)
    {
        if (introComplete || scene1Done)
            return Mode.Outpost;
        if (scene1aDone)
            return Mode.HomesteadInterior;
        if (scene0Done)
            return Mode.HomesteadExterior;
        return Mode.Intro;
    }

    private static void SetClockPaused(bool paused)
    {
        GameState.Instance?.Clock?.SetPaused(ClockPauseSource, paused);
    }
}
