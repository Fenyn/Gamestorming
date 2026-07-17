using System;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Reusable one-shot player-contact sensor for the territory enemy scenes
/// (<c>scenes/territory/roaming_enemy.tscn</c>, <c>scenes/territory/wolf_lair.tscn</c>): an Area2D
/// child whose CollisionShape2D (sized per scene — a regular roamer's trigger is smaller than the
/// boss lair's) raises <see cref="Contacted"/> exactly once when the player body first overlaps, then
/// latches. This is the idiomatic Godot replacement for the old hand-rolled
/// <c>GlobalPosition.DistanceTo(player)</c> poll: it reuses the same <c>BodyEntered</c> + default
/// collision layer/mask convention the forest's ExitTrigger already uses, and identifies the avatar
/// by type (<see cref="PlayerController"/>) exactly like <c>TerritoryScene.OnExitBodyEntered</c> — so
/// baked walls, resource-node bodies and the owner's own body all overlap harmlessly and are ignored.
/// The shape IS the contact range (authored in the .tscn), so no tunable export is needed. Holds no
/// game rules — the owning enemy script turns <see cref="Contacted"/> into its PlayerContacted event.
/// </summary>
public partial class ContactTrigger : Area2D
{
    /// <summary>Raised once, when the player avatar first enters the trigger. After it fires (or after
    /// <see cref="Disarm"/>) the sensor is latched closed and never fires again.</summary>
    public event Action? Contacted;

    private bool _fired;

    public override void _Ready()
    {
        BodyEntered += OnBodyEntered;
    }

    private void OnBodyEntered(Node2D body)
    {
        if (_fired || body is not PlayerController)
            return;
        _fired = true;
        Contacted?.Invoke();
    }

    /// <summary>Latch the sensor closed without a contact (the owner froze for a hand-off): a lingering
    /// or later overlap must not re-fire while the encounter toast plays / the scene swaps.</summary>
    public void Disarm() => _fired = true;
}
