using System;
using System.Collections.Generic;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using Ungilded.Combat;

namespace Ungilded.Tutorial;

/// <summary>
/// Turns an intended degree of success into the d20 that produces it, so an encounter script can
/// say "this strike hits" without picking numbers by hand. The roll is the middle of the d20
/// values that give the degree once natural 1 and 20 are applied: a plain hit sits clear of the
/// crit band. Bonuses are read when called, so call right before the action.
/// </summary>
internal static class TutorialDice
{
    internal static int ForStrike(ICharacter attacker, ICharacter target, DegreeOfSuccess degree)
    {
        var ctx = AttackResolver.PreviewStrike(attacker, target,
            creatureStrikeIndex: StrikeActions.CreatureStrikeIndex(attacker));
        return ForCheck(ctx.EffectiveBonus, ctx.TargetAC, degree);
    }

    internal static int ForSkill(ICharacter actor, ICharacter target, string actionId, DegreeOfSuccess degree)
    {
        if (SkillActions.ResolveOwnedAction(actor, actionId) is not SkillActionBase skill)
            throw new ArgumentException($"'{actionId}' is not a skill check action of {actor.Name}.", nameof(actionId));
        var check = CombatPreviewCalculator.CalculateSkillCheckPreview(actor, target, skill);
        return ForCheck(check.TotalBonus, check.DC, degree);
    }

    /// <summary>The middle d20 that gives the degree. Throws when no d20 can, for example a
    /// critical failure against a DC the modifier always beats by 10.</summary>
    internal static int ForCheck(int modifier, int dc, DegreeOfSuccess degree)
    {
        var rolls = new List<int>();
        for (int d20 = 1; d20 <= 20; d20++)
            if (DegreeOfSuccessCalculator.Calculate(d20, dc, modifier) == degree) rolls.Add(d20);
        if (rolls.Count == 0)
            throw new InvalidOperationException($"No d20 gives {degree} at {modifier:+0;-0;0} against DC {dc}.");
        return rolls[(rolls.Count - 1) / 2];
    }
}
