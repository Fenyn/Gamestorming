using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// View-model for the calendar panel (<see cref="Bulwark.Autoload.GameState.GetCalendarView"/>): the
/// current season's 28 days, today flagged, each day carrying short marker lines (birthdays,
/// building-construction completions). Engine-free — the panel renders this only, per CLAUDE.md's
/// UI-is-passive rule.
/// </summary>
public sealed record CalendarView(
    Season Season,
    int Year,
    int CurrentDay,
    IReadOnlyList<CalendarDayView> Days);

/// <summary>One calendar cell: the day-of-season number, whether it's today, and any marker lines
/// (empty when nothing of note happens that day).</summary>
public sealed record CalendarDayView(
    int Day,
    bool IsToday,
    IReadOnlyList<string> Marks);
