using Bulwark.Autoload;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// One-shot exploration sensor: an Area3D placed directly in a territory .tscn that fires the first
/// time the player avatar walks into its CollisionShape3D, then latches. Where <see cref="ContactTrigger"/>
/// raises an event for an owner enemy script, this one talks straight to GameState — it turns "the
/// party has been HERE" into a persisted story beat (villager-arrival triggers like
/// <c>elderwood_explored</c> / <c>elderwood_far_campsite_discovered</c>) or a quest event
/// (<c>wolf_tracked</c>). It reuses the exact body-identification idiom from ContactTrigger
/// (<c>BodyEntered</c>, identify the avatar by <see cref="PlayerController"/> type, default collision
/// layer/mask) so the authored ground body, resource-node bodies and campsite props overlap
/// harmlessly and are ignored.
///
/// Exactly one of <see cref="StoryFlag"/> / <see cref="QuestEvent"/> is authored per instance (flag
/// wins if both are set). The shape IS the discovery range (authored per .tscn in METRES — a
/// deep-zone sensor is broad, a specific-corner one is tight), so no tunable export is needed beyond
/// the id.
///
/// One-shot semantics survive re-entry for free: within a session <see cref="_fired"/> latches after
/// the first hit; on scene re-entry a fresh instance MAY re-fire, but both sinks are idempotent —
/// <see cref="GameState.SetStoryFlag"/> no-ops an already-set flag, and
/// <see cref="GameState.RecordQuestEvent"/> re-completing an already-satisfied one-shot objective (or
/// firing while no quest wants the event) is a no-op. So the persisted beat/event carries the
/// one-shot guarantee; the sensor needs no save field. Null-safe: with no GameState autoload
/// (F6/headless standalone) it latches and does nothing, exactly like ContactTrigger with no owner.
/// </summary>
public partial class ExplorationTrigger : Area3D
{
    /// <summary>Story flag to set on first contact (villager-arrival beats). Leave empty to use
    /// <see cref="QuestEvent"/> instead. If both are set, the flag wins.</summary>
    [Export] public string StoryFlag { get; set; } = "";

    /// <summary>Quest event to record on first contact (e.g. <c>wolf_tracked</c>). Used only when
    /// <see cref="StoryFlag"/> is empty.</summary>
    [Export] public string QuestEvent { get; set; } = "";

    private bool _fired;

    public override void _Ready()
    {
        BodyEntered += OnBodyEntered;
    }

    private void OnBodyEntered(Node3D body)
    {
        if (_fired || body is not PlayerController)
            return;
        _fired = true;

        var gs = GameState.Instance;
        if (gs == null)
            return;

        if (!string.IsNullOrEmpty(StoryFlag))
            gs.SetStoryFlag(StoryFlag);
        else if (!string.IsNullOrEmpty(QuestEvent))
            gs.RecordQuestEvent(QuestEvent);
    }
}
