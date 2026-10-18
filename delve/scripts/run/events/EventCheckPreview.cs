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

    public const string NoRoll = "No roll";
    public const string NobodyCanTry = "Nobody is standing to try";

    /// <summary>The option's chance at a glance: "Elara 55%" for whoever would try, or "No roll".</summary>
    public static string ChanceLine(EventOption option, Party party, PF2eCharacter? selected)
    {
        if (option.Check is not { } check) return NoRoll;
        var actor = EventResolver.ActorFor(party, check, selected);
        if (actor == null) return NobodyCanTry;
        return $"{actor.Name} {SuccessPercent(SkillCalculator.CalculateSkillBonus(actor, check.Skill), check.Dc)}%";
    }

    /// <summary>"Thievery · DC 18", or "No roll".</summary>
    public static string CheckCaption(EventOption option) => option.Check is { } check ? $"{check.Skill} · DC {check.Dc}" : NoRoll;

    /// <summary>Where a member's bonus comes from, "Thievery +8: Dexterity +4 · Trained +4", for a hover.</summary>
    public static string Breakdown(EventOption option, PF2eCharacter actor)
    {
        if (option.Check is not { } check) return "";
        int bonus = SkillCalculator.CalculateSkillBonus(actor, check.Skill);
        var ability = SkillAbilities.GetAbility(check.Skill);
        int abilityBonus = actor.Stats.GetAbilityModifier(ability);
        var rank = SkillCalculator.GetProficiency(actor, check.Skill);
        int proficiency = ProficiencyCalculator.GetBonus(rank, actor.Stats.Level);
        int other = bonus - abilityBonus - proficiency;
        return $"{actor.Name}: {check.Skill} {bonus:+0;-0;0} vs DC {check.Dc}\n{ability} {abilityBonus:+0;-0;0} · {rank} {proficiency:+0;-0;0}"
            + (other != 0 ? $" · equipment / conditions {other:+0;-0;0}" : "")
            + "\nThe chance counts natural 1s and 20s.";
    }

    /// <summary>What each degree of the option does, as captioned figures: the critical rows only
    /// where they differ from the plain ones, and a single row for an option with no roll.</summary>
    public static IReadOnlyList<(string Caption, string Effects)> Outcomes(EventOption option)
    {
        if (option.Check == null) return new[] { ("Result", Describe(option.Success)) };
        var rows = new List<(string, string)>();
        var critical = EventResolver.OutcomeFor(option, DegreeOfSuccess.CriticalSuccess);
        if (critical != option.Success) rows.Add(("Critical success", Describe(critical)));
        rows.Add(("Success", Describe(option.Success)));
        var failure = EventResolver.OutcomeFor(option, DegreeOfSuccess.Failure);
        rows.Add(("Failure", Describe(failure)));
        var criticalFailure = EventResolver.OutcomeFor(option, DegreeOfSuccess.CriticalFailure);
        if (criticalFailure != failure) rows.Add(("Critical failure", Describe(criticalFailure)));
        return rows;
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
                EventEffectKind.Damage => $"{effect.Value} damage, never below 1 HP",
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
