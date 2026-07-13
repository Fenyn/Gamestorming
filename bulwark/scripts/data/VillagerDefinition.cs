namespace Bulwark.Data;

/// <summary>
/// Declarative definition of one hand-authored named character in the STATIC cast (Phase 3
/// keystone). Data-only per CLAUDE.md — the shipped <see cref="Villagers"/> registry is EMPTY and
/// the user authors villagers here later (exactly like building markers), so this type only
/// describes the framework, never content.
///
/// A villager becomes present at the outpost when its <see cref="Arrival"/> trigger fires
/// (building restored / story flag / date). Association with a building is many-to-many and purely
/// informational (<see cref="AssociatedBuildingId"/>) — a domain hint the NPC loader can use to
/// place the character near a building, NOT a lock. Some villagers are playable: when
/// <see cref="Recruitable"/> is true, <see cref="JoinPresetKey"/> names the PC preset (registered in
/// Bulwark.Presets.PartyPresets) that is inserted into the squad when the player has them join.
/// </summary>
public sealed class VillagerDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Optional domain building this character associates with (many-to-many hint, not a lock).</summary>
    public string? AssociatedBuildingId { get; init; }

    /// <summary>The condition that brings this character to the outpost.</summary>
    public required ArrivalTrigger Arrival { get; init; }

    /// <summary>True when this character is a playable party member that can JOIN the squad once arrived.</summary>
    public bool Recruitable { get; init; }

    /// <summary>
    /// For a recruitable villager: the key of the joinable PC preset (Bulwark.Presets.PartyPresets)
    /// inserted into the squad on join. Null for pure townsfolk. No preset ships now, so nothing
    /// actually joins in shipped play — the mechanism exists for authored content.
    /// </summary>
    public string? JoinPresetKey { get; init; }

    /// <summary>Marker the NPC loader spawns this character at (the user hand-places it in the outpost).</summary>
    public string MarkerName => $"Villager_{Id}";

    /// <summary>Optional premade NPC scene; the loader falls back to a placeholder node when absent.</summary>
    public string ScenePath => $"res://scenes/villagers/{Id}.tscn";
}
