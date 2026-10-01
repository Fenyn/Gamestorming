using System;
using System.Collections.Generic;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run.Events;

/// <summary>Read-only estimates. Never rolls dice or publishes potentially consuming rule events.</summary>
public static class EventCheckPreview
{
    public const string NoEffect = "No effect";

    public static string CheckLine(EventOption option, Party party, PF2eCharacter? selected)
    {
        if (option.Check is not { } check) return "No check required";
        var actor = EventResolver.ActorFor(party, check, selected);
        if (actor == null) return "Unavailable: nobody is standing to attempt this check.";
        int bonus = SkillCalculator.CalculateSkillBonus(actor, check.Skill);
        return $"{actor.Name} · {check.Skill} {bonus:+0;-0;0} · DC {check.Dc} · {SuccessPercent(bonus, check.Dc)}% base success";
    }

    /// <summary>One member's odds on an option's check, "+8 · 55%", so "Who tries?" is a
    /// comparison before any click. Empty when the option rolls nothing.</summary>
    public static string ActorForecast(EventOption option, PF2eCharacter actor)
    {
        if (option.Check is not { } check) return "";
        int bonus = SkillCalculator.CalculateSkillBonus(actor, check.Skill);
        return $"{bonus:+0;-0;0} · {SuccessPercent(bonus, check.Dc)}%";
    }

    /// <summary>Chance of a success or better on a d20, natural 1 and 20 shifts included.</summary>
    public static int SuccessPercent(int bonus, int dc)
    {
        int successes = 0;
        for (int die = 1; die <= 20; die++)
        {
            var degree = DegreeOfSuccessCalculator.Calculate(die, dc, bonus);
            if (degree is DegreeOfSuccess.Success or DegreeOfSuccess.CriticalSuccess) successes++;
        }
        return successes * 5;
    }

    public static string Details(EventOption option, Party party, PF2eCharacter? selected)
    {
        var actor = option.Check is { } check ? EventResolver.ActorFor(party, check, selected) : selected;
        var lines = new List<string>();
        if (option.Check is { } c && actor != null)
        {
            int bonus = SkillCalculator.CalculateSkillBonus(actor, c.Skill);
            var ability = SkillAbilities.GetAbility(c.Skill);
            int abilityBonus = actor.Stats.GetAbilityModifier(ability);
            var rank = SkillCalculator.GetProficiency(actor, c.Skill);
            int proficiency = ProficiencyCalculator.GetBonus(rank, actor.Stats.Level);
            int other = bonus - abilityBonus - proficiency;
            lines.Add($"{ability} {abilityBonus:+0;-0;0} · {rank} {proficiency:+0;-0;0}"
                + (other != 0 ? $" · equipment / conditions {other:+0;-0;0}" : ""));
        }
        lines.Add((option.Check == null ? "" : "Success: ") + Describe(option.Success));
        if (option.Check != null)
        {
            var critical = EventResolver.OutcomeFor(option, DegreeOfSuccess.CriticalSuccess);
            if (critical != option.Success) lines.Add("Critical success: " + Describe(critical));
            lines.Add("Failure: " + Describe(EventResolver.OutcomeFor(option, DegreeOfSuccess.Failure)));
            var criticalFailure = EventResolver.OutcomeFor(option, DegreeOfSuccess.CriticalFailure);
            if (criticalFailure != EventResolver.OutcomeFor(option, DegreeOfSuccess.Failure))
                lines.Add("Critical failure: " + Describe(criticalFailure));
        }
        return string.Join("\n", lines);
    }

    /// <summary>What an outcome does, as figures only. The outcome's prose stays unread until the
    /// party commits, as Slay the Spire shows an event's effects but not its ending.</summary>
    private static string Describe(EventOutcome outcome)
    {
        var effects = new List<string>();
        foreach (var effect in outcome.Effects)
        {
            string text = effect.Kind switch
            {
                EventEffectKind.HealFraction => $"Heal {effect.Value}% of maximum HP",
                EventEffectKind.Damage => $"{effect.Value} damage (cannot reduce below 1 HP)",
                EventEffectKind.WoundedDelta => $"Wounded {effect.Value:+0;-0;0}",
                EventEffectKind.GoldDelta => $"Gold {effect.Value:+0;-0;0}",
                EventEffectKind.WardDelta => $"Ward {effect.Value:+0;-0;0}",
                EventEffectKind.FreeRest => "Banks a free ten-minute rest",
                EventEffectKind.HealingPotion => $"Potions +{effect.Value}",
                EventEffectKind.HazardDamage => $"Damage, {effect.Value}% of maximum HP",
                EventEffectKind.RevealKinds => effect.Value switch
                {
                    0 => "Reveals the rooms next to this one",
                    1 => "Reveals the rooms next to every visited room",
                    _ => "Reveals every room on the floor",
                },
                EventEffectKind.PartyRefocus => $"Focus +{effect.Value} for every caster",
                EventEffectKind.RepairShields => effect.Value < 0 ? "2d6 damage less Hardness to the shield on the bench"
                    : effect.Value > 1 ? "Repair every damaged shield, doubled" : "Repair every damaged shield",
                EventEffectKind.CacheGold => "Gold for the party's level",
                _ => "",
            };
            if (text.Length > 0) effects.Add(text);
        }
        return effects.Count > 0 ? string.Join("; ", effects) : NoEffect;
    }
}
