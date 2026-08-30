using System;
using System.Collections.Generic;
using PF2e.CharacterComponents;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.Utilities;

namespace Delve.Flow;

/// <summary>
/// Reads a built <see cref="PF2eCharacter"/> into the <see cref="HeroSheetData"/> the hero-select
/// sheet renders: identity, the four headline numbers, the six ability boxes and the overview
/// rows. Strikes, defences and spells come from <see cref="HeroSheetLoadout"/>. Every element also
/// carries the <see cref="SheetTip"/> that explains it, assembled from the same character, because
/// the page prints numbers and the hover prints the arithmetic. Pure - no Godot types, no scene,
/// no autoload - so the spike asserts on the same numbers and words the screen prints.
/// </summary>
public static class HeroSheetBuilder
{
    /// <summary>The overview rows, in reading order. Labels are the sheet's own row keys.</summary>
    public const string SavesRow = "SAVES";
    public const string SensesRow = "SENSES";
    public const string SkillsRow = "SKILLS";
    public const string StrikesRow = "STRIKES";
    public const string DefencesRow = "DEFENCES";
    public const string SpellsRow = "SPELLS";
    public const string FeaturesRow = "FEATURES";

    /// <summary>Every label the overview can print. The sheet sizes its label column to the
    /// widest of them, so the content edge stays on one x as the reader moves along the
    /// roster and a caster's extra row does not shift the page.</summary>
    public static readonly string[] RowLabels =
    {
        SavesRow, SensesRow, SkillsRow, StrikesRow, DefencesRow, SpellsRow, FeaturesRow,
    };

    private static readonly AbilityScore[] AbilityOrder =
    {
        AbilityScore.Strength, AbilityScore.Dexterity, AbilityScore.Constitution,
        AbilityScore.Intelligence, AbilityScore.Wisdom, AbilityScore.Charisma,
    };

    private static readonly string[] AbilityCodes = { "STR", "DEX", "CON", "INT", "WIS", "CHA" };

    private static readonly SavingThrow[] SaveOrder =
        { SavingThrow.Fortitude, SavingThrow.Reflex, SavingThrow.Will };

    /// <summary>The whole sheet for one built character.</summary>
    public static HeroSheetData Read(PF2eCharacter character)
    {
        var stats = character.Stats;
        var characterClass = stats?.CharacterClass;
        int level = stats?.Level ?? 1;
        int hitPoints = character.Health?.MaxHP ?? 0;
        int armorClass = StatsCalculator.CalculateAC(character);
        var strikes = HeroSheetLoadout.Strikes(character, characterClass, level);
        var casting = HeroSheetLoadout.Casting(character);

        return new HeroSheetData(
            Name: character.Name ?? "",
            Subtitle: Identity(stats, level),
            HitPoints: hitPoints,
            ArmorClass: armorClass,
            Headlines: Headlines(character, stats, characterClass, hitPoints, armorClass,
                casting?.Signature ?? HeroSheetLoadout.StrikeHeadline(strikes)),
            Abilities: Abilities(stats, characterClass),
            Rows: Rows(character, stats, characterClass, level, strikes, casting?.Row));
    }

    // ---------------------------------------------------------------- Identity

    /// <summary>
    /// "Ancestry · Class (Subclass) · Level N". The presets carry no ancestry, so that segment
    /// drops out. The engine folds a subclass overlay into the class - the resolved ClassName IS
    /// the subclass name - so the base class is read back off the resolved DefinitionId
    /// ("fighter-sentinel" → Fighter), and a subclass name that already ends in its class
    /// ("Battle Magic Wizard") loses the repeat.
    /// </summary>
    private static string Identity(PF2eCharacterStats? stats, int level)
    {
        var parts = new List<string>();

        string ancestry = stats?.Ancestry?.AncestryName ?? "";
        if (ancestry.Length > 0) parts.Add(ancestry);

        string line = ClassLine(stats?.CharacterClass);
        if (line.Length > 0) parts.Add(line);

        parts.Add($"Level {level}");
        return string.Join("  ·  ", parts);
    }

    private static string ClassLine(ClassDefinition? characterClass)
    {
        if (characterClass == null) return "";

        string subclass = characterClass.ClassName ?? "";
        string baseClass = BaseClassName(characterClass.DefinitionId);
        if (baseClass.Length == 0) return subclass;

        if (subclass.EndsWith(" " + baseClass, StringComparison.OrdinalIgnoreCase))
            subclass = subclass[..^(baseClass.Length + 1)];
        if (subclass.Length == 0 || subclass.Equals(baseClass, StringComparison.OrdinalIgnoreCase))
            return baseClass;

        return $"{baseClass} ({subclass})";
    }

    private static string BaseClassName(string? definitionId)
    {
        if (string.IsNullOrEmpty(definitionId)) return "";
        int dash = definitionId.IndexOf('-');
        string word = dash < 0 ? definitionId : definitionId[..dash];
        return word.Length == 0 ? "" : char.ToUpperInvariant(word[0]) + word[1..];
    }

    // ---------------------------------------------------------------- Header

    /// <summary>
    /// The four numbers that pop: what keeps you alive, what keeps you untouched, the ability the
    /// class is built on, and the one number that says what this character does - a caster's spell
    /// DC or a martial's attack bonus. A fifth would mean none of them stood out.
    ///
    /// The key ability names itself and stops there - "STR", never "STR +4". The rail box under
    /// the plinth already prints that modifier and the hover spells it out, so the headline says
    /// which ability the class is built on and leaves the arithmetic to them.
    /// </summary>
    private static IReadOnlyList<SheetHeadline> Headlines(
        PF2eCharacter character, PF2eCharacterStats? stats, ClassDefinition? characterClass,
        int hitPoints, int armorClass, SheetHeadline? signature)
    {
        if (stats == null) return Array.Empty<SheetHeadline>();

        var row = new List<SheetHeadline>(4)
        {
            new("HP", hitPoints.ToString(),
                HeroSheetVitalTips.HitPoints(stats, characterClass, hitPoints)),
            new("AC", armorClass.ToString(),
                HeroSheetVitalTips.ArmorClass(character, armorClass)),
        };

        if (characterClass != null)
        {
            var key = characterClass.KeyAbility;
            row.Add(new SheetHeadline(
                "KEY ABILITY",
                HeroSheetTips.Code(key).ToUpperInvariant(),
                HeroSheetVitalTips.Ability(stats, characterClass, key)));
        }
        if (signature != null) row.Add(signature);
        return row;
    }

    private static IReadOnlyList<SheetAbility> Abilities(
        PF2eCharacterStats? stats, ClassDefinition? characterClass)
    {
        if (stats == null) return Array.Empty<SheetAbility>();

        var boxes = new List<SheetAbility>(AbilityOrder.Length);
        for (int i = 0; i < AbilityOrder.Length; i++)
        {
            var ability = AbilityOrder[i];
            boxes.Add(new SheetAbility(
                AbilityCodes[i],
                Signed(stats.GetAbilityModifier(ability)),
                stats.GetAbilityScore(ability).ToString(),
                characterClass != null && characterClass.KeyAbility == ability,
                HeroSheetVitalTips.Ability(stats, characterClass, ability)));
        }
        return boxes;
    }

    // ---------------------------------------------------------------- Overview

    /// <summary>One quiet line per subject. A subject the character has nothing for is absent
    /// rather than printed empty.</summary>
    private static IReadOnlyList<SheetRow> Rows(
        PF2eCharacter character, PF2eCharacterStats? stats, ClassDefinition? characterClass,
        int level, IReadOnlyList<SheetEntry> strikes, SheetRow? spells)
    {
        var rows = new List<SheetRow>(7);
        if (stats == null) return rows;

        Add(rows, SavesRow, Saves(character, stats, characterClass), SheetRowStyle.Text);
        Add(rows, SensesRow, Senses(character, stats, characterClass), SheetRowStyle.Text);
        Add(rows, SkillsRow, Skills(character, stats), SheetRowStyle.Chips);
        Add(rows, StrikesRow, strikes, SheetRowStyle.Chips);
        Add(rows, DefencesRow, HeroSheetLoadout.Defences(character), SheetRowStyle.Chips);
        if (spells != null) rows.Add(spells);
        Add(rows, FeaturesRow, Features(character, level), SheetRowStyle.Chips);
        return rows;
    }

    private static void Add(
        List<SheetRow> rows, string label, IReadOnlyList<SheetEntry> entries, SheetRowStyle style)
    {
        if (entries.Count > 0) rows.Add(new SheetRow(label, entries, style));
    }

    private static IReadOnlyList<SheetEntry> Saves(
        PF2eCharacter character, PF2eCharacterStats stats, ClassDefinition? characterClass)
    {
        var entries = new List<SheetEntry>(SaveOrder.Length);
        foreach (var save in SaveOrder)
        {
            int total = StatsCalculator.CalculateSave(character, save);
            entries.Add(new SheetEntry(
                $"{save} {Signed(total)}",
                HeroSheetVitalTips.Save(stats, characterClass, save, total)));
        }
        return entries;
    }

    private static IReadOnlyList<SheetEntry> Senses(
        PF2eCharacter character, PF2eCharacterStats stats, ClassDefinition? characterClass)
    {
        int perception = StatsCalculator.CalculatePerception(character);
        int speed = StatsCalculator.GetEffectiveSpeed(character);
        return new List<SheetEntry>(2)
        {
            new($"Perception {Signed(perception)}",
                HeroSheetVitalTips.Perception(stats, characterClass, perception)),
            new($"Speed {speed} ft", HeroSheetVitalTips.Speed(character, stats, speed)),
        };
    }

    /// <summary>Trained or better, alphabetically, by name alone. The rank and the modifier are on
    /// the hover - a wall of "+8 T" is what made the old sheet a spreadsheet.</summary>
    private static IReadOnlyList<SheetEntry> Skills(PF2eCharacter character, PF2eCharacterStats stats)
    {
        var entries = new List<SheetEntry>();
        foreach (Skill skill in Enum.GetValues<Skill>())
        {
            var proficiency = SkillCalculator.GetProficiency(character, skill);
            if (proficiency < ProficiencyLevel.Trained) continue;

            int total = SkillCalculator.CalculateSkillBonus(character, skill);
            entries.Add(new SheetEntry(
                skill.ToString(), HeroSheetVitalTips.Skill(stats, skill, proficiency, total)));
        }
        return entries;
    }

    /// <summary>Granted class features, class feats and archetype feats at or below this level,
    /// by the level they arrived and then by name. The row prints the names; each name carries
    /// the feature's own description on its hover.</summary>
    private static IReadOnlyList<SheetEntry> Features(PF2eCharacter character, int level)
    {
        var granted = character.Features?.ActiveFeatures;
        if (granted == null) return Array.Empty<SheetEntry>();

        var kept = new List<CharacterFeature>();
        foreach (var feature in granted)
        {
            if (feature == null || string.IsNullOrEmpty(feature.DisplayName)) continue;
            if (feature.LevelRequirement > level) continue;
            kept.Add(feature);
        }
        kept.Sort((a, b) => a.LevelRequirement != b.LevelRequirement
            ? a.LevelRequirement.CompareTo(b.LevelRequirement)
            : string.CompareOrdinal(a.DisplayName, b.DisplayName));

        var entries = new List<SheetEntry>(kept.Count);
        var seen = new HashSet<string>();
        foreach (var feature in kept)
        {
            if (!seen.Add(feature.DisplayName)) continue;
            entries.Add(new SheetEntry(feature.DisplayName, HeroSheetGearTips.Feature(feature)));
        }
        return entries;
    }

    // ---------------------------------------------------------------- Formatting

    /// <summary>A modifier always carries its sign - "+4" reads as a bonus, "4" reads as a score.</summary>
    internal static string Signed(int value) => value >= 0 ? $"+{value}" : value.ToString();
}
