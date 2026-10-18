using System;
using System.Collections.Generic;
using PF2e.CharacterComponents;
using PF2e.Classes;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Import;
using PF2e.RuleEvents;
using Ungilded.Presets;

namespace Ungilded.Content;

/// <summary>
/// The two Prologue pregens (spec section 4), level 1 only. The Player is a Guard Fighter with a
/// longsword, scale mail and a steel shield. The Friend is a Criminal Alchemist (Bomber) with a
/// dagger, leather armour, Sneak Attack 1d6 and two lesser acid flasks. Both are Wintertouched
/// Humans. Requires GameDataLoader (equipment comes from the packs).
/// </summary>
public static class PrologueCast
{
    public const string PlayerId = "player";
    public const string FriendId = "friend";
    public const string PlayerName = "The Player";
    public const string FriendName = "The Friend";
    public const int Level = 1;
    public const int FriendAcidFlasks = 2;
    public const int FriendSneakAttackDie = 6;

    /// <summary>General Training takes Intimidating Prowess when the Player qualifies and
    /// Intimidating Glare otherwise. At level 1 the Player does not qualify.</summary>
    public static PF2eCharacter BuildPlayer(int teamId = 1)
    {
        var generalPick = PrologueOrigins.IntimidatingProwess();
        return Assemble(new HeroSpec
        {
            Id = PlayerId,
            Name = PlayerName,
            TeamId = teamId,
            Class = PresetClasses.BuildFighter(),
            Background = PrologueOrigins.Guard(),
            Boosts = new[]
            {
                // ancestry, background, four free, class key
                AbilityScore.Strength, AbilityScore.Charisma,
                AbilityScore.Strength, AbilityScore.Charisma,
                AbilityScore.Strength, AbilityScore.Constitution, AbilityScore.Dexterity, AbilityScore.Charisma,
                AbilityScore.Strength,
            },
            MainHand = Weapon("longsword"),
            ArmorSlug = "scale-mail",
            ShieldSlug = "steel-shield",
            WeaponGroup = WeaponGroup.Sword,
            ChosenSkills = new[] { Skill.Medicine, Skill.Acrobatics, Skill.Survival },
            Lores = new[] { PrologueOrigins.WarfareLore },
            Feats = new[] { PrologueOrigins.GeneralTraining(), PrologueOrigins.SuddenCharge() },
            // Prerequisites read skills, so the pick is checked once skills are trained.
            GeneralFeat = c => generalPick.MeetsPrerequisites(c) ? generalPick : PrologueOrigins.IntimidatingGlare(),
        });
    }

    public static PF2eCharacter BuildFriend(int teamId = 1, int acidFlasks = FriendAcidFlasks)
    {
        var character = Assemble(new HeroSpec
        {
            Id = FriendId,
            Name = FriendName,
            TeamId = teamId,
            Class = AlchemistClass.BuildBomber(),
            Background = PrologueOrigins.Criminal(),
            Boosts = new[]
            {
                AbilityScore.Intelligence, AbilityScore.Dexterity,
                AbilityScore.Dexterity, AbilityScore.Intelligence,
                AbilityScore.Intelligence, AbilityScore.Dexterity, AbilityScore.Wisdom, AbilityScore.Constitution,
                AbilityScore.Intelligence,
            },
            MainHand = Weapon("dagger"),
            ArmorSlug = "leather-armor",
            WeaponGroup = WeaponGroup.Knife,
            // 3 + Int 4 class skill choices.
            ChosenSkills = new[]
            {
                Skill.Medicine, Skill.Nature, Skill.Acrobatics, Skill.Arcana,
                Skill.Deception, Skill.Intimidation, Skill.Society,
            },
            Lores = new[] { PrologueOrigins.AlchemyLore },
            Feats = new[] { PrologueOrigins.GeneralTraining(), PrologueOrigins.SneakAttack(FriendSneakAttackDie) },
            GeneralFeat = _ => PrologueOrigins.IncredibleInitiative(),
            FormulaBook = AlchemistClass.CreateFormulaBook(
                AlchemicalItems.AcidFlaskLesserId,
                AlchemicalItems.AlchemistsFireLesserId,
                AlchemicalItems.BottledLightningLesserId,
                AlchemicalItems.FrostVialLesserId,
                AlchemicalItems.ElixirOfLifeMinorId),
        });
        // Encounter loadout only: no daily preparations, so no versatile vials or infused items.
        character.Equipment.Consumables.SetCount(AlchemicalItems.AcidFlaskLesserId, acidFlasks);
        return character;
    }

    /// <summary>Base 10 plus 2 per boost, 1 per boost once a score is 18 or more (Player Core).</summary>
    public static int ScoreFor(AbilityScore ability, IReadOnlyList<AbilityScore> boosts)
    {
        int score = 10;
        foreach (var boost in boosts)
            if (boost == ability) score += score >= 18 ? 1 : 2;
        return score;
    }

    private sealed class HeroSpec
    {
        public string Id = "";
        public string Name = "";
        public int TeamId = 1;
        public ClassDefinition Class = null!;
        public BackgroundDefinition Background = null!;
        public AbilityScore[] Boosts = Array.Empty<AbilityScore>();
        public WeaponDefinition? MainHand;
        public string? ArmorSlug;
        public string? ShieldSlug;
        public WeaponGroup WeaponGroup;
        public Skill[] ChosenSkills = Array.Empty<Skill>();
        public string[] Lores = Array.Empty<string>();
        public CharacterFeature[] Feats = Array.Empty<CharacterFeature>();
        public Func<PF2eCharacter, CharacterFeature> GeneralFeat = null!;
        public FormulaBook? FormulaBook;
    }

    /// <summary>The PresetCharacters chassis order: stats, components, defenses and health,
    /// equipment, conditions, dying, skills, features, then health again for feature HP.</summary>
    private static PF2eCharacter Assemble(HeroSpec spec)
    {
        var ancestry = PrologueOrigins.Human();
        var modifiers = new ModifierStack();
        var stats = new PF2eCharacterStats(modifiers)
        {
            CharacterClass = spec.Class,
            Ancestry = ancestry,
            Heritage = PrologueOrigins.Wintertouched(),
            Background = spec.Background,
            Level = Level,
            Strength = ScoreFor(AbilityScore.Strength, spec.Boosts),
            Dexterity = ScoreFor(AbilityScore.Dexterity, spec.Boosts),
            Constitution = ScoreFor(AbilityScore.Constitution, spec.Boosts),
            Intelligence = ScoreFor(AbilityScore.Intelligence, spec.Boosts),
            Wisdom = ScoreFor(AbilityScore.Wisdom, spec.Boosts),
            Charisma = ScoreFor(AbilityScore.Charisma, spec.Boosts),
            BaseSpeedInFeet = ancestry.BaseSpeedInFeet,
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
            BuildChoices = new CharacterBuildChoices
            {
                ChosenWeaponGroup = spec.WeaponGroup,
                FormulaBook = spec.FormulaBook,
            },
        };

        character.DefenseProfile = new DefenseProfile(character.RuleEvents);
        character.Health = new Health(character, usesDying: true);
        character.Health.Initialize();
        character.CooldownTracker = new AbilityCooldownTracker();

        var appendages = new AppendageTracker(AppendageLayout.Humanoid());
        character.Appendages = appendages;
        ShieldManager? shield = null;
        if (spec.ShieldSlug != null)
        {
            shield = new ShieldManager(character, appendages);
            shield.SetEquippedShield(Equipment(spec.ShieldSlug).ToShieldDefinition());
        }
        character.Equipment = new EquipmentHolder(appendages, shield!, modifiers);
        character.Equipment.SetStartingLoadout(
            mainHand: spec.MainHand,
            offHand: null,
            armor: spec.ArmorSlug != null ? Equipment(spec.ArmorSlug).ToArmorDefinition() : null);
        character.Equipment.Initialize();

        character.Conditions = new ConditionTracker(character, character.Actions, modifiers, character.DefenseProfile);
        character.Health.DyingSystem = new DyingSystem(character, character.Health, character.Conditions);

        character.Skills = new SkillProficiencies();
        character.Skills.ApplyClassSkills(spec.Class);
        foreach (var skill in spec.Background.GrantedSkills)
            character.Skills.SetProficiency(skill, ProficiencyLevel.Trained);
        foreach (var skill in spec.ChosenSkills)
            character.Skills.SetProficiency(skill, ProficiencyLevel.Trained);
        foreach (string lore in spec.Lores)
            character.Skills.SetSpecificLore(lore, ProficiencyLevel.Trained);

        var features = new FeatureHolder();
        character.Features = features;
        features.Initialize(character);
        foreach (var feat in spec.Feats)
            features.AddChosenFeat(new LeveledFeature { Level = Level, Feature = feat });
        features.AddChosenFeat(new LeveledFeature { Level = Level, Feature = spec.GeneralFeat(character) });
        features.ResolveAndGrantFeatures();

        character.Health.Initialize();
        character.Actions.RefillActions();
        return character;
    }

    private static WeaponDefinition Weapon(string slug) => Equipment(slug).ToWeaponDefinition();

    private static ImportedEquipment Equipment(string slug) => GameDataLoader.FindEquipment(slug)
        ?? throw new InvalidOperationException($"[PrologueCast] Pack item '{slug}' not found. Load GameDataLoader first.");
}
