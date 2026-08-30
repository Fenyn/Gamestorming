namespace Delve.Run;

/// <summary>
/// The run's PF2e time layer. Travel between nodes costs nothing tracked; each day allows a fixed
/// number of ten-minute short rests, and a Campsite node ends the day and refills the budget.
/// </summary>
public sealed class DayClock
{
    public DayClock(int shortRestsPerDay = 3)
    {
        ShortRestsPerDay = shortRestsPerDay < 0 ? 0 : shortRestsPerDay;
    }

    /// <summary>Days elapsed, starting at 1.</summary>
    public int Day { get; private set; } = 1;

    /// <summary>Ten-minute blocks already spent today.</summary>
    public int ShortRestsUsed { get; private set; }

    /// <summary>Ten-minute blocks allowed per day.</summary>
    public int ShortRestsPerDay { get; }

    /// <summary>Blocks left today.</summary>
    public int ShortRestsRemaining => ShortRestsPerDay - ShortRestsUsed;

    /// <summary>True while a ten-minute activity can still be taken today.</summary>
    public bool CanShortRest => ShortRestsUsed < ShortRestsPerDay;

    /// <summary>Consume one block. False, and no change, when the budget is spent.</summary>
    public bool SpendShortRest()
    {
        if (!CanShortRest) return false;
        ShortRestsUsed++;
        return true;
    }

    /// <summary>A night's rest: next day, budget back to full.</summary>
    public void NewDay()
    {
        Day++;
        ShortRestsUsed = 0;
    }
}
