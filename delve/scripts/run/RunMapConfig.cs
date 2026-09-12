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
    /// Target number of optional Wayfarer nodes per floor tree. Placement varies by seed and
    /// uses spare Combat/Event nodes on branching rows after Lair and Campsite minimums are met.
    /// Small maps without eligible branches may contain fewer meetings.
    /// </summary>
    public int MinMeetingsPerFloor { get; init; } = 1;
    public int MaxMeetingsPerFloor { get; init; } = 2;
}
