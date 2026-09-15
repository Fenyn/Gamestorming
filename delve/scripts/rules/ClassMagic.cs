using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Rules;

internal static class ClassMagic
{
    internal static SpellCastAction? Build(ClassActionSpec spec, ICharacter caster)
    {
        int rank = (caster.StatProvider.Level+1)/2;
        var state = WayfarerFeature.State(caster);
        int dice, size;
        DamageType type;
        SavingThrow save;
        switch (spec.Id)
        {
            case "clinging-ice": dice=rank; size=4; type=DamageType.Cold; save=SavingThrow.Reflex; break;
            case "amped-daze": dice=1+2*((rank-1)/2); size=10; type=DamageType.Mental; save=SavingThrow.Will; break;
            case "elemental-toss": dice=rank; size=8; type=DamageType.Fire; save=SavingThrow.Reflex; break;
            default: return null;
        }
        int flat = spec.Class == "Psychic" && state.PsycheTurns>0 ? 2*rank : 0;
        // Construct per execution. Its formula is already heightened, so the shared source spell
        // and other characters' casts cannot be mutated by an amp or Unleash Psyche.
        return new HexSpell(spec.Id, caster)
        {
            SpellId = spec.Id, ActionName = spec.Name, Description = spec.Description,
            ActionCostCount = spec.Cost, RequiresTarget = true, TargetMode = TargetMode.Enemies,
            Area = new AreaDefinition { RangeInFeet = spec.Range*5 },
            Traits = new TraitCollection(new[]
            {
                new TraitDefinition { TraitId="concentrate",DisplayName="Concentrate" },
                new TraitDefinition { TraitId="manipulate",DisplayName="Manipulate" },
            }),
            Spell = new SpellDefinition
            {
                SpellLevel = spec.Focus>0 ? 1 : 0, IsFocusSpell = spec.Focus>0,
                DefenseType = spec.Id=="elemental-toss" ? SpellDefenseType.SpellAttack : SpellDefenseType.BasicSave,
                SaveType = save, DamageType = type, DamageFormula = new DiceFormula(dice,size,flat),
            },
        };
    }

    private sealed class HexSpell(string id, ICharacter owner) : SpellCastAction
    {
        protected override void OnSpellEffectApplied(ICharacter caster, ICharacter target, DegreeOfSuccess degree)
        {
            base.OnSpellEffectApplied(caster,target,degree);
            if (id == "clinging-ice" && degree <= DegreeOfSuccess.Failure)
                WayfarerFeature.State(owner).Buff(target,"Clinging Ice",StatType.Speed,
                    degree==DegreeOfSuccess.CriticalFailure ? -10 : -5,ModifierType.Circumstance);
            if (id == "amped-daze" && degree == DegreeOfSuccess.CriticalFailure)
                target.Conditions.AddCondition(ConditionDatabase.Instance.Stunned,1,source:caster);
        }
    }
}
