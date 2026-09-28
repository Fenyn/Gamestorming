using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>UI-facing snapshot of one combatant for the turn-order strip. No engine types.</summary>
public sealed record UnitView
{
    public required string Name { get; init; }

    /// <summary>Encounter letter of an enemy ("A"), empty for allies.</summary>
    public string Letter { get; init; } = "";

    /// <summary>The name without the letter, for chips that draw the letter as a badge.</summary>
    public string BaseName { get; init; } = "";
    /// <summary>Engine UniqueId, carried so a chip click can name its combatant without engine types.</summary>
    public int Id { get; init; }
    public int TeamId { get; init; }

    /// <summary>True for a party member. Team 1 is always the player's side.</summary>
    public bool IsAlly => TeamId == 1;

    public bool IsCurrent { get; init; }
    public bool IsDead { get; init; }

    /// <summary>Waiting out a Delay. Shown at the slot the combatant returns to.</summary>
    public bool IsDelayed { get; init; }

    /// <summary>Offered as a Delay slot: the chip takes a click.</summary>
    public bool IsPickable { get; init; }
    public int Initiative { get; init; }

    /// <summary>Current/max HP for the chip's thin fill strip. Both 0 when unknown (Health-less).</summary>
    public int Hp { get; init; }
    public int MaxHp { get; init; }

    /// <summary>Active conditions, most urgent first.</summary>
    public IReadOnlyList<ConditionMarkView> Conditions { get; init; } = System.Array.Empty<ConditionMarkView>();
}
