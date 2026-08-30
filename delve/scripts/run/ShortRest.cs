using System;
using System.Collections.Generic;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run;

/// <summary>The ten-minute activities the whole party can take from the map between nodes.</summary>
public enum ShortRestKind
{
    TreatWounds,
    Refocus,
    RepairShield,
}

/// <summary>Outcome of one ten-minute block: what happened, in lines the UI can print.</summary>
public sealed class ShortRestResult
{
    public required ShortRestKind Kind { get; init; }

    /// <summary>False when the block was refused; <see cref="Reason"/> then says why.</summary>
    public required bool Performed { get; init; }

    /// <summary>Refusal reason, or null.</summary>
    public string? Reason { get; init; }

    /// <summary>Degree of success of the block's check, or null when it rolled none.</summary>
    public DegreeOfSuccess? Degree { get; init; }

    /// <summary>HP delta applied by the block. Negative on a Treat Wounds critical failure.</summary>
    public int HpChange { get; init; }

    /// <summary>Human-readable log lines.</summary>
    public IReadOnlyList<string> Lines { get; init; } = new List<string>();
}

/// <summary>
/// The short-rest table (CLAUDE.md: per-kind behaviour in one place). One call spends one
/// <see cref="DayClock"/> block and resolves one activity for the party.
///
/// Dice come from a <see cref="Random"/> seeded through <see cref="RunRng"/> on the clock's own
/// position in the day, so a spike replaying the same day gets the same dice, and forces a degree of
/// success through <c>dcOverride</c> rather than through the dice.
/// </summary>
public static class ShortRest
{
    public static ShortRestResult Perform(
        Party party,
        DayClock clock,
        ShortRestKind kind,
        PF2eCharacter? target,
        RecoveryRules rules,
        int? dcOverride = null,
        Wardstone? wardstone = null)
    {
        if (!clock.CanShortRest)
        {
            return new ShortRestResult
            {
                Kind = kind,
                Performed = false,
                Reason = "No time left today.",
            };
        }

        int block = clock.ShortRestsUsed;
        clock.SpendShortRest();
        // Rest under the ward costs ward (design/core_concept.md, "Wardstone"). A refused block
        // burns nothing - the refusal returned above.
        wardstone?.BurnShortRest();
        var rng = new Random(RunRng.StableSeed(clock.Day, block, "shortrest"));

        return kind switch
        {
            ShortRestKind.TreatWounds => TreatWounds(party, target, rules, dcOverride, rng),
            ShortRestKind.Refocus => Refocus(party, rules),
            ShortRestKind.RepairShield => RepairShield(party),
            _ => new ShortRestResult { Kind = kind, Performed = false, Reason = "Unknown activity." },
        };
    }

    // ---------------------------------- Treat Wounds ----------------------------------

    private static ShortRestResult TreatWounds(
        Party party, PF2eCharacter? target, RecoveryRules rules, int? dcOverride, Random rng)
    {
        var lines = new List<string>();
        var healer = BestMedic(party);
        var patient = target ?? MostWounded(party);

        if (healer == null || patient == null)
        {
            return new ShortRestResult
            {
                Kind = ShortRestKind.TreatWounds,
                Performed = false,
                Reason = "Nobody is standing to treat or be treated.",
            };
        }

        int dc = dcOverride ?? rules.TreatWoundsDc;
        var check = SkillCheckResolver.ResolveVsDC(healer, Skill.Medicine, dc, hasAttackTrait: false);
        lines.Add($"{healer.Name} treats {patient.Name}: Medicine {check.Total} vs DC {dc} ({check.Degree}).");

        int hpChange = 0;
        bool removeWounded = false;
        switch (check.Degree)
        {
            case DegreeOfSuccess.CriticalSuccess:
                hpChange = Roll(rng, rules.TreatWoundsCritSuccessDice, rules.TreatWoundsDie);
                removeWounded = true;
                break;
            case DegreeOfSuccess.Success:
                hpChange = Roll(rng, rules.TreatWoundsSuccessDice, rules.TreatWoundsDie);
                removeWounded = true;
                break;
            case DegreeOfSuccess.Failure:
                lines.Add("The wound will not close.");
                break;
            case DegreeOfSuccess.CriticalFailure:
                hpChange = -Roll(rng, rules.TreatWoundsCritFailureDice, rules.TreatWoundsDie);
                break;
        }

        var health = patient.Health;
        if (health != null && hpChange > 0)
        {
            int before = health.CurrentHP;
            health.Heal(hpChange);
            hpChange = health.CurrentHP - before;
            lines.Add($"{patient.Name} recovers {hpChange} HP.");
        }
        else if (health != null && hpChange < 0)
        {
            // Out of combat there is no dying pipeline to enter; the botch floors at 1 HP the same
            // way the post-fight stabilize does.
            int before = health.CurrentHP;
            health.SetCurrentHP(Math.Max(rules.HpFloor, before + hpChange));
            hpChange = health.CurrentHP - before;
            lines.Add($"{patient.Name} takes {-hpChange} damage from the botched treatment.");
        }

        if (removeWounded)
        {
            var wounded = ConditionDatabase.Instance?.Wounded;
            if (wounded != null && patient.Conditions != null && patient.Conditions.HasCondition(wounded))
            {
                patient.Conditions.RemoveCondition(wounded);
                lines.Add($"{patient.Name} is no longer wounded.");
            }
        }

        return new ShortRestResult
        {
            Kind = ShortRestKind.TreatWounds,
            Performed = true,
            Degree = check.Degree,
            HpChange = hpChange,
            Lines = lines,
        };
    }

    /// <summary>Living member with the highest Medicine bonus.</summary>
    private static PF2eCharacter? BestMedic(Party party)
    {
        PF2eCharacter? best = null;
        int bestBonus = int.MinValue;
        foreach (var member in party.Members)
        {
            if (member.Health == null || member.Health.IsDead) continue;
            int bonus = SkillCalculator.CalculateSkillBonus(member, Skill.Medicine);
            if (bonus > bestBonus) { bestBonus = bonus; best = member; }
        }
        return best;
    }

    /// <summary>Living member missing the most HP.</summary>
    private static PF2eCharacter? MostWounded(Party party)
    {
        PF2eCharacter? worst = null;
        int worstMissing = -1;
        foreach (var member in party.Members)
        {
            var health = member.Health;
            if (health == null || health.IsDead) continue;
            int missing = health.MaxHP - health.CurrentHP;
            if (missing > worstMissing) { worstMissing = missing; worst = member; }
        }
        return worst;
    }

    // ------------------------------------ Refocus ------------------------------------

    private static ShortRestResult Refocus(Party party, RecoveryRules rules)
    {
        var lines = new List<string>();
        foreach (var member in party.Members)
        {
            var casting = member.Spellcasting;
            if (member.Health == null || member.Health.IsDead) continue;
            if (casting == null || casting.MaxFocusPoints <= 0) continue;

            int restored = casting.RestoreFocusPoints(rules.RefocusPoints);
            lines.Add($"{member.Name}: focus {casting.CurrentFocusPoints}/{casting.MaxFocusPoints}"
                      + (restored > 0 ? $" (+{restored})" : " (already full)"));
        }
        if (lines.Count == 0)
            lines.Add("Nobody in the party has a focus pool.");

        return new ShortRestResult { Kind = ShortRestKind.Refocus, Performed = true, Lines = lines };
    }

    // ---------------------------------- Repair Shield ----------------------------------

    private static ShortRestResult RepairShield(Party party)
    {
        var lines = new List<string>();
        foreach (var member in party.Members)
        {
            var shield = member.Equipment?.Shield;
            if (member.Health == null || member.Health.IsDead) continue;
            if (shield?.EquippedShield == null) continue;

            shield.SetCurrentShieldHP(shield.MaxShieldHP);
            lines.Add($"{member.Name}: shield repaired to {shield.CurrentShieldHP}/{shield.MaxShieldHP}.");
        }
        if (lines.Count == 0)
            lines.Add("Nobody in the party carries a shield.");

        return new ShortRestResult { Kind = ShortRestKind.RepairShield, Performed = true, Lines = lines };
    }

    private static int Roll(Random rng, int dice, int sides)
    {
        int total = 0;
        for (int i = 0; i < dice; i++)
            total += rng.Next(1, sides + 1);
        return total;
    }
}
