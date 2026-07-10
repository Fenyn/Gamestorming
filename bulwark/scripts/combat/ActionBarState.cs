using System.Collections.Generic;

namespace Bulwark.Combat;

/// <summary>
/// UI-facing snapshot of what the action bar should show for the current ally. Pure Bulwark data.
/// </summary>
public sealed record ActionBarState
{
    public int ActionsRemaining { get; init; }
    public int MaxActions { get; init; } = 3;
    public bool CanMove { get; init; }
    public bool CanStep { get; init; }
    public bool CanStrike { get; init; }
    public bool CanRaiseShield { get; init; }
    public int Map { get; init; }
    public PlayerTurnMode Mode { get; init; }
    public string ActorName { get; init; } = "";

    /// <summary>Castable spells / cost-variants for the dynamic chip row (empty for non-casters).</summary>
    public IReadOnlyList<SpellEntryView> SpellEntries { get; init; } = System.Array.Empty<SpellEntryView>();

    /// <summary>Castable skill actions for the dynamic chip row.</summary>
    public IReadOnlyList<SkillEntryView> SkillEntries { get; init; } = System.Array.Empty<SkillEntryView>();
}
