using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Rules;

/// <summary>Per-character spell action. Class damage bonuses never mutate a canonical preset or
/// another caster's preparation. Normal engine casting still owns targeting, saves, costs and slots.</summary>
internal sealed class NativeSpell : SpellCastAction
{
    private readonly string _class;
    private bool _executing;
    internal NativeSpell(SpellCastAction source,string name)
    {
        _class=name;
        SpellId=source.SpellId; ActionName=source.ActionName; Description=source.Description;
        ActionCostCount=source.ActionCostCount; Traits=source.Traits; Area=source.Area;
        TargetMode=source.TargetMode; RequiresTarget=source.RequiresTarget; CanTargetSelf=source.CanTargetSelf;
        MaxTargets=source.MaxTargets; RequiresAreaTarget=source.RequiresAreaTarget; AllowDuplicateTargets=source.AllowDuplicateTargets;
        // Spell definitions remain immutable. Only this action's pointer is swapped for one cast.
        Spell=source.Spell;
    }
    public override Task ExecuteAsync(ICharacter actor,ICharacter target=null!) => WithBonus(actor,()=>base.ExecuteAsync(actor,target));
    public override Task ExecuteMultiTargetAsync(ICharacter actor,List<ICharacter> targets) => WithBonus(actor,()=>base.ExecuteMultiTargetAsync(actor,targets));
    public override Task ExecuteAreaAsync(ICharacter actor,AreaTargetResult area) => WithBonus(actor,()=>base.ExecuteAreaAsync(actor,area));
    protected override void OnSpellEffectApplied(ICharacter caster,ICharacter target,DegreeOfSuccess degree)
    {
        base.OnSpellEffectApplied(caster,target,degree);
        Delve.Data.UtilityCantrips.ApplyRider(SpellId,caster,target,degree);
    }
    private async Task WithBonus(ICharacter actor,Func<Task> execute)
    {
        if (_executing) { await execute(); return; } // self-centered casts delegate to ExecuteArea
        _executing=true;
        var original=Spell;
        var originalVariant=ActiveVariant;
        try
        {
            int rank=Spell.GetEffectiveLevel(actor.StatProvider.Level);
            if (!Spell.IsCantrip && !Spell.IsFocusSpell)
                for (int r=Spell.SpellLevel;r<=9;r++)
                    if (actor.Spellcasting.GetCurrentSlots(r)>0) { rank=r; break; }
            int bonus=_class=="Sorcerer" && !Spell.IsCantrip && !Spell.IsFocusSpell ? rank :
                _class=="Psychic" && WayfarerFeature.State(actor).PsycheTurns>0 ? 2*rank : 0;
            if (bonus>0)
            {
                Spell=WithFlatBonus(original,bonus,_class=="Sorcerer");
                if (originalVariant!=null) ActiveVariant=VariantWithBonus(originalVariant,bonus,_class=="Sorcerer");
            }
            await execute();
        }
        finally { Spell=original; ActiveVariant=originalVariant; _executing=false; }
    }
    private static SpellCostVariant VariantWithBonus(SpellCostVariant v,int value,bool healing) => new()
    {
        Label=v.Label,ActionCost=v.ActionCost,HealingFormula=healing?Add(v.HealingFormula,value):v.HealingFormula,
        DamageFormula=Add(v.DamageFormula,value),HeightenBonusFlat=v.HeightenBonusFlat,HeightenBonusDamage=v.HeightenBonusDamage,
        RangeInFeet=v.RangeInFeet,MaxTargets=v.MaxTargets,TargetNoun=v.TargetNoun,AllowDuplicateTargets=v.AllowDuplicateTargets,
        TargetMode=v.TargetMode,CanTargetSelf=v.CanTargetSelf,IsAreaEffect=v.IsAreaEffect,IsSelfCentered=v.IsSelfCentered,
        Area=v.Area,ChannelDualEffect=v.ChannelDualEffect,ChannelDamageType=v.ChannelDamageType,
    };
    private static DiceFormula? Add(DiceFormula? formula,int value) => formula==null ? null : new(formula.NumberOfDice,formula.DieSize,formula.Modifier+value);
    private static SpellDefinition WithFlatBonus(SpellDefinition s,int value,bool healing) => new()
    {
        Identity=s.Identity,SpellLevel=s.SpellLevel,IsFocusSpell=s.IsFocusSpell,Traditions=s.Traditions,
        DefenseType=s.DefenseType,SaveType=s.SaveType,DamageType=s.DamageType,DamageFormula=Add(s.DamageFormula,value),
        HealingFormula=healing?Add(s.HealingFormula,value):s.HealingFormula,BonusFlatHealing=s.BonusFlatHealing,
        DamageOnCritSuccess=s.DamageOnCritSuccess,DamageOnSuccess=s.DamageOnSuccess,DamageOnFailure=s.DamageOnFailure,DamageOnCritFailure=s.DamageOnCritFailure,
        HeightenIncrement=s.HeightenIncrement,HeightenBonusDamage=s.HeightenBonusDamage,HeightenBonusHealing=s.HeightenBonusHealing,HeightenBonusFlatValue=s.HeightenBonusFlatValue,
        ConditionEffect=s.ConditionEffect,Duration=s.Duration,DurationValue=s.DurationValue,SustainEffect=s.SustainEffect,CostVariants=s.CostVariants,
    };
}
