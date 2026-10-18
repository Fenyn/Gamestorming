using System.Collections.Generic;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;

namespace Ungilded.Content;

/// <summary>
/// The ancestry, heritage, backgrounds and level 1 feats of the Prologue pregens, copied from the
/// pack entries (ancestries/human.json, heritages/human/wintertouched-human.json,
/// backgrounds/guard.json, backgrounds/criminal.json, feats/...). Pf2e.Core has no importer for
/// ancestries or backgrounds, so they are authored here. Every call returns fresh instances: a
/// feature holds per-character handlers.
/// </summary>
public static class PrologueOrigins
{
    public static AncestryDefinition Human() => new()
    {
        DefinitionId = "human",
        AncestryName = "Human",
        HitPoints = 8,
        Size = CreatureSize.Medium,
        BaseSpeedInFeet = 25,
        AbilityBoostOptions = new() { AnyBoost(), AnyBoost() },
        Traits = new TraitCollection(new[]
        {
            Trait("human", "Human", TraitCategory.CreatureType),
            Trait("humanoid", "Humanoid", TraitCategory.CreatureType),
        }),
    };

    public static HeritageDefinition Wintertouched() => new()
    {
        DefinitionId = "wintertouched-human",
        HeritageName = "Wintertouched Human",
        Description = "Cold resistance equal to half your level (minimum 1).",
        GrantedFeatures = new List<CharacterFeature>
        {
            new HalfLevelResistanceFeature
            {
                FeatureId = "wintertouched-human",
                DisplayName = "Wintertouched Human",
                Description = "Cold resistance equal to half your level (minimum 1).",
                Category = FeatureCategory.HeritageFeature,
                LevelRequirement = 1,
                ResistanceType = DamageType.Cold,
            },
        },
    };

    /// <summary>Guard: Str or Cha plus a free boost, Intimidation, Legal or Warfare Lore (Warfare
    /// here), Quick Coercion.</summary>
    public static BackgroundDefinition Guard() => new()
    {
        DefinitionId = "guard",
        BackgroundName = "Guard",
        AbilityBoostOptions = new() { Boost(AbilityScore.Strength, AbilityScore.Charisma), AnyBoost() },
        GrantedSkills = new() { Skill.Intimidation },
        GrantedLores = new() { WarfareLore },
        GrantedFeat = Feat(new QuickCoercionFeature(), "quick-coercion", "Quick Coercion", FeatureCategory.SkillFeat,
            "Coerce takes 1 round of conversation instead of 1 minute."),
    };

    /// <summary>Criminal: Dex or Int plus a free boost, Stealth, Underworld Lore, Experienced
    /// Smuggler. The Friend trains Alchemy Lore instead of Underworld Lore (spec section 8).</summary>
    public static BackgroundDefinition Criminal() => new()
    {
        DefinitionId = "criminal",
        BackgroundName = "Criminal",
        AbilityBoostOptions = new() { Boost(AbilityScore.Dexterity, AbilityScore.Intelligence), AnyBoost() },
        GrantedSkills = new() { Skill.Stealth },
        GrantedLores = new() { "Underworld Lore" },
        GrantedFeat = Feat(new ExperiencedSmugglerFeature(), "experienced-smuggler", "Experienced Smuggler",
            FeatureCategory.SkillFeat, "A Stealth check to conceal a small item treats a d20 roll below 10 as 10."),
    };

    public const string WarfareLore = "Warfare Lore";
    public const string AlchemyLore = "Alchemy Lore";
    public const string IntimidatingProwessId = "intimidating_prowess";
    public const string IntimidatingGlareId = "intimidating_glare";

    /// <summary>Human ancestry feat: gain one 1st-level general feat.</summary>
    public static CharacterFeature GeneralTraining() => Feat(new GeneralTrainingFeature(), "general-training",
        "General Training", FeatureCategory.AncestryFeature, "Gain one 1st-level general feat.");

    /// <summary>The Player's authored General Training pick. It is a level 2 feat that needs expert
    /// Intimidation, so a level 1 Player does not qualify.</summary>
    public static CharacterFeature IntimidatingProwess()
    {
        var feat = Feat(new IntimidatingProwessFeature(), IntimidatingProwessId, "Intimidating Prowess",
            FeatureCategory.GeneralFeat, "+1 circumstance bonus to Coerce and Demoralize. No penalty for a target that does not share your language.");
        feat.LevelRequirement = 2;
        feat.SkillPrerequisites.Add(new SkillPrerequisite { Skill = Skill.Intimidation, MinimumProficiency = ProficiencyLevel.Expert });
        return feat;
    }

    /// <summary>The legal level 1 substitute for Intimidating Prowess: a general skill feat on the
    /// same skill. The id is the one DemoralizeAction looks up.</summary>
    public static CharacterFeature IntimidatingGlare()
    {
        var feat = Feat(new IntimidatingGlareFeature(), IntimidatingGlareId, "Intimidating Glare",
            FeatureCategory.SkillFeat, "Demoralize is visual instead of auditory. No penalty for a target that does not share your language.");
        feat.SkillPrerequisites.Add(new SkillPrerequisite { Skill = Skill.Intimidation, MinimumProficiency = ProficiencyLevel.Trained });
        return feat;
    }

    public static CharacterFeature IncredibleInitiative() => Feat(new IncredibleInitiativeFeature(), "incredible-initiative",
        "Incredible Initiative", FeatureCategory.GeneralFeat, "+2 circumstance bonus to initiative rolls.");

    public static CharacterFeature SuddenCharge() => Feat(new SuddenChargeFeature(), "sudden-charge", "Sudden Charge",
        FeatureCategory.ClassFeat, "Stride twice. If you end within melee reach of an enemy, make a melee Strike against it.");

    /// <summary>Creature Sneak Attack: extra precision dice on a Strike against an off-guard target
    /// with an agile or finesse melee weapon or a ranged attack.</summary>
    public static CharacterFeature SneakAttack(int dieSize) => new CreatureSneakAttackFeature
    {
        FeatureId = "sneak-attack",
        DisplayName = "Sneak Attack",
        Description = $"+1d{dieSize} precision damage against an off-guard target with an agile or finesse melee weapon or a ranged attack.",
        Category = FeatureCategory.ClassFeature,
        LevelRequirement = 1,
        BonusDice = new DiceFormula(1, dieSize, 0),
    };

    private static CharacterFeature Feat(CharacterFeature feature, string id, string name, FeatureCategory category, string description)
    {
        feature.FeatureId = id;
        feature.DisplayName = name;
        feature.Category = category;
        feature.Description = description;
        feature.LevelRequirement = 1;
        return feature;
    }

    private static AbilityBoostOption AnyBoost() => new() { ChoiceDescription = "Any ability" };

    private static AbilityBoostOption Boost(params AbilityScore[] allowed) => new()
    {
        AllowedAbilities = new List<AbilityScore>(allowed),
        ChoiceDescription = string.Join(" or ", allowed),
    };

    private static TraitDefinition Trait(string id, string name, TraitCategory category)
        => new() { TraitId = id, DisplayName = name, Category = category };
}
