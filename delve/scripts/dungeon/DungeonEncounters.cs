using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Delve.Data;
using Delve.Run;
using Delve.Run.Events;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using RunState = Delve.Run.RunState;

namespace Delve.Dungeon;
public static partial class DungeonEncounters
{
    public static EventDefinition Event(RoomFamily family) => family switch
    {
        RoomFamily.Collapse => EventCatalog.CollapsedPassage,
        RoomFamily.Shrine => new()
        {
            Id = "dungeon-shrine",
            Title = "Forgotten shrine",
            Body = "A pale light rests in the offering bowl. The worn statue watches the chamber.",
            Options = new[]
            {
                new EventOption
                {
                    Label = "Leave an offering and receive its blessing",
                    Success = new("The light settles over your wounds.", new[] { new EventEffect(EventEffectKind.HealFraction, 30) })
                },
                new EventOption
                {
                    Label = "Take the old offerings",
                    Success = new("You gather the coins. The shrine falls dark.", new[] { new EventEffect(EventEffectKind.GoldDelta, 15) })
                }
            }
        },
        RoomFamily.Cache => new()
        {
            Id = "dungeon-cache",
            Title = "Abandoned cache",
            Body = "A broken supply cart lies among scattered crates. One iron-bound container remains intact.",
            Options = new[]
            {
                new EventOption
                {
                    Label = "Open the container",
                    Check = new(Skill.Thievery, 15, true),
                    Success = new("Inside are coins and salvage.", new[] { new EventEffect(EventEffectKind.GoldDelta, 25) }),
                    Failure = new("The rusted latch snaps across your hand.", new[] { new EventEffect(EventEffectKind.Damage, 3) })
                },
                new EventOption
                {
                    Label = "Gather the loose supplies",
                    Success = new("You salvage a handful of valuables.", new[] { new EventEffect(EventEffectKind.GoldDelta, 8) })
                }
            }
        },
        _ => new()
        {
            Id = "dungeon-entrance",
            Title = "The abandoned expedition",
            Body = "Cold bedrolls and a scratched inscription mark the entrance. Every doorway draws power from the Wardstone. What lies beyond is unknown.",
            Options = new[]
            {
                new EventOption
                {
                    Label = "Raise the Wardstone and enter",
                    Success = EventOutcome.Nothing("The stone lights the chamber. Choose a door to begin exploring.")
                }
            }
        }
    };
    /// <summary>Who holds a named place, by floor and purpose, so the name predicts the fight. Places
    /// without a row draw from the floor's whole roster.</summary>
    private static readonly Dictionary<(string Floor, RoomPurpose Purpose), string[]> RoomSpecies = new()
    {
        [("grassland", RoomPurpose.Barracks)] = new[] { "goblin-warrior", "goblin-commando", "goblin-war-chanter" },
        [("grassland", RoomPurpose.Stores)] = new[] { "kobold-warrior", "kobold-scout" },
        [("grassland", RoomPurpose.Cistern)] = new[] { "viper", "giant-rat", "giant-viper", "giant-monitor-lizard" },
    };

    /// <summary>The selected family stays fixed; party level and ward affect the first-entry composition.</summary>
    public static CombatSetup? Build(RunState state, DungeonRoom room, DungeonRoomPrefab prefab, DoorSide entry, Func<CreatureRef, EnemyDefinition?> resolve, bool campaign = false, string? floorId = null) => Build(state, room, prefab.Generated, entry, resolve, campaign, prefab.Shell?.BiomeId, floorId);
    public static CombatSetup? Build(RunState state, DungeonRoom room, GeneratedRoom generated, DoorSide entry, Func<CreatureRef, EnemyDefinition?> resolve, bool campaign = false, string? biome = null, string? floorId = null)
    {
        // A standalone forest crawl fights its own floor's roster; the standalone station keeps the level 1 test roster.
        var wilds = !campaign && floorId != null && FloorThemes.ById(floorId) is { Crawl: CrawlSetting.Wilds } own ? own : null;
        var floor = campaign ? FloorThemes.ForStratum(state.Stratum) : wilds ?? FloorThemes.ForStratum(0);
        string[] species = StationPlan.Prefab(room.Purpose) switch
        {
            RoomFamily.Cistern => new[]
            {
                "giant-rat",
                "viper",
                "giant-viper",
                "kobold-warrior",
                "kobold-scout"
            },
            RoomFamily.Barracks => new[]
            {
                "goblin-warrior",
                "goblin-commando",
                "goblin-war-chanter"
            },
            _ => new[]
            {
                "goblin-warrior",
                "goblin-commando",
                "kobold-warrior",
                "kobold-scout",
                "goblin-war-chanter"
            }
        };
        var roster = !campaign && wilds == null ? floor.Roster.Where(r => species.Contains(r.Slug)).ToArray()
            : RoomSpecies.TryGetValue((floor.Id, room.Purpose), out var locals) ? floor.Roster.Where(r => locals.Contains(r.Slug)).ToArray()
            : floor.Roster;
        var theme = floor with
        {
            TerrainBiome = biome ?? MapThemes.Sewer.BiomeId,
            Roster = roster.Count > 0 ? roster : floor.Roster
        };
        var node = state.Map.Node(room.Id)!;
        if (room.Family == RoomFamily.Guardian)
            theme = theme with
            {
                Weights = new TierWeights(0, 0, 1, 0)
            };
        var rules = new EncounterGenRules();
        var encounter = campaign && node.Kind == NodeKind.Boss
            ? EncounterFactory.BuildBoss(BossEncounters.ForStratum(state.Stratum), resolve)
            : GeneratedEncounters.Generate(state, node, resolve, rules, theme);
        if (encounter == null)
            return null;
        var layout = generated.Layout;
        layout.DeploymentZones = RoomGeneration.Zones(layout.Width, entry, generated.ZoneHalf);
        var setup = new CombatSetup
        {
            Layout = layout,
            BiomeId = biome ?? MapThemes.Sewer.BiomeId,
            RngSeed = RunRng.StableSeed(campaign ? state.StratumSeed : state.Seed, room.Id, "fight"),
            XpAward = EncounterXPCalculator.CalculateTotalXP(encounter, state.Party.Level)
        };
        var living = state.Party.Living();
        var anchors = PF2e.MapGen.DeploymentPlanner.GetAnchors(layout, 0, living.Count);
        for (int i = 0; i < living.Count; i++)
            setup.Party.Add((living[i], EncounterSpawner.AnchorAt(anchors, i)));
        EncounterSpawner.Spawn(encounter, layout, setup, rules.MaxEnemies);
        setup.Normalize();
        return setup.Enemies.Count > 0 ? setup : null;
    }
}
