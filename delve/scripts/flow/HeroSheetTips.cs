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
    // What the number drives on this sheet (2e.aonprd.com/Rules.aspx?ID=67).
    private static readonly Dictionary<AbilityScore, string> AbilityRoles = new()
    {
        [AbilityScore.Strength] = "Adds to melee attack rolls, melee and thrown damage, and Athletics.",
        [AbilityScore.Dexterity] =
            "Adds to AC, Reflex saves, ranged and finesse attack rolls, Acrobatics, Stealth and Thievery.",
        [AbilityScore.Constitution] = "Adds Hit Points at every level and adds to Fortitude saves.",
        [AbilityScore.Intelligence] =
            "Adds to Arcana, Crafting, Occultism and Society, and grants extra trained skills. "
            + "It is the spellcasting ability of wizards.",
        [AbilityScore.Wisdom] =
            "Adds to Perception, Will saves, Medicine, Nature, Religion and Survival. "
            + "It is the spellcasting ability of clerics and druids.",
        [AbilityScore.Charisma] =
            "Adds to Deception, Diplomacy, Intimidation and Performance. "
            + "It is the spellcasting ability of bards and sorcerers.",
    };

    private const string Attunement =
        " The party's best trained Arcana, Nature, Occultism or Religion attunes the Wardstone after a floor guardian falls.";

    // Only what the card's Actions row does not already say. A skill with nothing to add has no entry.
    private static readonly Dictionary<Skill, string> SkillRoles = new()
    {
        [Skill.Arcana] = "Recall Knowledge about arcane magic and arcane creatures." + Attunement,
        [Skill.Intimidation] = "Demoralize makes a foe within 30 feet frightened.",
        [Skill.Nature] = "Recall Knowledge about animals, plants and magical beasts." + Attunement,
        [Skill.Occultism] = "Recall Knowledge about esoteric lore and supernatural creatures." + Attunement,
        [Skill.Religion] = "Recall Knowledge about deities and divine creatures." + Attunement,
        [Skill.Society] = "Recall Knowledge about people, cultures and history.",
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

    // Weapon trait rules from each trait's Archives of Nethys page (2e.aonprd.com/Traits.aspx;
    // agile 170, finesse 602, reach 684, two-hand 718, deadly 570, fatal 597, thrown 711,
    // sweep 708, forceful 611, backswing 545, parry 667, backstabber 544, propulsive 677,
    // nonlethal 661, versatile 724). The weapon card shows only the first sentence.
    private static readonly Dictionary<string, string> TraitRoles = new()
    {
        ["agile"] = "The multiple attack penalty is -4 on the second attack and -8 on later attacks, "
            + "instead of -5 and -10.",
        ["finesse"] = "Attack rolls can use Dexterity instead of Strength. Damage still uses Strength.",
        ["reach"] = "Attacks enemies up to 10 feet away.",
        ["two-hand"] = "Wielded in two hands, the weapon damage die becomes the listed size.",
        ["deadly"] = "A critical hit adds one damage die of the listed size, rolled after doubling.",
        ["fatal"] = "A critical hit raises the damage die to the listed size and adds one more die of that size.",
        ["thrown"] = "Can be thrown as a ranged attack. Thrown damage adds Strength, as a melee weapon does.",
        ["sweep"] = "+1 circumstance bonus to attack if you already attacked a different target with "
            + "this weapon this turn.",
        ["forceful"] = "The second attack in a turn adds circumstance damage equal to the number of "
            + "weapon damage dice, and each later attack adds double that.",
        ["backswing"] = "After a miss with this weapon, the next attack with it this turn gets a "
            + "+1 circumstance bonus.",
        ["parry"] = "If trained with it, spend 1 action to gain a +1 circumstance bonus to AC until "
            + "the start of your next turn.",
        ["backstabber"] = "Deals 1 extra precision damage to off-guard creatures.",
        ["propulsive"] = "Adds half your Strength modifier to damage when positive, or the full "
            + "modifier when negative.",
        ["nonlethal"] = "Attacks knock creatures unconscious instead of killing them. A lethal attack "
            + "takes a -2 circumstance penalty.",
        ["versatile"] = "Can deal the listed second damage type instead. You choose the type for each attack.",
        ["shield"] = "A shield boss or shield spikes, struck with the raised shield.",
    };

    /// <summary>What the ability does in play.</summary>
    public static string Ability(AbilityScore ability)
        => AbilityRoles.TryGetValue(ability, out string? role) ? role : "";

    /// <summary>What the skill covers beyond its action list, or empty.</summary>
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
