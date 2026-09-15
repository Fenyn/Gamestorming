using System;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Reactions;
using PF2e.Utilities;

namespace Delve.Rules;

// The engine's ally-reaction discovery currently searches adjacent allies. Keep that limitation
// explicit in the sheet until the core exposes a configurable protection radius.
public sealed class JusticeReaction : CharacterFeature, IDamageReaction
{
    public JusticeReaction()
    {
        FeatureId="retributive-strike"; DisplayName="Retributive Strike"; Category=FeatureCategory.ClassFeature;
        Description="React to damage against an adjacent ally: resist 2 + your level, then Strike the attacker if within melee reach. Current engine protection radius: 5 feet.";
    }
    public bool CanProtectAlly => true;
    public int ReactionPriority => 5;
    public bool CanReact(ICharacter reactor,ICharacter source,DamageResult damage) =>
        reactor.Health.IsAlive && reactor.Actions.ReactionAvailable && reactor.Conditions?.AreReactionsBlocked()!=true &&
        source!=null && source.TeamId!=reactor.TeamId && FlankingCalculator.IsWithinReach(reactor.GridPosition,reactor.TileWidth,source.GridPosition,source.TileWidth,3);
    public bool ShouldAIUse(ICharacter reactor,ICharacter source,DamageResult damage) => true;
    public ReactionPromptInfo GetPromptInfo(ICharacter reactor,DamageResult damage) => new()
    { Title="Retributive Strike",Description=$"Prevent up to {2+reactor.StatProvider.Level} damage to your ally; retaliate if the attacker is in reach." };
    public void Execute(ICharacter reactor,ICharacter source,DamageResult damage)
    {
        if (!reactor.Actions.TryConsumeReaction()) return;
        int reduction=Math.Min(damage.TotalDamage,2+reactor.StatProvider.Level);
        damage.TotalDamage-=reduction;
        if (damage.TypedDamageBreakdown!=null)
        {
            int remaining=reduction;
            foreach (var key in new System.Collections.Generic.List<DamageType>(damage.TypedDamageBreakdown.Keys))
            { int amount=Math.Min(remaining,damage.TypedDamageBreakdown[key]); damage.TypedDamageBreakdown[key]-=amount; remaining-=amount; }
        }
        if (FlankingCalculator.IsWithinReach(reactor.GridPosition,reactor.TileWidth,source.GridPosition,source.TileWidth,1))
            ReactionSuspension.Track(StrikeResolver.ExecuteStrike(reactor,source,new StrikeAction(),actionName:"Retributive Strike",mapOverride:0,suppressMapAccrual:true));
    }
}
