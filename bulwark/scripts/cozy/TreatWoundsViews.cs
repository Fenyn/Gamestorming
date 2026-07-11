using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// View-model for the squad panel: everything the passive <c>SquadPanel</c> Control needs to render
/// the four members and drive the target → healer → DC flow. Built by
/// <see cref="TreatWoundsSystem.BuildPanelView"/> — engine types never cross this boundary.
/// </summary>
public sealed class SquadPanelView
{
    public List<SquadMemberView> Members { get; set; } = new();

    /// <summary>Preselected healer: the living member with the highest Medicine bonus.</summary>
    public string? DefaultHealerId { get; set; }
}

/// <summary>One squad member as the panel sees them: vitals, conditions, healer capability.</summary>
public sealed class SquadMemberView
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public int CurrentHp { get; set; }
    public int MaxHp { get; set; }
    public bool IsDead { get; set; }

    /// <summary>Comma-joined notable conditions ("Wounded 1, Fatigued"); empty when none.</summary>
    public string ConditionsText { get; set; } = "";

    /// <summary>Game-minutes of Treat Wounds immunity left; 0 when treatable.</summary>
    public int ImmunityMinutesRemaining { get; set; }

    /// <summary>Valid Treat Wounds target right now (alive, injured or Wounded, not immune).</summary>
    public bool CanBeTreated { get; set; }

    public int MedicineBonus { get; set; }

    /// <summary>DC tiers this member can attempt as the healer; empty when untrained or dead.</summary>
    public List<DcOptionView> DcOptions { get; set; } = new();
}

/// <summary>One selectable Treat Wounds DC tier with its success-healing formula.</summary>
public sealed class DcOptionView
{
    public int Dc { get; set; }

    /// <summary>Healing on a success, rider included — e.g. "2d8+10 (+5)" for a Medic at DC 20.</summary>
    public string SuccessFormula { get; set; } = "";
}

/// <summary>The outcome of one Treat Wounds command, shaped for the panel's result readout.</summary>
public sealed class TreatWoundsResultView
{
    public string HealerName { get; set; } = "";
    public string TargetName { get; set; } = "";
    public int Dc { get; set; }
    public int D20Roll { get; set; }
    public int Total { get; set; }
    public string DegreeText { get; set; } = "";

    /// <summary>Rolled result: positive = healing, negative = crit-fail damage, 0 = failure.</summary>
    public int HealingOrDamage { get; set; }

    /// <summary>Rolled formula ("2d8+10+5"); empty on a plain failure.</summary>
    public string HealingFormula { get; set; } = "";

    public bool RemovedWounded { get; set; }
    public int MinutesSpent { get; set; }

    /// <summary>Immunity minutes left on the target after this treatment.</summary>
    public int ImmunityMinutesRemaining { get; set; }
}
