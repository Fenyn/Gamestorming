using PF2e.Actions;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Data;

public static partial class PresetSpells
{
    private static SpellCastAction BuildSoothe() => new()
    {
        SpellId="preset-soothe",ActionName="Soothe",Description="Restore 1d10+4 HP to a living ally, heightened by 1d10+4 per spell rank.",
        ActionCostCount=2,RequiresTarget=true,TargetMode=TargetMode.Allies,CanTargetSelf=true,
        Area=new AreaDefinition { RangeInFeet=30 },
        Spell=new SpellDefinition
        {
            SpellLevel=1,Traditions=new() { SpellcastingTradition.Occult },DefenseType=SpellDefenseType.None,
            HealingFormula=new DiceFormula(1,10,4),HeightenIncrement=1,HeightenBonusHealing=new DiceFormula(1,10,0),HeightenBonusFlatValue=4,
        },
    };
}
