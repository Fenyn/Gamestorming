using System;
using System.Collections.Generic;

namespace Delve.Run;

/// <summary>
/// Every tunable of the run map in one record (design/core_concept.md: numbers live in code
/// records, not in the doc). Weights are relative and only apply to the free middle floors.
/// </summary>
public sealed record RunMapConfig
{
    /// <summary>Rows including the boss floor. Needs at least 3 (entrance, campsite, boss).</summary>
    public int Floors { get; init; } = 8;

    /// <summary>Columns a node may occupy.</summary>
    public int Lanes { get; init; } = 5;

    /// <summary>Upward walks traced through the grid. More walks means a wider, busier map.</summary>
    public int Paths { get; init; } = 4;

    public int CombatWeight { get; init; } = 5;
    public int EventWeight { get; init; } = 3;
    public int RestWeight { get; init; } = 2;
    public int EliteWeight { get; init; } = 1;

    /// <summary>Earliest floor an Elite may appear on.</summary>
    public int MinEliteFloor { get; init; } = 3;

    /// <summary>
    /// Earliest floor a Rest may appear on. Below this the party has not spent enough HP, slots or
    /// focus for a night's rest to be worth a node, so an early Campsite is a dead pick.
    /// </summary>
    public int MinRestFloor { get; init; } = 3;

    /// <summary>
    /// Elites the map must hold. The weighted roll alone leaves a large share of maps with no Elite
    /// at all, so the generator promotes nodes until it reaches this count.
    /// </summary>
    public int MinElites { get; init; } = 1;

    /// <summary>Rests the map must hold on the free floors, on top of the forced pre-boss Campsite.</summary>
    public int MinMidRests { get; init; } = 1;

    /// <summary>
    /// Rows taken whole by <see cref="NodeKind.Meeting"/>, one entry per stratum. A whole row, the way
    /// row 0 is Combat, so every path hits it: party size is a guarantee, not a lane. The default
    /// fills slot 2 on the run's second node, slot 3 just before floor 1's Campsite, slot 4 early on
    /// floor 2. Rows 3 and 4 stay free: the Elite and Rest top-up passes need somewhere to land.
    /// </summary>
    public IReadOnlyList<IReadOnlyList<int>> MeetingFloorsByStratum { get; init; } =
        new IReadOnlyList<int>[]
        {
            new[] { 1, 5 },
            new[] { 1 },
            Array.Empty<int>(),
        };

    /// <summary>Meeting rows for a stratum. Empty past the end of the table.</summary>
    public IReadOnlyList<int> MeetingFloorsFor(int stratum)
        => stratum >= 0 && stratum < MeetingFloorsByStratum.Count
            ? MeetingFloorsByStratum[stratum]
            : Array.Empty<int>();
}
