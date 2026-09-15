using System;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.RuleEvents.Contexts;
using PF2e.Utilities;

namespace Delve.Rules;

internal static class StunningBlows
{
    internal static async Task Resolve(ICharacter actor,ICharacter target,BaseAction action)
    {
        int reaction=await ReactionEvents.CheckSaveReactions(target,action);
        int roll=DiceRoller.RollD20(),dc=StatsCalculator.CalculateClassDC(actor);
        var context=ModifierContext.Save(SavingThrow.Fortitude);
        int total=StatsCalculator.CalculateSave(target,SavingThrow.Fortitude,context);
        var save=new SavingThrowContext { Saver=target,Source=actor,SaveType=SavingThrow.Fortitude,D20Roll=roll,BaseSaveBonus=total,DC=dc,SourceAction=action };
        if (reaction>0) save.Modifiers.Add(ModifierType.Circumstance,reaction);
        target.RuleEvents.Publish(save);
        int stacked=target.Modifiers.GetModifierTotal(StatType.Fortitude,context);
        ModifierMergeHelper.InjectStackModifiers(target.Modifiers,StatType.Fortitude,context,save.Modifiers);
        var degree=DegreeOfSuccessCalculator.Calculate(roll,dc,total-stacked+save.Modifiers.Total);
        var adjusted=new DegreeAdjustmentContext { Actor=target,Reactor=actor,CheckType=DegreeCheckType.SavingThrow,SaveType=SavingThrow.Fortitude,SourceAction=action,OriginalDegree=degree,AdjustedDegree=degree };
        target.RuleEvents.Publish(adjusted); degree=adjusted.AdjustedDegree;
        if (target.StatProvider.Level>actor.StatProvider.Level && degree<DegreeOfSuccess.CriticalSuccess) degree++;
        if (degree<=DegreeOfSuccess.Failure)
            target.Conditions.AddCondition(ConditionDatabase.Instance.Stunned,degree==DegreeOfSuccess.CriticalFailure?3:1,source:actor);
        CombatLog.Emit($"Stunning Blows: {target.Name} Fortitude {roll+total-stacked+save.Modifiers.Total} vs DC {dc}: {degree}");
    }
}
