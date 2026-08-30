using System;
using System.Collections.Generic;
using System.Text;
using Delve.Data;
using PF2e.Actions;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Import;
using PF2e.RuleEvents;
using PF2e.Utilities;

namespace Delve.Flow;

/// <summary>
/// The explanations behind what the character carries and casts: how a strike's attack and damage
/// are built, what a piece of armour costs and caps, and what a feat or a spell actually does.
/// Feat text comes off the granted feature; spell text comes out of the loaded pack, so neither
/// is written twice.
///
/// Godot-free.
/// </summary>
internal static class HeroSheetGearTips
{
    /// <summary>One weapon: the attack terms, the damage terms, then every trait it carries.</summary>
    internal static SheetTip Strike(
        PF2eCharacter character, ClassDefinition? characterClass, int level,
        WeaponInstance weapon, int attack, int damageMod, string damage,
        IReadOnlyList<string> traits)
    {
        var stats = character.Stats;
        string name = weapon.WeaponDef?.ItemName ?? "Strike";
        if (stats == null) return new SheetTip(name, "", "");

        var ability = WeaponAttackCalculator.GetAttackAbility(stats, weapon);
        var proficiency = WeaponAttackCalculator.ResolveWeaponProficiency(
            characterClass, level, weapon, character.BuildChoices?.ChosenWeaponGroup,
            character.BuildChoices?.GetFavoredWeapon(), character.Features);
        int profBonus = ProficiencyCalculator.GetBonus(proficiency, level);
        int abilityMod = stats.GetAbilityModifier(ability);
        int item = weapon.PotencyBonus;

        var meta = new List<SheetMetaRow>
        {
            new("Attack", HeroSheetBuilder.Signed(attack)),
            new("Damage", damage),
        };
        foreach (string trait in traits)
        {
            string text = HeroSheetTips.Trait(trait);
            if (text.Length == 0) continue;
            int stop = text.IndexOf(". ", StringComparison.Ordinal);
            meta.Add(new SheetMetaRow(Capitalise(trait), stop > 0 ? text[..(stop + 1)] : text));
        }

        var footer = new StringBuilder();
        footer.Append($"{HeroSheetBuilder.Signed(attack)} = ")
            .Append($"{HeroSheetTips.RankName(proficiency)} {HeroSheetBuilder.Signed(profBonus)}")
            .Append($" · {ability} {HeroSheetBuilder.Signed(abilityMod)}");
        if (item != 0) footer.Append($" · item {HeroSheetBuilder.Signed(item)}");
        if (damageMod != 0) footer.Append($"  |  damage {HeroSheetBuilder.Signed(damageMod)}");

        var definition = weapon.WeaponDef;
        string subtitle = definition == null
            ? ""
            : $"{definition.Category} {definition.Group} weapon";
        return new SheetTip(name, subtitle, "",
            Cost: SheetActionCost.Of(1),
            Traits: traits.Count > 0 ? traits : null,
            Meta: meta,
            Footer: footer.ToString());
    }

    /// <summary>Worn armour: the AC it adds and everything it costs.</summary>
    internal static SheetTip Armor(ArmorDefinition armor)
    {
        var meta = new List<SheetMetaRow>
        {
            new("AC bonus", $"+{armor.TotalACBonus}"),
            new("Dex cap", $"+{armor.DexCap}"),
        };
        if (armor.CheckPenalty != 0)
            meta.Add(new SheetMetaRow("Check", $"{armor.CheckPenalty} to Str- and Dex-based skills"));
        if (armor.SpeedPenalty != 0)
            meta.Add(new SheetMetaRow("Speed", $"{armor.SpeedPenalty} ft"));

        return new SheetTip(armor.ItemName ?? "Armour", $"{armor.Category} armour", "",
            Meta: meta,
            Footer: armor.StrengthModRequired > 0
                ? $"Strength +{armor.StrengthModRequired} or better cancels the penalties."
                : null);
    }

    private static string Capitalise(string word)
        => word.Length == 0 ? word : char.ToUpperInvariant(word[0]) + word[1..];

    /// <summary>No armour at all - which is why the wizard's AC is what it is.</summary>
    internal static SheetTip Unarmoured() => new(
        "Unarmoured",
        "no armour worn",
        "Nothing adds to AC and nothing caps your Dexterity, so your full Dexterity modifier and "
        + "your unarmoured proficiency carry the whole defence. No check penalty and no Speed "
        + "penalty either.");

    /// <summary>A carried shield: what raising it buys and how much punishment it takes.</summary>
    internal static SheetTip Shield(ShieldDefinition shield) => new(
        shield.ItemName ?? "Shield",
        $"{shield.Type} shield",
        "",
        Cost: SheetActionCost.Of(1),
        Meta: new[]
        {
            new SheetMetaRow("Raised", $"+{shield.ACBonus} AC until your next turn"),
            new SheetMetaRow("Hardness", $"{shield.Hardness} damage stopped by Shield Block"),
            new SheetMetaRow("HP", $"{shield.MaxHP}, broken at {shield.BrokenThreshold}"),
        });

    /// <summary>
    /// A granted class feature or feat as a full stat-block card. The pack entry (found by the
    /// feature's slug) supplies the action cost, traits, Trigger/Requirements/Frequency rows and
    /// rules text; a feature the pack does not carry falls back to the engine's own description,
    /// and the cost falls back to the action the feature grants.
    /// </summary>
    internal static SheetTip Feature(CharacterFeature feature)
    {
        var pack = FeatLookup.Find(PackText.Slug(feature.DisplayName));

        string html = pack?.DescriptionHtml is { Length: > 0 } d ? d : feature.Description ?? "";
        var meta = new List<SheetMetaRow>();
        foreach (string label in new[] { "Trigger", "Requirements", "Frequency" })
        {
            string text = PackText.MetaBlock(html, label);
            if (text.Length > 0) meta.Add(new SheetMetaRow(label, text));
        }
        if (meta.TrueForAll(m => m.Label != "Frequency") && pack?.Frequency is { Length: > 0 } freq)
            meta.Add(new SheetMetaRow("Frequency", freq));

        string body = PackText.Plain(PackText.WithoutMetaBlocks(html));
        if (body.Length == 0)
        {
            body = $"A {Category(feature.Category).ToLowerInvariant()} this build gains at level "
                   + $"{feature.LevelRequirement}.";
        }

        return new SheetTip(
            feature.DisplayName ?? "Feature",
            "",
            body,
            Cost: FeatureCost(feature, pack),
            Traits: RulesTraits(pack?.Traits),
            Tag: $"{Category(feature.Category).ToUpperInvariant()} {feature.LevelRequirement}",
            Meta: meta.Count > 0 ? meta : null);
    }

    /// <summary>
    /// The traits worth a chip on a feature card. Class names on a feature are a membership list
    /// (every class that can take it), not a rule, so they are dropped; what remains - general,
    /// archetype, dedication, healing, manipulate and friends - changes how the feature plays.
    /// </summary>
    private static IReadOnlyList<string>? RulesTraits(IReadOnlyList<string>? traits)
    {
        if (traits == null) return null;
        var kept = new List<string>();
        foreach (string trait in traits)
        {
            if (!ClassTraits.Contains(trait)) kept.Add(trait);
        }
        return kept.Count > 0 ? kept : null;
    }

    private static readonly HashSet<string> ClassTraits = new()
    {
        "alchemist", "animist", "barbarian", "bard", "champion", "cleric", "commander", "druid",
        "exemplar", "fighter", "guardian", "gunslinger", "inventor", "investigator", "kineticist",
        "magus", "monk", "necromancer", "oracle", "psychic", "ranger", "rogue", "runesmith",
        "sorcerer", "summoner", "swashbuckler", "thaumaturge", "witch", "wizard",
    };

    /// <summary>Pack action type first; the granted action's own cost when the pack is silent.</summary>
    private static SheetActionCost? FeatureCost(CharacterFeature feature, FeatEntry? pack)
    {
        switch (pack?.ActionType)
        {
            case "action": return SheetActionCost.Of(Math.Clamp(pack.Actions, 1, 3));
            case "reaction": return SheetActionCost.Reaction;
            case "free": return SheetActionCost.Free;
            case "passive": return null;
        }

        if (feature.GrantedActions is { Count: > 0 } acts && acts[0] != null)
        {
            var act = acts[0];
            return act.IsReaction ? SheetActionCost.Reaction
                : act.IsFreeAction ? SheetActionCost.Free
                : SheetActionCost.Of(Math.Clamp(act.ActionCostCount, 1, 3));
        }
        return null;
    }

    /// <summary>
    /// One group of prepared magic, spelled out: every spell in the group with what it costs to
    /// cast and what it does in a sentence, read out of the loaded pack by the slug its name
    /// makes. A pack that is not loaded, or a spell the pack does not carry, falls back to the
    /// preset's own definition, so a chip never hovers blank.
    /// </summary>
    internal static SheetTip SpellGroup(string term, IReadOnlyList<SpellAction> spells)
    {
        var order = new List<string>();
        var counts = new Dictionary<string, int>();
        var first = new Dictionary<string, SpellAction>();
        foreach (var spell in spells)
        {
            string name = spell.ActionName ?? "";
            if (name.Length == 0) continue;
            if (!counts.ContainsKey(name))
            {
                order.Add(name);
                first[name] = spell;
                counts[name] = 0;
            }
            counts[name]++;
        }

        var meta = new List<SheetMetaRow>();
        foreach (string name in order)
            meta.Add(SpellRow(name, counts[name], first[name]));

        return new SheetTip(term, $"{spells.Count} {Availability(term)}", "", Meta: meta);
    }

    /// <summary>The divine font: the extra castings a cleric's deity hands out on top of the
    /// slots the character chooses.</summary>
    internal static SheetTip DivineFont(string spellName, int slots)
    {
        var imported = GameDataLoader.FindSpell(PackText.Slug(spellName));
        string prose = PackText.Sentence(imported?.Description);
        string tokens = imported == null ? "" : SpellShorthand.Tokens(imported);
        string spellText = tokens.Length > 0 ? $"{spellName} — {tokens}" : spellName;

        return new SheetTip("Divine Font", $"{slots} extra {spellName}", prose,
            Meta: new[]
            {
                new SheetMetaRow("Castings", $"{slots} per day, on top of your prepared slots"),
                new SheetMetaRow("Spell", spellText),
            },
            Footer: "Granted by your deity - they cannot be traded for other spells.");
    }

    // ---------------------------------------------------------------- Parts

    /// <summary>One spell as a card row: the shorthand tokens, an em dash, the first sentence.</summary>
    private static SheetMetaRow SpellRow(string name, int count, SpellAction spell)
    {
        var imported = GameDataLoader.FindSpell(PackText.Slug(name));
        string label = count > 1 ? $"{name} ×{count}" : name;

        string tokens = SpellShorthand.Tokens(imported, spell);
        string prose = PackText.Sentence(imported?.Description ?? spell.Description);
        string text = tokens.Length > 0 && prose.Length > 0 ? $"{tokens} — {prose}"
            : tokens.Length > 0 ? tokens
            : prose;
        return new SheetMetaRow(label, text.Length > 0 ? text : "-");
    }

    /// <summary>How a group of magic is paid for, which is what the count actually means.</summary>
    private static string Availability(string term) => term switch
    {
        "Cantrips" => "known, cast at will",
        "Focus" => "cast from the focus pool",
        _ => "prepared for the day",
    };

    /// <summary>"ClassFeature" reads as "Class feature" once a person has to read it.</summary>
    private static string Category(FeatureCategory category) => category switch
    {
        FeatureCategory.ClassFeature => "Class feature",
        FeatureCategory.AncestryFeature => "Ancestry feature",
        FeatureCategory.HeritageFeature => "Heritage feature",
        FeatureCategory.GeneralFeat => "General feat",
        FeatureCategory.ClassFeat => "Class feat",
        FeatureCategory.SkillFeat => "Skill feat",
        FeatureCategory.DedicationFeat => "Dedication feat",
        FeatureCategory.ArchetypeFeat => "Archetype feat",
        _ => "Ability",
    };
}
