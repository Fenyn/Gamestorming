using System.Collections.Generic;
using System.Linq;
using PF2e.Data;

namespace Delve.Run;

/// <summary>Bulwark identities and authored native-class adventuring loadouts.</summary>
public sealed record WayfarerSpec(string Id, string Name, string IntendedClass, string Ancestry,
    string Role, string Introduction, string ArcTitle, string PersonalGoal, string Sprite,
    int[] Abilities, string Weapon, string? Armor, string? Shield,
    Skill[] Skills, string[] Cantrips, string[] Spells);

public static class BulwarkWayfarers
{
    public static readonly IReadOnlyList<WayfarerSpec> All = new[]
    {
        new WayfarerSpec("arkus", "Arkus", "Barbarian", "Orc", "two-handed bruiser",
            "A wounded orc smith is gathering the courage to return after a failed rite of passage.",
            "Steel after the broken rite", "Defeat a floor guardian and bring the smith home.", "veteran",
            new[] {18,12,16,10,12,10}, "greataxe", "hide-armor", null,
            new[] {Skill.Athletics, Skill.Crafting, Skill.Intimidation}, [], []),
        new WayfarerSpec("aldric", "Sir Garran", "Champion", "Human", "shield guardian",
            "An old soldier offers his shield while searching for a way to make amends.",
            "A watch worth keeping", "Protect the expedition through a floor guardian fight.", "veteran",
            new[] {18,12,14,10,12,14}, "longsword", "chain-mail", "steel-shield",
            new[] {Skill.Diplomacy, Skill.Religion, Skill.Athletics}, [], []),
        new WayfarerSpec("spore", "Spore", "Witch", "Fungus Leshy", "hex scholar",
            "A fungus leshy tends a bubbling mixture among the damp stones, curious about the travelers.",
            "A place for strange remedies", "Bring knowledge of a defeated guardian back to the apothecary.", "wizard",
            new[] {10,14,14,18,14,10}, "staff", null, null,
            new[] {Skill.Nature, Skill.Occultism, Skill.Medicine}, ["preset-electric-arc", "preset-frostbite"],
            ["preset-heal", "preset-breathe-fire"]),
        new WayfarerSpec("josen", "Josen", "Monk", "Elf", "unarmed fighter and field medic",
            "A Quiet Hand healer works without hurry, studying injuries that others would turn away from.",
            "The patient hand", "Keep the party standing through a guardian encounter.", "recruit",
            new[] {16,18,12,10,14,10}, "fist", null, null,
            new[] {Skill.Medicine, Skill.Acrobatics, Skill.Religion}, [], []),
        new WayfarerSpec("grub", "Grub", "Druid", "Goblin", "garden keeper and healer",
            "A cheerful goblin has made a garden in the ruins and offers a freshly pulled radish.",
            "Roots in the stone", "Clear a guardian's chamber for something new to grow.", "cleric",
            new[] {12,14,14,10,18,10}, "sickle", "hide-armor", "wooden-shield",
            new[] {Skill.Nature, Skill.Survival, Skill.Medicine}, ["preset-electric-arc", "preset-frostbite"],
            ["preset-heal", "preset-heal", "preset-breathe-fire"]),
        new WayfarerSpec("sera", "Sera", "Magus", "Human", "arcane researcher",
            "An exiled academic is mapping the ward machinery and insists the expedition has interrupted an experiment.",
            "Research without permission", "Record a guardian's defeat for the arcane study.", "wizard",
            new[] {18,12,14,16,10,10}, "longsword", "chain-mail", null,
            new[] {Skill.Arcana, Skill.Crafting, Skill.Society}, ["preset-electric-arc", "preset-frostbite"],
            ["preset-force-barrage", "preset-force-barrage", "preset-fear", "preset-fireball"]),
        new WayfarerSpec("oskar", "Oskar", "Oracle", "Dwarf", "war-scarred divine healer",
            "A gentle elder bears the aftermath of a divine weapon and hopes to leave a sanctuary behind.",
            "A sanctuary after war", "Survive a guardian fight and return with a story for the shrine.", "cleric",
            new[] {12,12,16,10,12,18}, "warhammer", "leather-armor", null,
            new[] {Skill.Religion, Skill.Diplomacy, Skill.Medicine}, ["preset-divine-lance", "preset-daze"],
            ["preset-heal", "preset-fear", "preset-heal"]),
        new WayfarerSpec("hazel", "Hazel", "Thaumaturge", "Halfling", "relic investigator",
            "A former curator examines a dangerous relic with tongs, careful notes, and visible delight.",
            "The collection begins again", "Recover knowledge from a defeated guardian for the reliquary.", "rogue",
            new[] {12,16,12,12,12,18}, "rapier", "leather-armor", null,
            new[] {Skill.Occultism, Skill.Arcana, Skill.Thievery}, [], []),
        new WayfarerSpec("wynn", "Wynn", "Bard", "Human", "storyteller and rallying healer",
            "An exiled playwright has been collecting the stories of everyone who passes through the ruins.",
            "A company worth writing about", "Return from a guardian fight with the party's next story.", "cleric",
            new[] {10,14,14,12,12,18}, "staff", "leather-armor", null,
            new[] {Skill.Performance, Skill.Diplomacy, Skill.Society}, ["preset-daze", "preset-telekinetic-projectile"],
            ["preset-fear", "preset-soothe"]),
        new WayfarerSpec("vasska", "Vasska", "Psychic", "Nagaji", "mentalist",
            "A still-eyed nagaji greets the party with unsettling concentration and an interest in Oskar's affliction.",
            "A mind welcomed at the fire", "Understand the threat behind a floor guardian.", "wizard",
            new[] {10,14,12,18,14,14}, "staff", null, null,
            new[] {Skill.Occultism, Skill.Diplomacy, Skill.Deception}, ["preset-daze", "preset-telekinetic-projectile"],
            ["preset-force-barrage", "preset-fear", "preset-fear"]),
        new WayfarerSpec("hilde", "Hilde", "Summoner", "Dwarf", "stonewise survivor",
            "A fugitive miner listens to a patient presence in the stone, unsure whether to trust the bond.",
            "A bond no longer hidden", "Face a guardian with companions who know Hilde's secret.", "recruit",
            new[] {10,12,16,12,12,18}, "staff", null, null,
            new[] {Skill.Crafting, Skill.Occultism, Skill.Survival}, ["preset-frostbite", "preset-electric-arc"],
            ["preset-heal", "preset-breathe-fire"]),
        new WayfarerSpec("flick", "Flick", "Sorcerer", "Goblin", "elemental junk mage",
            "A delighted goblin channels dangerous elemental magic through a pocketful of scavenged junk.",
            "Somewhere safe to experiment", "Test Flick's discoveries against a guardian and bring her home.", "wizard",
            new[] {10,16,14,10,12,18}, "dagger", null, null,
            new[] {Skill.Crafting, Skill.Acrobatics, Skill.Intimidation}, ["preset-ignition", "preset-electric-arc", "preset-frostbite"],
            ["preset-breathe-fire", "preset-breathe-fire", "preset-heal", "preset-fireball", "preset-fireball"]),
    };

    public static readonly WayfarerSpec Raven = new("raven", "Raven", "Swashbuckler", "Human", "braggart duelist",
        "A bounty hunter has found a quarry worth boasting about.", "A place at the fire", "Defeat a floor guardian.", "rogue",
        new[] {12,18,12,10,12,16}, "rapier", "leather-armor", null, [Skill.Intimidation, Skill.Diplomacy], [], []);
    public static readonly WayfarerSpec Thistle = new("thistle", "Thistle", "Ranger", "Gnome", "precision scout",
        "A restless scout is watching the paths ahead.", "A trail back home", "Defeat a floor guardian.", "recruit",
        new[] {14,18,12,10,14,10}, "shortbow", "leather-armor", null, [Skill.Survival, Skill.Stealth], [], []);
    public static WayfarerSpec? Find(string id) => id == "raven" ? Raven : id == "thistle" ? Thistle : All.FirstOrDefault(s => s.Id == id);
}
