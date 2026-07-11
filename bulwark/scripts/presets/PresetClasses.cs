using System.Collections.Generic;
using Bulwark.Data;
using PF2e.Actions;
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
    /// Per the pack JSON, the dedication grants the Reactive Shield fighter feat — wired here
    /// (the engine feature no-ops with a warning if the grant target is left unset).
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
            ReactiveShieldFeature = BuildReactiveShield(),
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
    /// The racket is the rogue's subclass: the Thief overlay (<see cref="BuildThiefSubclass"/>)
    /// is resolved onto this base by the Scout's combo.
    /// </summary>
    public static ClassDefinition BuildRogue()
    {
        var rogue = new ClassDefinition
        {
            DefinitionId = "rogue",
            ClassName = "Rogue",
            Description = "A skilled scout and skirmisher who strikes from advantage.",
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

        // Skill Increases (Player Core Rogue: "You gain a skill increase at 2nd level and every
        // level thereafter"; pack classes/rogue.json skillIncreaseLevels = [2, 3, 4, ..., 20]).
        // Overrides the standard odd-level cadence in LevelUpSchedule/LevelUpApplicator; the
        // Scout's combo scripts no explicit picks, so ApplyLevelUp auto-assigns each increase.
        for (int level = 2; level <= 20; level++)
            rogue.SkillIncreaseLevels.Add(level);

        // Core Remaster Rogue class features, granted by level:
        //  L1 Sneak Attack (1d6 precision vs off-guard) + Surprise Attack (round-1 off-guard on a
        //     Stealth/Deception initiative);
        //  L3 Deny Advantage (can't be made off-guard by equal/lower-level foes);
        //  L5 Weapon Tricks (crit specialization vs off-guard with agile/finesse; the Expert weapon
        //     bump is the progression below).
        // The racket is the rogue's subclass decision — granted by the Thief overlay below.
        rogue.ClassFeatures = new List<LeveledFeature>
        {
            new LeveledFeature { Level = 1, Feature = BuildSneakAttack() },
            new LeveledFeature { Level = 1, Feature = BuildSurpriseAttack() },
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

        rogue.Subclasses = new List<SubclassDefinition> { BuildThiefSubclass() };
        return rogue;
    }

    /// <summary>
    /// Thief racket as a subclass overlay (the racket IS the rogue's subclass decision — Remaster
    /// Player Core "Rogue's Racket"). Grants the ThiefRacketFeature at L1; key ability Dex.
    /// </summary>
    public static SubclassDefinition BuildThiefSubclass()
    {
        return new SubclassDefinition
        {
            DefinitionId = "rogue-thief",
            SubclassName = "Thief",
            Description = "A rogue whose racket is theft: Dexterity fuels both blade-work and damage.",
            KeyAbility = AbilityScore.Dexterity,

            SubclassFeatures = new List<LeveledFeature>
            {
                new LeveledFeature { Level = 1, Feature = BuildThiefRacket() },
            },
        };
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
    /// Thief racket (Rogue subclass feature, L1) — the Scout's LOCKED racket. Adds the (Dex − Str)
    /// difference as bonus damage on finesse melee Strikes, letting the rogue use Dex for both attack
    /// and damage. The engine's ThiefRacketFeature reads NOTHING from CharacterBuildChoices (there is
    /// no racket field on it); the racket is selected purely by which racket feature is granted.
    /// </summary>
    public static ThiefRacketFeature BuildThiefRacket()
    {
        return new ThiefRacketFeature
        {
            FeatureId = "thief-racket",
            DisplayName = "Thief Racket",
            Description = "Use Dexterity instead of Strength for damage with finesse melee weapons.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    // ─────────────────────────────── Caster classes ───────────────────────────────

    /// <summary>
    /// Cleric (PF2e Remaster, Player Core "Cleric" class entry) — divine prepared full caster.
    /// HP 8/level, key ability Wis (spell DC derives from KeyAbility).
    ///
    /// Level-1 proficiencies (cross-checked against pf2e-source classes/cleric.json ranks:
    /// attacks{simple:1,unarmed:1,other:"Deity's favored weapon":1}, defenses{unarmored:1,
    /// light:0,medium:0,heavy:0}, saves{fort:1,reflex:1,will:2}, perception:1, spellcasting:1):
    ///   Perception Trained; Fort/Reflex Trained, Will Expert; simple/unarmed Trained, martial
    ///   Untrained; UNARMORED ONLY Trained (armor training is a Warpriest doctrine grant — the
    ///   old placeholder wrongly gave the base cleric light+medium); spell DC Trained.
    ///
    /// Deity's favored weapon: Trained at L1 (the FavoredWeapon progression entry below —
    /// resolved by ClassDefinition.GetWeaponProficiency when BuildChoices.Deity is set).
    ///
    /// Class features: Divine Font at L1 (HealingFontFeature) — reads the deity's
    /// FontSpellIdentity from BuildChoices (Aveline → heal font) and configures the
    /// DivineFontPool on the Spellcasting component. Requires the Spellcasting component to
    /// exist BEFORE features resolve (see PresetCharacters.BuildCaster ordering).
    ///
    /// Skills: Religion (class auto) + Medicine (Aveline's divine skill — deities grant their
    /// divine skill as a trained skill, mirroring the original RuntimeCharacterBuilder).
    /// </summary>
    public static ClassDefinition BuildCleric()
    {
        var cleric = new ClassDefinition
        {
            DefinitionId = "cleric",
            ClassName = "Cleric",
            Description = "A divine spellcaster who channels a deity's power.",
            HitPointsPerLevel = 8,
            KeyAbility = AbilityScore.Wisdom,
            RequiresDeity = true,

            PerceptionProficiency = ProficiencyLevel.Trained,
            FortitudeProficiency = ProficiencyLevel.Trained,
            ReflexProficiency = ProficiencyLevel.Trained,
            WillProficiency = ProficiencyLevel.Expert,

            UnarmedAttackProficiency = ProficiencyLevel.Trained,
            SimpleWeaponProficiency = ProficiencyLevel.Trained,
            MartialWeaponProficiency = ProficiencyLevel.Untrained,

            UnarmoredProficiency = ProficiencyLevel.Trained,
            LightArmorProficiency = ProficiencyLevel.Untrained,
            MediumArmorProficiency = ProficiencyLevel.Untrained,

            ClassDCProficiency = ProficiencyLevel.Trained,
            SpellProficiency = ProficiencyLevel.Trained,

            SpellcastingSource = new SpellcastingSource
            {
                SourceName = "Cleric Spellcasting",
                Tradition = SpellcastingTradition.Divine,
                CastingType = SpellcastingType.Prepared,
                KnowledgeType = SpellKnowledgeType.Spellbook, // personal list (see PresetCharacters)
                SpellcastingAbility = AbilityScore.Wisdom,
                ProgressionFormula = SpellProgressionFormula.Cleric,
                CantripsKnown = 5,
                MaxSpellLevel = 10,
            },

            AutoTrainedSkills = new List<Skill> { Skill.Religion, Skill.Medicine },
            AdditionalSkillChoices = 2,
        };

        // Divine Font (Cleric core, L1) — extra Heal slots at the highest castable rank.
        cleric.ClassFeatures = new List<LeveledFeature>
        {
            new LeveledFeature { Level = 1, Feature = BuildHealingFont() },
        };

        // Deity's favored weapon is Trained from L1 (cleric.json attacks.other rank 1).
        cleric.ProficiencyProgressions = new List<ProficiencyProgression>
        {
            new ProficiencyProgression { Level = 1, Target = ProficiencyTarget.FavoredWeapon, NewProficiency = ProficiencyLevel.Trained },
        };

        cleric.Subclasses = new List<SubclassDefinition> { BuildWarpriestSubclass() };
        return cleric;
    }

    /// <summary>Divine Font (Cleric core, L1) — configures the DivineFontPool from
    /// BuildChoices.Deity.FontSpellIdentity (Aveline → Heal). Compiled Pf2e.Core feature.
    /// Font slot count and rank are re-synced after level-up in PresetCharacters.BuildCaster.</summary>
    public static HealingFontFeature BuildHealingFont()
    {
        return new HealingFontFeature
        {
            FeatureId = "divine-font",
            DisplayName = "Divine Font (Heal)",
            Description = "Channel your deity's power: extra Heal castings at your highest spell rank.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
        };
    }

    /// <summary>
    /// Warpriest doctrine as a subclass overlay, per the pack classfeatures JSON schedule
    /// (first/second/third/fourth/fifth-doctrine-warpriest.json):
    ///  - First Doctrine (L1): trained light+medium armor, EXPERT Fortitude, Shield Block.
    ///    (Deadly Simplicity is NOT granted: it requires the deity's favored weapon to be
    ///    simple/unarmed, and Aveline's scimitar is martial.)
    ///  - Second Doctrine (L3): trained martial weapons.
    ///  - Third Doctrine (L7): expert simple/martial/unarmed + favored weapon; crit-spec on
    ///    favored-weapon crits (WarpriestThirdDoctrineFeature, compiled).
    ///  - Fourth Doctrine (L11): expert spell attack/DC.  Fifth Doctrine (L15): master
    ///    Fortitude (the success→crit-success upgrade rider is NOT implemented — deferred).
    /// </summary>
    public static SubclassDefinition BuildWarpriestSubclass()
    {
        return new SubclassDefinition
        {
            DefinitionId = "cleric-warpriest",
            SubclassName = "Warpriest",
            Description = "A cleric trained in the militant doctrine of the church: spells and battle.",
            KeyAbility = AbilityScore.Wisdom,

            ProficiencyOverrides = new List<ProficiencyOverride>
            {
                new ProficiencyOverride { Target = ProficiencyTarget.Fortitude, NewProficiency = ProficiencyLevel.Expert },
                new ProficiencyOverride { Target = ProficiencyTarget.LightArmor, NewProficiency = ProficiencyLevel.Trained },
                new ProficiencyOverride { Target = ProficiencyTarget.MediumArmor, NewProficiency = ProficiencyLevel.Trained },
            },

            SubclassFeatures = new List<LeveledFeature>
            {
                new LeveledFeature { Level = 1, Feature = BuildShieldBlock() },
                new LeveledFeature { Level = 7, Feature = BuildWarpriestThirdDoctrine() },
            },

            AdditionalProgressions = new List<ProficiencyProgression>
            {
                // Second Doctrine (L3): martial weapons trained.
                new ProficiencyProgression { Level = 3, Target = ProficiencyTarget.MartialWeapon, NewProficiency = ProficiencyLevel.Trained },
                // Third Doctrine (L7): simple/martial/unarmed + favored weapon expert.
                new ProficiencyProgression { Level = 7, Target = ProficiencyTarget.SimpleWeapon, NewProficiency = ProficiencyLevel.Expert },
                new ProficiencyProgression { Level = 7, Target = ProficiencyTarget.MartialWeapon, NewProficiency = ProficiencyLevel.Expert },
                new ProficiencyProgression { Level = 7, Target = ProficiencyTarget.UnarmedAttack, NewProficiency = ProficiencyLevel.Expert },
                new ProficiencyProgression { Level = 7, Target = ProficiencyTarget.FavoredWeapon, NewProficiency = ProficiencyLevel.Expert },
                // Fourth Doctrine (L11): spell attack/DC expert.
                new ProficiencyProgression { Level = 11, Target = ProficiencyTarget.SpellAttack, NewProficiency = ProficiencyLevel.Expert },
                // Fifth Doctrine (L15): Fortitude master (success→crit rider deferred).
                new ProficiencyProgression { Level = 15, Target = ProficiencyTarget.Fortitude, NewProficiency = ProficiencyLevel.Master },
            },
        };
    }

    /// <summary>Third Doctrine (Warpriest, L7) — critical specialization with the deity's favored
    /// weapon (reads BuildChoices.GetFavoredWeapon). Compiled Pf2e.Core feature; the paired
    /// weapon-proficiency bumps are AdditionalProgressions on the overlay.</summary>
    public static WarpriestThirdDoctrineFeature BuildWarpriestThirdDoctrine()
    {
        return new WarpriestThirdDoctrineFeature
        {
            FeatureId = "warpriest-third-doctrine",
            DisplayName = "Third Doctrine (Warpriest)",
            Description = "Critical hits with your deity's favored weapon apply its critical specialization effect.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 7,
        };
    }

    /// <summary>
    /// Wizard (PF2e Remaster, Player Core "Wizard" class entry) — arcane prepared full caster.
    /// HP 6/level, Int key ability, Trained spell proficiency, Trained simple weapons, unarmored
    /// only, Expert Will (cross-checked against pf2e-source classes/wizard.json). Auto-trains
    /// Arcana.
    ///
    /// Arcane thesis: SPELL BLENDING, set on the SpellcastingSource (the engine seam —
    /// Spellcasting.HasSpellBlending reads Sources[0].ArcaneThesis). The daily-prep trade
    /// decision is a static configuration applied at build time (see PresetCharacters).
    ///
    /// Arcane school: School of Battle Magic, granted by the subclass overlay below as a
    /// WizardSchoolFeature (focus spell + curriculum cantrips + the curriculum-restricted
    /// bonus slot per rank).
    /// </summary>
    public static ClassDefinition BuildWizard()
    {
        var wizard = new ClassDefinition
        {
            DefinitionId = "wizard",
            ClassName = "Wizard",
            Description = "An arcane spellcaster who studies magic from a spellbook.",
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
                ArcaneThesis = ArcaneThesis.SpellBlending,
            },

            AutoTrainedSkills = new List<Skill> { Skill.Arcana },
            AdditionalSkillChoices = 2,
        };

        wizard.Subclasses = new List<SubclassDefinition> { BuildBattleMagicSubclass() };
        return wizard;
    }

    /// <summary>
    /// "Battle Magic Wizard" — the School of Battle Magic expressed as a subclass overlay so the
    /// combo seam (ClassDefinition.ResolveSubclass) grants the school like any other subclass
    /// decision. The overlay's only payload is the L1 WizardSchoolFeature.
    /// </summary>
    public static SubclassDefinition BuildBattleMagicSubclass()
    {
        return new SubclassDefinition
        {
            DefinitionId = "wizard-battle-magic",
            SubclassName = "Battle Magic Wizard",
            Description = "A wizard of the School of Battle Magic: whirling energies for the battlefield.",
            KeyAbility = AbilityScore.Intelligence,

            SubclassFeatures = new List<LeveledFeature>
            {
                new LeveledFeature { Level = 1, Feature = BuildBattleMagicSchoolFeature() },
            },
        };
    }

    /// <summary>School of Battle Magic (Wizard, L1) — grants Force Bolt (+1 focus point), the
    /// curriculum cantrip, and the curriculum-restricted bonus preparation slot per rank
    /// (Spellcasting.SetSchoolSlots). Compiled Pf2e.Core feature + code-authored school data.</summary>
    public static WizardSchoolFeature BuildBattleMagicSchoolFeature()
    {
        return new WizardSchoolFeature
        {
            FeatureId = "school-of-battle-magic",
            DisplayName = "School of Battle Magic",
            Description = "Arcane study of war: curriculum spells and the Force Bolt focus spell.",
            Category = FeatureCategory.ClassFeature,
            LevelRequirement = 1,
            School = BuildBattleMagicSchool(),
        };
    }

    /// <summary>
    /// School of Battle Magic curriculum (pack school-of-battle-magic.json). Authored subset —
    /// only spells that exist in PresetSpells are referenced:
    ///   cantrips: Telekinetic Projectile (Shield is deferred — no sustain/AC-buff pipeline);
    ///   rank 1: Breathe Fire, Force Barrage (Mystic Armor deferred);
    ///   rank 2: none authored (Mist / Resist Energy deferred — the rank-2 school slot exists
    ///           but stays unfilled until a curriculum spell is authored);
    ///   rank 3: Fireball (Earthbind deferred).
    ///   School spells: initial Force Bolt (advanced Energy Absorption deferred).
    /// Curriculum ranks 4+ are beyond the preset ceiling (L5 → rank 3).
    /// </summary>
    public static WizardSchoolDefinition BuildBattleMagicSchool()
    {
        return new WizardSchoolDefinition
        {
            DefinitionId = "battle-magic",
            DisplayName = "School of Battle Magic",
            Description = "Magic is power, and there are always those who will use power for the art of battle.",
            InitialSpell = PresetSpells.Get(PresetSpells.ForceBoltId),
            CurriculumCantrips = new List<SpellAction>
            {
                PresetSpells.Get(PresetSpells.TelekineticProjectileId),
            },
            CurriculumSpells = new List<LeveledSpellGrant>
            {
                new LeveledSpellGrant { SpellRank = 1, Spell = PresetSpells.Get(PresetSpells.BreatheFireId) },
                new LeveledSpellGrant { SpellRank = 1, Spell = PresetSpells.Get(PresetSpells.ForceBarrageId) },
                new LeveledSpellGrant { SpellRank = 3, Spell = PresetSpells.Get(PresetSpells.FireballId) },
            },
        };
    }

    // ─────────────────────────────── Archetype (Free Archetype) feats ───────────────────────────────

    /// <summary>Reactive Shield (Fighter Feat 1, granted by Bastion Dedication) — reaction: Raise a
    /// Shield when a melee Strike would hit you. Compiled Pf2e.Core defense reaction.</summary>
    public static ReactiveShieldFeature BuildReactiveShield()
    {
        return new ReactiveShieldFeature
        {
            FeatureId = "reactive-shield",
            DisplayName = "Reactive Shield",
            Description = "Raise your shield as a reaction against an incoming melee Strike.",
            Category = FeatureCategory.ClassFeat,
            LevelRequirement = 1,
        };
    }

    /// <summary>Disarming Block (Bastion Feat 4) — free action Disarm when you Shield Block a melee
    /// Strike from a held weapon. Compiled Pf2e.Core post-damage reaction hook.</summary>
    public static DisarmingBlockFeature BuildDisarmingBlock()
    {
        return new DisarmingBlockFeature
        {
            FeatureId = "disarming-block",
            DisplayName = "Disarming Block",
            Description = "When you Shield Block a melee Strike, attempt to Disarm the attacker.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 4,
        };
    }

    /// <summary>Double Slice (Fighter Feat 1, granted by Dual-Weapon Warrior Dedication) — two
    /// Strikes, one per weapon, at the same MAP; off-hand −2 unless Agile. The feature is a
    /// carrier for the compiled DoubleSliceAction.</summary>
    public static CharacterFeature BuildDoubleSlice()
    {
        return new CharacterFeature
        {
            FeatureId = "double-slice",
            DisplayName = "Double Slice",
            Description = "Strike once with each of your two weapons at the same multiple attack penalty.",
            Category = FeatureCategory.ClassFeat,
            LevelRequirement = 1,
            GrantedActions = new List<PF2e.Actions.BaseAction> { new PF2e.Actions.DoubleSliceAction() },
        };
    }

    /// <summary>Dual-Weapon Warrior Dedication (Free Archetype feat, L2) — grants Double Slice
    /// (Remaster: the dedication itself grants the feat; confirmed against the pack JSON).
    /// Compiled Pf2e.Core feature; the granted Double Slice is wired here.</summary>
    public static DualWeaponWarriorDedicationFeature BuildDualWeaponWarriorDedication()
    {
        return new DualWeaponWarriorDedicationFeature
        {
            FeatureId = "dual-weapon-warrior-dedication",
            DisplayName = "Dual-Weapon Warrior Dedication",
            Description = "You're exceptional in your use of two weapons.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 2,
            DoubleSliceFeature = BuildDoubleSlice(),
        };
    }

    /// <summary>Dual Thrower (DWW Feat 4) — one-handed ranged/thrown weapons qualify for DWW feats.
    /// Compiled marker consumed by DoubleSliceAction.HasDualWeapons.</summary>
    public static DualThrowerFeature BuildDualThrower()
    {
        return new DualThrowerFeature
        {
            FeatureId = "dual-thrower",
            DisplayName = "Dual Thrower",
            Description = "Use thrown and one-handed ranged weapons with your dual-weapon techniques.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 4,
        };
    }

    /// <summary>Marshal Dedication (Free Archetype feat, L2) — Diplomacy/Intimidation upgrade +
    /// Marshal's Aura (15 ft, +1 status to saves vs fear for allies). Compiled Pf2e.Core
    /// aura provider.</summary>
    public static MarshalDedicationFeature BuildMarshalDedication()
    {
        return new MarshalDedicationFeature
        {
            FeatureId = "marshal-dedication",
            DisplayName = "Marshal Dedication",
            Description = "Your presence steadies your allies: +1 to saves against fear within 15 feet.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 2,
        };
    }

    /// <summary>Inspiring Marshal Stance (Marshal Feat 4, Remaster Player Core 2) — 1-action
    /// [stance]: Diplomacy check vs an easy DC of your level; on a success the marshal's aura
    /// (15 ft, from the dedication) grants you and allies +1 status to attack rolls and saves
    /// vs mental effects while the stance holds; crit failure locks the action for 1 minute.
    /// Compiled Pf2e.Core aura provider; the feature grants its own compiled action.</summary>
    public static InspiringMarshalStanceFeature BuildInspiringMarshalStance()
    {
        return new InspiringMarshalStanceFeature
        {
            FeatureId = "inspiring-marshal-stance",
            DisplayName = "Inspiring Marshal Stance",
            Description = "A stance of dedication and poise: your marshal's aura grants you and "
                + "allies +1 status to attack rolls and saves against mental effects.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 4,
        };
    }

    /// <summary>Battle Medicine (Skill Feat 1) — 1-action in-combat Medicine patch-up. Carrier for
    /// the compiled BattleMedicineAction (cost/target metadata is construction-site config,
    /// mirroring PlayerActionExecutor.MakeSkillAction).</summary>
    public static BattleMedicineFeature BuildBattleMedicine()
    {
        return new BattleMedicineFeature
        {
            FeatureId = "battle-medicine",
            DisplayName = "Battle Medicine",
            Description = "Patch up wounds, even in combat (1 action).",
            Category = FeatureCategory.SkillFeat,
            LevelRequirement = 1,
            GrantedActions = new List<PF2e.Actions.BaseAction>
            {
                new PF2e.Actions.SkillActions.BattleMedicineAction
                {
                    ActionName = "Battle Medicine", ActionCostCount = 1,
                    RequiresTarget = true, TargetMode = TargetMode.Allies, CanTargetSelf = true,
                },
            },
        };
    }

    /// <summary>Medic Dedication (Free Archetype feat, L2) — Medicine → Expert (compiled; the
    /// Battle Medicine / Treat Wounds HP-bonus rider is deferred, see the engine feature doc).</summary>
    public static MedicDedicationFeature BuildMedicDedication()
    {
        return new MedicDedicationFeature
        {
            FeatureId = "medic-dedication",
            DisplayName = "Medic Dedication",
            Description = "You become an expert medical practitioner.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 2,
        };
    }

    /// <summary>Treat Condition (Medic Feat 4) — 2-action Medicine counteract to reduce Clumsy,
    /// Enfeebled or Sickened on an adjacent ally. Carrier for the compiled TreatConditionAction.</summary>
    public static TreatConditionFeature BuildTreatCondition()
    {
        return new TreatConditionFeature
        {
            FeatureId = "treat-condition",
            DisplayName = "Treat Condition",
            Description = "Reduce an ally's Clumsy, Enfeebled, or Sickened condition with quick treatment.",
            Category = FeatureCategory.DedicationFeat,
            LevelRequirement = 4,
            GrantedActions = new List<PF2e.Actions.BaseAction>
            {
                new PF2e.Actions.SkillActions.TreatConditionAction
                {
                    ActionName = "Treat Condition", ActionCostCount = 2,
                    RequiresTarget = true, TargetMode = TargetMode.Allies,
                },
            },
        };
    }
}
