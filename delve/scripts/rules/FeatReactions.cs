using PF2e.Actions;
using PF2e.Core;
using PF2e.Events;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;
using PF2e.RuleEvents.Reactions;
using PF2e.Utilities;

namespace Delve.Rules;

public sealed class ScopedTumbleBehindFeat : TumbleBehindFeature
{
    // The base type's static success recorder is used by Tumble Through. The encounter owns
    // cleanup instead of subscribing to whichever TurnManager existed during character creation.
    public override void OnGranted(ICharacter c,RuleEventBus bus) { }
}

public sealed class DivineGraceFeat : CharacterFeature, ISaveReaction
{
    public bool CanReact(ICharacter c,BaseAction action) => action is SpellAction && c.Actions.ReactionAvailable && c.Conditions?.AreReactionsBlocked()!=true;
    public int GetSaveBonus(ICharacter c)=>2;
    public bool ShouldAIUse(ICharacter c,BaseAction action)=>true;
    public ReactionPromptInfo GetPromptInfo(ICharacter c,int bonus)=>new() { Title="Divine Grace",Description="+2 circumstance to this save against a spell.",Style=ReactionPromptStyle.YesNo };
    public void OnAccepted(ICharacter c)=>c.Actions.TryConsumeReaction();
}

/// <summary>Only movement triggers; it does not inherit Reactive Strike's manipulate/ranged triggers.</summary>
public sealed class StandStillFeat : CharacterFeature, IMovementReaction
{
    public int ReactionPriority=>0;
    public bool IsEligible(ICharacter c)=>c.Actions.ReactionAvailable && c.Conditions?.AreReactionsBlocked()!=true;
    public int GetReachTiles(ICharacter c)=>1;
    public bool ShouldAIUse(ICharacter c,ICharacter mover)=>true;
    public ReactionPromptInfo GetPromptInfo(ICharacter c,ICharacter mover)=>new() { Title="Stand Still",Style=ReactionPromptStyle.AttackPreview };
    public void Execute(ICharacter c,ICharacter mover,BeforeMoveEventArgs args)
    {
        if (!c.Actions.TryConsumeReaction()) return;
        ReactionStrikeBridge.Execute(c,mover,isReactiveStrike:true,onComplete:crit=> { if (crit) args.Cancelled=true; },onTargetKilled:()=>args.Cancelled=true);
    }
}
