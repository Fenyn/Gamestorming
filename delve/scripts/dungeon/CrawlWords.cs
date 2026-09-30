using System;
using System.Collections.Generic;
using Delve.Run.Events;

namespace Delve.Dungeon;

/// <summary>Everything a floor's crawl says on screen, and the landmarks its beats look for. One row
/// per floor id in <see cref="CrawlWordsTable"/>.</summary>
public sealed record CrawlWords
{
    public required IReadOnlyDictionary<RoomPurpose, string> Names { get; init; }
    public required IReadOnlyDictionary<StationHistory, string> Accounts { get; init; }

    /// <summary>What a quiet room shows before its options.</summary>
    public required Func<RoomPurpose, StationHistory, string> Body { get; init; }

    public required Func<RoomPurpose, StationHistory, IReadOnlyList<EventOption>> Scenes { get; init; }

    public required string NewRoomKicker { get; init; }
    public required string UnexploredTitle { get; init; }
    public required string ProgressLabel { get; init; }

    /// <summary>What each crossing is, for the ward tooltip: "doorway" or "trail".</summary>
    public required string CrossingNoun { get; init; }

    public required string GoalFind { get; init; }
    public required string GoalDefeat { get; init; }
    public required string GoalLeave { get; init; }

    public required string ExitAction { get; init; }
    public required string ExitTip { get; init; }
    public required string ExitBlockedTip { get; init; }
    public required string FloorComplete { get; init; }

    /// <summary>The line shown while the party arrives on this floor from the one above.</summary>
    public required string ArrivalCaption { get; init; }

    /// <summary>Prop the guardian's reveal focuses on, and the prop the party leaves by.</summary>
    public required string RevealProp { get; init; }
    public required string ExitProp { get; init; }

    /// <summary>Prop at the entrance's outer mouth that shows where the party came from.</summary>
    public required string ArrivalProp { get; init; }

    public string Name(RoomPurpose purpose) => Names.TryGetValue(purpose, out var name) ? name : purpose.ToString();
    public string Account(StationHistory history) => Accounts[history];
}
