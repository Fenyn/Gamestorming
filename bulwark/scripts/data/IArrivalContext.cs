namespace Bulwark.Data;

/// <summary>
/// The read-only snapshot an <see cref="ArrivalTrigger"/> evaluates against — the small slice of
/// live game state a villager's arrival condition can read: building tiers (the Phase-2 build loop),
/// the bulwark story-flag set, and the calendar as an absolute day ordinal for date comparisons.
/// Deliberately engine- and Godot-free so triggers stay pure, declarative data. GameState implements
/// it directly; spikes stub it.
/// </summary>
public interface IArrivalContext
{
    /// <summary>Current tier of a building (0 = not commissioned). Mirrors GameState.GetBuildingTier.</summary>
    int GetBuildingTier(string buildingId);

    /// <summary>True once the given bulwark story flag has been set.</summary>
    bool HasStoryFlag(string flagId);

    /// <summary>Absolute day index for calendar comparisons (see <see cref="ArrivalTrigger.Ordinal"/>).</summary>
    int CurrentDayOrdinal { get; }
}
