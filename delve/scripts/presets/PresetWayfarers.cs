using PF2e.Core;
using PF2e.Data;

namespace Delve.Presets;

public static partial class PresetCharacters
{
    public const string RavenId = "raven";
    public const string ThistleId = "thistle";

    // Supported prototype builds. Their Bulwark classes remain roster adaptation targets.
    public static PF2eCharacter BuildRaven(int level) => BuildChassis(new ChassisSpec
    {
        Id = RavenId, Name = "Raven", Level = level,
        BaseClass = PresetClasses.BuildRogue(), Combo = PresetCombos.RogueThief,
        Strength = 12, Dexterity = 18, Constitution = 12,
        Intelligence = 10, Wisdom = 12, Charisma = 16,
        MainHand = FindWeapon("rapier"), OffHand = FindWeapon("shortsword"),
        ArmorSlug = "leather-armor", ChosenWeaponGroup = WeaponGroup.Sword,
        ExtraTrainedSkills = new[] { Skill.Intimidation, Skill.Diplomacy },
    });

    public static PF2eCharacter BuildThistle(int level) => BuildChassis(new ChassisSpec
    {
        Id = ThistleId, Name = "Thistle", Level = level,
        BaseClass = PresetClasses.BuildFighter(), Combo = PresetCombos.FighterSentinel,
        Strength = 14, Dexterity = 18, Constitution = 12,
        Intelligence = 10, Wisdom = 14, Charisma = 10,
        MainHand = FindWeapon("shortbow"), ArmorSlug = "leather-armor",
        ChosenWeaponGroup = WeaponGroup.Bow,
        ExtraTrainedSkills = new[] { Skill.Survival, Skill.Stealth },
    });
}
