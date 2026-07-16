using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>
/// Reference to a PF2e pack creature, resolvable through DataManager the way CombatTestScene does:
/// FindCreature(<see cref="DisplayName"/>) with a LoadCreatureFile(<see cref="Pack"/>, <see cref="Slug"/>)
/// fallback. Data-only per CLAUDE.md.
/// </summary>
public sealed class CreatureRef
{
    public required string DisplayName { get; init; }
    public required string Pack { get; init; }
    public required string Slug { get; init; }

    /// <summary>
    /// Optional loot table this creature rolls when defeated (see <see cref="DropTables"/>). Null =
    /// no drops. Rolled once per defeated instance on victory (see LootRoller). Data-only per CLAUDE.md.
    /// </summary>
    public string? DropTableId { get; init; }
}

/// <summary>One creature line of an encounter: which creature, how many.</summary>
public sealed class EncounterCreature
{
    public required CreatureRef Creature { get; init; }
    public int Count { get; init; } = 1;
}

/// <summary>A named encounter: the creature list a combat is built from.</summary>
public sealed class EncounterDefinition
{
    public required string Id { get; init; }

    /// <summary>Shown in the "X attacks!" HUD line when the encounter starts.</summary>
    public required string DisplayName { get; init; }

    public required IReadOnlyList<EncounterCreature> Creatures { get; init; }
}

/// <summary>A weighted entry in a spawn-marker's encounter table.</summary>
public sealed class WeightedEncounter
{
    public required string EncounterId { get; init; }
    public int Weight { get; init; } = 1;
}

/// <summary>
/// Static registry of encounter definitions, keyed for the per-territory roamer tables (see
/// <see cref="Territories"/>).
///
/// Full bestiary set (design/economy/materials.md): all fifteen creature families across the three
/// biomes (Verdant Fringe: Goblins, Rats, Brigands, Bramble Slicks, Hedge Folk; the Elderwood:
/// Beasts, Root Wardens, Canopy Spiders, Thornbacks; the Sunken Reach: Mudclaws, Marsh Serpents, Bog
/// Fungus, The Drowned, Swamp Drakes, Marsh Wisps). Each family gets 2-3 common encounters (group-
/// size variants of its rank-and-file creature), one elite encounter (the named roamer), and one
/// boss encounter, wired to the <see cref="DropTables"/> table the design doc names for that tier.
///
/// Creature stat blocks are drawn from the two PF2e packs actually on disk (pathfinder-monster-core,
/// pathfinder-bestiary — see DataManager.Pf2eDataPath); neither pack has a plain "human bandit" or a
/// second will-o'-wisp-tier fey-light stat block, so a few families are built on the closest
/// available reskin (Brigands run on dwarf/bugbear stat blocks; Marsh Wisps' common/elite/boss all
/// resolve to the single Will-o'-Wisp block in the dataset, differentiated only by DisplayName/Count).
/// <see cref="CreatureRef.DisplayName"/> is set to each stat block's real compendium name (matching
/// the existing GoblinWarrior/GiantRat convention, so FindCreature hits directly); the fiction's
/// proper names (Rustjaw, the Warlord, ...) live on the elite/boss <see cref="EncounterDefinition.DisplayName"/>
/// instead, which is what's actually shown to the player.
/// </summary>
public static class EncounterTables
{
    // ================= The Verdant Fringe =================

    // --- Goblins ---
    public static readonly CreatureRef GoblinWarrior = new()
    {
        DisplayName = "Goblin Warrior", Pack = "pathfinder-monster-core", Slug = "goblin-warrior",
        DropTableId = "goblin_drops",
    };
    public static readonly CreatureRef Rustjaw = new()
    {
        DisplayName = "Goblin Commando", Pack = "pathfinder-monster-core", Slug = "goblin-commando",
        DropTableId = "goblin_elite_drops",
    };
    public static readonly CreatureRef Warlord = new()
    {
        DisplayName = "Hobgoblin General", Pack = "pathfinder-monster-core", Slug = "hobgoblin-general",
        DropTableId = "goblin_boss_drops",
    };

    public static readonly EncounterDefinition GoblinPair = new()
    {
        Id = "goblin_pair", DisplayName = "A goblin pair",
        Creatures = new[] { new EncounterCreature { Creature = GoblinWarrior, Count = 2 } },
    };
    public static readonly EncounterDefinition GoblinPatrol = new()
    {
        Id = "goblin_patrol", DisplayName = "A goblin patrol",
        Creatures = new[] { new EncounterCreature { Creature = GoblinWarrior, Count = 3 } },
    };
    public static readonly EncounterDefinition GoblinWarband = new()
    {
        Id = "goblin_warband", DisplayName = "A goblin warband",
        Creatures = new[] { new EncounterCreature { Creature = GoblinWarrior, Count = 4 } },
    };
    public static readonly EncounterDefinition GoblinEliteRustjaw = new()
    {
        Id = "goblin_elite_rustjaw", DisplayName = "Rustjaw",
        Creatures = new[] { new EncounterCreature { Creature = Rustjaw, Count = 1 } },
    };
    public static readonly EncounterDefinition GoblinBossWarlord = new()
    {
        Id = "goblin_boss_warlord", DisplayName = "The Warlord",
        Creatures = new[] { new EncounterCreature { Creature = Warlord, Count = 1 } },
    };

    // --- Rats ---
    public static readonly CreatureRef GiantRat = new()
    {
        DisplayName = "Giant Rat", Pack = "pathfinder-monster-core", Slug = "giant-rat",
        DropTableId = "rat_drops",
    };
    public static readonly CreatureRef Broodmother = new()
    {
        DisplayName = "Rat Swarm", Pack = "pathfinder-monster-core", Slug = "rat-swarm",
        DropTableId = "rat_elite_drops",
    };
    public static readonly CreatureRef GnawKing = new()
    {
        DisplayName = "Wererat", Pack = "pathfinder-monster-core", Slug = "wererat",
        DropTableId = "rat_boss_drops",
    };

    public static readonly EncounterDefinition RatPack = new()
    {
        Id = "rat_pack", DisplayName = "A pack of giant rats",
        Creatures = new[] { new EncounterCreature { Creature = GiantRat, Count = 3 } },
    };
    public static readonly EncounterDefinition RatInfestation = new()
    {
        Id = "rat_infestation", DisplayName = "A rat infestation",
        Creatures = new[] { new EncounterCreature { Creature = GiantRat, Count = 5 } },
    };
    public static readonly EncounterDefinition RatEliteBroodmother = new()
    {
        Id = "rat_elite_broodmother", DisplayName = "The Broodmother",
        Creatures = new[] { new EncounterCreature { Creature = Broodmother, Count = 1 } },
    };
    public static readonly EncounterDefinition RatBossGnawKing = new()
    {
        Id = "rat_boss_gnaw_king", DisplayName = "The Gnaw King",
        Creatures = new[] { new EncounterCreature { Creature = GnawKing, Count = 1 } },
    };

    // --- Brigands (no plain human stat block in either pack; Deserter/Outrider/Warband Captain
    //     run on the closest available mundane-martial reskins — dwarf and bugbear stat blocks) ---
    public static readonly CreatureRef Deserter = new()
    {
        DisplayName = "Dwarf Warrior", Pack = "pathfinder-monster-core", Slug = "dwarf-warrior",
        DropTableId = "brigand_drops",
    };
    public static readonly CreatureRef Outrider = new()
    {
        DisplayName = "Bugbear Prowler", Pack = "pathfinder-monster-core", Slug = "bugbear-prowler",
        DropTableId = "brigand_elite_drops",
    };
    public static readonly CreatureRef WarbandCaptain = new()
    {
        DisplayName = "Bugbear Tormentor", Pack = "pathfinder-monster-core", Slug = "bugbear-tormentor",
        DropTableId = "brigand_boss_drops",
    };

    public static readonly EncounterDefinition DeserterPatrol = new()
    {
        Id = "deserter_patrol", DisplayName = "A deserter patrol",
        Creatures = new[] { new EncounterCreature { Creature = Deserter, Count = 3 } },
    };
    public static readonly EncounterDefinition OutriderAmbush = new()
    {
        Id = "outrider_ambush", DisplayName = "An outrider ambush",
        Creatures = new[] { new EncounterCreature { Creature = Deserter, Count = 2 } },
    };
    public static readonly EncounterDefinition BrigandEliteOutrider = new()
    {
        Id = "brigand_elite_outrider", DisplayName = "The Outrider",
        Creatures = new[] { new EncounterCreature { Creature = Outrider, Count = 1 } },
    };
    public static readonly EncounterDefinition BrigandBossWarbandCaptain = new()
    {
        Id = "brigand_boss_warband_captain", DisplayName = "The Warband Captain",
        Creatures = new[] { new EncounterCreature { Creature = WarbandCaptain, Count = 1 } },
    };

    // --- Bramble Slicks (ooze) ---
    public static readonly CreatureRef BrambleSlick = new()
    {
        DisplayName = "Sewer Ooze", Pack = "pathfinder-monster-core", Slug = "sewer-ooze",
        DropTableId = "bramble_slick_drops",
    };
    public static readonly CreatureRef Ambercore = new()
    {
        DisplayName = "Ochre Jelly", Pack = "pathfinder-bestiary", Slug = "ochre-jelly",
        DropTableId = "bramble_slick_elite_drops",
    };
    public static readonly CreatureRef OrchardMother = new()
    {
        DisplayName = "Black Pudding", Pack = "pathfinder-bestiary", Slug = "black-pudding",
        DropTableId = "bramble_slick_boss_drops",
    };

    public static readonly EncounterDefinition BrambleSlickSingle = new()
    {
        Id = "bramble_slick", DisplayName = "A bramble slick",
        Creatures = new[] { new EncounterCreature { Creature = BrambleSlick, Count = 1 } },
    };
    public static readonly EncounterDefinition KnotOfSlicks = new()
    {
        Id = "knot_of_slicks", DisplayName = "A knot of slicks",
        Creatures = new[] { new EncounterCreature { Creature = BrambleSlick, Count = 3 } },
    };
    public static readonly EncounterDefinition BrambleSlickEliteAmbercore = new()
    {
        Id = "bramble_slick_elite_ambercore", DisplayName = "The Ambercore",
        Creatures = new[] { new EncounterCreature { Creature = Ambercore, Count = 1 } },
    };
    public static readonly EncounterDefinition BrambleSlickBossOrchardMother = new()
    {
        Id = "bramble_slick_boss_orchard_mother", DisplayName = "The Orchard Mother",
        Creatures = new[] { new EncounterCreature { Creature = OrchardMother, Count = 1 } },
    };

    // --- Hedge Folk (fey trickster) ---
    public static readonly CreatureRef HedgeFolk = new()
    {
        DisplayName = "Grig", Pack = "pathfinder-bestiary", Slug = "grig",
        DropTableId = "hedge_folk_drops",
    };
    public static readonly CreatureRef Thistlewhistle = new()
    {
        DisplayName = "Pixie", Pack = "pathfinder-monster-core", Slug = "pixie",
        DropTableId = "hedge_folk_elite_drops",
    };
    public static readonly CreatureRef HollowKing = new()
    {
        DisplayName = "Redcap", Pack = "pathfinder-monster-core", Slug = "redcap",
        DropTableId = "hedge_folk_boss_drops",
    };

    public static readonly EncounterDefinition HedgePrankster = new()
    {
        Id = "hedge_prankster", DisplayName = "A hedge prankster",
        Creatures = new[] { new EncounterCreature { Creature = HedgeFolk, Count = 1 } },
    };
    public static readonly EncounterDefinition HedgeFolkGathering = new()
    {
        Id = "hedge_folk_gathering", DisplayName = "A hedge folk gathering",
        Creatures = new[] { new EncounterCreature { Creature = HedgeFolk, Count = 3 } },
    };
    public static readonly EncounterDefinition HedgeFolkEliteThistlewhistle = new()
    {
        Id = "hedge_folk_elite_thistlewhistle", DisplayName = "Old Thistlewhistle",
        Creatures = new[] { new EncounterCreature { Creature = Thistlewhistle, Count = 1 } },
    };
    public static readonly EncounterDefinition HedgeFolkBossHollowKing = new()
    {
        Id = "hedge_folk_boss_hollow_king", DisplayName = "The Hollow King",
        Creatures = new[] { new EncounterCreature { Creature = HollowKing, Count = 1 } },
    };

    // ================= The Elderwood =================

    // --- Beasts (fills the beast_drops table that shipped with no creature behind it) ---
    public static readonly CreatureRef Predator = new()
    {
        DisplayName = "Wolf", Pack = "pathfinder-monster-core", Slug = "wolf",
        DropTableId = "beast_drops",
    };
    public static readonly CreatureRef Alpha = new()
    {
        DisplayName = "Dire Wolf", Pack = "pathfinder-monster-core", Slug = "dire-wolf",
        DropTableId = "beast_elite_drops",
    };
    public static readonly CreatureRef OldGrowl = new()
    {
        DisplayName = "Cave Bear", Pack = "pathfinder-monster-core", Slug = "cave-bear",
        DropTableId = "beast_boss_drops",
    };

    public static readonly EncounterDefinition LonePredator = new()
    {
        Id = "lone_predator", DisplayName = "A lone predator",
        Creatures = new[] { new EncounterCreature { Creature = Predator, Count = 1 } },
    };
    public static readonly EncounterDefinition HuntingPack = new()
    {
        Id = "hunting_pack", DisplayName = "A hunting pack",
        Creatures = new[] { new EncounterCreature { Creature = Predator, Count = 3 } },
    };
    public static readonly EncounterDefinition BeastEliteAlpha = new()
    {
        Id = "beast_elite_alpha", DisplayName = "The Alpha",
        Creatures = new[] { new EncounterCreature { Creature = Alpha, Count = 1 } },
    };
    public static readonly EncounterDefinition BeastBossOldGrowl = new()
    {
        Id = "beast_boss_old_growl", DisplayName = "The Old Growl",
        Creatures = new[] { new EncounterCreature { Creature = OldGrowl, Count = 1 } },
    };

    // --- Root Wardens (animate root-and-bark; proposed alongside the Elderwood itself) ---
    public static readonly CreatureRef RootWarden = new()
    {
        DisplayName = "Leaf Leshy", Pack = "pathfinder-monster-core", Slug = "leaf-leshy",
        DropTableId = "root_warden_drops",
    };
    public static readonly CreatureRef BrambleWarden = new()
    {
        DisplayName = "Awakened Tree", Pack = "pathfinder-monster-core", Slug = "awakened-tree",
        DropTableId = "root_warden_elite_drops",
    };
    public static readonly CreatureRef Heartwood = new()
    {
        DisplayName = "Giant Flytrap", Pack = "pathfinder-monster-core", Slug = "giant-flytrap",
        DropTableId = "root_warden_boss_drops",
    };

    public static readonly EncounterDefinition RootWardenSingle = new()
    {
        Id = "root_warden", DisplayName = "A root warden",
        Creatures = new[] { new EncounterCreature { Creature = RootWarden, Count = 1 } },
    };
    public static readonly EncounterDefinition StandOfRootWardens = new()
    {
        Id = "stand_of_root_wardens", DisplayName = "A stand of root wardens",
        Creatures = new[] { new EncounterCreature { Creature = RootWarden, Count = 3 } },
    };
    public static readonly EncounterDefinition RootWardenEliteBrambleWarden = new()
    {
        Id = "root_warden_elite_bramble_warden", DisplayName = "The Bramble Warden",
        Creatures = new[] { new EncounterCreature { Creature = BrambleWarden, Count = 1 } },
    };
    public static readonly EncounterDefinition RootWardenBossHeartwood = new()
    {
        Id = "root_warden_boss_heartwood", DisplayName = "The Heartwood",
        Creatures = new[] { new EncounterCreature { Creature = Heartwood, Count = 1 } },
    };

    // --- Canopy Spiders (vertical, ambush-driven arachnid counterpart to the Fringe's Rats) ---
    public static readonly CreatureRef CanopySpider = new()
    {
        DisplayName = "Hunting Spider", Pack = "pathfinder-monster-core", Slug = "hunting-spider",
        DropTableId = "canopy_spider_drops",
    };
    public static readonly CreatureRef Weaver = new()
    {
        DisplayName = "Giant Tarantula", Pack = "pathfinder-monster-core", Slug = "giant-tarantula",
        DropTableId = "canopy_spider_elite_drops",
    };
    public static readonly CreatureRef Silkqueen = new()
    {
        DisplayName = "Goliath Spider", Pack = "pathfinder-monster-core", Slug = "goliath-spider",
        DropTableId = "canopy_spider_boss_drops",
    };

    public static readonly EncounterDefinition CanopySpiderSingle = new()
    {
        Id = "canopy_spider", DisplayName = "A canopy spider",
        Creatures = new[] { new EncounterCreature { Creature = CanopySpider, Count = 1 } },
    };
    public static readonly EncounterDefinition SpiderDrop = new()
    {
        Id = "spider_drop", DisplayName = "A spider drop",
        Creatures = new[] { new EncounterCreature { Creature = CanopySpider, Count = 2 } },
    };
    public static readonly EncounterDefinition CanopySpiderEliteWeaver = new()
    {
        Id = "canopy_spider_elite_weaver", DisplayName = "The Weaver",
        Creatures = new[] { new EncounterCreature { Creature = Weaver, Count = 1 } },
    };
    public static readonly EncounterDefinition CanopySpiderBossSilkqueen = new()
    {
        Id = "canopy_spider_boss_silkqueen", DisplayName = "The Silkqueen",
        Creatures = new[] { new EncounterCreature { Creature = Silkqueen, Count = 1 } },
    };

    // --- Thornbacks (heavy, single-target giant-kin bruiser) ---
    public static readonly CreatureRef Thornback = new()
    {
        DisplayName = "Ogre Warrior", Pack = "pathfinder-monster-core", Slug = "ogre-warrior",
        DropTableId = "thornback_drops",
    };
    public static readonly CreatureRef Stumpfist = new()
    {
        DisplayName = "Stone Giant", Pack = "pathfinder-monster-core", Slug = "stone-giant",
        DropTableId = "thornback_elite_drops",
    };
    public static readonly CreatureRef Grovefather = new()
    {
        DisplayName = "Frost Giant", Pack = "pathfinder-monster-core", Slug = "frost-giant",
        DropTableId = "thornback_boss_drops",
    };

    public static readonly EncounterDefinition ThornbackBrute = new()
    {
        Id = "thornback_brute", DisplayName = "A thornback brute",
        Creatures = new[] { new EncounterCreature { Creature = Thornback, Count = 1 } },
    };
    public static readonly EncounterDefinition ThornbackPair = new()
    {
        Id = "thornback_pair", DisplayName = "A thornback pair",
        Creatures = new[] { new EncounterCreature { Creature = Thornback, Count = 2 } },
    };
    public static readonly EncounterDefinition ThornbackEliteStumpfist = new()
    {
        Id = "thornback_elite_stumpfist", DisplayName = "Stumpfist",
        Creatures = new[] { new EncounterCreature { Creature = Stumpfist, Count = 1 } },
    };
    public static readonly EncounterDefinition ThornbackBossGrovefather = new()
    {
        Id = "thornback_boss_grovefather", DisplayName = "The Grovefather",
        Creatures = new[] { new EncounterCreature { Creature = Grovefather, Count = 1 } },
    };

    // ================= The Sunken Reach =================

    // --- Mudclaws (territorial amphibian hunters) ---
    public static readonly CreatureRef MudclawHunter = new()
    {
        DisplayName = "Boggard Warrior", Pack = "pathfinder-monster-core", Slug = "boggard-warrior",
        DropTableId = "mudclaw_drops",
    };
    public static readonly CreatureRef MudclawSkulker = new()
    {
        DisplayName = "Boggard Scout", Pack = "pathfinder-monster-core", Slug = "boggard-scout",
        DropTableId = "mudclaw_drops",
    };
    public static readonly CreatureRef SiltReaver = new()
    {
        DisplayName = "Boggard Swampseer", Pack = "pathfinder-monster-core", Slug = "boggard-swampseer",
        DropTableId = "mudclaw_elite_drops",
    };
    public static readonly CreatureRef BogChief = new()
    {
        DisplayName = "Marsh Giant", Pack = "pathfinder-monster-core", Slug = "marsh-giant",
        DropTableId = "mudclaw_boss_drops",
    };

    public static readonly EncounterDefinition MudclawHuntingPair = new()
    {
        Id = "mudclaw_hunting_pair", DisplayName = "A mudclaw hunting pair",
        Creatures = new[] { new EncounterCreature { Creature = MudclawHunter, Count = 2 } },
    };
    public static readonly EncounterDefinition MudclawAmbush = new()
    {
        Id = "mudclaw_ambush", DisplayName = "A mudclaw ambush",
        Creatures = new[] { new EncounterCreature { Creature = MudclawSkulker, Count = 2 } },
    };
    public static readonly EncounterDefinition MudclawEliteSiltReaver = new()
    {
        Id = "mudclaw_elite_silt_reaver", DisplayName = "The Silt Reaver",
        Creatures = new[] { new EncounterCreature { Creature = SiltReaver, Count = 1 } },
    };
    public static readonly EncounterDefinition MudclawBossBogChief = new()
    {
        Id = "mudclaw_boss_bog_chief", DisplayName = "The Bog Chief",
        Creatures = new[] { new EncounterCreature { Creature = BogChief, Count = 1 } },
    };

    // --- Marsh Serpents (ambush constrictors) ---
    public static readonly CreatureRef MarshSerpent = new()
    {
        DisplayName = "Python", Pack = "pathfinder-monster-core", Slug = "python",
        DropTableId = "marsh_serpent_drops",
    };
    public static readonly CreatureRef Coildancer = new()
    {
        DisplayName = "Giant Viper", Pack = "pathfinder-monster-core", Slug = "giant-viper",
        DropTableId = "marsh_serpent_elite_drops",
    };
    public static readonly CreatureRef GreatCoil = new()
    {
        DisplayName = "Giant Anaconda", Pack = "pathfinder-monster-core", Slug = "giant-anaconda",
        DropTableId = "marsh_serpent_boss_drops",
    };

    public static readonly EncounterDefinition MarshSerpentSingle = new()
    {
        Id = "marsh_serpent", DisplayName = "A marsh serpent",
        Creatures = new[] { new EncounterCreature { Creature = MarshSerpent, Count = 1 } },
    };
    public static readonly EncounterDefinition NestOfSerpents = new()
    {
        Id = "nest_of_serpents", DisplayName = "A nest of serpents",
        Creatures = new[] { new EncounterCreature { Creature = MarshSerpent, Count = 3 } },
    };
    public static readonly EncounterDefinition MarshSerpentEliteCoildancer = new()
    {
        Id = "marsh_serpent_elite_coildancer", DisplayName = "The Coildancer",
        Creatures = new[] { new EncounterCreature { Creature = Coildancer, Count = 1 } },
    };
    public static readonly EncounterDefinition MarshSerpentBossGreatCoil = new()
    {
        Id = "marsh_serpent_boss_great_coil", DisplayName = "The Great Coil",
        Creatures = new[] { new EncounterCreature { Creature = GreatCoil, Count = 1 } },
    };

    // --- Bog Fungus (animated fungal blooms) ---
    public static readonly CreatureRef BogFungus = new()
    {
        DisplayName = "Fungus Leshy", Pack = "pathfinder-monster-core", Slug = "fungus-leshy",
        DropTableId = "bog_fungus_drops",
    };
    public static readonly CreatureRef Bloomcap = new()
    {
        DisplayName = "Tomb Jelly", Pack = "pathfinder-monster-core", Slug = "tomb-jelly",
        DropTableId = "bog_fungus_elite_drops",
    };
    public static readonly CreatureRef Rootmind = new()
    {
        DisplayName = "Giant Flytrap", Pack = "pathfinder-monster-core", Slug = "giant-flytrap",
        DropTableId = "bog_fungus_boss_drops",
    };

    public static readonly EncounterDefinition BloomCluster = new()
    {
        Id = "bloom_cluster", DisplayName = "A bloom cluster",
        Creatures = new[] { new EncounterCreature { Creature = BogFungus, Count = 2 } },
    };
    public static readonly EncounterDefinition SporeSwarm = new()
    {
        Id = "spore_swarm", DisplayName = "A spore swarm",
        Creatures = new[] { new EncounterCreature { Creature = BogFungus, Count = 3 } },
    };
    public static readonly EncounterDefinition BogFungusEliteBloomcap = new()
    {
        Id = "bog_fungus_elite_bloomcap", DisplayName = "The Bloomcap",
        Creatures = new[] { new EncounterCreature { Creature = Bloomcap, Count = 1 } },
    };
    public static readonly EncounterDefinition BogFungusBossRootmind = new()
    {
        Id = "bog_fungus_boss_rootmind", DisplayName = "The Rootmind",
        Creatures = new[] { new EncounterCreature { Creature = Rootmind, Count = 1 } },
    };

    // --- The Drowned (undead-lite; behavioral wrongness only, no appearance change) ---
    public static readonly CreatureRef Drowned = new()
    {
        DisplayName = "Zombie Shambler", Pack = "pathfinder-monster-core", Slug = "zombie-shambler",
        DropTableId = "drowned_drops",
    };
    public static readonly CreatureRef DeepKeeper = new()
    {
        DisplayName = "Zombie Brute", Pack = "pathfinder-monster-core", Slug = "zombie-brute",
        DropTableId = "drowned_elite_drops",
    };
    public static readonly CreatureRef DrownedLord = new()
    {
        DisplayName = "Ghost Mage", Pack = "pathfinder-monster-core", Slug = "ghost-mage",
        DropTableId = "drowned_boss_drops",
    };

    public static readonly EncounterDefinition DrownedWanderer = new()
    {
        Id = "drowned_wanderer", DisplayName = "A drowned wanderer",
        Creatures = new[] { new EncounterCreature { Creature = Drowned, Count = 1 } },
    };
    public static readonly EncounterDefinition DrownedProcession = new()
    {
        Id = "drowned_procession", DisplayName = "A drowned procession",
        Creatures = new[] { new EncounterCreature { Creature = Drowned, Count = 3 } },
    };
    public static readonly EncounterDefinition DrownedEliteDeepKeeper = new()
    {
        Id = "drowned_elite_deep_keeper", DisplayName = "The Deep Keeper",
        Creatures = new[] { new EncounterCreature { Creature = DeepKeeper, Count = 1 } },
    };
    public static readonly EncounterDefinition DrownedBossDrownedLord = new()
    {
        Id = "drowned_boss_drowned_lord", DisplayName = "The Drowned Lord",
        Creatures = new[] { new EncounterCreature { Creature = DrownedLord, Count = 1 } },
    };

    // --- Swamp Drakes (armored, defensive drake-kin) ---
    public static readonly CreatureRef SwampDrake = new()
    {
        DisplayName = "River Drake", Pack = "pathfinder-monster-core", Slug = "river-drake",
        DropTableId = "swamp_drake_drops",
    };
    public static readonly CreatureRef Ironjaw = new()
    {
        DisplayName = "Jungle Drake", Pack = "pathfinder-monster-core", Slug = "jungle-drake",
        DropTableId = "swamp_drake_elite_drops",
    };
    public static readonly CreatureRef BogSovereign = new()
    {
        DisplayName = "Desert Drake", Pack = "pathfinder-monster-core", Slug = "desert-drake",
        DropTableId = "swamp_drake_boss_drops",
    };

    public static readonly EncounterDefinition SwampDrakeSingle = new()
    {
        Id = "swamp_drake", DisplayName = "A swamp drake",
        Creatures = new[] { new EncounterCreature { Creature = SwampDrake, Count = 1 } },
    };
    public static readonly EncounterDefinition DrakePair = new()
    {
        Id = "drake_pair", DisplayName = "A drake pair",
        Creatures = new[] { new EncounterCreature { Creature = SwampDrake, Count = 2 } },
    };
    public static readonly EncounterDefinition SwampDrakeEliteIronjaw = new()
    {
        Id = "swamp_drake_elite_ironjaw", DisplayName = "The Ironjaw",
        Creatures = new[] { new EncounterCreature { Creature = Ironjaw, Count = 1 } },
    };
    public static readonly EncounterDefinition SwampDrakeBossBogSovereign = new()
    {
        Id = "swamp_drake_boss_bog_sovereign", DisplayName = "The Bog Sovereign",
        Creatures = new[] { new EncounterCreature { Creature = BogSovereign, Count = 1 } },
    };

    // --- Marsh Wisps (lure-and-punish fey lights; only one will-o'-wisp-tier stat block exists in
    //     the dataset, so common/elite/boss share it, distinguished by DisplayName/Count only) ---
    public static readonly CreatureRef MarshWisp = new()
    {
        DisplayName = "Will-o'-Wisp", Pack = "pathfinder-monster-core", Slug = "will-o-wisp",
        DropTableId = "marsh_wisp_drops",
    };
    public static readonly CreatureRef Lantern = new()
    {
        DisplayName = "Will-o'-Wisp", Pack = "pathfinder-monster-core", Slug = "will-o-wisp",
        DropTableId = "marsh_wisp_elite_drops",
    };
    public static readonly CreatureRef DrowningLight = new()
    {
        DisplayName = "Will-o'-Wisp", Pack = "pathfinder-monster-core", Slug = "will-o-wisp",
        DropTableId = "marsh_wisp_boss_drops",
    };

    public static readonly EncounterDefinition MarshWispSingle = new()
    {
        Id = "marsh_wisp", DisplayName = "A marsh wisp",
        Creatures = new[] { new EncounterCreature { Creature = MarshWisp, Count = 1 } },
    };
    public static readonly EncounterDefinition WispCluster = new()
    {
        Id = "wisp_cluster", DisplayName = "A wisp cluster",
        Creatures = new[] { new EncounterCreature { Creature = MarshWisp, Count = 2 } },
    };
    public static readonly EncounterDefinition MarshWispEliteLantern = new()
    {
        Id = "marsh_wisp_elite_lantern", DisplayName = "The Lantern",
        Creatures = new[] { new EncounterCreature { Creature = Lantern, Count = 1 } },
    };
    public static readonly EncounterDefinition MarshWispBossDrowningLight = new()
    {
        Id = "marsh_wisp_boss_drowning_light", DisplayName = "The Drowning Light",
        Creatures = new[] { new EncounterCreature { Creature = DrowningLight, Count = 1 } },
    };

    private static readonly DefinitionRegistry<EncounterDefinition> Registry = new(d => d.Id,
        GoblinPair, GoblinPatrol, GoblinWarband, GoblinEliteRustjaw, GoblinBossWarlord,
        RatPack, RatInfestation, RatEliteBroodmother, RatBossGnawKing,
        DeserterPatrol, OutriderAmbush, BrigandEliteOutrider, BrigandBossWarbandCaptain,
        BrambleSlickSingle, KnotOfSlicks, BrambleSlickEliteAmbercore, BrambleSlickBossOrchardMother,
        HedgePrankster, HedgeFolkGathering, HedgeFolkEliteThistlewhistle, HedgeFolkBossHollowKing,
        LonePredator, HuntingPack, BeastEliteAlpha, BeastBossOldGrowl,
        RootWardenSingle, StandOfRootWardens, RootWardenEliteBrambleWarden, RootWardenBossHeartwood,
        CanopySpiderSingle, SpiderDrop, CanopySpiderEliteWeaver, CanopySpiderBossSilkqueen,
        ThornbackBrute, ThornbackPair, ThornbackEliteStumpfist, ThornbackBossGrovefather,
        MudclawHuntingPair, MudclawAmbush, MudclawEliteSiltReaver, MudclawBossBogChief,
        MarshSerpentSingle, NestOfSerpents, MarshSerpentEliteCoildancer, MarshSerpentBossGreatCoil,
        BloomCluster, SporeSwarm, BogFungusEliteBloomcap, BogFungusBossRootmind,
        DrownedWanderer, DrownedProcession, DrownedEliteDeepKeeper, DrownedBossDrownedLord,
        SwampDrakeSingle, DrakePair, SwampDrakeEliteIronjaw, SwampDrakeBossBogSovereign,
        MarshWispSingle, WispCluster, MarshWispEliteLantern, MarshWispBossDrowningLight);

    public static IReadOnlyCollection<EncounterDefinition> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static EncounterDefinition Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out EncounterDefinition def) => Registry.TryGet(id, out def);
}
