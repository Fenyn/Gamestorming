using System.Collections.Generic;
using PF2e.Actions.SkillActions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run;

/// <summary>One Recall Knowledge attempt about a creature before the party meets it.</summary>
public sealed record StudyResult(string Actor, Skill Skill, int Total, int Dc, DegreeOfSuccess Degree,
    string Species, IReadOnlyList<CreatureKnowledgeField> Revealed);

/// <summary>
/// Recall Knowledge on the floor's guardian from the refuge (Player Core). The best member in the
/// creature's identification skill rolls against its level DC plus rarity, the same numbers the
/// in-fight action uses, and the journal takes the result as it would a combat Recall Knowledge.
/// </summary>
public static class GuardianStudy
{
    /// <summary>Recall Knowledge DC: the creature's level after its Elite (+1) or Weak (-1)
    /// adjustment, plus rarity.</summary>
    public static int Dc(EnemyDefinition creature, CreatureAdjustment adjustment = CreatureAdjustment.Normal)
    {
        int shift = adjustment switch { CreatureAdjustment.Elite => 1, CreatureAdjustment.Weak => -1, _ => 0 };
        return PF2eRules.GetDCByLevel(creature.StatBlock.CreatureLevel + shift) + RecallKnowledgeAction.GetRarityAdjustment(creature.CreatureTraits);
    }

    public static Skill SkillFor(EnemyDefinition creature) => PF2eRules.GetCreatureIdentificationSkill(creature.CreatureTraits);

    public static StudyResult? Study(Party party, EnemyDefinition creature, MonsterJournal journal,
        CreatureAdjustment adjustment = CreatureAdjustment.Normal)
    {
        var skill = SkillFor(creature);
        PF2eCharacter? best = null;
        int bestBonus = int.MinValue;
        foreach (var member in party.Living())
        {
            int bonus = SkillCalculator.CalculateSkillBonus(member, skill);
            if (bonus > bestBonus) { bestBonus = bonus; best = member; }
        }
        if (best == null) return null;
        int dc = Dc(creature, adjustment);
        var roll = SkillCheckResolver.ResolveVsDC(best, skill, dc, hasAttackTrait: false);
        journal.MarkEncountered(creature.CreatureId, creature.CreatureName);
        var revealed = journal.Reveal(creature.CreatureId, roll.Degree, creature.CreatureName);
        return new StudyResult(best.Name, skill, roll.Total, dc, roll.Degree, creature.CreatureName, revealed);
    }
}
