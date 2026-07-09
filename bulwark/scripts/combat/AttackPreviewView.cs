namespace Bulwark.Combat;

/// <summary>
/// UI-facing snapshot of an attack preview. Pure Bulwark data — deliberately carries no PF2e
/// engine types so it can be consumed by passive Control scripts.
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
}
