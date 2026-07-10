using System.Collections.Generic;
using PF2e.Classes;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;
using PF2e.Spellcasting;

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
    /// Fighter (PF2e Remaster, Player Core "Fighter" class entry) initial proficiencies + level-gated
    /// progression. HP 10/level, key ability Str.
    ///
    /// Level-1 proficiencies (Player Core Fighter, "Initial Proficiencies"; cross-checked against the
    /// pf2e-source classes/fighter.json ranks attacks{simple:2,martial:2,unarmed:2,advanced:1},
    /// defenses{all:1}, saves{fort:2,reflex:2,will:1}, perception:2):
    ///   Perception Expert; Fortitude Expert, Reflex Expert, Will Trained; simple/martial/unarmed
    ///   Expert, advanced Trained; all armor + unarmored Trained; class DC Trained.
    ///
    /// Level-gated (ProficiencyProgressions, resolved by ClassDefinition.GetSaveProficiency /
    /// weapon getters as max(base, entries ≤ level)):
    ///   L3 Bravery → Will Expert (Player Core Fighter, "Bravery": "your proficiency rank for Will
    ///       saves increases to expert");
    ///   L5 Weapon Mastery → simple/martial/unarmed Master, advanced Expert (Player Core Fighter,
    ///       "Weapon Mastery": ranks for simple/martial weapons and unarmed increase to master,
    ///       advanced to expert).
    ///
    /// The Master weapon bumps are NOT RestrictToChosenWeaponGroup (they apply to every weapon of the
    /// category); the group-specific critical specialization is granted separately by WeaponMastery's
    /// feature, keyed off BuildChoices.ChosenWeaponGroup.
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
            // CORRECTION: Remaster Fighter is EXPERT in Reflex at level 1 (Player Core "Initial
            // Proficiencies"; fighter.json saves.reflex == 2). The prior preset authored Trained,
            // which understated the Veteran's Reflex save by +2 at every level. Now Expert.
            ReflexProficiency = ProficiencyLevel.Expert,
            WillProficiency = ProficiencyLevel.Trained, // → Expert @3 via Bravery progression below

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

        // Core Remaster Fighter class features, granted by level (NOT combo choices):
        //  L1 Reactive Strike (Attack of Opportunity) + Shield Block — WP4 reaction wiring (preserved);
        //  L3 Bravery — fear/frightened defense (the Will→Expert bump is the progression entry below);
        //  L5 Weapon Mastery — critical specialization for the chosen weapon group (the Master weapon
        //     bump is the progression entries below).
        // Authored as ClassFeatures so FeatureHolder.ResolveAndGrantFeatures grants them by level,
        // exactly like the Sentinel subclass feature. Fresh instances per BuildFighter() (no shared state).
        fighter.ClassFeatures = new List<LeveledFeature>
        {
            new LeveledFeature { Level = 1, Feature = BuildReactiveStrike() },
            new LeveledFeature { Level = 1, Feature = BuildShieldBlock() },
            new LeveledFeature { Level = 3, Feature = BuildBravery() },
            new LeveledFeature { Level = 5, Feature = BuildWeaponMastery() },
        };

        // Level-gated proficiency increases (see class doc above for Remaster citations).
        fighter.ProficiencyProgressions = new List<ProficiencyProgression>
        {
            // Bravery (L3): Will Trained → Expert.
            new ProficiencyProgression { Level = 3, Target = ProficiencyTarget.Will, NewProficiency = ProficiencyLevel.Expert },
            // Weapon Mastery (L5): simple/martial/unarmed → Master; advanced → Expert.
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.SimpleWeapon, NewProficiency = ProficiencyLevel.Master },
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.MartialWeapon, NewProficiency = ProficiencyLevel.Master },
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.UnarmedAttack, NewProficiency = ProficiencyLevel.Master },
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.AdvancedWeapon, NewProficiency = ProficiencyLevel.Expert },
        };

        fighter.Subclasses = new List<SubclassDefinition> { BuildSentinelSubclass() };
        return fighter;
    }

    /// <summary>Bravery (Fighter core class feature, L3) — upgrades a success on a Will save vs a fear
    /// effect to a critical success and reduces any incoming Frightened value by 1. The paired Will
    /// Trained→Expert increase is authored as a ProficiencyProgression on the class (getters read that,
    /// not the feature). Compiled Pf2e.Core feature.</summary>
    public static BraveryFeature BuildBravery()
    {
        return new BraveryFeature
        {
            FeatureId = "bravery",
            DisplayName = "Bravery",
            Description = "Your training helps you resist fear; reduce Frightened by 1 and upgrade Will saves vs fear.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 3,
        };
    }

    /// <summary>Weapon Mastery (Fighter core class feature, L5) — grants the critical specialization
    /// effect of the character's chosen weapon group (BuildChoices.ChosenWeaponGroup; Sword → the crit
    /// applies Off-Guard). The paired simple/martial/unarmed→Master increase is a ProficiencyProgression
    /// on the class. Compiled Pf2e.Core feature.</summary>
    public static WeaponMasteryFeature BuildWeaponMastery()
    {
        return new WeaponMasteryFeature
        {
            FeatureId = "weapon-mastery",
            DisplayName = "Weapon Mastery",
            Description = "You gain the critical specialization effect of your chosen weapon group.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 5,
        };
    }

    /// <summary>Reactive Strike (Fighter core class feature, L1) — the reaction melee Strike on a
    /// foe leaving reach / using a manipulate or ranged action. Compiled Pf2e.Core feature.</summary>
    public static ReactiveStrikeFeature BuildReactiveStrike()
    {
        return new ReactiveStrikeFeature
        {
            FeatureId = "reactive-strike",
            DisplayName = "Reactive Strike",
            Description = "Make a melee Strike against a creature that provokes within your reach.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    /// <summary>Shield Block (Fighter core class feature, L1) — the damage reaction that prevents
    /// damage up to the raised shield's Hardness. Compiled Pf2e.Core feature.</summary>
    public static ShieldBlockFeature BuildShieldBlock()
    {
        return new ShieldBlockFeature
        {
            FeatureId = "shield-block",
            DisplayName = "Shield Block",
            Description = "Ward off a blow with your raised shield, preventing damage up to its Hardness.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
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

    // ─────────────────────────────── Rogue class ───────────────────────────────

    /// <summary>
    /// Rogue (PF2e Remaster, Player Core "Rogue" class entry) initial proficiencies + level-gated
    /// progression. HP 8/level, key ability Dex.
    ///
    /// Level-1 proficiencies (Player Core Rogue "Initial Proficiencies"; cross-checked against
    /// pf2e-source classes/rogue.json attacks{simple:1,martial:1,unarmed:1,advanced:0},
    /// defenses{unarmored:1,light:1,medium:0,heavy:0}, saves{fort:1,reflex:2,will:2}, perception:2):
    ///   Perception Expert; Fortitude Trained, Reflex Expert, Will Expert; simple/martial/unarmed
    ///   Trained, advanced Untrained; unarmored + light armor Trained; class DC Trained (Dex).
    ///
    /// Level-gated (ProficiencyProgressions):
    ///   L5 Weapon Tricks (Player Core Rogue "Weapon Tricks": "Your proficiency ranks for simple
    ///       weapons and your rogue weapons increase to expert") → simple/martial/unarmed Expert.
    ///       NOTE: the engine models weapons by category, not the tabletop "rapier, sap, shortbow,
    ///       shortsword" whitelist, so this bumps the whole martial category to Expert (the Scout
    ///       only wields a rapier, so the over-grant has no gameplay effect). The crit-spec half of
    ///       Weapon Tricks is granted by WeaponTricksFeature (below).
    ///
    /// Racket is NOT chosen here (subclass-level decision pending design review); the placeholder
    /// Thief racket feature is granted at the character level as a class feature.
    /// </summary>
    public static ClassDefinition BuildRogue()
    {
        var rogue = new ClassDefinition
        {
            DefinitionId = "rogue",
            ClassName = "Rogue",
            Description = "A skilled scout and skirmisher who strikes from advantage. (PLACEHOLDER racket chassis.)",
            HitPointsPerLevel = 8,
            KeyAbility = AbilityScore.Dexterity,

            PerceptionProficiency = ProficiencyLevel.Expert,

            FortitudeProficiency = ProficiencyLevel.Trained,
            ReflexProficiency = ProficiencyLevel.Expert,
            WillProficiency = ProficiencyLevel.Expert,

            UnarmedAttackProficiency = ProficiencyLevel.Trained,
            SimpleWeaponProficiency = ProficiencyLevel.Trained,
            MartialWeaponProficiency = ProficiencyLevel.Trained, // covers rapier/shortsword (Player Core rogue weapons)
            AdvancedWeaponProficiency = ProficiencyLevel.Untrained,

            UnarmoredProficiency = ProficiencyLevel.Trained,
            LightArmorProficiency = ProficiencyLevel.Trained,
            MediumArmorProficiency = ProficiencyLevel.Untrained,
            HeavyArmorProficiency = ProficiencyLevel.Untrained,

            ClassDCProficiency = ProficiencyLevel.Trained,
            SpellProficiency = ProficiencyLevel.Untrained,

            AutoTrainedSkills = new List<Skill> { Skill.Stealth }, // rogue signature; Scout adds Thievery + Intimidation
            AdditionalSkillChoices = 7,
        };

        // Core Remaster Rogue class features, granted by level:
        //  L1 Sneak Attack (1d6 precision vs off-guard) + Surprise Attack (round-1 off-guard on a
        //     Stealth/Deception initiative) + Thief racket PLACEHOLDER (Dex-to-damage on finesse melee);
        //  L3 Deny Advantage (can't be made off-guard by equal/lower-level foes);
        //  L5 Weapon Tricks (crit specialization vs off-guard with agile/finesse; the Expert weapon
        //     bump is the progression below).
        rogue.ClassFeatures = new List<LeveledFeature>
        {
            new LeveledFeature { Level = 1, Feature = BuildSneakAttack() },
            new LeveledFeature { Level = 1, Feature = BuildSurpriseAttack() },
            new LeveledFeature { Level = 1, Feature = BuildThiefRacket() },
            new LeveledFeature { Level = 3, Feature = BuildDenyAdvantage() },
            new LeveledFeature { Level = 5, Feature = BuildWeaponTricks() },
        };

        // Weapon Tricks (L5): simple/martial/unarmed Trained → Expert (see class doc for the
        // category-granularity caveat).
        rogue.ProficiencyProgressions = new List<ProficiencyProgression>
        {
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.SimpleWeapon, NewProficiency = ProficiencyLevel.Expert },
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.MartialWeapon, NewProficiency = ProficiencyLevel.Expert },
            new ProficiencyProgression { Level = 5, Target = ProficiencyTarget.UnarmedAttack, NewProficiency = ProficiencyLevel.Expert },
        };

        return rogue;
    }

    /// <summary>Sneak Attack (Rogue core, L1) — adds precision dice (1d6 at L1, 2d6 at L5) when the
    /// target is off-guard and the rogue attacks with a finesse/agile melee or a ranged weapon.
    /// Compiled Pf2e.Core feature.</summary>
    public static SneakAttackFeature BuildSneakAttack()
    {
        return new SneakAttackFeature
        {
            FeatureId = "sneak-attack",
            DisplayName = "Sneak Attack",
            Description = "Deal extra precision damage to off-guard foes with the right weapon.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    /// <summary>Surprise Attack (Rogue core, L1) — on round 1, foes that haven't acted yet are
    /// off-guard to the rogue if it rolled Stealth or Deception for initiative. Compiled feature.</summary>
    public static SurpriseAttackFeature BuildSurpriseAttack()
    {
        return new SurpriseAttackFeature
        {
            FeatureId = "surprise-attack",
            DisplayName = "Surprise Attack",
            Description = "Foes that haven't acted in the first round are off-guard to you.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    /// <summary>Deny Advantage (Rogue core, L3) — you aren't off-guard to foes of your level or lower
    /// that would flank you or otherwise make you off-guard by surprise. Compiled feature.</summary>
    public static DenyAdvantageFeature BuildDenyAdvantage()
    {
        return new DenyAdvantageFeature
        {
            FeatureId = "deny-advantage",
            DisplayName = "Deny Advantage",
            Description = "Foes of your level or lower can't make you off-guard through positioning tricks.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 3,
        };
    }

    /// <summary>Weapon Tricks (Rogue core, L5) — on a critical hit vs an off-guard target with an
    /// agile or finesse weapon, apply that weapon's critical specialization effect. The paired
    /// simple/rogue-weapon → Expert increase is a ProficiencyProgression on the class. Compiled feature.</summary>
    public static WeaponTricksFeature BuildWeaponTricks()
    {
        return new WeaponTricksFeature
        {
            FeatureId = "weapon-tricks",
            DisplayName = "Weapon Tricks",
            Description = "Critically hitting an off-guard foe with an agile or finesse weapon triggers crit specialization.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 5,
        };
    }

    /// <summary>
    /// Thief racket (Rogue, L1) — PLACEHOLDER racket, pending design review. Adds the (Dex − Str)
    /// difference as bonus damage on finesse melee Strikes, letting the rogue use Dex for both attack
    /// and damage. The engine's ThiefRacketFeature reads NOTHING from CharacterBuildChoices (there is
    /// no racket field on it); the racket is selected purely by which racket feature is granted, so
    /// swapping to Ruffian/Scoundrel later is a one-line change and does not touch BuildChoices.
    /// </summary>
    public static ThiefRacketFeature BuildThiefRacket()
    {
        return new ThiefRacketFeature
        {
            FeatureId = "thief-racket", // PLACEHOLDER racket — pending design review
            DisplayName = "Thief Racket",
            Description = "Use Dexterity instead of Strength for damage with finesse melee weapons.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    // ─────────────────────────────── Caster classes ───────────────────────────────
    //
    // PLACEHOLDER build — class combos pending design review. Cleric and Wizard exist only to
    // exercise the spell + skill-action layer; NO doctrine, thesis, dedication, or variant-combo
    // choices are locked in here. The class SYSTEMS wiring (SpellcastingSource, proficiencies,
    // key ability that CalculateSpellDC keys off of) is real and permanent; the specific numbers
    // and the choice of a bare full-caster chassis are throwaway.

    /// <summary>
    /// Cleric (PF2e Remaster) — divine prepared full caster. Wis key ability (spell DC derives from
    /// KeyAbility), Trained spell proficiency, Trained simple weapons + unarmored/light/medium armor,
    /// Expert Will. Auto-trains Religion + Medicine so the Medic can attempt Battle Medicine.
    /// Divine Font is intentionally omitted for the placeholder (heal via normal slots suffices) —
    /// wiring a font would require locking a deity's FontSpellIdentity, a combo choice we must not make.
    /// </summary>
    public static ClassDefinition BuildCleric()
    {
        return new ClassDefinition
        {
            DefinitionId = "cleric",
            ClassName = "Cleric",
            Description = "A divine spellcaster who channels a deity's power. (PLACEHOLDER placeholder chassis.)",
            HitPointsPerLevel = 8,
            KeyAbility = AbilityScore.Wisdom,

            PerceptionProficiency = ProficiencyLevel.Trained,
            FortitudeProficiency = ProficiencyLevel.Trained,
            ReflexProficiency = ProficiencyLevel.Trained,
            WillProficiency = ProficiencyLevel.Expert,

            UnarmedAttackProficiency = ProficiencyLevel.Trained,
            SimpleWeaponProficiency = ProficiencyLevel.Trained,
            MartialWeaponProficiency = ProficiencyLevel.Untrained,

            UnarmoredProficiency = ProficiencyLevel.Trained,
            LightArmorProficiency = ProficiencyLevel.Trained,
            MediumArmorProficiency = ProficiencyLevel.Trained,

            ClassDCProficiency = ProficiencyLevel.Trained,
            SpellProficiency = ProficiencyLevel.Trained,

            SpellcastingSource = new SpellcastingSource
            {
                SourceName = "Cleric Spellcasting",
                Tradition = SpellcastingTradition.Divine,
                CastingType = SpellcastingType.Prepared,
                KnowledgeType = SpellKnowledgeType.Spellbook, // placeholder uses a personal list (see PresetCharacters)
                SpellcastingAbility = AbilityScore.Wisdom,
                ProgressionFormula = SpellProgressionFormula.Cleric,
                CantripsKnown = 5,
                MaxSpellLevel = 10,
            },

            AutoTrainedSkills = new List<Skill> { Skill.Religion, Skill.Medicine },
            AdditionalSkillChoices = 2,
        };
    }

    /// <summary>
    /// Wizard (PF2e Remaster) — arcane prepared full caster. Int key ability, Trained spell
    /// proficiency, Trained simple weapons, unarmored only, Expert Will. Auto-trains Arcana.
    /// No arcane thesis or school is set (PLACEHOLDER — pending design review).
    /// </summary>
    public static ClassDefinition BuildWizard()
    {
        return new ClassDefinition
        {
            DefinitionId = "wizard",
            ClassName = "Wizard",
            Description = "An arcane spellcaster who studies magic from a spellbook. (PLACEHOLDER chassis.)",
            HitPointsPerLevel = 6,
            KeyAbility = AbilityScore.Intelligence,

            PerceptionProficiency = ProficiencyLevel.Trained,
            FortitudeProficiency = ProficiencyLevel.Trained,
            ReflexProficiency = ProficiencyLevel.Trained,
            WillProficiency = ProficiencyLevel.Expert,

            UnarmedAttackProficiency = ProficiencyLevel.Trained,
            SimpleWeaponProficiency = ProficiencyLevel.Trained,
            MartialWeaponProficiency = ProficiencyLevel.Untrained,

            UnarmoredProficiency = ProficiencyLevel.Trained,

            ClassDCProficiency = ProficiencyLevel.Trained,
            SpellProficiency = ProficiencyLevel.Trained,

            SpellcastingSource = new SpellcastingSource
            {
                SourceName = "Wizard Spellcasting",
                Tradition = SpellcastingTradition.Arcane,
                CastingType = SpellcastingType.Prepared,
                KnowledgeType = SpellKnowledgeType.Spellbook,
                SpellcastingAbility = AbilityScore.Intelligence,
                ProgressionFormula = SpellProgressionFormula.Wizard,
                CantripsKnown = 5,
                MaxSpellLevel = 10,
            },

            AutoTrainedSkills = new List<Skill> { Skill.Arcana },
            AdditionalSkillChoices = 2,
        };
    }
}
