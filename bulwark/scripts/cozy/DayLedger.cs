using System;
using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// Accumulates the noteworthy happenings of the current in-game day for the Stardew-style
/// end-of-day summary: items gained (through the inventory's single AddItem choke point — farm
/// harvests and territory node yields alike), farm crops harvested, encounter XP awarded,
/// encounters won/lost, Treat Wounds uses, and the all-nighter flag. Pure C# — no Godot types.
///
/// Lifecycle (owned by GameState): <see cref="Reset"/> when a new day starts (and on load),
/// <see cref="BuildSummary"/> when a day ends by any path (sleep, 30:00 rollover, defeat wake).
/// TRANSIENT BY DESIGN: the ledger is deliberately not saved — quitting mid-day loses the
/// running tallies, and the next session's summary covers only what happened after the load.
/// </summary>
public sealed class DayLedger
{
    private readonly Dictionary<string, int> _itemsGained = new();

    /// <summary>Items gained today (item id → total count). Read-only live view for diagnostics.</summary>
    public IReadOnlyDictionary<string, int> ItemsGained => _itemsGained;

    /// <summary>Farm plots harvested today (a Stardew-cozy stat, distinct from item counts).</summary>
    public int CropsHarvested { get; private set; }

    /// <summary>Encounter XP banked per member today (each member receives the same award).</summary>
    public int XpAwarded { get; private set; }

    public int EncountersWon { get; private set; }
    public int EncountersLost { get; private set; }

    /// <summary>Out-of-combat Treat Wounds commands that resolved today.</summary>
    public int TreatWoundsUses { get; private set; }

    /// <summary>True once the day ended via the 30:00 all-nighter rollover instead of sleep.</summary>
    public bool AllNighter { get; private set; }

    public void RecordItemGained(string itemId, int qty)
    {
        if (string.IsNullOrEmpty(itemId) || qty <= 0)
            return;
        _itemsGained[itemId] = (_itemsGained.TryGetValue(itemId, out int n) ? n : 0) + qty;
    }

    public void RecordCropHarvested() => CropsHarvested++;

    public void RecordXpAwarded(int amount)
    {
        if (amount > 0)
            XpAwarded += amount;
    }

    public void RecordEncounter(bool victory)
    {
        if (victory) EncountersWon++;
        else EncountersLost++;
    }

    public void RecordTreatWounds() => TreatWoundsUses++;

    public void MarkAllNighter() => AllNighter = true;

    /// <summary>Clear every tally for a fresh day (called after the summary is built, and on load).</summary>
    public void Reset()
    {
        _itemsGained.Clear();
        CropsHarvested = 0;
        XpAwarded = 0;
        EncountersWon = 0;
        EncountersLost = 0;
        TreatWoundsUses = 0;
        AllNighter = false;
    }

    /// <summary>
    /// Snapshot the day's tallies into an immutable <see cref="DaySummaryView"/>.
    /// <paramref name="dateEnded"/> is the date string of the day that just ENDED (capture it
    /// before the clock advances); level-ups and the fatigue notice are the caller's knowledge
    /// (GameState) — the ledger only carries what it accumulated. The ledger is not mutated;
    /// the caller resets it separately once the summary is staged.
    /// </summary>
    public DaySummaryView BuildSummary(
        string dateEnded,
        IReadOnlyList<SquadLevelUpView>? levelUps,
        string? fatigueNotice)
    {
        return new DaySummaryView
        {
            Date = dateEnded,
            ItemsGained = new Dictionary<string, int>(_itemsGained),
            CropsHarvested = CropsHarvested,
            XpAwarded = XpAwarded,
            EncountersWon = EncountersWon,
            EncountersLost = EncountersLost,
            TreatWoundsUses = TreatWoundsUses,
            AllNighter = AllNighter,
            FatigueNotice = fatigueNotice,
            LevelUps = levelUps ?? Array.Empty<SquadLevelUpView>(),
        };
    }
}
