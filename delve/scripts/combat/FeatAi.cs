using System.Linq;
using System.Threading.Tasks;
using Delve.Presets;
using Delve.Rules;
using PF2e.Core;

namespace Delve.Combat;

internal static class FeatAi
{
    internal static async Task Act(ICharacter actor,PlayerActionExecutor executor)
    {
        foreach(var id in new[]{"root-to-life","hunters-aim","deadly-aim","psi-strikes","renewed-vigor","spell-parry","reinforce-eidolon"})
        {
            if (!RosterFeats.Has(actor,id)) continue;
            var action=new RosterFeatAction(id);
            if (!action.CanPerform(actor)) continue;
            if (id=="renewed-vigor" && actor.Health.TempHP>=actor.StatProvider.Level/2+(actor.Stats.Constitution-10)/2) continue;
            if (id=="reinforce-eidolon" && actor.Health.HealthPercentage>0.5f) continue;
            if (action.Range==0) { await executor.ExecuteSelfSkill(actor,id); continue; }
            var target=CombatantQuery.TargetsInRange(actor,action.Range,!action.Ally).FirstOrDefault(t=>action.CanPerform(actor,t));
            if (target!=null) await executor.ExecuteSkillAction(actor,id,target.GridPosition);
        }
    }
}
