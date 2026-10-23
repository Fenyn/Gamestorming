using System.Collections.Generic;
using PF2e.CharacterComponents;
using PF2e.Core;
using PF2e.Data;
using PF2e.RuleEvents;
using PF2e.RuleEvents.Features;

namespace Ungilded.Content;

/// <summary>
/// The Prologue's sewer creatures as custom stat blocks (spec section 5, with the section 8 fixes:
/// the Tyrant's weakness is acid, Vicious Bite bleeds). All are Animal, Beast faction, low-light
/// vision and scent 30 ft. Every call returns a fresh definition, so a creature feature never
/// carries handlers between encounters.
/// </summary>
public static class PrologueBestiary
{
    public const string SewerRatId = "sewer_rat";
    public const string ViciousSewerRatId = "vicious_sewer_rat";
    public const string DireSewerRatId = "dire_sewer_rat";
    public const string SewerTyrantId = "sewer_tyrant";

    public const int TyrantAcidWeakness = 7;

    /// <summary>The definition for a creature id above, or null for an unknown id.</summary>
    public static EnemyDefinition? Find(string creatureId) => creatureId switch
    {
        SewerRatId => SewerRat(),
        ViciousSewerRatId => ViciousSewerRat(),
        DireSewerRatId => DireSewerRat(),
        SewerTyrantId => SewerTyrant(),
        _ => null,
    };

    /// <summary>A combatant for a creature id. <paramref name="maxHp"/> replaces the stat block HP
    /// (the encounter overrides in spec section 3).</summary>
    public static PF2eCharacter Create(string creatureId, int teamId = 2, int? maxHp = null)
    {
        var def = Find(creatureId)
            ?? throw new KeyNotFoundException($"[PrologueBestiary] Unknown creature id '{creatureId}'.");
        var creature = CreatureFactory.Create(def, teamId);
        if (maxHp is int hp) creature.Health.OverrideMaxHP(hp);
        return creature;
    }

    public static EnemyDefinition SewerRat() => Define(SewerRatId, "Sewer Rat",
        "A mangy rat the size of a small dog, thriving in the neglected tunnels beneath the city.",
        new CreatureStatBlockData
        {
            CreatureLevel = -1, CreatureSize = CreatureSize.Small,
            SpeedInFeet = 30, ClimbSpeedFeet = 10,
            AC = 15, FortSave = 6, RefSave = 7, WillSave = 3, MaxHP = 8,
            Str = 1, Dex = 3, Con = 2, Int = -4, Wis = 1, Cha = -3,
            Perception = 5,
            Strikes = new[] { Jaws(7, 6, 1, agile: true, finesse: true) },
            SkillOverrides = Skills((Skill.Acrobatics, 5), (Skill.Athletics, 2), (Skill.Stealth, 5)),
        });

    /// <summary>The Sewer Rat block plus Vicious Bite (1d4 persistent bleed on a Jaws hit). It
    /// shares the Sewer Rat's name, so the board shows no difference (spec section 3, Encounter 3
    /// Rat 4).</summary>
    /// <summary>The persistent bleed a Vicious Sewer Rat's Jaws hit deals.</summary>
    public static DiceFormula ViciousBleed => new(1, 4, 0);

    public static EnemyDefinition ViciousSewerRat()
    {
        var def = SewerRat();
        def.CreatureId = ViciousSewerRatId;
        def.Description = "A particularly aggressive sewer rat with a bite that causes persistent bleeding.";
        def.CreatureFeatures = new CharacterFeature[]
        {
            new ViciousBiteFeature
            {
                FeatureId = "vicious-bite",
                DisplayName = "Vicious Bite",
                Description = "A Jaws hit deals 1d4 persistent bleed damage.",
                Category = FeatureCategory.CreatureAbility,
                StrikeName = JawsName,
                BleedDice = ViciousBleed,
                PersistentType = DamageType.Bleed,
            },
        };
        return def;
    }

    public static EnemyDefinition DireSewerRat() => Define(DireSewerRatId, "Dire Sewer Rat",
        "A massive sewer rat, twice the size of its lesser kin. Its bite carries the filth of a century of neglect.",
        new CreatureStatBlockData
        {
            CreatureLevel = 0, CreatureSize = CreatureSize.Small,
            SpeedInFeet = 30, ClimbSpeedFeet = 10,
            AC = 16, FortSave = 5, RefSave = 5, WillSave = 2, MaxHP = 16,
            Str = 2, Dex = 3, Con = 2, Int = -4, Wis = 1, Cha = -3,
            Perception = 5,
            Strikes = new[] { Jaws(8, 8, 2, agile: false, finesse: true) },
            SkillOverrides = Skills((Skill.Acrobatics, 6), (Skill.Stealth, 6)),
        });

    public static EnemyDefinition SewerTyrant()
    {
        var def = Define(SewerTyrantId, "Sewer Tyrant",
            "A grotesquely mutated rat the size of a pony. Its hide splits and reforms as it moves, and it reeks of alchemical corruption.",
            new CreatureStatBlockData
            {
                // Large and long: a 2x2 space, and Jaws keeps the default 5 ft reach.
                CreatureLevel = 1, CreatureSize = CreatureSize.Large,
                SpeedInFeet = 25,
                AC = 17, FortSave = 7, RefSave = 4, WillSave = 3, MaxHP = 35,
                Str = 3, Dex = 1, Con = 3, Int = -4, Wis = 1, Cha = -2,
                Perception = 6,
                Strikes = new[] { Jaws(9, 10, 3, agile: false, finesse: false) },
                SkillOverrides = Skills((Skill.Athletics, 7), (Skill.Stealth, 5)),
            });
        def.Weaknesses = new[] { new DamageAffinity(DamageType.Acid, TyrantAcidWeakness) };
        // The PDF gives the Tyrant one hidden ability slot. No ability is written for it yet.
        return def;
    }

    private const string JawsName = "Jaws";
    private const int ScentRangeFeet = 30;

    private static EnemyDefinition Define(string id, string name, string description, CreatureStatBlockData stats)
    {
        stats.Vision = VisionType.LowLight;
        stats.ScentRangeFeet = ScentRangeFeet;
        return new EnemyDefinition
        {
            CreatureId = id,
            CreatureName = name,
            Description = description,
            Faction = FactionType.Beast,
            CreatureTraits = new TraitCollection(new[]
            {
                new TraitDefinition { TraitId = "animal", DisplayName = "Animal", Category = TraitCategory.CreatureType },
            }),
            StatBlock = stats,
        };
    }

    private static CreatureStrike Jaws(int attackBonus, int dieSize, int modifier, bool agile, bool finesse)
    {
        var traits = new TraitCollection();
        if (agile) traits.AddTrait(new TraitDefinition { TraitId = TraitIds.Agile, DisplayName = "Agile" });
        if (finesse) traits.AddTrait(new TraitDefinition { TraitId = TraitIds.Finesse, DisplayName = "Finesse" });
        return new CreatureStrike
        {
            StrikeName = JawsName,
            AttackBonus = attackBonus,
            DamageDice = new DiceFormula(1, dieSize, modifier),
            DamageType = DamageType.Piercing,
            IsAgile = agile,
            IsFinesse = finesse,
            StrikeTraits = traits,
        };
    }

    private static SkillEntry[] Skills(params (Skill Skill, int Bonus)[] entries)
    {
        var skills = new SkillEntry[entries.Length];
        for (int i = 0; i < entries.Length; i++)
            skills[i] = new SkillEntry { Skill = entries[i].Skill, Bonus = entries[i].Bonus };
        return skills;
    }
}
