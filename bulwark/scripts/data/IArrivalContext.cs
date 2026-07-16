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

    /// <summary>
    /// The party's total CURRENT count of an item — every member's carry plus the outpost warehouse,
    /// regardless of the scene mode a trigger happens to be evaluated in (mirrors
    /// <see cref="Bulwark.Cozy.Inventory.CountEverywhere"/>, not the mode-gated <c>Inventory.Count</c>).
    /// Powers <see cref="ArrivalTrigger.ItemCountReached"/>.
    /// </summary>
    int CountItem(string itemId);

    /// <summary>
    /// A character's current friendship heart level (0 when unknown / never befriended / the
    /// friendship system is unavailable). Mirrors <c>FriendshipSystem.HeartsOf</c> — no decay, so
    /// hearts only ever rise and a threshold comparison is monotonic. Powers
    /// <see cref="ArrivalTrigger.FriendshipReached"/>.
    /// </summary>
    int HeartsOf(string characterId);
}
