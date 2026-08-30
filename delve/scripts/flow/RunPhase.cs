namespace Delve.Flow;

/// <summary>
/// The screen the run is on. One phase is active at a time; <see cref="RunDirector"/> owns the
/// transitions and shows exactly one screen per phase (design/core_concept.md "Run flow").
/// </summary>
public enum RunPhase
{
    HeroSelect,
    Map,
    Combat,
    Event,
    Rest,
    ShortRest,
    RunEnd,
}
