using System.Linq;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run;

/// <summary>One Identify Magic attempt to attune the Wardstone to a fallen guardian's ward engine.</summary>
public sealed record AttunementResult(string Actor, Skill Skill, int Total, int Dc, DegreeOfSuccess Degree, int RefillPercent);

/// <summary>
/// After a floor's guardian falls, the party's best trained Identify Magic skill (Arcana, Nature,
/// Occultism or Religion, Player Core) rolls against the DC of the guardian's level, as Identify
/// Magic keys on what is identified. The degree sets the share of missing ward the stone regains
/// (<see cref="WardstoneRules"/>). With no trained member the stone takes the plain refill.
/// </summary>
public static class WardAttunement
{
    private static readonly Skill[] MagicSkills = { Skill.Arcana, Skill.Nature, Skill.Occultism, Skill.Religion };

    public static int RefillPercent(DegreeOfSuccess degree, WardstoneRules rules) => degree switch
    {
        DegreeOfSuccess.CriticalSuccess => rules.BossRefillCriticalPercent,
        DegreeOfSuccess.CriticalFailure => rules.BossRefillFumblePercent,
        _ => rules.BossRefillPercent,
    };

    public static AttunementResult? Roll(Party party, Wardstone ward, int guardianLevel)
    {
        var pick = party.Living()
            .SelectMany(m => MagicSkills.Select(s => (Member: m, Skill: s)))
            .Where(p => SkillCalculator.GetProficiency(p.Member, p.Skill) >= ProficiencyLevel.Trained)
            .Select(p => (p.Member, p.Skill, Bonus: SkillCalculator.CalculateSkillBonus(p.Member, p.Skill)))
            .OrderByDescending(p => p.Bonus).FirstOrDefault();
        if (pick.Member == null)
        {
            ward.RefillAfterBoss();
            return null;
        }
        int dc = PF2eRules.GetDCByLevel(guardianLevel);
        var roll = SkillCheckResolver.ResolveVsDC(pick.Member, pick.Skill, dc, hasAttackTrait: false);
        int percent = RefillPercent(roll.Degree, ward.Rules);
        ward.RefillAfterBoss(percent);
        return new AttunementResult(pick.Member.Name, pick.Skill, roll.Total, dc, roll.Degree, percent);
    }
}
