using Delve.Data;
using Delve.Run;
using PF2e.CharacterComponents;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Presets;

public static partial class PresetCharacters
{
    public static PF2eCharacter BuildWayfarer(WayfarerSpec spec, int level)
    {
        var a = spec.Abilities;
        var definition = WayfarerClasses.Build(spec.IntendedClass, level);
        var weapon = spec.IntendedClass == "Monk" ? WayfarerClasses.PowerfulFist() : FindWeapon(spec.Weapon);
        var character = BuildChassis(new ChassisSpec
        {
            Id = spec.Id, Name = spec.Name, Level = level, BaseClass = definition, Combo = WayfarerCombo(spec),
            Strength = a[0], Dexterity = a[1], Constitution = a[2], Intelligence = a[3], Wisdom = a[4], Charisma = a[5],
            MainHand = weapon, ArmorSlug = spec.Armor, ShieldSlug = spec.Shield,
            ChosenWeaponGroup = weapon?.Group ?? WeaponGroup.Sword, ExtraTrainedSkills = spec.Skills,
            BeforeFeatures = (c, stats) =>
            {
                if (stats.CharacterClass.SpellcastingSource == null) return;
                c.Spellcasting = new Spellcasting(c, stats);
                c.Spellcasting.Sources.Add(stats.CharacterClass.SpellcastingSource);
                c.Spellcasting.InitializeSlots();
            },
        });
        WayfarerCasting.Configure(character, spec, fresh: true);
        FeatCantrips.Apply(character);
        return character;
    }

    private static VariantComboDefinition WayfarerCombo(WayfarerSpec spec) => new()
    {
        Id = spec.IntendedClass.ToLowerInvariant(), DisplayName = WayfarerClasses.Specialty(spec.IntendedClass),
        Description = spec.Role,
        // ResolveSubclass replaces class identity. Keep the native class name; the specialty
        // is a separate feature shown on the sheet.
        Subclass = new SubclassDefinition
        {
            DefinitionId = spec.IntendedClass.ToLowerInvariant(), SubclassName = spec.IntendedClass,
            KeyAbility = WayfarerClasses.Key(spec.IntendedClass),
        },
    };
}
