namespace Bulwark.Combat;

/// <summary>UI-facing snapshot of one combatant for the turn-order strip. No engine types.</summary>
public sealed record UnitView
{
    public required string Name { get; init; }
    public int TeamId { get; init; }
    public bool IsCurrent { get; init; }
    public bool IsDead { get; init; }
    public int Initiative { get; init; }
}
