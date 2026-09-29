using Godot;

namespace Delve.Combat;

/// <summary>Stopping an encounter and putting the scene back in the state StartEncounter expects.</summary>
public partial class CombatScene
{
    /// <summary>Release combat-owned objects without touching terrain supplied by a dungeon.</summary>
    public void EndHostedEncounter()
    {
        ResetEncounter();
        SetPresentationVisible(false);
        ProcessMode = ProcessModeEnum.Disabled;
        _terrain.SetLookActive(false);
    }

    /// <summary>The torn-down session may still resume once on the sync context; with
    /// <see cref="_session"/> cleared, its handlers see a stale session and leave the freed HUD alone.</summary>
    public override void _ExitTree()
    {
        Delve.Settings.UserSettings.Changed -= ApplyUserSettings;
        StopEncounter();
        _session = null!;
    }

    /// <summary>
    /// Stop the encounter loop and unwire everything it owns: log subscription, cancellation source,
    /// and the session (engine globals). Node children are NOT touched — the scene may be leaving
    /// the tree, where re-parenting children is unsafe; <see cref="ResetEncounter"/> adds that step,
    /// terrain included.
    /// Null-tolerant and idempotent, so it is safe before the first encounter and twice in a row.
    /// </summary>
    private void StopEncounter()
    {
        _logBridge?.Dispose();
        // Cancel the awaited pipeline before clearing dice can release its presentation gate.
        _encounterCts?.Cancel();
        _cameraRig?.CancelIntro();
        _cameraRig?.RestorePlanningView(true);
        EndIntro();
        _dice?.ClearRoll();
        _inspectPanel?.Render(null);
        _logBridge = null;
        // Cancel BEFORE teardown: the loop may be parked in a presenter pacing delay / tween wait or on the
        // player-turn TCS. Cancelling releases those so it unwinds without resuming on freed nodes;
        // Teardown then clears the engine statics/delegates and completes any still-pending player turn.
        _session?.Teardown();
        _encounterCts?.Dispose();
        _encounterCts = null;
    }

    /// <summary>
    /// Put the scene back in the state <see cref="StartEncounter"/> expects. On top of
    /// <see cref="StopEncounter"/> it frees the previous encounter's unit tokens, damage popups and
    /// effect nodes, drops the presenter's unit registry (which would otherwise hold freed visuals),
    /// releases the controller, and clears the terrain back to the flat placeholder board. Called at
    /// the top of every StartEncounter, so the first call runs against an empty scene and does nothing.
    /// </summary>
    private void ResetEncounter()
    {
        StopEncounter();
        ResetTacticalPresentation();

        _controller?.EndControl();
        _controller = null!;
        _session = null!;

        // Registrations first, nodes second: the map must never hand out a freed visual.
        _presenter?.ClearUnits();
        _presenter = null!;

        FreeChildren(_unitLayer);
        FreeChildren(_popupLayer);

        // Terrain last, after the loop is released and the session is unwired: nothing may still be
        // resolving a position against the map when its meshes and collider go away. Clear also shows
        // the checker plane again, which a generated map hid.
        _terrain.Clear();
        _borrowedHeights = null;

        _victoryBanner.HideResult();
        _journalPanel.Hide();
    }

    /// <summary>
    /// Free every child of <paramref name="parent"/> NOW. RemoveChild before QueueFree, because
    /// QueueFree alone leaves the node in the tree until the end of the frame, and the caller
    /// (and its tests) reads the child count immediately after.
    /// </summary>
    private static void FreeChildren(Node parent)
    {
        foreach (var child in parent.GetChildren())
        {
            parent.RemoveChild(child);
            child.QueueFree();
        }
    }
}
