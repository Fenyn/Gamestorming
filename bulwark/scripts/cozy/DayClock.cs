using System;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// The Stardew-style game clock and calendar. Pure C# — no Godot types, unit-testable without a
/// scene tree. GameState owns an instance, feeds it real delta each frame via <see cref="Tick"/>,
/// and reacts to its events. Exploration activities (M3) charge time through <see cref="SpendTime"/>.
///
/// A day runs 6:00 → 26:00 (2 AM). Reaching 26:00 fires <see cref="DayEnded"/> once and freezes the
/// clock until <see cref="StartNextDay"/> resets it — GameState decides the collapse consequence.
/// Calendar: 4 seasons × 28 days, with a year counter that increments on the Winter → Spring wrap.
/// </summary>
public sealed class DayClock
{
    /// <summary>First minute-of-day the clock sits at each morning (6:00).</summary>
    public const int DayStartMinute = 6 * 60;   // 360

    /// <summary>Minute-of-day the day ends / collapse triggers (26:00 = 2 AM next morning).</summary>
    public const int DayEndMinute = 26 * 60;    // 1560

    public const int DaysPerSeason = 28;

    /// <summary>
    /// Real seconds that elapse per in-game minute. Default 0.75 → ~15 real minutes per full
    /// 6:00–26:00 day (1200 game minutes). GameState drives this from an exported tunable.
    /// </summary>
    public double RealSecondsPerGameMinute { get; set; } = 0.75;

    /// <summary>When true, <see cref="Tick"/> is a no-op. Set during combat / menus.</summary>
    public bool IsPaused { get; set; }

    private double _realAccumulator;
    private bool _dayEnded;

    // --- Calendar / time-of-day state ---

    /// <summary>Minutes since midnight, in [<see cref="DayStartMinute"/>, <see cref="DayEndMinute"/>].</summary>
    public int MinuteOfDay { get; private set; } = DayStartMinute;

    /// <summary>Day within the current season, 1..28.</summary>
    public int Day { get; private set; } = 1;

    public Season Season { get; private set; } = Season.Spring;

    /// <summary>Year counter, starts at 1.</summary>
    public int Year { get; private set; } = 1;

    /// <summary>Current hour (6..26). 24 = midnight, 26 = 2 AM.</summary>
    public int Hour => MinuteOfDay / 60;

    /// <summary>Current minute within the hour, 0..59.</summary>
    public int Minute => MinuteOfDay % 60;

    /// <summary>True once 26:00 has been reached and before <see cref="StartNextDay"/>.</summary>
    public bool DayIsOver => _dayEnded;

    // --- Events (raised from logic, no Godot signals at this layer) ---

    /// <summary>Raised once per in-game minute (throttled — never per-frame).</summary>
    public event Action? MinuteChanged;

    /// <summary>Raised when the hour rolls over.</summary>
    public event Action? HourChanged;

    /// <summary>Raised once when 26:00 is reached. The clock freezes until <see cref="StartNextDay"/>.</summary>
    public event Action? DayEnded;

    /// <summary>Raised by <see cref="StartNextDay"/> after the calendar advances to the new morning.</summary>
    public event Action? DayStarted;

    /// <summary>
    /// Advance real time. Accumulates and releases whole in-game minutes; a no-op while paused or
    /// after the day has ended. GameState calls this from _Process(delta).
    /// </summary>
    public void Tick(double realDelta)
    {
        if (IsPaused || _dayEnded || RealSecondsPerGameMinute <= 0.0)
            return;

        _realAccumulator += realDelta;
        while (_realAccumulator >= RealSecondsPerGameMinute)
        {
            _realAccumulator -= RealSecondsPerGameMinute;
            AdvanceOneMinute();
            if (_dayEnded)
            {
                _realAccumulator = 0.0;
                break;
            }
        }
    }

    /// <summary>
    /// Instantly advance the clock by <paramref name="minutes"/> in-game minutes (the seam PF2e
    /// exploration activities charge in M3). Raises the same events an equivalent real-time tick
    /// would, and stops early if the day ends mid-advance.
    /// </summary>
    public void SpendTime(int minutes)
    {
        if (minutes <= 0)
            return;

        for (int i = 0; i < minutes && !_dayEnded; i++)
            AdvanceOneMinute();
    }

    /// <summary>Reset to 6:00 and advance the calendar (day, then season/year rollover).</summary>
    public void StartNextDay()
    {
        MinuteOfDay = DayStartMinute;
        _realAccumulator = 0.0;
        _dayEnded = false;

        Day++;
        if (Day > DaysPerSeason)
        {
            Day = 1;
            AdvanceSeason();
        }

        DayStarted?.Invoke();
    }

    /// <summary>Overwrite calendar/time state (used by the save system). Clears the day-ended latch.</summary>
    public void RestoreState(int minuteOfDay, int day, Season season, int year)
    {
        MinuteOfDay = Math.Clamp(minuteOfDay, DayStartMinute, DayEndMinute);
        Day = day;
        Season = season;
        Year = year;
        _realAccumulator = 0.0;
        _dayEnded = MinuteOfDay >= DayEndMinute;
    }

    /// <summary>"6:00 AM" / "1:30 PM" / "12:00 AM" (midnight) / "2:00 AM" (collapse hour).</summary>
    public string TimeString()
    {
        int displayHour = Hour % 24;        // 24→0, 25→1, 26→2
        string suffix = displayHour < 12 ? "AM" : "PM";
        int twelve = displayHour % 12;
        if (twelve == 0) twelve = 12;
        return $"{twelve}:{Minute:D2} {suffix}";
    }

    /// <summary>"Spring 5, Year 1"</summary>
    public string DateString() => $"{Season} {Day}, Year {Year}";

    private void AdvanceOneMinute()
    {
        if (_dayEnded)
            return;

        int prevHour = Hour;
        MinuteOfDay++;
        MinuteChanged?.Invoke();

        if (Hour != prevHour)
            HourChanged?.Invoke();

        if (MinuteOfDay >= DayEndMinute)
        {
            MinuteOfDay = DayEndMinute;
            _dayEnded = true;
            DayEnded?.Invoke();
        }
    }

    private void AdvanceSeason()
    {
        if (Season == Season.Winter)
        {
            Season = Season.Spring;
            Year++;
        }
        else
        {
            Season = (Season)((int)Season + 1);
        }
    }
}
