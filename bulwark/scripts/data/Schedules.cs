using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// One slot in a villager's daily routine: from <see cref="MinuteOfDay"/> onward the villager anchors
/// at the scene marker named <see cref="MarkerName"/> (a <c>%Spot_*</c> node the user places in the
/// world). Data-only per CLAUDE.md — the scene resolves the marker to a world position.
/// </summary>
public sealed class ScheduleEntry
{
    /// <summary>Minute-of-day (6:00 = 360 .. 30:00 = 1800) this slot begins.</summary>
    public required int MinuteOfDay { get; init; }

    /// <summary>Scene marker (%UniqueName) this slot anchors the villager at.</summary>
    public required string MarkerName { get; init; }
}

/// <summary>An ordered day plan for one villager, keyed by villager/resident id.</summary>
public sealed class VillagerSchedule
{
    public required string VillagerId { get; init; }

    /// <summary>Entries in strictly ascending <see cref="ScheduleEntry.MinuteOfDay"/> order
    /// (enforced by <see cref="DataValidation"/>).</summary>
    public required IReadOnlyList<ScheduleEntry> Entries { get; init; }
}

/// <summary>
/// Static registry of villager daily schedules (time-slot routines) — same DefinitionRegistry pattern
/// as <see cref="Villagers"/>/<see cref="Buildings"/>. Adding a routine touches only this file (plus the
/// <c>%Spot_*</c> markers in the world scene). A villager id with NO schedule here has no behavior
/// change: the NPC simply wanders around its home marker exactly as before.
///
/// Minute-of-day helpers below are authored against the clock's 6:00–30:00 day (see
/// <see cref="Bulwark.Cozy.DayClock"/>): 8:00 = 480, 13:00 = 780, etc.
/// </summary>
public static class Schedules
{
    private static int At(int hour, int minute = 0) => hour * 60 + minute;

    // Placement markers derive from existing outpost nodes (see scenes/outpost/outpost.tscn); the user
    // repositions them in-editor. Command post = the planning table, gate = the walls/expedition gate,
    // farm field = the tilled plots, trading post = Elara's stall, tavern = the evening gathering spot.
    private const string SpotCommandPost = "Spot_command_post";
    private const string SpotGate = "Spot_gate";
    private const string SpotFarmField = "Spot_farm_field";
    private const string SpotTradingPost = "Spot_trading_post";
    private const string SpotTavern = "Spot_tavern";

    /// <summary>Tharr (captain): morning at the planning table, midday walking the walls/gate, evening
    /// at the tavern.</summary>
    public static readonly VillagerSchedule Tharr = new()
    {
        VillagerId = "tharr",
        Entries = new ScheduleEntry[]
        {
            new() { MinuteOfDay = At(8),  MarkerName = SpotCommandPost },
            new() { MinuteOfDay = At(13), MarkerName = SpotGate },
            new() { MinuteOfDay = At(19), MarkerName = SpotTavern },
        },
    };

    /// <summary>Fenwick (cook): morning at the tavern hearth, afternoon out in the farm field, back at
    /// the tavern for the evening meal.</summary>
    public static readonly VillagerSchedule Fenwick = new()
    {
        VillagerId = "fenwick",
        Entries = new ScheduleEntry[]
        {
            new() { MinuteOfDay = At(9),  MarkerName = SpotTavern },
            new() { MinuteOfDay = At(15), MarkerName = SpotFarmField },
            new() { MinuteOfDay = At(20), MarkerName = SpotTavern },
        },
    };

    /// <summary>Elara (quartermaster): morning at the trading post, afternoon at the gate, evening at
    /// the tavern.</summary>
    public static readonly VillagerSchedule Elara = new()
    {
        VillagerId = "elara",
        Entries = new ScheduleEntry[]
        {
            new() { MinuteOfDay = At(9),  MarkerName = SpotTradingPost },
            new() { MinuteOfDay = At(14), MarkerName = SpotGate },
            new() { MinuteOfDay = At(19), MarkerName = SpotTavern },
        },
    };

    private static readonly DefinitionRegistry<VillagerSchedule> Registry =
        new(s => s.VillagerId, Tharr, Fenwick, Elara);

    /// <summary>Every defined schedule.</summary>
    public static IReadOnlyCollection<VillagerSchedule> All => Registry.All;

    /// <summary>True when <paramref name="villagerId"/> has a schedule.</summary>
    public static bool IsDefined(string villagerId) => Registry.IsDefined(villagerId);

    /// <summary>Non-throwing lookup.</summary>
    public static bool TryGet(string villagerId, out VillagerSchedule schedule)
        => Registry.TryGet(villagerId, out schedule);

    /// <summary>
    /// Pure resolution: the marker anchoring <paramref name="villagerId"/> at <paramref name="minuteOfDay"/>
    /// — the entry with the LATEST <see cref="ScheduleEntry.MinuteOfDay"/> ≤ now. Returns null before the
    /// first slot (early morning → the villager stays at its home/spawn marker) and for a villager with no
    /// schedule. Depends only on the (validated) ascending entry order, so it is Node-free and testable.
    /// </summary>
    public static string? ResolveMarker(string villagerId, int minuteOfDay)
    {
        if (!Registry.TryGet(villagerId, out var schedule))
            return null;

        string? marker = null;
        foreach (var entry in schedule.Entries)
        {
            if (entry.MinuteOfDay <= minuteOfDay)
                marker = entry.MarkerName;
            else
                break; // entries ascend, so the first future slot ends the search
        }
        return marker; // null = before the first slot → home anchor
    }
}
