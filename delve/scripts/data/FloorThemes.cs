using System.Collections.Generic;
using PF2e.Data;

namespace Delve.Data;

/// <summary>Relative weights for the base threat-tier roll of one floor. Trivial never rolls;
/// Lethal is reached only through the Wardstone upshift.</summary>
public sealed record TierWeights(int Low, int Moderate, int Severe, int Extreme);

/// <summary>
/// One floor (code: stratum) of the wilderness crawl: its identity, the terrain biome its battle
/// maps generate with, the creature pool its fights draw from, and the base tier distribution the
/// Wardstone upshifts (design/core_concept.md "Wardstone", "Run flow").
/// </summary>
public sealed record FloorTheme
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>MapGenerator biome for battle maps. Grassland, deep forest and swamp terrain do
    /// not exist yet, so every floor generates forest boards until their biomes are authored.</summary>
    public required string TerrainBiome { get; init; }

    public required IReadOnlyList<CreatureRef> Roster { get; init; }

    public required TierWeights Weights { get; init; }
}

/// <summary>
/// The floor table, one row per stratum (CLAUDE.md: per-kind behaviour in one data table). The run
/// is as long as this table; <see cref="BossEncounters"/> rows pair with it 1:1. Level flow across
/// a full run is 1-10: floor 1 carries party levels 1-4, floor 2 levels 5-7, floor 3 levels 8-10,
/// and each roster is curated for its band. Every slug is pack-verified; <see cref="IsSpawnable"/>
/// re-checks at resolve time.
/// </summary>
public static class FloorThemes
{
    private const string MonsterCore = "pathfinder-monster-core";
    private const string Bestiary = "pathfinder-bestiary";

    private static CreatureRef Core(string name, string slug) =>
        new() { DisplayName = name, Pack = MonsterCore, Slug = slug };

    private static CreatureRef Best(string name, string slug) =>
        new() { DisplayName = name, Pack = Bestiary, Slug = slug };

    private static readonly FloorTheme Grassland = new()
    {
        Id = "grassland",
        DisplayName = "The Fringe",
        TerrainBiome = "forest",
        // Party levels 1-4: pests, raiders and pack hunters, creature levels -1..4.
        Roster = new[]
        {
            Core("Giant Rat", "giant-rat"),                    // -1
            Core("Viper", "viper"),                            // -1
            Core("Kobold Warrior", "kobold-warrior"),          // -1
            Core("Goblin Warrior", "goblin-warrior"),          // -1
            Core("Wolf", "wolf"),                              //  1
            Core("Goblin Commando", "goblin-commando"),        //  1
            Core("Goblin War Chanter", "goblin-war-chanter"),  //  1
            Core("Hunting Spider", "hunting-spider"),          //  1
            Core("Kobold Scout", "kobold-scout"),              //  1
            Core("Boar", "boar"),                              //  2
            Core("Giant Viper", "giant-viper"),                //  2
            Core("Giant Monitor Lizard", "giant-monitor-lizard"), // 2
            Core("Dire Wolf", "dire-wolf"),                    //  3
            Core("Grizzly Bear", "grizzly-bear"),              //  3
            Core("Giant Stag Beetle", "giant-stag-beetle"),    //  4
        },
        // Low and Moderate country; Severe is the rare bad day.
        Weights = new TierWeights(Low: 4, Moderate: 5, Severe: 1, Extreme: 0),
    };

    private static readonly FloorTheme DeepForest = new()
    {
        Id = "deepforest",
        DisplayName = "The Deep Wood",
        TerrainBiome = "forest",
        // Party levels 5-7: the forest's own things, creature levels 3..8.
        Roster = new[]
        {
            Core("Dire Wolf", "dire-wolf"),                    //  3
            Best("Web Lurker", "web-lurker"),                  //  3
            Core("Grizzly Bear", "grizzly-bear"),              //  3
            Core("Ogre Warrior", "ogre-warrior"),              //  3
            Best("Owlbear", "owlbear"),                        //  4
            Core("Forest Troll", "forest-troll"),              //  5
            Best("Shambler", "shambler"),                      //  6
            Core("Chimera", "chimera"),                        //  8
            Core("Giant Anaconda", "giant-anaconda"),          //  8
            Core("Megaprimatus", "megaprimatus"),              //  8
        },
        // Rarely Low, Moderate and Severe carry the floor.
        Weights = new TierWeights(Low: 1, Moderate: 5, Severe: 4, Extreme: 0),
    };

    private static readonly FloorTheme Swamp = new()
    {
        Id = "swamp",
        DisplayName = "The Drowning Dark",
        TerrainBiome = "forest",
        // Party levels 8-10: drowned horrors, creature levels 5..10.
        Roster = new[]
        {
            Core("Bogwid", "bogwid"),                          //  5
            Core("Hydra", "hydra"),                            //  6
            Best("Chuul", "chuul"),                            //  7
            Core("Krooth", "krooth"),                          //  8
            Core("Marsh Giant", "marsh-giant"),                //  8
            Core("Giant Anaconda", "giant-anaconda"),          //  8
            Core("Doldrums Heap", "doldrums-heap"),            //  9
            Core("Deinosuchus", "deinosuchus"),                //  9
            Core("Dezullon", "dezullon"),                      // 10
            Core("Giant Flytrap", "giant-flytrap"),            // 10
        },
        // No Low. Moderate up, with Extreme in the deck before the ward touches it.
        Weights = new TierWeights(Low: 0, Moderate: 4, Severe: 5, Extreme: 1),
    };

    private static readonly FloorTheme[] ByStratum = { Grassland, DeepForest, Swamp };

    /// <summary>Floors in a run.</summary>
    public static int Count => ByStratum.Length;

    /// <summary>Theme for a stratum index, clamped to the table.</summary>
    public static FloorTheme ForStratum(int stratum)
    {
        if (stratum < 0) stratum = 0;
        if (stratum >= ByStratum.Length) stratum = ByStratum.Length - 1;
        return ByStratum[stratum];
    }

    /// <summary>Trait ids that never enter a generated pool: the combat layer does not model
    /// swarm area-logic or incorporeal passthrough, and aquatic creatures have no water.</summary>
    public static readonly string[] TraitBlacklist = { "incorporeal", "swarm", "aquatic" };

    /// <summary>True when a resolved definition can fight on a ground board: it walks
    /// (land speed above 0) and carries no blacklisted trait.</summary>
    public static bool IsSpawnable(EnemyDefinition def)
    {
        if (def.StatBlock.SpeedInFeet <= 0) return false;
        var traits = def.CreatureTraits;
        if (traits != null)
        {
            foreach (string id in TraitBlacklist)
            {
                if (traits.HasTraitById(id)) return false;
            }
        }
        return true;
    }
}
