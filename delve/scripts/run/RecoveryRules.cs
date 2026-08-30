namespace Delve.Run;

/// <summary>
/// Every healing number the run layer uses, in one record. RAW placeholders for the skeleton: the
/// Treat Wounds DC tier, its dice, and the night's-rest formula all move here when they get tuned.
/// </summary>
public sealed record RecoveryRules
{
    /// <summary>Trained-tier Treat Wounds DC. <c>dcOverride</c> beats it in spikes and tests.</summary>
    public int TreatWoundsDc { get; init; } = 15;

    /// <summary>Die size for every Treat Wounds roll.</summary>
    public int TreatWoundsDie { get; init; } = 8;

    /// <summary>Dice healed on a critical success.</summary>
    public int TreatWoundsCritSuccessDice { get; init; } = 4;

    /// <summary>Dice healed on a success.</summary>
    public int TreatWoundsSuccessDice { get; init; } = 2;

    /// <summary>Dice of damage on a critical failure.</summary>
    public int TreatWoundsCritFailureDice { get; init; } = 1;

    /// <summary>HP a stabilized or crit-failed character can never drop below out of combat.</summary>
    public int HpFloor { get; init; } = 1;

    /// <summary>Minimum HP per level healed by a night's rest, used when the Con modifier is lower.</summary>
    public int LongRestMinHealPerLevel { get; init; } = 1;

    /// <summary>Focus points a Refocus block restores to each member with a focus pool.</summary>
    public int RefocusPoints { get; init; } = 1;
}
