using System;
using PF2e.CharacterComponents;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Flow;

/// <summary>
/// The explanations behind the sheet's derived numbers: where the Hit Points came from, what the
/// AC is built out of, and which proficiency and ability each roll adds together. Every term is
/// read back off the built character, and a breakdown that does not reach the printed total says
/// so rather than hiding the difference.
///
/// Godot-free.
/// </summary>
internal static class HeroSheetVitalTips
{
    /// <summary>What the ability governs, plus the score and modifier behind the box.</summary>
    internal static SheetTip Ability(
        PF2eCharacterStats stats, ClassDefinition? characterClass, AbilityScore ability)
    {
        int score = stats.GetAbilityScore(ability);
        int modifier = stats.GetAbilityModifier(ability);
        bool key = characterClass != null && characterClass.KeyAbility == ability;

        return new SheetTip(
            ability.ToString(),
            $"Score {score} · modifier {HeroSheetBuilder.Signed(modifier)}",
            HeroSheetTips.Ability(ability),
            Tag: key ? "KEY ABILITY" : null,
            Footer: key ? $"Key ability for {characterClass!.ClassName} - sets the class DC." : null);
    }

    /// <summary>Ancestry HP, then the class's per-level HP and Constitution at every level.</summary>
    internal static SheetTip HitPoints(
        PF2eCharacterStats stats, ClassDefinition? characterClass, int printed)
    {
        int ancestry = stats.AncestryHP;
        int perLevel = characterClass?.HitPointsPerLevel ?? 0;
        int con = stats.GetAbilityModifier(AbilityScore.Constitution);
        int level = stats.Level;
        int fromLevels = (perLevel + con) * level;

        return new SheetTip("Hit Points", "", "",
            Meta: new[]
            {
                new SheetMetaRow("Ancestry", ancestry.ToString()),
                new SheetMetaRow("Per level", $"{perLevel} class + {con} Con, x {level} "
                    + $"level{(level == 1 ? "" : "s")}"),
            },
            Footer: $"{ancestry} + {perLevel + con} x {level} = {ancestry + fromLevels}"
                + Reconcile(ancestry + fromLevels, printed, "total"));
    }

    /// <summary>10, Dexterity under the armour's cap, armour proficiency, and the item bonus.</summary>
    internal static SheetTip ArmorClass(PF2eCharacter character, int printed)
    {
        var stats = character.Stats;
        var characterClass = stats?.CharacterClass;
        if (stats == null || characterClass == null)
            return new SheetTip("Armour Class", printed.ToString(), "");

        var armor = character.Equipment?.WornArmor;
        int level = stats.Level;
        int dex = stats.GetAbilityModifier(AbilityScore.Dexterity);
        int usedDex = armor != null ? Math.Min(dex, armor.DexCap) : dex;
        var proficiency = armor != null
            ? armor.GetProficiency(characterClass, level)
            : characterClass.GetArmorProficiency(ArmorCategory.Unarmored, level);
        int profBonus = ProficiencyCalculator.GetBonus(proficiency, level);
        int item = armor?.TotalACBonus ?? 0;

        string cap = armor != null && dex > armor.DexCap
            ? $" (capped from {HeroSheetBuilder.Signed(dex)} by the armour)"
            : "";
        string? worn = armor?.ArmorDef?.ItemName;
        return new SheetTip(
            "Armour Class",
            worn != null ? $"wearing {worn}" : "unarmoured",
            "",
            Meta: new[]
            {
                new SheetMetaRow("Base", "10"),
                new SheetMetaRow("Dexterity", $"{HeroSheetBuilder.Signed(usedDex)}{cap}"),
                new SheetMetaRow("Proficiency",
                    $"{HeroSheetTips.RankName(proficiency)} {HeroSheetBuilder.Signed(profBonus)}"),
                new SheetMetaRow("Item", HeroSheetBuilder.Signed(item)),
            },
            Footer: $"10 {HeroSheetBuilder.Signed(usedDex)} {HeroSheetBuilder.Signed(profBonus)} "
                + $"{HeroSheetBuilder.Signed(item)} = {10 + usedDex + profBonus + item}"
                + Reconcile(10 + usedDex + profBonus + item, printed, "AC"));
    }

    /// <summary>Perception: the class's Perception proficiency plus Wisdom.</summary>
    internal static SheetTip Perception(
        PF2eCharacterStats stats, ClassDefinition? characterClass, int printed)
    {
        var proficiency = characterClass?.GetPerceptionProficiency(stats.Level)
                          ?? ProficiencyLevel.Untrained;
        return new SheetTip("Perception", "",
            "Perception measures your ability to be aware of your environment. It usually determines "
            + "how quickly you spring into action in combat.",
            Footer: Formula(stats, proficiency, AbilityScore.Wisdom, printed));
    }

    /// <summary>One saving throw: its proficiency plus the ability the save uses.</summary>
    internal static SheetTip Save(
        PF2eCharacterStats stats, ClassDefinition? characterClass, SavingThrow save, int printed)
    {
        var proficiency = characterClass?.GetSaveProficiency(save, stats.Level)
                          ?? ProficiencyLevel.Untrained;
        return new SheetTip($"{save} save", "",
            SaveRole(save),
            Footer: Formula(stats, proficiency, SaveAbility(save), printed));
    }

    /// <summary>Speed: the ancestry's base, less what the armour costs.</summary>
    internal static SheetTip Speed(PF2eCharacter character, PF2eCharacterStats stats, int printed)
    {
        int penalty = StatsCalculator.GetArmorSpeedPenalty(character);
        return new SheetTip("Speed", "", "How far one Stride action carries you.",
            Meta: penalty != 0
                ? new[]
                {
                    new SheetMetaRow("Base", $"{stats.BaseSpeedInFeet} ft"),
                    new SheetMetaRow("Armour", $"-{Math.Abs(penalty)} ft"),
                }
                : null);
    }

    /// <summary>One trained skill: what it is rolled for, and what the number is made of.</summary>
    internal static SheetTip Skill(
        PF2eCharacterStats stats, PF2e.Data.Skill skill, ProficiencyLevel proficiency, int printed)
    {
        var ability = SkillAbilities.GetAbility(skill);
        return new SheetTip(
            skill.ToString(),
            "",
            HeroSheetTips.SkillRole(skill),
            Meta: new[] { new SheetMetaRow("Actions", HeroSheetTips.SkillActionList(skill)) },
            Footer: Formula(stats, proficiency, ability, printed));
    }

    // ---------------------------------------------------------------- Parts

    /// <summary>The compact formula every roll footer prints: "+8 = trained +4 · Wis +4".</summary>
    private static string Formula(
        PF2eCharacterStats stats, ProficiencyLevel proficiency, AbilityScore ability, int printed)
    {
        int profBonus = ProficiencyCalculator.GetBonus(proficiency, stats.Level);
        int abilityMod = stats.GetAbilityModifier(ability);
        string rank = proficiency == ProficiencyLevel.Untrained
            ? "untrained +0"
            : $"{HeroSheetTips.RankName(proficiency)} {HeroSheetBuilder.Signed(profBonus)}";

        return $"{HeroSheetBuilder.Signed(printed)} = {rank}"
               + $" · {HeroSheetTips.Code(ability)} {HeroSheetBuilder.Signed(abilityMod)}"
               + Reconcile(profBonus + abilityMod, printed, "roll");
    }

    /// <summary>Say so when features move the number past what the parts add up to.</summary>
    private static string Reconcile(int parts, int printed, string noun)
        => parts == printed ? "" : $" Features and effects move the {noun} to {printed}.";

    private static AbilityScore SaveAbility(SavingThrow save) => save switch
    {
        SavingThrow.Fortitude => AbilityScore.Constitution,
        SavingThrow.Reflex => AbilityScore.Dexterity,
        _ => AbilityScore.Wisdom,
    };

    // Save descriptions quoted from Archives of Nethys (2e.aonprd.com/Rules.aspx?ID=2296).
    private static string SaveRole(SavingThrow save) => save switch
    {
        SavingThrow.Fortitude => "Fortitude saving throws allow you to reduce the effects of "
            + "abilities and afflictions that can debilitate the body.",
        SavingThrow.Reflex => "Reflex saving throws measure how well you can respond quickly to "
            + "a situation and how gracefully you can avoid effects that have been thrown at you.",
        _ => "Will saving throws measure how well you can resist attacks to your mind and spirit.",
    };

    private static string Capital(string word)
        => word.Length == 0 ? word : char.ToUpperInvariant(word[0]) + word[1..];
}
