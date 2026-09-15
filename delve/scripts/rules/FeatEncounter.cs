using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using Delve.Presets;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents.Features;
using PF2e.TurnManagement;

namespace Delve.Rules;

public static class FeatEncounter
{
    private static readonly ConditionalWeakTable<ICharacter,FeatState> States=new();
    public static FeatState State(ICharacter c)=>States.GetValue(c,_=>new());
    public static IDisposable Bind(ICharacter c,TurnManager turns)
    {
        var s=State(c); s.Clear(c); var epoch=s.Epoch=Guid.NewGuid();
        void Start(ICharacter actor)
        {
            if (actor!=c || s.Epoch!=epoch) return;
            foreach (var tumble in c.Features.ActiveFeatures.OfType<ScopedTumbleBehindFeat>()) tumble.OnRevoked(c,c.RuleEvents);
            if (!s.PsiUnleashed || WayfarerFeature.State(c).PsycheTurns<=0) s.PsiStrikes=false;
            s.Turn++; s.ReachSequence=-1; s.PsiUsed=false; s.Parrying=false;
            c.Modifiers.RemoveModifier(s.BuffId);
            EidolonLink.For(c)?.Eidolon.Modifiers.RemoveModifier(s.BuffId);
            s.Reinforced=false;
            if (RosterFeats.Has(c,"quick-shield-block")) c.Actions.GrantBonusReaction(BonusReactionType.ShieldBlock);
        }
        void Cast(ICharacter actor) { if (actor==c) s.LastSpellSequence=c.Combat.ActionSequence; }
        turns.OnTurnStart+=Start; SpellCastAction.OnSpellCasted+=Cast;
        return new Release(()=> { turns.OnTurnStart-=Start; SpellCastAction.OnSpellCasted-=Cast; if(s.Epoch==epoch)s.Clear(c); });
    }
    public static void Prepare(IReadOnlyList<ICharacter> team)
    {
        foreach (var scout in team.Where(c=>RosterFeats.Has(c,"scouts-warning")))
            foreach (var ally in team.Where(c=>c!=scout))
                ally.Modifiers.AddModifier(new ConditionModifier { Source="Scout's Warning",SourceInstanceId=State(ally).BuffId,TargetStat=StatType.Initiative,Type=ModifierType.Circumstance,Value=1 });
    }
    public static IDisposable MovementGuard(ICharacter c)
    {
        var id=Guid.NewGuid();
        if (RosterFeats.Has(c,"guarded-movement"))
            c.Modifiers.AddModifier(new ConditionModifier { Source="Guarded Movement",SourceInstanceId=id,TargetStat=StatType.AC,Type=ModifierType.Circumstance,Value=4 });
        return new Release(()=>c.Modifiers.RemoveModifier(id));
    }
    public static void Ward(ICharacter c,ICharacter target,DegreeOfSuccess degree)
    {
        var s=State(c); s.WardTarget=null; s.WardAC=s.WardSave=0;
        if (!RosterFeats.Has(c,"esoteric-warden") || degree<DegreeOfSuccess.Success || !s.WardedToday.Add(target.UniqueId)) return;
        s.WardTarget=target; s.WardAC=s.WardSave=degree==DegreeOfSuccess.CriticalSuccess?2:1;
    }
    public static bool SameAntithesis(ICharacter c,ICharacter target)
    {
        var prey=WayfarerFeature.State(c).Prey;
        if (prey==target) return true;
        return RosterFeats.Has(c,"sympathetic-vulnerabilities") && prey?.CreatureStats?.CreatureId is { Length:>0 } id &&
            target.CreatureStats?.CreatureId==id && prey.CreatureStats.Traits?.HasTraitById("humanoid")!=true;
    }
    private sealed class Release(Action dispose):IDisposable { public void Dispose()=>dispose(); }
}

public sealed class FeatState
{
    public Guid Epoch,BuffId=Guid.NewGuid();
    public int ReachActions;
    public int Turn,ReachSequence=-1,LastSpellSequence=-1,UnleashSequence=-1,PsiTurns;
    public bool Aiming,DeadlyAim,Parrying,Reinforced,PsiStrikes,PsiUsed,PsiUnleashed;
    public PF2e.Equipment.WeaponInstance? PsiWeapon;
    public ICharacter? WardTarget;
    public int WardAC,WardSave;
    public HashSet<int> WardedToday=new();
    public void Clear(ICharacter c)
    {
        c.Actions?.TryConsumeBonusReaction(BonusReactionType.ShieldBlock);
        c.Modifiers.RemoveModifier(BuffId); EidolonLink.For(c)?.Eidolon.Modifiers.RemoveModifier(BuffId);
        Turn=0; ReachSequence=LastSpellSequence=-1; Aiming=DeadlyAim=Parrying=Reinforced=PsiStrikes=PsiUsed=false;
        WardTarget=null; WardAC=WardSave=0; PsiWeapon=null; PsiUnleashed=false;
    }
}
