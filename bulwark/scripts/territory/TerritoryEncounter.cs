using System.Collections.Generic;
using Bulwark.Combat;
using Godot;
using PF2e.Core;

namespace Bulwark.Territory;

/// <summary>
/// A pending (or just-finished) territory encounter: the parameterized <see cref="CombatSetup"/>
/// the combat scene consumes, the defeated-enemy list CompleteEncounter needs for XP, and the
/// return context (which territory, where the player stood, which roamer triggered it).
/// Built by <see cref="TerritorySystem.BeginEncounter"/>; combat-layer data, never touched by UI.
/// </summary>
public sealed class TerritoryEncounter
{
    public required string TerritoryId { get; init; }
    public required string RoamerId { get; init; }
    public required string EncounterId { get; init; }
    public required string EncounterName { get; init; }

    /// <summary>World position the player returns to on victory.</summary>
    public required Vector2 ReturnPosition { get; init; }

    /// <summary>Grid, party (selected members only) and enemies for the combat scene.</summary>
    public required CombatSetup Setup { get; init; }

    /// <summary>
    /// Battle-map provenance: the biome the map was generated from and the seed it was generated with.
    /// <c>MapGenerator.GenerateValidated(BiomeId, MapSeed)</c> rebuilds <see cref="Setup"/>'s layout
    /// byte-for-byte, so an encounter is fully described by this pair and no MapLayout ever needs to be
    /// serialized. Null/0 when the encounter fell back to the flat <see cref="CombatBoards"/> board.
    ///
    /// Nothing persists a pending encounter today — <c>TerritoryDto</c> carries none and RestoreState
    /// clears it, because the player always loads back at the outpost — so these are carried for
    /// debugging (which map am I looking at?) and to keep that reconstruction one call away if an
    /// in-flight save is ever wanted.
    /// </summary>
    public string? BiomeId { get; init; }

    /// <inheritdoc cref="BiomeId"/>
    public int MapSeed { get; init; }

    /// <summary>The enemy instances, for XP on victory (GameState.CompleteEncounter).</summary>
    public required IReadOnlyList<ICharacter> Enemies { get; init; }
}
