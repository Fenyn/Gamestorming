using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Data;

internal static class UtilityCantrips
{
    internal static SpellCastAction Get(string id)
    {
        bool hymn=id=="feat-haunting-hymn", timber=id=="feat-timber",acid=id=="feat-caustic-blast";
        bool area=hymn||timber||acid;
        return new FeatCantrip(id)
        {
            SpellId=id,ActionName=hymn?"Haunting Hymn":timber?"Timber":acid?"Caustic Blast":"Void Warp",ActionCostCount=2,
            RequiresTarget=!area,RequiresAreaTarget=area,TargetMode=TargetMode.Enemies,
            Traits=new TraitCollection(new[] {new TraitDefinition { TraitId="concentrate",DisplayName="Concentrate" },new TraitDefinition { TraitId="manipulate",DisplayName="Manipulate" },new TraitDefinition { TraitId=hymn?"auditory":timber?"wood":acid?"acid":"void",DisplayName=hymn?"Auditory":timber?"Wood":acid?"Acid":"Void" }}),
            Area=new AreaDefinition { Type=hymn?AreaType.Cone:timber?AreaType.Line:acid?AreaType.Burst:AreaType.None,SizeInFeet=hymn||timber?15:acid?5:0,RangeInFeet=hymn||timber?0:30 },
            Spell=new SpellDefinition
            {
                SpellLevel=0,Traditions=timber||acid?new() {SpellcastingTradition.Arcane,SpellcastingTradition.Primal}:new() {SpellcastingTradition.Divine,SpellcastingTradition.Occult},
                DefenseType=SpellDefenseType.BasicSave,SaveType=timber||acid?SavingThrow.Reflex:SavingThrow.Fortitude,
                DamageType=hymn?DamageType.Sonic:timber?DamageType.Bludgeoning:acid?DamageType.Acid:DamageType.Void,
                DamageFormula=new DiceFormula(hymn||acid?1:2,hymn||acid?8:4,0),HeightenIncrement=hymn||acid?2:1,
                HeightenBonusDamage=new DiceFormula(1,hymn||acid?8:4,0),
                ConditionEffect=acid?null:new SpellConditionEffect { Condition=hymn?ConditionDatabase.Instance.Deafened:timber?ConditionDatabase.Instance.Dazzled:ConditionDatabase.Instance.Enfeebled,
                    ValueOnCritFailure=1,DurationInRounds=hymn?10:1 },
            },
        };
    }
    internal static void ApplyRider(string id,ICharacter caster,ICharacter target,DegreeOfSuccess degree)
    {
        if (id=="feat-caustic-blast" && degree==DegreeOfSuccess.CriticalFailure)
            target.Conditions.ApplyPersistentDamage(new DiceFormula(1,1,((caster.StatProvider.Level+1)/2-1)/2),DamageType.Acid,caster);
    }
    private sealed class FeatCantrip(string id):SpellCastAction
    {
        protected override void OnSpellEffectApplied(ICharacter caster,ICharacter target,DegreeOfSuccess degree)
        {
            base.OnSpellEffectApplied(caster,target,degree);
            ApplyRider(id,caster,target,degree);
        }
    }

}
