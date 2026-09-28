using System.Collections.Generic;

namespace Delve.Combat;

/// <summary>
/// UI-facing snapshot of an attack, spell or skill forecast. Pure Delve data.
///
/// The <c>*Text</c> fields and <see cref="Figures"/> are BESTIARY-MASKED by their builders: until
/// Recall Knowledge reveals the target's defence, defender-derived numbers read "?" while
/// everything the attacker owns stays visible. The decision slot draws <see cref="Figures"/>,
/// <see cref="Tags"/> and <see cref="Modifiers"/>; the sentences in <see cref="OutcomeText"/> and <see cref="DetailText"/>
/// are the hover.
/// </summary>
public sealed record AttackPreviewView
{
    public string? HeaderText { get; init; }
    public string? OutcomeText { get; init; }
    public string? DetailText { get; init; }
    public required string AttackerName { get; init; }
    public required string TargetName { get; init; }
    public required string WeaponName { get; init; }
    public int TotalAttackBonus { get; init; }
    public string DamageFormula { get; init; } = "";

    /// <summary>Target AC as drawn: "15", or "?" when unknown.</summary>
    public string TargetAcText { get; init; } = "";

    /// <summary>Hit chance as drawn: "60%", or "?%" when the target's AC is unknown.</summary>
    public string HitChanceText { get; init; } = "";

    /// <summary>Crit chance as drawn: "5%", or "?%" when the target's AC is unknown.</summary>
    public string CritChanceText { get; init; } = "";

    /// <summary>Labelled numbers: "Hit 65%", "Crit 10%", "Damage 1d8+4".</summary>
    public IReadOnlyList<FigureView> Figures { get; init; } = System.Array.Empty<FigureView>();

    /// <summary>Short facts drawn as tags: "Reflex DC 20", "Basic save", "Opening Strike".</summary>
    public IReadOnlyList<string> Tags { get; init; } = System.Array.Empty<string>();

    /// <summary>Every non-zero modifier that moves the odds, signed by its effect on the actor:
    /// "MAP -5", "Off-guard (Prone) +2", "Frightened 1 -1".</summary>
    public IReadOnlyList<ModifierChip> Modifiers { get; init; } = System.Array.Empty<ModifierChip>();
}
