using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Presets;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Utilities;

namespace Delve.Rules;

public sealed class RosterFeatAction : BaseAction
{
    public static readonly string[] Ids=["intimidating-strike","reach-spell","renewed-vigor","hunters-aim","deadly-aim","spell-parry","root-to-life","reinforce-eidolon","advanced-weaponry","psi-strikes"];
    public string Id { get; }
    public int Range => Id is "hunters-aim" or "deadly-aim" ? 24 : Id=="advanced-weaponry"?24:Id is "root-to-life" or "intimidating-strike"?1:0;
    public bool Ally => Id=="root-to-life";
    public RosterFeatAction(string id)
    {
        Id=id; ActionName=id=="advanced-weaponry"?"Eidolon Slash":RosterFeats.Name(id);
        ActionCostCount=id is "hunters-aim" or "intimidating-strike"?2:id=="psi-strikes"?0:1;
        IsFreeAction=ActionCostCount==0; RequiresTarget=Range>0; TargetMode=Ally?TargetMode.Allies:TargetMode.Enemies;
        CanTargetSelf=Ally; Traits=new TraitCollection();
        if (id is "hunters-aim" or "reach-spell" or "spell-parry" or "psi-strikes")
            Traits.AddTrait(new TraitDefinition { TraitId="concentrate",DisplayName="Concentrate" });
        if (id is "hunters-aim" or "deadly-aim" or "advanced-weaponry" or "intimidating-strike")
            Traits.AddTrait(new TraitDefinition { TraitId="attack",DisplayName="Attack" });
        Description=id switch
        {
            "intimidating-strike"=>"Two actions: make a melee Strike. A hit frightens the foe (1 on success, 2 on a critical success).",
            "hunters-aim"=>"Two actions: a ranged Strike against your hunted prey with +2 circumstance to the attack. Ignores lesser cover.",
            "deadly-aim"=>"One action: a ranged Strike against your hunted prey at -2 to hit and +4 circumstance damage (+6 at level 11).",
            "renewed-vigor"=>"While raging, gain temporary HP equal to half level + Constitution, or level + Constitution if you attacked this turn.",
            "spell-parry"=>"With a free hand, gain +1 circumstance AC and saves against targeted spells until your next turn.",
            "root-to-life"=>"One action: stabilize an adjacent dying ally at 0 HP. The ally remains unconscious.",
            "reinforce-eidolon"=>"One action: your eidolon gains +1 status AC and saves, and resistance to all damage equal to half spell rank, until your next turn. Replaces Boost Eidolon.",
            "psi-strikes"=>"Free action after casting or unleashing: your wielded weapon gains 1d6 force damage this turn, or until your active psyche subsides. Once per turn.",
            "advanced-weaponry"=>"Your eidolon Strikes with its stone fist's versatile slashing option.",
            _=>"One action: your next spell gains 30 feet of range (touch becomes 30 feet).",
        };
    }
    public override bool CanPerform(ICharacter c,ICharacter target=null!)
    {
        if (!RosterFeats.Has(c,Id) || !base.CanPerform(c,target)) return false;
        var s=FeatEncounter.State(c);
        if (target!=null && (target.TeamId==c.TeamId)!=Ally) return false;
        if (Id=="root-to-life") return target==null || target.Health.DyingSystem?.IsDying()==true && !target.Health.IsDead && FlankingCalculator.IsWithinReach(c.GridPosition,c.TileWidth,target.GridPosition,target.TileWidth,1);
        if (target!=null && !target.Health.IsAlive) return false;
        if (target!=null && Id!="advanced-weaponry" && Range>0 && AreaCalculator.GetPF2eDistance(c.GridPosition,c.TileWidth,target.GridPosition,target.TileWidth)>Range) return false;
        return Id switch
        {
            "intimidating-strike"=>WeaponAttackCalculator.ResolveWeapon(c).IsMelee,
            "renewed-vigor"=>WayfarerFeature.State(c).Raging,
            "hunters-aim" or "deadly-aim"=>!WeaponAttackCalculator.ResolveWeapon(c).IsMelee && WayfarerFeature.State(c).Prey!=null && (target==null || WayfarerFeature.State(c).Prey==target),
            "spell-parry"=>!s.Parrying && c.Appendages?.HasFreeHand==true,
            "advanced-weaponry"=>EidolonLink.For(c)?.CanStrike(target)==true,
            "reinforce-eidolon"=>EidolonLink.For(c)?.CanAct==true && !s.Reinforced,
            "psi-strikes"=>!s.PsiUsed && (s.LastSpellSequence==c.Combat.ActionSequence || WayfarerFeature.State(c).PsycheTurns>0 && c.Combat.ActionSequence==s.UnleashSequence),
            "reach-spell"=>!SpellReach.Pending(c) && c.Spellcasting!=null,
            _=>true,
        };
    }
    public override void Execute(ICharacter c,ICharacter target=null!)=>ReactionSuspension.Track(ExecuteAsync(c,target));
    public override async Task ExecuteAsync(ICharacter c,ICharacter target=null!)
    {
        if (!CanPerform(c,target) || RequiresTarget && target==null || !TryConsumeCost(c)) return;
        var s=FeatEncounter.State(c);
        switch(Id)
        {
            case "intimidating-strike":
                await StrikeResolver.ExecuteStrike(c,target,this,onHit:hit=>target.Conditions.AddCondition(ConditionDatabase.Instance.Frightened,hit.Degree==DegreeOfSuccess.CriticalSuccess?2:1,source:c)); break;
            case "reach-spell": s.ReachSequence=c.Combat.ActionSequence; s.ReachActions=c.Actions.TotalActionsRemaining; break;
            case "renewed-vigor":
                c.Health.GrantTempHP((c.Combat.AttacksMadeThisTurn>0?c.StatProvider.Level:c.StatProvider.Level/2)+(c.Stats.Constitution-10)/2,WayfarerFeature.State(c)); break;
            case "root-to-life": target.Health.DyingSystem.Stabilize(); break;
            case "spell-parry": s.Parrying=true; Buff(c,s.BuffId,StatType.AC,1,ModifierType.Circumstance); break;
            case "reinforce-eidolon":
                WayfarerFeature.State(c).ClearBuffs();
                s.Reinforced=true; var eidolon=EidolonLink.For(c)!.Eidolon;
                eidolon.Modifiers.RemoveModifier(s.BuffId);
                Buff(eidolon,s.BuffId,StatType.AC,1,ModifierType.Status);
                foreach(var stat in new[]{StatType.Fortitude,StatType.Reflex,StatType.Will}) Buff(eidolon,s.BuffId,stat,1,ModifierType.Status);
                break;
            case "psi-strikes": s.PsiStrikes=true; s.PsiUsed=true; s.PsiTurns=s.Turn; s.PsiUnleashed=WayfarerFeature.State(c).PsycheTurns>0; s.PsiWeapon=WeaponAttackCalculator.ResolveWeapon(c); break;
            case "hunters-aim": case "deadly-aim":
                s.Aiming=Id=="hunters-aim"; s.DeadlyAim=Id=="deadly-aim";
                var aimId=Guid.NewGuid();
                if(s.DeadlyAim) Buff(c,aimId,StatType.DamageDealt,c.StatProvider.Level>=15?8:c.StatProvider.Level>=11?6:4,ModifierType.Circumstance);
                try { await StrikeResolver.ExecuteStrike(c,target,this,maxCoverLevel:Id=="hunters-aim" && CoverHelper.GetEffectiveCoverLevel(c,target)==CoverLevel.Lesser?CoverLevel.None:null); }
                finally { c.Modifiers.RemoveModifier(aimId); s.Aiming=s.DeadlyAim=false; }
                break;
            case "advanced-weaponry":
                var link=EidolonLink.For(c)!; var weapon=WeaponAttackCalculator.ResolveWeapon(link.Eidolon).WeaponDef;
                var damage=weapon.DamageType;
                try { weapon.DamageType=DamageType.Slashing; await link.Strike(target,this); }
                finally { weapon.DamageType=damage; }
                break;
        }
    }
    internal static void Buff(ICharacter c,Guid id,StatType stat,int value,ModifierType type)=>c.Modifiers.AddModifier(new ConditionModifier { Source="Class feat",SourceInstanceId=id,TargetStat=stat,Value=value,Type=type });
}
