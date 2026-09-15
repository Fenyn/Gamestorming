using System;
using PF2e.Classes;
using PF2e.Data;

namespace Delve.Presets;

// Initial proficiencies transcribed from the bundled pf2e-source class packs.
internal static partial class WayfarerClasses
{
    private static ClassDefinition Initial(string name) => name switch
    {
        "Barbarian" => Initial("barbarian", "Barbarian", 12, AbilityScore.Strength, [2, 2, 1, 2, 1, 1, 1, 1, 0, 0], [Skill.Athletics], 3),
        "Champion" => Initial("champion", "Champion", 10, AbilityScore.Strength, [1, 2, 1, 2, 1, 1, 1, 1, 1, 1], [Skill.Religion], 2),
        "Witch" => Initial("witch", "Witch", 6, AbilityScore.Intelligence, [1, 1, 1, 2, 0, 1, 0, 0, 0, 1], [], 3),
        "Monk" => Initial("monk", "Monk", 10, AbilityScore.Dexterity, [1, 2, 2, 2, 0, 2, 0, 0, 0, 0], [], 4),
        "Ranger" => Initial("ranger", "Ranger", 10, AbilityScore.Dexterity, [2, 2, 2, 1, 1, 1, 1, 1, 0, 0], [Skill.Survival], 4),
        "Druid" => Initial("druid", "Druid", 8, AbilityScore.Wisdom, [1, 1, 1, 2, 0, 1, 1, 1, 0, 1], [Skill.Nature], 2),
        "Magus" => Initial("magus", "Magus", 8, AbilityScore.Strength, [1, 2, 1, 2, 1, 1, 1, 1, 0, 1], [Skill.Arcana], 2),
        "Oracle" => Initial("oracle", "Oracle", 8, AbilityScore.Charisma, [1, 1, 1, 2, 0, 1, 1, 0, 0, 1], [Skill.Religion], 3),
        "Thaumaturge" => Initial("thaumaturge", "Thaumaturge", 8, AbilityScore.Charisma, [2, 2, 1, 2, 1, 1, 1, 1, 0, 0], [Skill.Arcana, Skill.Nature, Skill.Occultism, Skill.Religion], 3),
        "Bard" => Initial("bard", "Bard", 8, AbilityScore.Charisma, [2, 1, 1, 2, 1, 1, 1, 0, 0, 1], [Skill.Occultism, Skill.Performance], 4),
        "Psychic" => Initial("psychic", "Psychic", 6, AbilityScore.Intelligence, [1, 1, 1, 2, 0, 1, 0, 0, 0, 1], [Skill.Occultism], 3),
        "Swashbuckler" => Initial("swashbuckler", "Swashbuckler", 10, AbilityScore.Dexterity, [2, 1, 2, 2, 1, 1, 1, 0, 0, 0], [Skill.Acrobatics], 4),
        "Summoner" => Initial("summoner", "Summoner", 10, AbilityScore.Charisma, [1, 2, 1, 2, 0, 1, 0, 0, 0, 1], [], 3),
        "Sorcerer" => Initial("sorcerer", "Sorcerer", 6, AbilityScore.Charisma, [1, 1, 1, 2, 0, 1, 0, 0, 0, 1], [], 2),
        _ => throw new ArgumentOutOfRangeException(nameof(name), name, "No native class definition"),
    };

    private static ClassDefinition Initial(string id, string name, int hp, AbilityScore key, int[] p, Skill[] skills, int extra) => new()
    {
        DefinitionId = id, ClassName = name, Description = $"{name} adventurer.",
        HitPointsPerLevel = hp, KeyAbility = key,
        PerceptionProficiency = (ProficiencyLevel)p[0],
        FortitudeProficiency = (ProficiencyLevel)p[1], ReflexProficiency = (ProficiencyLevel)p[2], WillProficiency = (ProficiencyLevel)p[3],
        SimpleWeaponProficiency = ProficiencyLevel.Trained, UnarmedAttackProficiency = ProficiencyLevel.Trained,
        MartialWeaponProficiency = (ProficiencyLevel)p[4],
        UnarmoredProficiency = (ProficiencyLevel)p[5], LightArmorProficiency = (ProficiencyLevel)p[6],
        MediumArmorProficiency = (ProficiencyLevel)p[7], HeavyArmorProficiency = (ProficiencyLevel)p[8],
        SpellProficiency = (ProficiencyLevel)p[9], ClassDCProficiency = ProficiencyLevel.Trained,
        AutoTrainedSkills = new(skills), AdditionalSkillChoices = extra,
    };
}
