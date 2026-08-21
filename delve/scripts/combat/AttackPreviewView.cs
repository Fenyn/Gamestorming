namespace Delve.Combat;

/// <summary>
/// UI-facing snapshot of an attack preview. Pure Delve data — deliberately carries no PF2e
/// engine types so it can be consumed by passive Control scripts.
///
/// The three <c>*Text</c> lines are BESTIARY-MASKED by <c>PlayerTurnController.BuildPreview</c>:
/// until Recall Knowledge reveals the target species' AC, the defender-derived numbers (target AC,
/// hit chance, crit chance) read "?" while everything the attacker owns — weapon, attack bonus,
/// damage formula, the off-guard tag — stays visible. The raw numbers stay on the record for
/// non-UI consumers; the Control renders the text.
/// </summary>
public sealed record AttackPreviewView
{
    public required string AttackerName { get; init; }
    public required string TargetName { get; init; }
    public required string WeaponName { get; init; }
    public int Map { get; init; }
    public int TotalAttackBonus { get; init; }
    public int TargetAc { get; init; }
    public int HitChancePercent { get; init; }
    public int CritChancePercent { get; init; }
    public string DamageFormula { get; init; } = "";
    public bool TargetOffGuard { get; init; }

    /// <summary>False while the target species' AC is still unknown — the three lines below are masked.</summary>
    public bool TargetAcKnown { get; init; } = true;

    /// <summary>Target AC as drawn: "15", or "?" when unknown.</summary>
    public string TargetAcText { get; init; } = "";

    /// <summary>Hit chance as drawn: "60%", or "?%" when the target's AC is unknown.</summary>
    public string HitChanceText { get; init; } = "";

    /// <summary>Crit chance as drawn: "5%", or "?%" when the target's AC is unknown.</summary>
    public string CritChanceText { get; init; } = "";
}
