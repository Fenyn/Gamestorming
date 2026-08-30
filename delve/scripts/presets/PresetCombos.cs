using System.Collections.Generic;
using Delve.Data;
using PF2e.Data;
using PF2e.RuleEvents;

namespace Delve.Presets;

/// <summary>
/// The four LOCKED variant combos (one per squad member) plus the FeatureDatabase registration
/// that lets <c>LevelUpApplicator</c> resolve scripted feats by id.
///
/// Free Archetype rule: an extra archetype feat slot at every even level (2/4/6/8/10). Each
/// line's dedication lands at L2. Levels whose archetype feats have no compiled engine feature
/// are left unscripted and documented — the level-up seam simply grants nothing there until the
/// feature is ported (the FA slot is banked, not burned on a dead marker).
///
/// The presets are built at level 2 and authored to L5; ChoicesUpTo(level) replays every scripted
/// decision at build, so all L1-5 choices take effect immediately, and the L6-10 script is ready
/// for the level-up milestone.
/// </summary>
public static class PresetCombos
{
    /// <summary>
    /// Veteran — Fighter "Sentinel" subclass overlay + BASTION Free Archetype line.
    /// L2 Bastion Dedication (grants Reactive Shield), L4 Disarming Block.
    /// L6 Nimble Shield Hand / L8 Drive Back / L10 Destructive Block: no compiled features —
    /// deferred (FA slots left unscripted).
    /// </summary>
    public static VariantComboDefinition FighterSentinel { get; } = new()
    {
        Id = "fighter-sentinel-bastion",
        DisplayName = "Fighter (Sentinel) — Bastion",
        Description =
            "A shield-focused Fighter: the Sentinel subclass overlay plus the Bastion "
            + "archetype line taken with the free-archetype feat slots.",
        Subclass = PresetClasses.BuildSentinelSubclass(),
        ScriptedChoices = new Dictionary<int, LevelUpChoices>
        {
            [2] = new LevelUpChoices { Level = 2, FreeArchetypeFeatId = "bastion-dedication" },
            [4] = new LevelUpChoices { Level = 4, FreeArchetypeFeatId = "disarming-block" },
        },
    };

    /// <summary>
    /// Elara — Rogue "Thief" racket overlay + DUAL-WEAPON WARRIOR Free Archetype line.
    /// L2 DWW Dedication (grants Double Slice per the Remaster pack JSON), L4 Dual Thrower.
    /// L8 Flensing Slice / L10 Dual-Weapon Blitz: compiled marker features exist but their
    /// ACTIONS are not ported yet — deferred (FA slots left unscripted).
    /// Skill increases (rogue cadence: L2 and every level after, rogue.json) are deliberately
    /// unscripted — LevelUpApplicator auto-assigns them from Elara's trained skills.
    /// </summary>
    public static VariantComboDefinition RogueThief { get; } = new()
    {
        Id = "rogue-thief-dual-weapon",
        DisplayName = "Rogue (Thief) — Dual-Weapon Warrior",
        Description =
            "A dual-wielding Thief-racket Rogue: rapier and agile shortsword, with the "
            + "Dual-Weapon Warrior archetype line in the free-archetype slots.",
        Subclass = PresetClasses.BuildThiefSubclass(),
        ScriptedChoices = new Dictionary<int, LevelUpChoices>
        {
            [2] = new LevelUpChoices { Level = 2, FreeArchetypeFeatId = "dual-weapon-warrior-dedication" },
            [4] = new LevelUpChoices { Level = 4, FreeArchetypeFeatId = "dual-thrower" },
        },
    };

    /// <summary>
    /// Medic — Cleric "Warpriest" doctrine overlay + MARSHAL Free Archetype line.
    /// Deity: Aveline (heal font, favored weapon scimitar) — set on CharacterBuildChoices at
    /// build, not here (the combo is class-shaped data; the deity is a character decision).
    /// L2 Marshal Dedication. L4 Inspiring Marshal Stance (compiled: stance + aura-while-in-
    /// stance via the engine's StanceRules/AuraSystem; grants its own stance action).
    /// </summary>
    public static VariantComboDefinition ClericWarpriest { get; } = new()
    {
        Id = "cleric-warpriest-marshal",
        DisplayName = "Cleric (Warpriest) — Marshal",
        Description =
            "The lone soldier-priest who held the outpost: Warpriest doctrine (armor, Shield "
            + "Block, martial training) with the Marshal archetype line rallying the relief squad.",
        Subclass = PresetClasses.BuildWarpriestSubclass(),
        ScriptedChoices = new Dictionary<int, LevelUpChoices>
        {
            [2] = new LevelUpChoices { Level = 2, FreeArchetypeFeatId = "marshal-dedication" },
            [4] = new LevelUpChoices { Level = 4, FreeArchetypeFeatId = "inspiring-marshal-stance" },
        },
    };

    /// <summary>
    /// Fenwick — Wizard "Battle Magic" school overlay (+ Spell Blending thesis, which lives on
    /// the wizard's SpellcastingSource) + MEDIC Free Archetype line.
    /// L2 Battle Medicine skill feat (Medic Dedication prerequisite) + Medic Dedication
    /// (Medicine → Expert); L4 Treat Condition. L6 Holistic Care / L8 Preventative Treatment:
    /// no compiled features — deferred.
    /// </summary>
    public static VariantComboDefinition WizardBattleMagic { get; } = new()
    {
        Id = "wizard-battle-magic-medic",
        DisplayName = "Wizard (Battle Magic) — Medic",
        Description =
            "A battle-mage field surgeon: School of Battle Magic curriculum + Spell Blending "
            + "thesis, with the Medic archetype line in the free-archetype slots.",
        Subclass = PresetClasses.BuildBattleMagicSubclass(),
        ScriptedChoices = new Dictionary<int, LevelUpChoices>
        {
            [2] = new LevelUpChoices
            {
                Level = 2,
                SkillFeatId = "battle-medicine",
                FreeArchetypeFeatId = "medic-dedication",
            },
            [4] = new LevelUpChoices { Level = 4, FreeArchetypeFeatId = "treat-condition" },
        },
    };

    /// <summary>
    /// Ensure a FeatureDatabase.Instance exists that can resolve every feat id referenced by the
    /// combos' scripted level-up choices. Idempotent — safe to call before every build.
    /// </summary>
    public static void EnsureFeaturesRegistered()
    {
        if (FeatureDatabase.Instance != null)
            return;

        FeatureDatabase.Instance = new FeatureDatabase
        {
            Features = new List<CharacterFeature>
            {
                // Bastion line (Veteran)
                PresetClasses.BuildBastionDedication(),
                PresetClasses.BuildDisarmingBlock(),
                // Dual-Weapon Warrior line (Elara)
                PresetClasses.BuildDualWeaponWarriorDedication(),
                PresetClasses.BuildDualThrower(),
                // Marshal line (Medic)
                PresetClasses.BuildMarshalDedication(),
                PresetClasses.BuildInspiringMarshalStance(),
                // Medic line (Fenwick)
                PresetClasses.BuildBattleMedicine(),
                PresetClasses.BuildMedicDedication(),
                PresetClasses.BuildTreatCondition(),
                // Subclass marker kept resolvable for tooling/debug lookups.
                PresetClasses.BuildSentinelShieldFocus(),
            },
        };
    }
}
