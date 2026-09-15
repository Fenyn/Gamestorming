using System.Linq;
using System.Threading.Tasks;
using Delve.Rules;
using PF2e.Core;

namespace Delve.Combat;

internal static class ClassAi
{
    internal static async Task Act(ICharacter actor,PlayerActionExecutor executor)
    {
        var feature=WayfarerFeature.Find(actor);
        if (feature==null) { await FeatAi.Act(actor,executor); return; }
        var state=WayfarerFeature.State(actor);
        string[] sequence=feature.Class switch
        {
            "Champion"=>["lay-on-hands"], "Witch"=>["clinging-ice"], "Monk"=>["flurry-of-blows"],
            "Ranger"=>["hunt-prey"], "Druid"=>["cornucopia"], "Magus"=>state.SpellstrikeReady?["spellstrike"]:["dimensional-assault","recharge-spellstrike"],
            "Oracle"=>["weapon-trance"],
            "Thaumaturge"=>["chalice","exploit-vulnerability"], "Bard"=>["courageous-anthem"],
            "Psychic"=>["unleash-psyche","amped-daze"], "Swashbuckler"=>["braggarts-boast","confident-finisher"],
            "Summoner"=>["eidolon-advance","act-together","eidolon-strike"], "Sorcerer"=>["elemental-toss"], _=>[],
        };
        foreach (string id in sequence)
        {
            var action=new ClassAction(ClassActions.All.Single(a=>a.Id==id));
            if (action.Spec.Range==0)
            {
                if (action.CanPerform(actor)) await executor.ExecuteSelfSkill(actor,id);
                continue;
            }
            var targets=CombatantQuery.TargetsInRange(actor,action.Spec.Range,!action.Spec.Ally)
                .Where(t=>action.CanPerform(actor,t));
            if (action.Spec.Ally) targets=targets.Where(t=>t.Health.CurrentHP<t.Health.MaxHP/2);
            var target=targets.OrderBy(t=>action.Spec.Ally?t.Health.HealthPercentage:PF2e.Utilities.AreaCalculator.GetPF2eDistance(actor.GridPosition,actor.TileWidth,t.GridPosition,t.TileWidth)).FirstOrDefault();
            if (target!=null) await executor.ExecuteSkillAction(actor,id,target.GridPosition);
        }
        await FeatAi.Act(actor,executor);
    }
}
