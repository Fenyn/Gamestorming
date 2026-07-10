using System;
using Bulwark.Combat;
using Godot;

namespace Bulwark.Autoload;

/// <summary>
/// Owns top-level mode transitions and swaps the active scene. Thin adapter: it changes scenes and
/// toggles the shared day clock (running in the Outpost, paused in Combat). Territory mode arrives
/// in M3.
/// </summary>
public partial class SceneRouter : Node
{
    public static SceneRouter Instance { get; private set; } = null!;

    public enum Mode
    {
        Outpost,
        Combat,
    }

    private const string OutpostScene = "res://scenes/outpost/outpost.tscn";

    // M2 stub: combat has no GameState-driven entry yet, so route to the existing combat dev scene.
    // M3 replaces this with a real combat scene built from the CombatSetup.
    private const string CombatDevScene = "res://scenes/dev/combat_test.tscn";

    public Mode CurrentMode { get; private set; } = Mode.Outpost;

    /// <summary>Raised after a mode transition completes.</summary>
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

    /// <summary>
    /// Enter a combat encounter. Pauses the day clock (attrition-time freezes in battle). For M2 the
    /// <paramref name="setup"/> is not yet consumed — the stub loads the existing combat dev scene.
    /// </summary>
    public void GoToCombat(CombatSetup setup)
    {
        _ = setup; // TODO (M3): build the combat scene from this setup.
        CurrentMode = Mode.Combat;
        SetClockPaused(true);
        GetTree().ChangeSceneToFile(CombatDevScene);
        ModeChanged?.Invoke(CurrentMode);
    }

    private static void SetClockPaused(bool paused)
    {
        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = paused;
    }
}
