using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Flow;

/// <summary>
/// The reference text the sheet's tooltips quote: what each ability governs, what each skill is
/// for, and what a weapon trait does. These are rules facts that no built character carries, so
/// they live in one table rather than being written at each call site. Everything numeric in a
/// tooltip comes from the character; only these sentences are fixed.
///
/// Godot-free.
/// </summary>
public static class HeroSheetTips
{
    // Attribute lines open with the Archives of Nethys wording (2e.aonprd.com/Rules.aspx?ID=67),
    // then one sentence of what the number drives on this sheet.
    private static readonly Dictionary<AbilityScore, string> AbilityRoles = new()
    {
        [AbilityScore.Strength] =
            "Strength measures your character's physical power. It adds to melee attack rolls, "
            + "melee damage, and Athletics.",
        [AbilityScore.Dexterity] =
            "Dexterity measures your character's agility, balance, and reflexes. It adds to AC, "
            + "Reflex saves, ranged attacks, and finesse weapons.",
        [AbilityScore.Constitution] =
            "Constitution measures your character's overall health and stamina. It adds Hit "
            + "Points at every level and feeds Fortitude saves.",
        [AbilityScore.Intelligence] =
            "Intelligence measures how well your character can learn and reason. It grants extra "
            + "trained skills and sets an arcane caster's spell attack and DC.",
        [AbilityScore.Wisdom] =
            "Wisdom measures your character's common sense, awareness, and intuition. It adds to "
            + "Perception, Will saves, and a divine caster's spell attack and DC.",
        [AbilityScore.Charisma] =
            "Charisma measures your character's personal magnetism and strength of personality. "
            + "It adds to Deception, Diplomacy and Intimidation, and an occult or primal caster's "
            + "spell attack and DC.",
    };

    // Skill descriptions are the remastered opening text of each skill's Archives of Nethys page
    // (2e.aonprd.com/Skills.aspx, IDs 34-50), quoted verbatim so the card reads as the rules do.
    private static readonly Dictionary<Skill, string> SkillRoles = new()
    {
        [Skill.Acrobatics] = "Acrobatics measures your ability to perform tasks requiring coordination and grace.",
        [Skill.Arcana] = "Arcana measures how much you know about arcane magic and creatures.",
        [Skill.Athletics] = "Athletics allows you to perform deeds of physical prowess.",
        [Skill.Crafting] = "You can use this skill to create and repair items.",
        [Skill.Deception] = "You can trick and mislead others using disguises, lies, and other forms of subterfuge.",
        [Skill.Diplomacy] = "You influence others through negotiation and flattery, or find out information through friendly chats.",
        [Skill.Intimidation] = "You bend others to your will using threats.",
        [Skill.Medicine] = "You can patch up wounds and help people recover from diseases and poisons.",
        [Skill.Nature] = "You know about the natural world, and you command and train animals and magical beasts.",
        [Skill.Occultism] = "You know a great deal about ancient philosophies, esoteric lore, obscure mysticism, and supernatural creatures.",
        [Skill.Performance] = "You are skilled at a form of performance, using your talents to impress a crowd or make a living.",
        [Skill.Religion] = "The secrets of deities, dogma, faith, and the realms of divine creatures both sublime and sinister are open to you.",
        [Skill.Society] = "You understand the people and systems that make civilization run, and you know the historical events that make societies what they are today.",
        [Skill.Stealth] = "You are skilled at avoiding detection, allowing you to slip past foes, hide, or conceal an item.",
        [Skill.Survival] = "You are adept at living in the wilderness, foraging for food and building shelter, and with training you discover the secrets of tracking and hiding your trail.",
        [Skill.Thievery] = "You are trained in a particular set of skills favored by thieves and miscreants.",
    };

    /// <summary>The signature actions the skill is rolled for, named as the rules name them.</summary>
    private static readonly Dictionary<Skill, string> SkillActions = new()
    {
        [Skill.Acrobatics] = "Balance, Tumble Through, Maneuver in Flight, Squeeze",
        [Skill.Arcana] = "Recall Knowledge, Identify Magic, Learn a Spell",
        [Skill.Athletics] = "Climb, Swim, Jump, Grapple, Shove, Trip, Disarm",
        [Skill.Crafting] = "Craft, Repair, Recall Knowledge, Identify Alchemy",
        [Skill.Deception] = "Lie, Feint, Impersonate, Create a Diversion",
        [Skill.Diplomacy] = "Make an Impression, Request, Gather Information",
        [Skill.Intimidation] = "Demoralize, Coerce",
        [Skill.Medicine] = "Treat Wounds, Administer First Aid, Treat Disease, Treat Poison",
        [Skill.Nature] = "Command an Animal, Recall Knowledge, Identify Magic",
        [Skill.Occultism] = "Recall Knowledge, Identify Magic, Learn a Spell",
        [Skill.Performance] = "Perform, Earn Income",
        [Skill.Religion] = "Recall Knowledge, Identify Magic, Learn a Spell",
        [Skill.Society] = "Recall Knowledge, Subsist, Create Forgery, Decipher Writing",
        [Skill.Stealth] = "Hide, Sneak, Conceal an Object",
        [Skill.Survival] = "Track, Subsist, Sense Direction, Cover Tracks",
        [Skill.Thievery] = "Pick a Lock, Disable a Device, Palm an Object, Steal",
    };

    // Weapon trait definitions quoted from each trait's Archives of Nethys page
    // (2e.aonprd.com/Traits.aspx; agile 170, finesse 602, reach 684, two-hand 718, deadly 570,
    // fatal 597, thrown 711, sweep 708, forceful 611, backswing 545, parry 667, backstabber 544,
    // propulsive 677, nonlethal 661, versatile 724).
    private static readonly Dictionary<string, string> TraitRoles = new()
    {
        ["agile"] = "The multiple attack penalty you take with this weapon on the second attack "
            + "on your turn is -4 instead of -5, and -8 instead of -10 on the third and "
            + "subsequent attacks in the turn.",
        ["finesse"] = "You can use your Dexterity modifier instead of your Strength modifier on "
            + "attack rolls using this melee weapon. You still calculate damage using Strength.",
        ["reach"] = "This weapon can be used to attack enemies up to 10 feet away instead of "
            + "only adjacent enemies.",
        ["two-hand"] = "This weapon can be wielded with two hands to change its weapon damage "
            + "die to the indicated value.",
        ["deadly"] = "On a critical hit, the weapon adds a weapon damage die of the listed size. "
            + "Roll this after doubling the weapon's damage.",
        ["fatal"] = "On a critical hit, the weapon's damage die increases to the listed size "
            + "instead of the normal die size, and the weapon adds one additional damage die of "
            + "the listed size.",
        ["thrown"] = "You can throw this weapon as a ranged attack; it is a ranged weapon when "
            + "thrown. You add your Strength modifier to damage as you would for a melee weapon.",
        ["sweep"] = "When you attack with this weapon, you gain a +1 circumstance bonus to your "
            + "attack roll if you already attempted to attack a different target this turn using "
            + "this weapon.",
        ["forceful"] = "When you attack with it more than once on your turn, the second attack "
            + "gains a circumstance bonus to damage equal to the number of weapon damage dice, "
            + "and each later attack gains double that.",
        ["backswing"] = "After missing with this weapon on your turn, you gain a +1 circumstance "
            + "bonus to your next attack with this weapon before the end of your turn.",
        ["parry"] = "While wielding this weapon, if your proficiency with it is trained or "
            + "better, you can spend a single action to position your weapon defensively, "
            + "gaining a +1 circumstance bonus to AC until the start of your next turn.",
        ["backstabber"] = "When you hit an off-guard creature, this weapon deals 1 precision "
            + "damage in addition to its normal damage.",
        ["propulsive"] = "You add half your Strength modifier (if positive) to damage rolls with "
            + "a propulsive ranged weapon. If you have a negative Strength modifier, you add "
            + "your full Strength modifier instead.",
        ["nonlethal"] = "Attacks with this weapon are nonlethal, and are used to knock creatures "
            + "unconscious instead of kill them. You can use a nonlethal weapon to make a lethal "
            + "attack with a -2 circumstance penalty.",
        ["versatile"] = "A versatile weapon can be used to deal a different type of damage than "
            + "its listed type. You choose the damage type each time you attack.",
        ["shield"] = "A shield boss or shield spikes, struck with the raised shield.",
    };

    /// <summary>What the ability does in play.</summary>
    public static string Ability(AbilityScore ability)
        => AbilityRoles.TryGetValue(ability, out string? role) ? role : "";

    /// <summary>The skill's Archives of Nethys description.</summary>
    public static string SkillRole(Skill skill)
        => SkillRoles.TryGetValue(skill, out string? role) ? role : "";

    /// <summary>The actions the skill is rolled for, for the card's Actions meta row.</summary>
    public static string SkillActionList(Skill skill)
        => SkillActions.TryGetValue(skill, out string? actions) ? actions : "";

    /// <summary>What one weapon trait does. A trait printed with its die ("deadly d10") is looked
    /// up on its first word.</summary>
    public static string Trait(string trait)
    {
        int space = trait.IndexOf(' ');
        string key = space < 0 ? trait : trait[..space];
        return TraitRoles.TryGetValue(key, out string? role) ? role : "";
    }


    /// <summary>The proficiency rank spelled out, for prose that cannot use the one-letter form.</summary>
    public static string RankName(ProficiencyLevel proficiency) => proficiency switch
    {
        ProficiencyLevel.Trained => "trained",
        ProficiencyLevel.Expert => "expert",
        ProficiencyLevel.Master => "master",
        ProficiencyLevel.Legendary => "legendary",
        _ => "untrained",
    };

    /// <summary>The ability's three-letter code, for a breakdown that has no room for the word.</summary>
    public static string Code(AbilityScore ability) => ability switch
    {
        AbilityScore.Strength => "Str",
        AbilityScore.Dexterity => "Dex",
        AbilityScore.Constitution => "Con",
        AbilityScore.Intelligence => "Int",
        AbilityScore.Wisdom => "Wis",
        _ => "Cha",
    };
}
