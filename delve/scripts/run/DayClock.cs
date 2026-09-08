namespace Delve.Run;

/// <summary>
/// The run's PF2e time layer. Travel costs no tracked time and a ten-minute short rest is paid for
/// in ward rather than in a daily allowance (design/core_concept.md, "Wardstone"). The clock counts
/// the day and the blocks taken within it, which gives short-rest dice a stable position to seed
/// from, and a Campsite node ends the day so the daily PF2e resources refresh.
/// </summary>
public sealed class DayClock
{
    /// <summary>Days elapsed, starting at 1.</summary>
    public int Day { get; private set; } = 1;

    /// <summary>Ten-minute blocks taken since the day began.</summary>
    public int ShortRestsToday { get; private set; }

    /// <summary>Count one ten-minute block against the current day.</summary>
    public void SpendShortRest() => ShortRestsToday++;

    /// <summary>A night's rest: next day, block count back to zero.</summary>
    public void NewDay()
    {
        Day++;
        ShortRestsToday = 0;
    }
}
