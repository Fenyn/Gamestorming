using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>One spendable resource on the action bar, drawn as a caption and a pip row.</summary>
public sealed record ResourcePipView(string Name, int Current, int Max);

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
    public bool HasShield { get; init; }
    /// <summary>Delay is open: nothing done yet this turn and the engine offers an anchor.</summary>
    public bool CanDelay { get; init; }
    public int Map { get; init; }
    public string ActorName { get; init; } = "";

    /// <summary>Hero sheet id for the bar portrait. Empty for a creature.</summary>
    public string ActorId { get; init; } = "";

    public int Hp { get; init; }
    public int MaxHp { get; init; }
    public int Ac { get; init; }

    /// <summary>Resources in words, for the pip row's hover.</summary>
    public string Resources { get; init; } = "";
    public IReadOnlyList<ResourcePipView> ResourcePips { get; init; } = System.Array.Empty<ResourcePipView>();

    /// <summary>Reasons a disabled button is disabled ("No actions remaining", "No targets in
    /// reach", ...), null when the button is enabled. Rules-derived in ActionBarStateBuilder —
    /// the action bar only renders them as TooltipText.</summary>
    public string? StrikeDisabledReason { get; init; }
    public string? ShieldDisabledReason { get; init; }
    public string? DelayDisabledReason { get; init; }

    /// <summary>True when Move has at least one reachable tile.</summary>
    public bool CanMove { get; init; }
    public string? MoveDisabledReason { get; init; }

    /// <summary>Why the move bands are limited or absent, for the hint line. Null when the actor
    /// may Stride.</summary>
    public string? MoveRestriction { get; init; }

    /// <summary>Castable spells / cost-variants for the dynamic chip row (empty for non-casters).</summary>
    public IReadOnlyList<SpellEntryView> SpellEntries { get; init; } = System.Array.Empty<SpellEntryView>();

    /// <summary>Castable skill actions for the dynamic chip row.</summary>
    public IReadOnlyList<SkillEntryView> SkillEntries { get; init; } = System.Array.Empty<SkillEntryView>();
}
