namespace Delve.Combat;

/// <summary>UI-facing snapshot of one combatant for the turn-order strip. No engine types.</summary>
public sealed record UnitView
{
    public required string Name { get; init; }
    public int TeamId { get; init; }

    /// <summary>True for a party member. Team 1 is always the player's side.</summary>
    public bool IsAlly => TeamId == 1;

    public bool IsCurrent { get; init; }
    public bool IsDead { get; init; }
    public int Initiative { get; init; }

    /// <summary>Current/max HP for the chip's thin fill strip. Both 0 when unknown (Health-less).</summary>
    public int Hp { get; init; }
    public int MaxHp { get; init; }
}
