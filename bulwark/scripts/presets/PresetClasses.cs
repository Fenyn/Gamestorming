using System.Collections.Generic;
using PF2e.Classes;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;

namespace Bulwark.Presets;

/// <summary>
/// Code-authored PF2e (Remaster) class + subclass definitions for the M0 spike.
/// Proves the "author a character in code from a ClassDefinition" integration path.
///
/// Every factory returns a fresh instance so callers never share mutable state.
/// </summary>
public static class PresetClasses
{
    /// <summary>
    /// Fighter (PF2e Remaster) initial proficiencies.
    /// HP 10/level, key ability Str; Expert in simple/martial/unarmed weapons; Trained in all
    /// armor + unarmored; Expert Fortitude + Perception; Trained Reflex/Will; Trained class DC.
    ///
    /// Note: tabletop Fighter is Expert in Reflex; the spec's explicit list calls for Trained
    /// Reflex, which is what is authored here (matches the reference test fixture).
    /// The subclass overlay is attached so BuildDatabase-style resolution could also find it.
    /// </summary>
    public static ClassDefinition BuildFighter()
    {
        var fighter = new ClassDefinition
        {
            DefinitionId = "fighter",
            ClassName = "Fighter",
            Description = "A master of martial combat, skilled with weapons, armor, and the shield.",
            HitPointsPerLevel = 10,
            KeyAbility = AbilityScore.Strength,

            PerceptionProficiency = ProficiencyLevel.Expert,

            FortitudeProficiency = ProficiencyLevel.Expert,
            ReflexProficiency = ProficiencyLevel.Trained,
            WillProficiency = ProficiencyLevel.Trained,

            UnarmedAttackProficiency = ProficiencyLevel.Expert,
            SimpleWeaponProficiency = ProficiencyLevel.Expert,
            MartialWeaponProficiency = ProficiencyLevel.Expert,
            AdvancedWeaponProficiency = ProficiencyLevel.Trained,

            UnarmoredProficiency = ProficiencyLevel.Trained,
            LightArmorProficiency = ProficiencyLevel.Trained,
            MediumArmorProficiency = ProficiencyLevel.Trained,
            HeavyArmorProficiency = ProficiencyLevel.Trained,

            ClassDCProficiency = ProficiencyLevel.Trained,
            SpellProficiency = ProficiencyLevel.Untrained,

            AutoTrainedSkills = new List<Skill> { Skill.Athletics },
            AdditionalSkillChoices = 3,
        };

        fighter.Subclasses = new List<SubclassDefinition> { BuildSentinelSubclass() };
        return fighter;
    }

    /// <summary>
    /// "Sentinel" — a shield-focused Fighter subclass overlay. Demonstrates every merge lane
    /// that <see cref="ClassDefinition.ResolveSubclass"/> honours:
    ///  - renames the resolved class ("Fighter" → "Sentinel"),
    ///  - a proficiency override (Heavy Armor Trained → Expert, leaning into the armored role),
    ///  - a subclass-granted class feature (visible in the granted-feature list),
    ///  - an additional auto-trained skill.
    /// </summary>
    public static SubclassDefinition BuildSentinelSubclass()
    {
        return new SubclassDefinition
        {
            DefinitionId = "fighter-sentinel",
            SubclassName = "Sentinel",
            Description = "A stalwart defender who fights behind a raised shield.",
            KeyAbility = AbilityScore.Strength,

            ProficiencyOverrides = new List<ProficiencyOverride>
            {
                new ProficiencyOverride
                {
                    Target = ProficiencyTarget.HeavyArmor,
                    NewProficiency = ProficiencyLevel.Expert,
                },
            },

            AdditionalAutoTrainedSkills = new List<Skill> { Skill.Intimidation },

            SubclassFeatures = new List<LeveledFeature>
            {
                new LeveledFeature { Level = 1, Feature = BuildSentinelShieldFocus() },
            },
        };
    }

    /// <summary>
    /// Marker class feature granted by the Sentinel subclass at level 1. Behaviourless — it
    /// exists so the granted-feature list can visibly prove the subclass overlay landed.
    /// </summary>
    public static CharacterFeature BuildSentinelShieldFocus()
    {
        return new CharacterFeature
        {
            FeatureId = "sentinel-shield-focus",
            DisplayName = "Sentinel: Shield Focus",
            Description = "Sentinel training in shield use.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    /// <summary>
    /// Bastion Dedication (Free Archetype feat, level 2). A real compiled Pf2e.Core feature
    /// (<see cref="BastionDedicationFeature"/>). Given a FeatureId so LevelUpApplicator can
    /// resolve it from FeatureDatabase by the combo's <c>FreeArchetypeFeatId</c>.
    /// </summary>
    public static BastionDedicationFeature BuildBastionDedication()
    {
        return new BastionDedicationFeature
        {
            FeatureId = "bastion-dedication",
            DisplayName = "Bastion Dedication",
            Description = "You have trained to fight from behind a shield.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 2,
        };
    }
}
