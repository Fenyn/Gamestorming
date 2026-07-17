using System;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// The fixed one-shot BOSS site for "The Wolf of the Fringe" (design/tutorial_quests.md quest 9): a
/// stationary lair placed at a marker in the forest territory. Unlike a <see cref="RoamingEnemy"/> it
/// never wanders — it waits. Walking into it raises <see cref="PlayerContacted"/> ONCE (with the boss
/// roamer id), which the scene turns into the very same BeginTerritoryEncounter hand-off a roamer
/// uses. Contact is sensed by the shared <see cref="ContactTrigger"/> Area2D child (its shape, larger
/// than a regular roamer's, is the contact range) — the same idiomatic BodyEntered seam a roamer uses,
/// so the two enemy kinds never drift apart. Holds no game rules; its lifecycle (appear when the quest
/// starts, despawn for good once the wolf is slain) is decided by <see cref="ShouldAppear"/> and
/// driven by the scene from GameState.
/// </summary>
public partial class WolfLair : Node2D
{
    /// <summary>Raised once when the player reaches the lair, with the boss roamer id.</summary>
    public event Action<string>? PlayerContacted;

    public string RoamerId { get; private set; } = "";

    private ContactTrigger? _contact;
    private bool _triggered;

    /// <summary>
    /// The lair's lifecycle predicate (pure, headless-testable): it is present exactly while its quest
    /// is active AND the wolf is not yet slain. Before the quest starts it is hidden; once
    /// <c>dire_wolf_slain</c> latches it is gone for good (that flag persists, so the despawn survives
    /// save/load with no extra save field). Defeat/retreat leave the flag unset, so it simply remains
    /// for a retry.
    /// </summary>
    public static bool ShouldAppear(bool questActive, bool wolfSlain) => questActive && !wolfSlain;

    public override void _Ready()
    {
        _contact = GetNodeOrNull<ContactTrigger>("%ContactTrigger");
        if (_contact != null)
            _contact.Contacted += OnContact;
    }

    /// <summary>Injected by the territory scene after instancing. The lair is stationary, so the
    /// player reference is unused here — contact flows through the <see cref="ContactTrigger"/> child;
    /// the parameter is kept so the scene wires a lair exactly like a roamer.</summary>
    public void Setup(string roamerId, Node2D player)
    {
        RoamerId = roamerId;
        _ = player;
    }

    /// <summary>Freeze so a lingering overlap does not re-fire while the hand-off toast plays.</summary>
    public void Freeze()
    {
        _triggered = true;
        _contact?.Disarm();
    }

    /// <summary>The contact trigger fired: latch and hand the boss encounter to the scene once.</summary>
    private void OnContact()
    {
        if (_triggered)
            return;
        Freeze();
        PlayerContacted?.Invoke(RoamerId);
    }
}
