using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>
/// UI-facing snapshot of what the action bar should show for the current ally. Pure Delve data.
/// Movement has no button: it lives on the board as the Idle-mode bands.
/// </summary>
public sealed record ActionBarState
{
    public int ActionsRemaining { get; init; }
    public int MaxActions { get; init; } = 3;
    public bool CanStrike { get; init; }
    public bool CanRaiseShield { get; init; }
    /// <summary>Delay is open: nothing done yet this turn and someone still acts after the actor.</summary>
    public bool CanDelay { get; init; }
    public int Map { get; init; }
    public string ActorName { get; init; } = "";

    /// <summary>Active actor's vitals, rendered next to the name (e.g. "HP 18/24  AC 17").</summary>
    public int Hp { get; init; }
    public int MaxHp { get; init; }
    public int Ac { get; init; }
    public string Resources { get; init; } = "";

    /// <summary>Reasons a disabled button is disabled ("No actions remaining", "No targets in
    /// reach", ...), null when the button is enabled. Rules-derived in ActionBarStateBuilder —
    /// the action bar only renders them as TooltipText.</summary>
    public string? StrikeDisabledReason { get; init; }
    public string? ShieldDisabledReason { get; init; }
    public string? DelayDisabledReason { get; init; }

    /// <summary>Castable spells / cost-variants for the dynamic chip row (empty for non-casters).</summary>
    public IReadOnlyList<SpellEntryView> SpellEntries { get; init; } = System.Array.Empty<SpellEntryView>();

    /// <summary>Castable skill actions for the dynamic chip row.</summary>
    public IReadOnlyList<SkillEntryView> SkillEntries { get; init; } = System.Array.Empty<SkillEntryView>();
}
