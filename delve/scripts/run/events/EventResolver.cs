using System;
using System.Linq;
using System.Collections.Generic;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run.Events;

/// <summary>What an event option did, in lines the UI can print.</summary>
public sealed class EventResult
{
    /// <summary>False when the option could not be resolved; <see cref="Reason"/> then says why.</summary>
    public required bool Resolved { get; init; }

    public string? Reason { get; init; }

    /// <summary>Degree of the option's check, or null when the option rolled none.</summary>
    public DegreeOfSuccess? Degree { get; init; }

    /// <summary>The member the check and the effects were applied to, or null.</summary>
    public PF2eCharacter? Actor { get; init; }

    public IReadOnlyList<string> Lines { get; init; } = new List<string>();
}

/// <summary>
/// Rolls an event option and applies its outcome. The actor is the caller's pick when the option
/// allows one, otherwise the living member with the best modifier in the checked skill. Effects hit
/// that member; gold lands on the <see cref="RunState"/>.
/// </summary>
public static class EventResolver
{
    public static EventResult Resolve(
        RunState state,
        EventDefinition definition,
        int optionIndex,
        PF2eCharacter? actor,
        int? dcOverride = null)
    {
        if (optionIndex < 0 || optionIndex >= definition.Options.Count)
            return new EventResult { Resolved = false, Reason = "No such option." };

        var option = definition.Options[optionIndex];
        var lines = new List<string>();

        if (option.Check == null)
        {
            // Explicit valid actor, otherwise a seeded choice among standing party members.
            var actorless = actor != null && state.Party.Members.Contains(actor) && actor.Health is { IsDead: false, CurrentHP: > 0 }
                ? actor : state.RandomMember("event-actor", livingOnly: true);
            Apply(state, actorless, option.Success, lines);
            return new EventResult { Resolved = true, Actor = actorless, Lines = lines };
        }

        var check = option.Check;
        var chosen = ActorFor(state.Party, check, actor);
        if (chosen == null)
            return new EventResult { Resolved = false, Reason = "Nobody is standing to attempt it." };

        int dc = dcOverride ?? check.Dc;
        var roll = SkillCheckResolver.ResolveVsDC(chosen, check.Skill, dc, hasAttackTrait: false);
        lines.Add($"{chosen.Name}: {check.Skill} {roll.Total} vs DC {dc} ({roll.Degree}).");

        var outcome = OutcomeFor(option, roll.Degree);
        Apply(state, chosen, outcome, lines);

        return new EventResult { Resolved = true, Degree = roll.Degree, Actor = chosen, Lines = lines };
    }

    /// <summary>Degree lookup with the documented fallbacks, so an option only authors what differs.</summary>
    public static EventOutcome OutcomeFor(EventOption option, DegreeOfSuccess degree) => degree switch
    {
        DegreeOfSuccess.CriticalSuccess => option.CriticalSuccess ?? option.Success,
        DegreeOfSuccess.Failure => option.Failure ?? option.Success,
        DegreeOfSuccess.CriticalFailure => option.CriticalFailure ?? option.Failure ?? option.Success,
        _ => option.Success,
    };

    public static PF2eCharacter? ActorFor(Party party, EventCheck check, PF2eCharacter? actor) =>
        check.AllowPickActor && actor != null && party.Members.Contains(actor)
            && actor.Health is { IsDead: false } ? actor : BestFor(party, check.Skill);

    private static void Apply(RunState state, PF2eCharacter? actor, EventOutcome outcome, List<string> lines)
    {
        if (!string.IsNullOrEmpty(outcome.Text))
            lines.Add(outcome.Text);

        foreach (var effect in outcome.Effects)
            ApplyEffect(state, actor, effect, lines);
    }

    private static void ApplyEffect(RunState state, PF2eCharacter? actor, EventEffect effect, List<string> lines)
    {
        switch (effect.Kind)
        {
            case EventEffectKind.Nothing:
                return;

            case EventEffectKind.GoldDelta:
                state.Gold += effect.Value;
                lines.Add(effect.Value >= 0 ? $"Gained {effect.Value} gold." : $"Lost {-effect.Value} gold.");
                return;

            case EventEffectKind.WardDelta:
            {
                int before = state.Wardstone.Ward;
                state.Wardstone.Adjust(effect.Value);
                lines.Add($"Ward {before} → {state.Wardstone.Ward}.");
                return;
            }

            case EventEffectKind.FreeRest:
                state.FreeRests++;
                lines.Add($"Free rests banked {state.FreeRests - 1} → {state.FreeRests}.");
                return;

            case EventEffectKind.HealingPotion:
                state.Potions += effect.Value;
                lines.Add($"Potions {state.Potions - effect.Value} → {state.Potions}.");
                return;

            case EventEffectKind.PartyRefocus:
                foreach (var member in state.Party.Living().Where(m => m.Spellcasting is { MaxFocusPoints: > 0 }))
                {
                    int restored = member.Spellcasting!.RestoreFocusPoints(effect.Value);
                    if (restored > 0) lines.Add($"{member.Name}: focus {member.Spellcasting.CurrentFocusPoints}/{member.Spellcasting.MaxFocusPoints}.");
                }
                return;

            case EventEffectKind.CacheGold:
            {
                int gold = TreasureByLevel.Scale(EventRewards.CacheGoldAtLevelOne, state.Party.Level);
                state.Gold += gold;
                lines.Add($"Gained {gold} gold.");
                return;
            }

            case EventEffectKind.RevealKinds:
                // The dungeon owns the floor plan and applies the reveal after the roll.
                return;
        }

        var health = actor?.Health;
        if (actor == null || health == null || health.IsDead)
            return;

        switch (effect.Kind)
        {
            case EventEffectKind.HealFraction:
            {
                int amount = Math.Max(1, health.MaxHP * effect.Value / 100);
                int before = health.CurrentHP;
                health.Heal(amount);
                lines.Add($"{actor.Name} recovers {health.CurrentHP - before} HP.");
                break;
            }

            case EventEffectKind.Damage:
            {
                // Events resolve on the map, outside the dying pipeline: the floor matches the
                // post-fight stabilize contract rather than dropping anyone to 0.
                int before = health.CurrentHP;
                health.SetCurrentHP(Math.Max(1, before - effect.Value));
                lines.Add($"{actor.Name} takes {before - health.CurrentHP} damage.");
                break;
            }

            case EventEffectKind.WoundedDelta:
                ApplyWounded(actor, effect.Value, lines);
                break;

            case EventEffectKind.HazardDamage:
            {
                int before = health.CurrentHP;
                health.SetCurrentHP(Math.Max(1, before - Math.Max(1, health.MaxHP * effect.Value / 100)));
                lines.Add($"{actor.Name}: HP {before} → {health.CurrentHP}.");
                break;
            }

            case EventEffectKind.RepairShields:
            {
                // Player Core Repair: 5 HP plus 5 per proficiency rank (trained 10, expert 15),
                // doubled on a critical success.
                var owners = state.Party.Living().Where(m => m.Equipment?.Shield?.EquippedShield != null).ToList();
                if (effect.Value < 0)
                {
                    // Critical failure: 2d6 damage, less Hardness, to the one shield on the bench,
                    // the most damaged.
                    var owner = owners.OrderBy(m => (double)m.Equipment!.Shield.CurrentShieldHP / m.Equipment.Shield.MaxShieldHP).FirstOrDefault();
                    if (owner == null) break;
                    var bench = owner.Equipment!.Shield;
                    var rng = new Random(RunRng.StableSeed(state.StratumSeed, state.CurrentNodeId ?? -1, "repair-slip"));
                    int damage = Math.Max(0, rng.Next(1, 7) + rng.Next(1, 7) - bench.EquippedShield!.Hardness);
                    int was = bench.CurrentShieldHP;
                    bench.SetCurrentShieldHP(Math.Max(0, was - damage));
                    lines.Add($"{owner.Name}'s shield {was} → {bench.CurrentShieldHP}.");
                    break;
                }
                int rank = (int)SkillCalculator.GetProficiency(actor, Skill.Crafting) / 2;
                int amount = (5 + 5 * rank) * Math.Max(1, effect.Value);
                foreach (var owner in owners)
                {
                    var shield = owner.Equipment!.Shield;
                    if (shield.CurrentShieldHP >= shield.MaxShieldHP) continue;
                    int before = shield.CurrentShieldHP;
                    shield.SetCurrentShieldHP(Math.Min(shield.MaxShieldHP, before + amount));
                    lines.Add($"{owner.Name}'s shield {before} → {shield.CurrentShieldHP}.");
                }
                break;
            }
        }
    }

    private static void ApplyWounded(PF2eCharacter actor, int delta, List<string> lines)
    {
        var conditions = actor.Conditions;
        var wounded = ConditionDatabase.Instance?.Wounded;
        if (conditions == null || wounded == null || delta == 0) return;

        int value = conditions.GetConditionValue(wounded) + delta;
        if (value <= 0)
        {
            if (conditions.HasCondition(wounded))
            {
                conditions.RemoveCondition(wounded);
                lines.Add($"{actor.Name} is no longer wounded.");
            }
            return;
        }

        if (conditions.HasCondition(wounded))
            conditions.SetConditionValue(wounded, value);
        else
            conditions.AddCondition(wounded, value: value, duration: 0);
        lines.Add($"{actor.Name} is wounded {value}.");
    }

    /// <summary>Living member with the best bonus in a skill.</summary>
    private static PF2eCharacter? BestFor(Party party, Skill skill)
    {
        PF2eCharacter? best = null;
        int bestBonus = int.MinValue;
        foreach (var member in party.Members)
        {
            if (member.Health == null || member.Health.IsDead) continue;
            int bonus = SkillCalculator.CalculateSkillBonus(member, skill);
            if (bonus > bestBonus) { bestBonus = bonus; best = member; }
        }
        return best;
    }
}
