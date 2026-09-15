using Delve.Data;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;

namespace Delve.Presets;

public static partial class PresetCharacters
{
    public static PF2eCharacter BuildEarthEidolon(PF2eCharacter summoner)
    {
        var definition = new ClassDefinition
        {
            DefinitionId="earth-eidolon",ClassName="Earth eidolon",HitPointsPerLevel=10,KeyAbility=AbilityScore.Strength,
            UnarmedAttackProficiency=ProficiencyLevel.Trained,UnarmoredProficiency=ProficiencyLevel.Trained,
            FortitudeProficiency=ProficiencyLevel.Expert,ReflexProficiency=ProficiencyLevel.Trained,WillProficiency=ProficiencyLevel.Expert,
            PerceptionProficiency=ProficiencyLevel.Trained,
        };
        definition.ProficiencyProgressions.Add(new() { Level=5,Target=ProficiencyTarget.UnarmedAttack,NewProficiency=ProficiencyLevel.Expert });
        var weapon = new WeaponDefinition { ItemName="Stone fist",Category=WeaponCategory.Unarmed,Group=WeaponGroup.Brawling,
            DamageDice=new DiceFormula(1,8,0),DamageType=DamageType.Bludgeoning,Traits=new TraitCollection() };
        var result = BuildChassis(new ChassisSpec
        {
            Id=summoner.Id+"-eidolon",Name="Earth Eidolon",Level=summoner.Stats.Level,BaseClass=definition,
            Combo=new VariantComboDefinition { Id="earth-eidolon",DisplayName="Earth eidolon",Description="Hilde's bonded companion",
                Subclass=new SubclassDefinition { DefinitionId="earth-eidolon",SubclassName="Earth eidolon",KeyAbility=AbilityScore.Strength } },
            Strength=18,Dexterity=14,Constitution=16,Intelligence=8,Wisdom=12,Charisma=10,MainHand=weapon,
        });
        // Same pool, action resource and MAP; the companion never receives an initiative entry.
        if (RosterFeats.Has(summoner,"eidolons-opportunity"))
            result.Features.GrantFeature(new PF2e.RuleEvents.Features.ReactiveStrikeFeature { FeatureId="eidolons-opportunity",DisplayName="Eidolon's Opportunity",Category=PF2e.RuleEvents.FeatureCategory.ClassFeat });
        result.Health = summoner.Health;
        result.Actions = summoner.Actions;
        result.Combat = summoner.Combat;
        return result;
    }
}
