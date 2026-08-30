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
}
