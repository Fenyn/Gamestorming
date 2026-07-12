using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// Immutable snapshot of a finished day for the end-of-day summary panel, built by
/// <see cref="DayLedger.BuildSummary"/> and staged as GameState's one-shot ConsumeDaySummary
/// hand-off (the ConsumeDefeatSummary precedent). View-model shaped per CLAUDE.md: item ids
/// (the UI resolves display names via the Items data class), plain counts, no engine types.
/// </summary>
public sealed class DaySummaryView
{
    /// <summary>Date string of the day that ENDED ("Spring 5, Year 1").</summary>
    public required string Date { get; init; }

    /// <summary>Items gained during the day (item id → total count).</summary>
    public required IReadOnlyDictionary<string, int> ItemsGained { get; init; }

    /// <summary>Farm plots harvested during the day.</summary>
    public required int CropsHarvested { get; init; }

    /// <summary>Encounter XP banked per member during the day.</summary>
    public required int XpAwarded { get; init; }

    public required int EncountersWon { get; init; }
    public required int EncountersLost { get; init; }

    /// <summary>Out-of-combat Treat Wounds commands that resolved during the day.</summary>
    public required int TreatWoundsUses { get; init; }

    /// <summary>True when the day ended via the 30:00 all-nighter rollover instead of sleep.</summary>
    public required bool AllNighter { get; init; }

    /// <summary>Fatigue line for the panel when <see cref="AllNighter"/> — null after a real rest.</summary>
    public string? FatigueNotice { get; init; }

    /// <summary>Level-ups applied overnight (the sleep path); empty on rollover/defeat wakes.</summary>
    public required IReadOnlyList<SquadLevelUpView> LevelUps { get; init; }
}
