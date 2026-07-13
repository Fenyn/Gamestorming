using System;
using System.Collections.Generic;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents.Features;
using PF2e.Utilities;

namespace Bulwark.Cozy;

/// <summary>
/// Out-of-combat Treat Wounds (PF2e Player Core, pack actions/skill/treat-wounds.json). Plain C#:
/// GameState owns the single instance and wraps <see cref="TreatWounds"/> in a command; the squad
/// panel renders the view-models this class builds and never touches engine types.
///
/// RAW contract implemented here:
///  - 10 minutes treating one injured living creature ("targeting yourself, if you so choose" —
///    self-treatment is legal, so healer == target passes validation).
///  - The target is then temporarily immune to Treat Wounds for 1 hour, "but this interval overlaps
///    with the time you spent treating" — the expiry anchors to the treatment START (a patient can
///    be treated once per hour, not once per 70 minutes). Immunity applies on EVERY outcome; the
///    action text has no crit-failure extension ("the damage dealt on a critical failure remains
///    the same" refers to the higher-DC tiers). Battle Medicine's separate in-combat immunity is
///    engine-side and deliberately not coupled to this clock.
///  - DC tiers gate on Medicine proficiency (engine <see cref="TreatWoundsResolver"/>: Trained 15,
///    Expert 20, Master 30, Legendary 40); the healer-aware Resolve overload applies the Medic
///    Dedication +5/+10/+15 rider.
///
/// Immunity is tracked as absolute game-clock minutes (day + minute via <see cref="DayClock"/>)
/// so it survives day rollover, and round-trips through the save as an additive field.
/// </summary>
public sealed class TreatWoundsSystem
{
    /// <summary>RAW: "You spend 10 minutes treating one injured living creature."</summary>
    public const int TreatMinutes = 10;

    /// <summary>RAW: "temporarily immune to Treat Wounds actions for 1 hour".</summary>
    public const int ImmunityMinutes = 60;

    /// <summary>Role: conditions worth surfacing on the panel (the shared attrition whitelist).</summary>
    private static readonly Condition[] NotableConditions = AttritionConditions.LongTerm;

    private readonly SquadRoster _squad;
    private readonly DayClock _clock;

    /// <summary>
    /// Phase-4 Infirmary seam: an ADDITIVE healing bonus (0-default) read from the building-effect
    /// aggregator (<see cref="OutpostEffects.InfirmaryHealingBonus"/>). Injected as a provider so the
    /// system stays pure and the bonus is always the current aggregated value. Null → baseline 0, so
    /// with no infirmary the heal is byte-identical to today.
    /// </summary>
    private readonly Func<int> _healingBonus;

    /// <summary>Per-target immunity expiry, in absolute game minutes.</summary>
    private readonly Dictionary<string, long> _immunityExpiry = new();

    /// <summary>Raised after a Treat Wounds command resolves (GameState re-exposes it to UI).</summary>
    public event Action<TreatWoundsResultView>? Resolved;

    public TreatWoundsSystem(SquadRoster squad, DayClock clock, Func<int>? healingBonus = null)
    {
        _squad = squad;
        _clock = clock;
        _healingBonus = healingBonus ?? (static () => 0);
    }

    // ===================== Command =====================

    /// <summary>
    /// Validate and execute one Treat Wounds: healer and target alive, DC within the healer's
    /// proficiency tiers, target injured or Wounded and not immune. Spends 10 game-minutes, resolves
    /// through the engine, applies the outcome to the live member, records the RAW immunity window,
    /// and raises <see cref="Resolved"/>. Returns false (no time spent) when validation fails.
    /// </summary>
    public bool TreatWounds(string healerId, string targetId, int dc)
    {
        var healer = _squad.FindMember(healerId);
        var target = _squad.FindMember(targetId);
        if (healer?.Health == null || healer.Health.IsDead)
            return false;
        if (target?.Health == null || target.Health.IsDead)
            return false;
        if (Array.IndexOf(GetAvailableDCs(healerId), dc) < 0)
            return false;
        if (!IsTreatableTarget(target))
            return false;
        if (IsImmune(targetId))
            return false;

        // Expiry anchors to the treatment start: the 1-hour immunity overlaps the 10 minutes spent.
        long expiresAt = AbsoluteMinute(_clock) + ImmunityMinutes;
        _clock.SpendTime(TreatMinutes);

        int bonus = SkillCalculator.CalculateSkillBonus(healer, Skill.Medicine);
        var result = TreatWoundsResolver.Resolve(bonus, dc, healer);

        // Phase-4 Infirmary bonus: additive, and only on a HEAL (positive) — crit-failure damage is
        // untouched. Baseline (no infirmary) adds 0, so the applied amount is byte-identical.
        int applied = result.HealingOrDamage;
        if (applied > 0)
            applied += Math.Max(0, _healingBonus());

        _squad.ApplyTreatWoundsResult(targetId, applied, result.RemovedWounded);
        _immunityExpiry[targetId] = expiresAt;

        Resolved?.Invoke(new TreatWoundsResultView
        {
            HealerName = healer.Name,
            TargetName = target.Name,
            Dc = result.DC,
            D20Roll = result.D20Roll,
            Total = result.Total,
            DegreeText = DegreeText(result.Degree),
            HealingOrDamage = applied,
            HealingFormula = result.HealingFormula ?? "",
            RemovedWounded = result.RemovedWounded,
            MinutesSpent = TreatMinutes,
            ImmunityMinutesRemaining = ImmunityMinutesRemaining(targetId),
        });
        return true;
    }

    // ===================== Queries =====================

    /// <summary>DC tiers the member can attempt as healer (empty when untrained or missing).</summary>
    public int[] GetAvailableDCs(string memberId)
    {
        var member = _squad.FindMember(memberId);
        if (member?.Health == null || member.Health.IsDead)
            return Array.Empty<int>();
        return TreatWoundsResolver.GetAvailableDCs(
            SkillCalculator.GetProficiency(member, Skill.Medicine));
    }

    public bool IsImmune(string memberId) => ImmunityMinutesRemaining(memberId) > 0;

    /// <summary>Game-minutes of immunity left; 0 when expired (expired entries are pruned).</summary>
    public int ImmunityMinutesRemaining(string memberId)
    {
        if (!_immunityExpiry.TryGetValue(memberId, out long expiresAt))
            return 0;

        long remaining = expiresAt - AbsoluteMinute(_clock);
        if (remaining <= 0)
        {
            _immunityExpiry.Remove(memberId);
            return 0;
        }
        return (int)remaining;
    }

    /// <summary>Build the full squad-panel view-model (see <see cref="SquadPanelView"/>).</summary>
    public SquadPanelView BuildPanelView()
    {
        var view = new SquadPanelView();
        int bestBonus = int.MinValue;

        foreach (var member in _squad.Members)
        {
            var health = member.Health;
            bool dead = health == null || health.IsDead;
            int immuneLeft = ImmunityMinutesRemaining(member.Id);
            int bonus = dead ? 0 : SkillCalculator.CalculateSkillBonus(member, Skill.Medicine);

            var options = new List<DcOptionView>();
            foreach (int dc in GetAvailableDCs(member.Id))
                options.Add(new DcOptionView { Dc = dc, SuccessFormula = SuccessFormula(member, dc) });

            view.Members.Add(new SquadMemberView
            {
                Id = member.Id,
                Name = member.Name,
                CurrentHp = health?.CurrentHP ?? 0,
                MaxHp = health?.MaxHP ?? 0,
                IsDead = dead,
                ConditionsText = ConditionsText(member),
                ImmunityMinutesRemaining = immuneLeft,
                CanBeTreated = !dead && immuneLeft == 0 && IsTreatableTarget(member),
                MedicineBonus = bonus,
                DcOptions = options,
            });

            // Default healer: highest Medicine bonus among living members who can attempt a DC.
            if (!dead && options.Count > 0 && bonus > bestBonus)
            {
                bestBonus = bonus;
                view.DefaultHealerId = member.Id;
            }
        }
        return view;
    }

    // ===================== Save bridge =====================

    /// <summary>Snapshot the still-active immunity windows (expired entries are dropped).</summary>
    public List<TreatWoundsImmunityDto> CaptureImmunities()
    {
        var result = new List<TreatWoundsImmunityDto>();
        long now = AbsoluteMinute(_clock);
        foreach (var (memberId, expiresAt) in _immunityExpiry)
        {
            if (expiresAt > now)
                result.Add(new TreatWoundsImmunityDto { MemberId = memberId, ExpiresAtMinute = expiresAt });
        }
        return result;
    }

    /// <summary>Overwrite immunity state from a save (null = pre-Treat-Wounds save = none).</summary>
    public void RestoreImmunities(List<TreatWoundsImmunityDto>? immunities)
    {
        _immunityExpiry.Clear();
        if (immunities == null)
            return;
        foreach (var dto in immunities)
        {
            if (!string.IsNullOrEmpty(dto.MemberId))
                _immunityExpiry[dto.MemberId] = dto.ExpiresAtMinute;
        }
    }

    // ===================== Internals =====================

    /// <summary>
    /// Absolute game minute since the calendar epoch (Year 1, Spring 1, midnight). Monotonic
    /// (non-decreasing) across day rollover: MinuteOfDay runs 6:00–30:00, so day N's 30:00
    /// (N·1440 + 1800) equals day N+1's 6:00 exactly — the clock never goes backwards, and the
    /// expiry comparisons (remaining &lt;= 0 expired, expiresAt &gt; now kept) behave at the
    /// boundary: immunity anchored before a rollover keeps its full RAW hour, no more, no less.
    /// </summary>
    public static long AbsoluteMinute(DayClock clock)
    {
        long dayIndex = (((long)clock.Year - 1) * 4 + (int)clock.Season) * DayClock.DaysPerSeason
            + (clock.Day - 1);
        return dayIndex * 24 * 60 + clock.MinuteOfDay;
    }

    /// <summary>RAW target gate: "one injured living creature" — hurt, or carrying Wounded.</summary>
    private static bool IsTreatableTarget(ICharacter target)
    {
        var health = target.Health;
        if (health == null || health.IsDead)
            return false;
        bool injured = health.CurrentHP < health.MaxHP;
        bool wounded = target.Conditions?.HasCondition(Condition.Wounded) ?? false;
        return injured || wounded;
    }

    /// <summary>Success-tier healing formula with the Medic Dedication rider, e.g. "2d8+10 (+5)".</summary>
    private static string SuccessFormula(ICharacter healer, int dc)
    {
        int flat = TreatWoundsResolver.GetFlatBonus(dc);
        int rider = MedicDedicationFeature.GetBonusHealing(healer, dc, DegreeOfSuccess.Success);
        string formula = flat > 0 ? $"2d8+{flat}" : "2d8";
        return rider > 0 ? $"{formula} (+{rider})" : formula;
    }

    private static string ConditionsText(ICharacter member)
    {
        var conds = member.Conditions;
        if (conds == null)
            return "";

        var parts = new List<string>();
        foreach (var condition in NotableConditions)
        {
            if (!conds.HasCondition(condition))
                continue;
            int value = conds.GetConditionValue(condition);
            parts.Add(value > 0 ? $"{condition} {value}" : condition.ToString());
        }
        return string.Join(", ", parts);
    }

    private static string DegreeText(DegreeOfSuccess degree) => degree switch
    {
        DegreeOfSuccess.CriticalSuccess => "Critical Success",
        DegreeOfSuccess.Success => "Success",
        DegreeOfSuccess.CriticalFailure => "Critical Failure",
        _ => "Failure",
    };
}
