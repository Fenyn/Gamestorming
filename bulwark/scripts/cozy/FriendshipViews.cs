using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// Friendship-panel view-model (engine-free per CLAUDE.md): one row per befriendable, PRESENT
/// character plus the carried gift options, built by <see cref="FriendshipSystem.BuildView"/> and
/// served through GameState.GetFriendshipView.
/// </summary>
public sealed class FriendshipView
{
    public List<FriendshipCharacterView> Characters { get; } = new();

    /// <summary>Every carried stack, as a gift option (the panel's near-a-villager gift flow).</summary>
    public List<GiftOptionView> GiftableItems { get; } = new();
}

/// <summary>One befriendable, present character's friendship status.</summary>
public sealed class FriendshipCharacterView
{
    public required string CharacterId { get; init; }
    public required string DisplayName { get; init; }
    public int Points { get; init; }
    public int Hearts { get; init; }
    public int MaxHearts { get; init; }
    public int GiftsGivenThisWeek { get; init; }
    public int GiftsPerWeek { get; init; }
    public bool TalkedToday { get; init; }
    public bool IsBirthdayToday { get; init; }
    public bool Romanceable { get; init; }
}

/// <summary>A carried stack offered in the gift flow.</summary>
public sealed class GiftOptionView
{
    public required string ItemId { get; init; }
    public required string DisplayName { get; init; }
    public int Count { get; init; }
}
