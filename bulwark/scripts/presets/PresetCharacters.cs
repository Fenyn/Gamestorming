using System;
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
    // Squad member ids — the single source the roster, sprite map, save data and daily-casting
    // switch all key on (SquadRoster re-exposes them as aliases for existing call sites).
    public const string VeteranId = "the-veteran";
    public const string RecruitId = "the-recruit";
    public const string ScoutId = "the-scout";
    public const string MedicId = "the-medic";
    public const string ScholarId = "the-scholar";

    // Authored daily-casting loadouts, shared by the initial build and the in-place level-up
    // refresh (RefreshDailyCasting) so both prepare the identical lists.
    private static readonly string[] MedicCantripIds =
        { PresetSpells.DivineLanceId, PresetSpells.DazeId };
    private static readonly string[] MedicPreparedSpellIds =
        { PresetSpells.HealId, PresetSpells.HealId, PresetSpells.FearId };
    private static readonly string[] ScholarCantripIds =
        { PresetSpells.ElectricArcId, PresetSpells.IgnitionId, PresetSpells.FrostbiteId };
    private static readonly string[] ScholarPreparedSpellIds =
    {
        // Rank 1 (curriculum first: Breathe Fire and Force Barrage may fill the school slot)
        PresetSpells.BreatheFireId, PresetSpells.ForceBarrageId,
        PresetSpells.BreatheFireId, PresetSpells.FearId,
        // Rank 3 (curriculum; auto-dropped below L5 where no rank-3 slots exist)
        PresetSpells.FireballId, PresetSpells.FireballId,
        PresetSpells.FireballId, PresetSpells.FireballId,
    };

    /// <summary>
    /// Build "the Veteran": a Fighter (Sentinel) PC with a longsword, steel shield and chain mail.
    /// At level >= 2 the combo's scripted Free-Archetype choice (Bastion Dedication) is applied.
    /// </summary>
    public static PF2eCharacter BuildVeteran(int level, int teamId = 1)
    {
        return BuildFighterSentinel(
            id: VeteranId,
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
            id: RecruitId,
            name: "the Recruit",
            level: level,
            teamId: teamId,
            strength: 16, dexterity: 16, constitution: 14,
            intelligence: 10, wisdom: 12, charisma: 10,
            shieldSlug: null);
    }

    /// <summary>
    /// Shared Fighter (Sentinel) parameterization: longsword + chain mail (+ optional shield).
    /// At level 1 the Fighter + Sentinel overlay is fully resolved and its features granted. At
    /// level >= 2, the chassis replays the combo's scripted choices.
    /// </summary>
    private static PF2eCharacter BuildFighterSentinel(
        string id, string name, int level, int teamId,
        int strength, int dexterity, int constitution,
        int intelligence, int wisdom, int charisma,
        string? shieldSlug)
    {
        return BuildChassis(new ChassisSpec
        {
            Id = id,
            Name = name,
            Level = level,
            TeamId = teamId,
            BaseClass = PresetClasses.BuildFighter(),
            Combo = PresetCombos.FighterSentinel,
            Strength = strength, Dexterity = dexterity, Constitution = constitution,
            Intelligence = intelligence, Wisdom = wisdom, Charisma = charisma,
            MainHand = FindWeapon("longsword"),
            ArmorSlug = "chain-mail",
            ShieldSlug = shieldSlug,
            // Sword is a data implication of the longsword loadout every Fighter preset carries —
            // NOT a pending combo choice.
            ChosenWeaponGroup = WeaponGroup.Sword,
        });
    }

    // ══════════════════════════ Rogue (Scout) ══════════════════════════

    /// <summary>
    /// Build "the Scout": a Dex-based Thief-racket Rogue dual-wielding a rapier (finesse) and an
    /// agile finesse shortsword off-hand, in leather armor. Locked combo: Thief subclass overlay +
    /// Dual-Weapon Warrior Free Archetype line (L2 DWW Dedication → grants Double Slice; L4 Dual
    /// Thrower). Built at level 1 then leveled via LevelUpApplicator so every scripted combo
    /// choice takes effect at build — same seam as the Fighter presets.
    /// </summary>
    public static PF2eCharacter BuildScout(int level, int teamId = 1)
    {
        return BuildChassis(new ChassisSpec
        {
            Id = ScoutId,
            Name = "the Scout",
            Level = level,
            TeamId = teamId,
            BaseClass = PresetClasses.BuildRogue(),
            Combo = PresetCombos.RogueThief,
            Strength = 12, Dexterity = 18, Constitution = 12,
            Intelligence = 12, Wisdom = 14, Charisma = 12,
            MainHand = FindWeapon("rapier"),
            OffHand = FindWeapon("shortsword"),
            ArmorSlug = "leather-armor",
            // Rapier and shortsword are Sword group — a data implication of the finesse loadout,
            // not a combo choice. No rogue feature reads ChosenWeaponGroup; set for consistency.
            ChosenWeaponGroup = WeaponGroup.Sword,
            // Stealth comes from the class auto-trained list; Thievery + Intimidation (Demoralize
            // chip) are the Scout's extra trained picks.
            ExtraTrainedSkills = new[] { Skill.Thievery, Skill.Intimidation },
        });
    }

    // ══════════════════════════ Casters (Medic / Scholar) ══════════════════════════

    /// <summary>
    /// Build "the Medic": the lone soldier-priest who held the outpost. Cleric with the
    /// WARPRIEST doctrine overlay (light/medium armor + Shield Block at L1, Expert Fort,
    /// martial @3), deity AVELINE (heal divine font, favored weapon scimitar, divine skill
    /// Medicine, holy sanctification), and the MARSHAL Free Archetype line (L2 dedication:
    /// fear-save aura + Diplomacy upgrade; L4 Inspiring Marshal Stance). Equipment: Aveline's
    /// scimitar (the SAME
    /// WeaponDefinition instance the favored-weapon checks compare against), steel shield
    /// (Shield Block), breastplate (medium — what First Doctrine grants).
    /// Prepared loadout: cantrips Divine Lance + Daze; rank 1 Heal ×2 + Fear. Heal casts are
    /// paid from the divine font pool first (4 slots at the highest castable rank).
    /// </summary>
    public static PF2eCharacter BuildMedic(int level, int teamId = 1)
    {
        var aveline = PresetDeities.Aveline;
        return BuildCaster(
            id: MedicId,
            name: "the Medic",
            baseClass: PresetClasses.BuildCleric(),
            combo: PresetCombos.ClericWarpriest,
            level: level,
            teamId: teamId,
            strength: 12, dexterity: 12, constitution: 14,
            intelligence: 10, wisdom: 18, charisma: 12,
            mainHand: aveline.FavoredWeapon,
            armorSlug: "breastplate",
            shieldSlug: "steel-shield",
            deity: aveline,
            cantripIds: MedicCantripIds,
            preparedSpellIds: MedicPreparedSpellIds,
            // Religion + Medicine come from the class list (Medicine = Aveline's divine skill).
            // Diplomacy: Inspiring Marshal Stance prerequisite ("trained in Diplomacy") and the
            // skill its stance check rolls — the Marshal Dedication upgrade path now lands on
            // Diplomacy (trained → expert) instead of Intimidation.
            extraTrainedSkills: new[] { Skill.Diplomacy });
    }

    /// <summary>
    /// Build "the Scholar": a Wizard of the SCHOOL OF BATTLE MAGIC (Force Bolt focus spell,
    /// curriculum cantrip, +1 curriculum-restricted slot per rank) with the SPELL BLENDING
    /// thesis (static daily-prep config: 2 rank-1 slots → 1 slot at the highest castable rank,
    /// applied once rank 2+ unlocks) and the MEDIC Free Archetype line (L2 Battle Medicine +
    /// Medic Dedication → Medicine Expert; L4 Treat Condition). Staff, no armor.
    /// Prepared loadout (curriculum-first so the school slots are legally filled; trimmed to
    /// the level's actual slots): rank 1 Breathe Fire + Force Barrage (+ Breathe Fire + Fear
    /// while pre-blending slots exist); rank 3 Fireball ×4 once unlocked at L5.
    /// </summary>
    public static PF2eCharacter BuildScholar(int level, int teamId = 1)
    {
        return BuildCaster(
            id: ScholarId,
            name: "the Scholar",
            baseClass: PresetClasses.BuildWizard(),
            combo: PresetCombos.WizardBattleMagic,
            level: level,
            teamId: teamId,
            strength: 10, dexterity: 14, constitution: 12,
            intelligence: 18, wisdom: 12, charisma: 10,
            mainHand: FindWeapon("staff"),
            armorSlug: null,
            shieldSlug: null,
            deity: null,
            cantripIds: ScholarCantripIds,
            preparedSpellIds: ScholarPreparedSpellIds,
            // Medicine trained at build: prerequisite for the L2 Battle Medicine skill feat and
            // Medic Dedication (which upgrades it to Expert).
            extraTrainedSkills: new[] { Skill.Medicine });
    }

    /// <summary>
    /// Shared prepared-caster assembly on top of <see cref="BuildChassis"/>, with two ordering
    /// rules specific to casters:
    ///  1. The Spellcasting component is created and slot-initialized BEFORE features resolve
    ///     (the chassis' BeforeFeatures hook) — WizardSchoolFeature (focus spell, curriculum
    ///     cantrips, school slots) and HealingFontFeature (divine font pool) both write into it
    ///     when granted.
    ///  2. After the level-up replay, slots are refilled (fresh character at full), the divine
    ///     font is re-synced to the final level/highest rank, the static Spell Blending trade is
    ///     applied, and the prepared loadout is trimmed to the final slot layout and prepared.
    /// </summary>
    private static PF2eCharacter BuildCaster(
        string id, string name, ClassDefinition baseClass, VariantComboDefinition combo,
        int level, int teamId,
        int strength, int dexterity, int constitution, int intelligence, int wisdom, int charisma,
        WeaponDefinition? mainHand, string? armorSlug, string? shieldSlug, DeityDefinition? deity,
        string[] cantripIds, string[] preparedSpellIds, Skill[]? extraTrainedSkills)
    {
        if (level < 1) level = 1;

        // Ensure the preset spells exist in SpellDatabase before we prepare from them.
        PresetSpells.EnsureRegistered();

        var character = BuildChassis(new ChassisSpec
        {
            Id = id,
            Name = name,
            Level = level,
            TeamId = teamId,
            BaseClass = baseClass,
            Combo = combo,
            Strength = strength, Dexterity = dexterity, Constitution = constitution,
            Intelligence = intelligence, Wisdom = wisdom, Charisma = charisma,
            MainHand = mainHand,
            ArmorSlug = armorSlug,
            ShieldSlug = shieldSlug,
            Deity = deity,
            ChosenWeaponGroup = mainHand?.Group ?? WeaponGroup.Sword,
            ExtraTrainedSkills = extraTrainedSkills,
            // Spellcasting BEFORE features (caster ordering rule #1): school/font features write
            // into it on grant.
            BeforeFeatures = (c, stats) =>
            {
                var casting = new Spellcasting(c, stats);
                casting.Sources.Add(stats.CharacterClass.SpellcastingSource);
                casting.InitializeSlots();
                c.Spellcasting = casting;
            },
        });

        var spellcasting = character.Spellcasting!;
        ApplySpellBlending(spellcasting);

        // Fresh character: slots/focus at full for the final level, then sync the divine font
        // (HealingFontFeature configured it at L1; count and rank scale with level).
        spellcasting.RefillSlots();
        spellcasting.RefillFocusPoints();
        if (deity?.FontSpellIdentity != null && spellcasting.DivineFont != null)
            spellcasting.DivineFont.Configure(deity.FontSpellIdentity, level, spellcasting.HighestSlotRank);

        // --- Cantrips (school curriculum cantrips were already added by the feature) ---
        foreach (var cantripId in cantripIds)
        {
            var cantrip = PresetSpells.Get(cantripId);
            if (cantrip != null && !spellcasting.Cantrips.Contains(cantrip))
                spellcasting.Cantrips.Add(cantrip);
        }

        // --- Learn + prepare the authored loadout, trimmed to the final slot layout ---
        PrepareLoadout(spellcasting, preparedSpellIds);

        return character;
    }

    // ══════════════════════════ Shared chassis ══════════════════════════

    /// <summary>Parameter block for <see cref="BuildChassis"/> — one property per axis the four
    /// preset builds vary on.</summary>
    private sealed class ChassisSpec
    {
        public string Id { get; init; } = "";
        public string Name { get; init; } = "";
        public int Level { get; init; } = 1;
        public int TeamId { get; init; } = 1;
        public ClassDefinition BaseClass { get; init; } = null!;
        public VariantComboDefinition Combo { get; init; } = null!;
        public int Strength { get; init; }
        public int Dexterity { get; init; }
        public int Constitution { get; init; }
        public int Intelligence { get; init; }
        public int Wisdom { get; init; }
        public int Charisma { get; init; }
        public WeaponDefinition? MainHand { get; init; }
        public WeaponDefinition? OffHand { get; init; }
        public string? ArmorSlug { get; init; }
        public string? ShieldSlug { get; init; }
        public DeityDefinition? Deity { get; init; }
        public WeaponGroup ChosenWeaponGroup { get; init; } = WeaponGroup.Sword;
        public Skill[]? ExtraTrainedSkills { get; init; }

        /// <summary>Runs after skills, immediately before the FeatureHolder resolves — the caster
        /// seam that must inject Spellcasting before school/font features grant.</summary>
        public Action<PF2eCharacter, PF2eCharacterStats>? BeforeFeatures { get; init; }
    }

    /// <summary>
    /// The single PC assembly sequence all four presets share (rules-bearing — fix it HERE, once):
    /// stats → components → defenses/health → equipment → conditions → DyingSystem → skills →
    /// [BeforeFeatures hook] → features → scripted level-up replay.
    /// </summary>
    private static PF2eCharacter BuildChassis(ChassisSpec spec)
    {
        int level = spec.Level < 1 ? 1 : spec.Level;

        PresetCombos.EnsureFeaturesRegistered();

        // --- Resolve class + subclass overlay ---
        ClassDefinition resolvedClass = spec.BaseClass.ResolveSubclass(spec.Combo.Subclass);

        // --- Ability scores + stats (start at level 1; level up applied below) ---
        var modifiers = new ModifierStack();
        var stats = new PF2eCharacterStats(modifiers)
        {
            CharacterClass = resolvedClass,
            Level = 1,
            Strength = spec.Strength,
            Dexterity = spec.Dexterity,
            Constitution = spec.Constitution,
            Intelligence = spec.Intelligence,
            Wisdom = spec.Wisdom,
            Charisma = spec.Charisma,
            BaseSpeedInFeet = 25,
        };

        var character = new PF2eCharacter
        {
            Id = spec.Id,
            Name = spec.Name,
            TeamId = spec.TeamId,
            Stats = stats,
            StatProvider = stats,
            Modifiers = modifiers,
            Combat = new CombatState(),
            RuleEvents = new RuleEventBus(),
            Actions = new ActionResource(),
            // Build choices must exist BEFORE features resolve: WeaponMasteryFeature (L5) reads
            // ChosenWeaponGroup for its critical-specialization gate and WeaponAttackCalculator
            // consults it for group-restricted progressions; HealingFontFeature reads the deity's
            // FontSpellIdentity, favored-weapon proficiency reads GetFavoredWeapon(), and
            // WarpriestThirdDoctrine compares strikes against it.
            BuildChoices = new CharacterBuildChoices
            {
                ChosenWeaponGroup = spec.ChosenWeaponGroup,
                Deity = spec.Deity,
                Sanctification = spec.Deity?.AllowedSanctification ?? SanctificationType.None,
            },
        };

        // --- Defenses / health / conditions ---
        character.DefenseProfile = new DefenseProfile(character.RuleEvents);
        // usesDying:true — PCs use the full PF2e dying rules. A downed PC becomes
        // Dying + Unconscious (not dead); the DyingSystem is wired below once Conditions exists.
        character.Health = new Health(character, usesDying: true);
        character.Health.Initialize();
        character.CooldownTracker = new AbilityCooldownTracker();

        // --- Equipment (main hand / optional off-hand, shield and armor, resolved from packs) ---
        var appendages = new AppendageTracker(AppendageLayout.Humanoid());
        character.Appendages = appendages;

        ShieldManager? shield = null;
        if (spec.ShieldSlug != null)
        {
            var shieldDef = FindShield(spec.ShieldSlug);
            if (shieldDef != null)
            {
                shield = new ShieldManager(character, appendages);
                shield.SetEquippedShield(shieldDef);
            }
        }

        var equipment = new EquipmentHolder(appendages, shield!, character.Modifiers);
        character.Equipment = equipment;
        equipment.SetStartingLoadout(
            mainHand: spec.MainHand,
            offHand: spec.OffHand,
            armor: spec.ArmorSlug != null ? FindArmor(spec.ArmorSlug) : null);
        equipment.Initialize();

        character.Conditions = new ConditionTracker(
            character, character.Actions, character.Modifiers, character.DefenseProfile);

        // Dying rules: Health delegates zero-HP handling to the DyingSystem, which drives
        // Dying/Wounded/Unconscious via the ConditionTracker. Must be constructed after Conditions.
        // CombatSession subscribes/unsubscribes it to the per-encounter TurnManager (recovery checks).
        character.Health.DyingSystem = new DyingSystem(character, character.Health, character.Conditions);

        // --- Skills (class + subclass overlay auto-trained list, then the spec's extra picks) ---
        character.Skills = new SkillProficiencies();
        character.Skills.ApplyClassSkills(resolvedClass);
        if (spec.ExtraTrainedSkills != null)
            foreach (var skill in spec.ExtraTrainedSkills)
                character.Skills.SetProficiency(skill, ProficiencyLevel.Trained);

        // --- Pre-feature hook (casters inject Spellcasting here) ---
        spec.BeforeFeatures?.Invoke(character, stats);

        // --- Features (ancestry/heritage/background are null; class + subclass features grant here) ---
        var features = new FeatureHolder();
        character.Features = features;
        features.Initialize(character);
        features.ResolveAndGrantFeatures();

        // --- Level up (replays the combo's scripted choices, incl. Free Archetype feats) ---
        if (level >= 2)
        {
            var choices = spec.Combo.ChoicesUpTo(level);
            LevelUpApplicator.ApplyLevelUp(character, fromLevel: 1, toLevel: level, choices);

            // ApplyLevelUp only appends the chosen feats to the FeatureHolder; re-resolve so the
            // newly granted feats (e.g. the free-archetype dedication) are actually granted at
            // their level.
            features.ResolveAndGrantFeatures();

            // Health caches MaxHP at Initialize; recompute now that the level (and HP) changed.
            character.Health.Initialize();
        }

        return character;
    }

    /// <summary>
    /// Re-run the level-dependent daily-casting decisions on a LIVE preset member after an
    /// in-place level-up — the same post-level steps <see cref="BuildCaster"/> runs on a fresh
    /// build, so a member leveled in place ends mechanically identical to one built at that
    /// level: the Spell Blending trade re-targets the new highest castable rank, the divine
    /// font is re-sized per its level table (4 → 5 slots at L5) at the new highest rank, and
    /// the authored loadout is re-learned/re-prepared into the new slot layout (the Scholar's
    /// rank-3 Fireballs unlock at L5). No-op for non-casters. Does NOT refill slots or focus —
    /// the caller's rest flow owns that (font Configure does reset its own pool, which the
    /// nightly rest refills anyway).
    /// </summary>
    public static void RefreshDailyCasting(PF2eCharacter character)
    {
        var spellcasting = character.Spellcasting;
        if (spellcasting == null)
            return;

        PresetSpells.EnsureRegistered();
        ApplySpellBlending(spellcasting);

        var deity = character.BuildChoices?.Deity;
        if (deity?.FontSpellIdentity != null && spellcasting.DivineFont != null)
        {
            spellcasting.DivineFont.Configure(
                deity.FontSpellIdentity, character.Stats?.Level ?? 1, spellcasting.HighestSlotRank);
        }

        string[]? loadout = character.Id switch
        {
            MedicId => MedicPreparedSpellIds,
            ScholarId => ScholarPreparedSpellIds,
            _ => null,
        };
        if (loadout != null)
            PrepareLoadout(spellcasting, loadout);
    }

    /// <summary>
    /// Spell Blending (static daily-prep decision, documented MVP simplification): trade
    /// 2 rank-1 slots for 1 slot at the highest castable rank above 1 (bonus rank must be
    /// ≤ sacrifice+2 and actually have base slots — both hold for ranks 2-3 at the L2-5
    /// preset band). Below rank-2 access there is no legal slot trade. No-op without the
    /// Spell Blending thesis. SetBlendTrades replaces any previous trade, so re-running at
    /// a higher level re-targets the bonus rank instead of stacking.
    /// </summary>
    private static void ApplySpellBlending(Spellcasting spellcasting)
    {
        if (!spellcasting.HasSpellBlending)
            return;

        int bonusRank = 0;
        for (int rank = 3; rank >= 2; rank--)
        {
            if (spellcasting.GetBaseMaxSlots(rank) > 0) { bonusRank = rank; break; }
        }
        if (bonusRank <= 0)
            return;

        var trades = new List<SpellBlendTrade>
        {
            new SpellBlendTrade { SacrificeRank = 1, BonusRank = bonusRank },
        };
        if (spellcasting.ValidateBlendTrades(trades))
            spellcasting.SetBlendTrades(trades);
    }

    /// <summary>
    /// Learn each unique authored spell (ranks the caster can actually cast) and prepare the
    /// loadout, trimming overflow so PrepareSpells always succeeds: per rank, total preparations
    /// are capped at max slots and NON-curriculum preparations at the unrestricted (non-school)
    /// slots. Authored lists put curriculum spells first so school slots are filled greedily.
    /// </summary>
    private static void PrepareLoadout(Spellcasting spellcasting, string[] preparedSpellIds)
    {
        var school = spellcasting.SchoolSlotSchool;
        var prepared = new List<PF2e.Actions.SpellAction>();
        var totalByRank = new int[11];
        var nonCurriculumByRank = new int[11];
        var learned = new HashSet<string>();

        foreach (var spellId in preparedSpellIds)
        {
            var spell = PresetSpells.Get(spellId);
            if (spell?.Spell == null) continue;

            int rank = spell.Spell.SpellLevel;
            if (rank < 1 || rank > 10) continue;
            if (rank > spellcasting.HighestSlotRank) continue; // not castable yet — skip learn too

            if (learned.Add(spellId))
                spellcasting.LearnSpell(spell);

            if (totalByRank[rank] >= spellcasting.GetMaxSlots(rank))
                continue; // rank full

            bool isCurriculum = school != null && school.IsCurriculumSpell(spell);
            if (!isCurriculum)
            {
                int unrestricted = spellcasting.GetMaxSlots(rank) - spellcasting.GetSchoolBonusSlots(rank);
                if (nonCurriculumByRank[rank] >= unrestricted)
                    continue; // only the school slot remains and this spell isn't curriculum
                nonCurriculumByRank[rank]++;
            }

            totalByRank[rank]++;
            prepared.Add(spell);
        }

        spellcasting.PrepareSpells(prepared);
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
