using System.Collections.Generic;
using Bulwark.Data;
using PF2e.CharacterComponents;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Import;
using PF2e.RuleEvents;
using PF2e.Utilities;

namespace Bulwark.Presets;

/// <summary>
/// Code-authored player characters. Assembles a Stats-based PF2eCharacter the same way
/// CreatureFactory assembles a monster, but driven by a ClassDefinition + subclass overlay +
/// scripted Free-Archetype level-up (Pf2e.Core has no built-in PC factory).
///
/// Requires GameDataLoader to be loaded first (equipment is resolved from the packs).
/// </summary>
public static class PresetCharacters
{
    /// <summary>
    /// Build "the Veteran": a Fighter (Sentinel) PC with a longsword, steel shield and chain mail.
    /// At level >= 2 the combo's scripted Free-Archetype choice (Bastion Dedication) is applied.
    /// </summary>
    public static PF2eCharacter BuildVeteran(int level, int teamId = 1)
    {
        return BuildFighterSentinel(
            id: "the-veteran",
            name: "the Veteran",
            level: level,
            teamId: teamId,
            strength: 18, dexterity: 14, constitution: 14,
            intelligence: 10, wisdom: 12, charisma: 10,
            shieldSlug: "steel-shield");
    }

    /// <summary>
    /// Build "the Recruit": a second Fighter (Sentinel), same class/combo as the Veteran but with
    /// NO shield (exercises the Raise-Shield-disabled path) and a balanced Str/Dex emphasis.
    /// </summary>
    public static PF2eCharacter BuildRecruit(int level, int teamId = 1)
    {
        return BuildFighterSentinel(
            id: "the-recruit",
            name: "the Recruit",
            level: level,
            teamId: teamId,
            strength: 16, dexterity: 16, constitution: 14,
            intelligence: 10, wisdom: 12, charisma: 10,
            shieldSlug: null);
    }

    /// <summary>
    /// Shared Fighter (Sentinel) build core. At level 1 the Fighter + Sentinel overlay is fully
    /// resolved and its features granted. At level >= 2, LevelUpApplicator replays the combo's
    /// scripted choices and the newly granted feats are resolved onto the sheet.
    /// </summary>
    private static PF2eCharacter BuildFighterSentinel(
        string id, string name, int level, int teamId,
        int strength, int dexterity, int constitution,
        int intelligence, int wisdom, int charisma,
        string? shieldSlug)
    {
        if (level < 1) level = 1;

        PresetCombos.EnsureFeaturesRegistered();

        // --- Resolve class + subclass overlay ---
        var fighter = PresetClasses.BuildFighter();
        var combo = PresetCombos.FighterSentinel;
        ClassDefinition resolvedClass = fighter.ResolveSubclass(combo.Subclass);

        // --- Ability scores + stats (start at level 1; level up applied below) ---
        var modifiers = new ModifierStack();
        var stats = new PF2eCharacterStats(modifiers)
        {
            CharacterClass = resolvedClass,
            Level = 1,
            Strength = strength,
            Dexterity = dexterity,
            Constitution = constitution,
            Intelligence = intelligence,
            Wisdom = wisdom,
            Charisma = charisma,
            BaseSpeedInFeet = 25,
        };

        var character = new PF2eCharacter
        {
            Id = id,
            Name = name,
            TeamId = teamId,
            Stats = stats,
            StatProvider = stats,
            Modifiers = modifiers,
            Combat = new CombatState(),
            RuleEvents = new RuleEventBus(),
            Actions = new ActionResource(),
            // Build choices must exist BEFORE features resolve: WeaponMasteryFeature (L5) reads
            // ChosenWeaponGroup for its critical-specialization gate, and WeaponAttackCalculator
            // consults it for group-restricted progressions. Sword is a data implication of the
            // longsword loadout every Fighter preset carries — NOT a pending combo choice.
            BuildChoices = new CharacterBuildChoices { ChosenWeaponGroup = WeaponGroup.Sword },
        };

        // --- Defenses / health / conditions ---
        character.DefenseProfile = new DefenseProfile(character.RuleEvents);
        // usesDying:true — PCs use the full PF2e dying rules. A downed PC becomes
        // Dying + Unconscious (not dead); the DyingSystem is wired below once Conditions exists.
        character.Health = new Health(character, usesDying: true);
        character.Health.Initialize();
        character.CooldownTracker = new AbilityCooldownTracker();

        // --- Equipment (longsword + optional shield + chain mail, resolved from packs) ---
        var appendages = new AppendageTracker(AppendageLayout.Humanoid());
        character.Appendages = appendages;

        ShieldManager? shield = null;
        if (shieldSlug != null)
        {
            var shieldDef = FindShield(shieldSlug);
            if (shieldDef != null)
            {
                shield = new ShieldManager(character, appendages);
                shield.SetEquippedShield(shieldDef);
            }
        }

        var equipment = new EquipmentHolder(appendages, shield!, character.Modifiers);
        character.Equipment = equipment;
        equipment.SetStartingLoadout(
            mainHand: FindWeapon("longsword"),
            offHand: null,
            armor: FindArmor("chain-mail"));
        equipment.Initialize();

        character.Conditions = new ConditionTracker(
            character, character.Actions, character.Modifiers, character.DefenseProfile);

        // Dying rules: Health delegates zero-HP handling to the DyingSystem, which drives
        // Dying/Wounded/Unconscious via the ConditionTracker. Must be constructed after Conditions.
        // CombatSession subscribes/unsubscribes it to the per-encounter TurnManager (recovery checks).
        character.Health.DyingSystem = new DyingSystem(character, character.Health, character.Conditions);

        // --- Skills (Trained Athletics for Trip + Intimidation for Demoralize come from the class
        //     + Sentinel overlay's auto-trained skill list). ---
        character.Skills = new SkillProficiencies();
        character.Skills.ApplyClassSkills(resolvedClass);

        // --- Features (ancestry/heritage/background are null; class + subclass features grant here) ---
        var features = new FeatureHolder();
        character.Features = features;
        features.Initialize(character);
        features.ResolveAndGrantFeatures();

        // --- Level up (replays scripted Free-Archetype choices) ---
        if (level >= 2)
        {
            var choices = combo.ChoicesUpTo(level);
            LevelUpApplicator.ApplyLevelUp(character, fromLevel: 1, toLevel: level, choices);

            // ApplyLevelUp only appends the chosen feats to the FeatureHolder; re-resolve so the
            // new free-archetype feat (Bastion Dedication) is actually granted at its level.
            features.ResolveAndGrantFeatures();

            // Health caches MaxHP at Initialize; recompute now that the level (and HP) changed.
            character.Health.Initialize();
        }

        return character;
    }

    // ══════════════════════════ Rogue (Scout) ══════════════════════════

    /// <summary>
    /// Build "the Scout": a Dex-based Rogue with a rapier (finesse) + leather armor. Sneak Attack,
    /// Surprise Attack and the placeholder Thief racket are granted at level 1; Deny Advantage at 3;
    /// Weapon Tricks at 5. Built at the target level directly (no Free-Archetype combo — the racket
    /// and any archetype are pending design review), then class features resolve by level. Mirrors the
    /// caster assembly (stats → components → Health → equipment → conditions → skills → features) plus
    /// the WP4 dying wiring.
    /// </summary>
    public static PF2eCharacter BuildScout(int level, int teamId = 1)
    {
        if (level < 1) level = 1;

        var modifiers = new ModifierStack();
        var stats = new PF2eCharacterStats(modifiers)
        {
            CharacterClass = PresetClasses.BuildRogue(),
            Level = level,
            Strength = 12, Dexterity = 18, Constitution = 12,
            Intelligence = 12, Wisdom = 14, Charisma = 12,
            BaseSpeedInFeet = 25,
        };

        var character = new PF2eCharacter
        {
            Id = "the-scout",
            Name = "the Scout",
            TeamId = teamId,
            Stats = stats,
            StatProvider = stats,
            Modifiers = modifiers,
            Combat = new CombatState(),
            RuleEvents = new RuleEventBus(),
            Actions = new ActionResource(),
            // Rapier (and shortsword) are Sword group — a data implication of the finesse loadout, not
            // a combo choice. No rogue feature reads ChosenWeaponGroup; set for consistency/future use.
            BuildChoices = new CharacterBuildChoices { ChosenWeaponGroup = WeaponGroup.Sword },
        };

        character.DefenseProfile = new DefenseProfile(character.RuleEvents);
        // usesDying:true — PCs use the full PF2e dying rules (DyingSystem wired after Conditions).
        character.Health = new Health(character, usesDying: true);
        character.Health.Initialize();
        character.CooldownTracker = new AbilityCooldownTracker();

        // --- Equipment (rapier + leather armor, no shield) ---
        var appendages = new AppendageTracker(AppendageLayout.Humanoid());
        character.Appendages = appendages;
        var equipment = new EquipmentHolder(appendages, null!, character.Modifiers);
        character.Equipment = equipment;
        equipment.SetStartingLoadout(
            mainHand: FindWeapon("rapier"),
            offHand: null,
            armor: FindArmor("leather-armor"));
        equipment.Initialize();

        character.Conditions = new ConditionTracker(
            character, character.Actions, character.Modifiers, character.DefenseProfile);

        // Dying rules (see BuildFighterSentinel): wire after Conditions exists.
        character.Health.DyingSystem = new DyingSystem(character, character.Health, character.Conditions);

        // --- Skills: Stealth (class auto) + Thievery + Intimidation (Demoralize chip) ---
        character.Skills = new SkillProficiencies();
        character.Skills.ApplyClassSkills(stats.CharacterClass);
        character.Skills.SetProficiency(Skill.Thievery, ProficiencyLevel.Trained);
        character.Skills.SetProficiency(Skill.Intimidation, ProficiencyLevel.Trained);

        // --- Features (rogue class features grant by level) ---
        var features = new FeatureHolder();
        character.Features = features;
        features.Initialize(character);
        features.ResolveAndGrantFeatures();

        return character;
    }

    // ══════════════════════════ Caster placeholders ══════════════════════════
    //
    // PLACEHOLDER build — class combos pending design review. The Medic and Scholar exist to
    // exercise the spell + skill-action layer. The assembly (Spellcasting component wiring, slot
    // init, prepared loadout, skill proficiencies) is real; the class chassis and prepared spell
    // list are throwaway. No doctrine / thesis / dedication is chosen.

    /// <summary>
    /// Build "the Medic": a Cleric with a warhammer + chain shirt, Trained Medicine (for Battle
    /// Medicine), and a placeholder prepared loadout (cantrips Divine Lance + Daze; 3×rank-1:
    /// Heal, Heal, Fear).
    /// </summary>
    public static PF2eCharacter BuildMedic(int level, int teamId = 1)
    {
        return BuildCaster(
            id: "the-medic",
            name: "the Medic",
            classDef: PresetClasses.BuildCleric(),
            level: level,
            teamId: teamId,
            strength: 12, dexterity: 12, constitution: 14,
            intelligence: 10, wisdom: 18, charisma: 12,
            weaponSlug: "warhammer",
            armorSlug: "chain-shirt",
            cantripIds: new[] { PresetSpells.DivineLanceId, PresetSpells.DazeId },
            preparedRank1: new[] { PresetSpells.HealId, PresetSpells.HealId, PresetSpells.FearId },
            extraTrainedSkills: new[] { Skill.Medicine });
    }

    /// <summary>
    /// Build "the Scholar": a Wizard with a staff and no armor, and a placeholder prepared loadout
    /// (cantrips Electric Arc + Ignition + Frostbite; 3×rank-1: Breathe Fire, Fear, Breathe Fire).
    /// </summary>
    public static PF2eCharacter BuildScholar(int level, int teamId = 1)
    {
        return BuildCaster(
            id: "the-scholar",
            name: "the Scholar",
            classDef: PresetClasses.BuildWizard(),
            level: level,
            teamId: teamId,
            strength: 10, dexterity: 14, constitution: 12,
            intelligence: 18, wisdom: 12, charisma: 10,
            weaponSlug: "staff",
            armorSlug: null,
            cantripIds: new[] { PresetSpells.ElectricArcId, PresetSpells.IgnitionId, PresetSpells.FrostbiteId },
            preparedRank1: new[] { PresetSpells.BreatheFireId, PresetSpells.FearId, PresetSpells.BreatheFireId },
            extraTrainedSkills: null);
    }

    /// <summary>
    /// Shared prepared-caster assembly. Mirrors the Fighter core (stats → components → Health →
    /// equipment → conditions → skills → features) then adds the Spellcasting component, initializes
    /// slots, learns the loadout into the personal spellbook, and prepares the rank-1 list.
    /// KnowledgeType is Spellbook for both placeholders (robust reference-identity preparation) —
    /// see PresetClasses for the rationale.
    /// </summary>
    private static PF2eCharacter BuildCaster(
        string id, string name, ClassDefinition classDef, int level, int teamId,
        int strength, int dexterity, int constitution, int intelligence, int wisdom, int charisma,
        string weaponSlug, string? armorSlug,
        string[] cantripIds, string[] preparedRank1, Skill[]? extraTrainedSkills)
    {
        if (level < 1) level = 1;

        // Ensure the preset spells exist in SpellDatabase before we prepare from them.
        PresetSpells.EnsureRegistered();

        var modifiers = new ModifierStack();
        var stats = new PF2eCharacterStats(modifiers)
        {
            CharacterClass = classDef,
            Level = level,
            Strength = strength,
            Dexterity = dexterity,
            Constitution = constitution,
            Intelligence = intelligence,
            Wisdom = wisdom,
            Charisma = charisma,
            BaseSpeedInFeet = 25,
        };

        var character = new PF2eCharacter
        {
            Id = id,
            Name = name,
            TeamId = teamId,
            Stats = stats,
            StatProvider = stats,
            Modifiers = modifiers,
            Combat = new CombatState(),
            RuleEvents = new RuleEventBus(),
            Actions = new ActionResource(),
            // Build choices must be non-null before features resolve. Deity is intentionally left
            // unset — HealingFontFeature (Divine Font) no-ops without a deity, and choosing one is a
            // combo decision pending design review. The placeholder casters read nothing else from it.
            BuildChoices = new CharacterBuildChoices(),
        };

        character.DefenseProfile = new DefenseProfile(character.RuleEvents);
        // usesDying:true — PCs use the full PF2e dying rules (DyingSystem wired after Conditions).
        character.Health = new Health(character, usesDying: true);
        character.Health.Initialize();
        character.CooldownTracker = new AbilityCooldownTracker();

        // --- Equipment ---
        var appendages = new AppendageTracker(AppendageLayout.Humanoid());
        character.Appendages = appendages;
        var equipment = new EquipmentHolder(appendages, null!, character.Modifiers);
        character.Equipment = equipment;
        equipment.SetStartingLoadout(
            mainHand: FindWeapon(weaponSlug),
            offHand: null,
            armor: armorSlug != null ? FindArmor(armorSlug) : null);
        equipment.Initialize();

        character.Conditions = new ConditionTracker(
            character, character.Actions, character.Modifiers, character.DefenseProfile);

        // Dying rules (see BuildFighterSentinel): wire after Conditions exists.
        character.Health.DyingSystem = new DyingSystem(character, character.Health, character.Conditions);

        // --- Skills ---
        character.Skills = new SkillProficiencies();
        character.Skills.ApplyClassSkills(classDef);
        if (extraTrainedSkills != null)
            foreach (var skill in extraTrainedSkills)
                character.Skills.SetProficiency(skill, ProficiencyLevel.Trained);

        // --- Features ---
        var features = new FeatureHolder();
        character.Features = features;
        features.Initialize(character);
        features.ResolveAndGrantFeatures();

        // --- Spellcasting: source + slots + prepared loadout ---
        var spellcasting = new Spellcasting(character, stats);
        spellcasting.Sources.Add(classDef.SpellcastingSource);
        spellcasting.InitializeSlots();
        character.Spellcasting = spellcasting;

        foreach (var cantripId in cantripIds)
            spellcasting.Cantrips.Add(PresetSpells.Get(cantripId));

        // Learn each unique rank-1 spell into the spellbook, then prepare (duplicates allowed).
        var prepared = new List<PF2e.Actions.SpellAction>();
        var learned = new HashSet<string>();
        foreach (var spellId in preparedRank1)
        {
            var spell = PresetSpells.Get(spellId);
            if (learned.Add(spellId))
                spellcasting.LearnSpell(spell);
            prepared.Add(spell);
        }
        spellcasting.PrepareSpells(prepared);

        return character;
    }

    private static WeaponDefinition? FindWeapon(string slug)
    {
        var imported = GameDataLoader.FindEquipment(slug);
        if (imported == null) return null;

        // Boolean weapon traits (finesse/agile/reach/...) are populated by the engine importer —
        // ImportedEquipment.MapTraitsToWeapon carries every raw trait id onto def.Traits.
        return imported.ToWeaponDefinition();
    }

    private static ArmorDefinition? FindArmor(string slug)
    {
        return GameDataLoader.FindEquipment(slug)?.ToArmorDefinition();
    }

    private static ShieldDefinition? FindShield(string slug)
    {
        return GameDataLoader.FindEquipment(slug)?.ToShieldDefinition();
    }
}
