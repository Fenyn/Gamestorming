using System;
using Delve.Presets;
using PF2e.CharacterComponents;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Run;

/// <summary>
/// The two out-of-combat healing steps of a run: the post-fight stabilize contract and the Campsite
/// night's rest. No permadeath - only a full wipe ends a run, so a downed or slain member walks off
/// the field at 1 HP carrying its Wounded value.
/// </summary>
public static class PartyRecovery
{
    /// <summary>
    /// Post-fight cleanup for every member (design/core_concept.md "After a fight"): per-turn state,
    /// temp HP, condition floors, non-persisting conditions and cooldowns are cleared; anyone at 0 HP
    /// is stabilized at 1 HP. Healing from 0 removes Dying, and the engine grants Wounded on that
    /// removal. A DEAD member is revived the same way, except that death cleared its conditions, so
    /// its Wounded is set explicitly - RAW still leaves you wounded.
    /// </summary>
    public static void CompleteEncounter(Party party, BattleResult result, RecoveryRules? rules = null)
    {
        var applied = rules ?? new RecoveryRules();
        foreach (var member in party.Members)
            Stabilize(member, applied);
    }

    private static void Stabilize(PF2eCharacter member, RecoveryRules rules)
    {
        // Per-turn combat state (MAP, flourish flags, strike follow-ups) must never leak into the
        // next fight; a mid-turn victory skips the TurnManager's normal EndTurn reset.
        member.Combat?.ResetTurnState();

        var health = member.Health;
        if (health == null)
            return;

        // Revive before healing: Health.Heal is a no-op while the permanent-death flag is set.
        bool wasDead = health.IsDead;
        if (wasDead)
            health.ClearPermanentDeath();

        health.ClearTempHP();

        if (health.CurrentHP <= 0)
            health.Heal(rules.HpFloor);

        var conditions = member.Conditions;
        if (conditions != null)
        {
            // Floors (Shatter Defenses) are combat effects that outlive their condition instance and
            // the engine cleanup below does not touch them, so sweep them all.
            foreach (Condition condition in Enum.GetValues(typeof(Condition)))
                conditions.ClearConditionFloor(condition);

            conditions.RemoveNonPersistingConditions();

            // A revived member never lost Dying (death cleared it), so the engine granted no Wounded.
            if (wasDead)
                EnsureWounded(conditions);
        }

        // Round cooldowns and per-encounter uses reset between fights; daily uses persist until rest.
        member.CooldownTracker?.ClearAll();
    }

    /// <summary>Wounded at 1 or its current value, whichever is higher.</summary>
    private static void EnsureWounded(ConditionTracker conditions)
    {
        var wounded = ConditionDatabase.Instance?.Wounded;
        if (wounded == null) return;

        if (conditions.GetConditionValue(wounded) < 1)
        {
            if (conditions.HasCondition(wounded))
                conditions.SetConditionValue(wounded, 1);
            else
                conditions.AddCondition(wounded, value: 1, duration: 0);
        }
    }

    /// <summary>
    /// A Campsite night's rest: heal <c>max(1, Con mod) x level</c> per member, clear Wounded, refresh
    /// the daily casting loadout, refill spell slots and focus points, then roll the day over and hand
    /// the short-rest budget back.
    /// </summary>
    public static void LongRest(
        Party party, DayClock clock, RecoveryRules? rules = null, Wardstone? wardstone = null)
    {
        var applied = rules ?? new RecoveryRules();
        foreach (var member in party.Members)
            RestMember(member, party.Level, applied);

        // The night under the ward recharges it in part (design/core_concept.md "Wardstone").
        wardstone?.RefillCampsite();
        clock.NewDay();
    }

    private static void RestMember(PF2eCharacter member, int partyLevel, RecoveryRules rules)
    {
        member.Combat?.ResetTurnState();

        var health = member.Health;
        if (health == null || health.IsDead)
            return;

        int level = member.Stats?.Level ?? partyLevel;
        int conMod = member.Stats?.GetAbilityModifier(AbilityScore.Constitution) ?? 0;
        int perLevel = Math.Max(rules.LongRestMinHealPerLevel, conMod);
        health.Heal(Math.Max(rules.LongRestMinHealPerLevel, perLevel * Math.Max(1, level)));

        var wounded = ConditionDatabase.Instance?.Wounded;
        if (wounded != null && member.Conditions != null && member.Conditions.HasCondition(wounded))
            member.Conditions.RemoveCondition(wounded);

        // Level-dependent daily decisions first (Spell Blending re-target, divine-font resize,
        // re-prepared loadout), then the pools they size.
        PresetCharacters.RefreshDailyCasting(member);

        var spellcasting = member.Spellcasting;
        if (spellcasting != null)
        {
            spellcasting.RefillSlots();
            spellcasting.RefillFocusPoints();
        }
    }
}
