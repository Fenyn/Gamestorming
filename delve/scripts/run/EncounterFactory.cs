using System;
using System.Collections.Generic;
using Delve.Combat;
using Delve.Data;
using PF2e.Data;
using PF2e.MapGen;
using PF2e.Utilities;

namespace Delve.Run;

/// <summary>
/// Turns a map node into a <see cref="CombatSetup"/>: a generated battle map for the floor theme's
/// terrain biome, the party deployed on its own zone, and the node's enemies on theirs. A Boss
/// node takes its floor's authored composition from <see cref="BossEncounters"/> and ignores the
/// Wardstone; every other fight node is composed by <see cref="GeneratedEncounters"/>.
///
/// The terrain and fight seeds are mixed from (stratum seed, node id) through <see cref="RunRng"/>
/// (tags "battle", "fight"), so re-entering the same node rebuilds the same terrain and the same
/// initiative, the same node id on a deeper floor rolls fresh, and encounter composition rolls on
/// its own tag never shift either stream.
/// </summary>
public static class EncounterFactory
{
    /// <summary>
    /// Build the setup, or null when a creature cannot be resolved or the biome cannot generate.
    /// <paramref name="resolve"/> keeps the autoload (and Godot) out of this assembly.
    /// </summary>
    public static CombatSetup? Build(
        RunState state,
        MapNode node,
        Func<CreatureRef, EnemyDefinition?> resolve,
        EncounterGenRules? rules = null)
    {
        var applied = rules ?? new EncounterGenRules();

        var encounter = node.Kind == NodeKind.Boss
            ? BuildBoss(state.Stratum, resolve)
            : GeneratedEncounters.Generate(state, node, resolve, applied);
        if (encounter == null) return null;

        string biome = FloorThemes.ForStratum(state.Stratum).TerrainBiome;
        var layout = MapGenerator.GenerateValidated(biome, RunRng.StableSeed(state.StratumSeed, node.Id, "battle"));
        if (layout == null) return null;

        var setup = new CombatSetup
        {
            Layout = layout,
            BiomeId = biome,
            RngSeed = RunRng.StableSeed(state.StratumSeed, node.Id, "fight"),
            XpAward = EncounterXPCalculator.CalculateTotalXP(encounter, state.Party.Level),
        };

        var survivors = state.Party.Living();
        var partyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 0, count: survivors.Count);
        for (int i = 0; i < survivors.Count; i++)
            setup.Party.Add((survivors[i], EncounterSpawner.AnchorAt(partyAnchors, i)));

        EncounterSpawner.Spawn(encounter, layout, setup, applied.MaxEnemies);
        return setup.Enemies.Count > 0 ? setup : null;
    }

    /// <summary>The authored boss fight for a floor, ward ignored.</summary>
    private static EncounterDefinition? BuildBoss(int stratum, Func<CreatureRef, EnemyDefinition?> resolve)
    {
        var spec = BossEncounters.ForStratum(stratum);
        var spawns = new List<EnemySpawn>(spec.Spawns.Count);
        foreach (var line in spec.Spawns)
        {
            var def = resolve(line.Creature);
            if (def == null) return null;
            spawns.Add(new EnemySpawn
            {
                Definition = def,
                Count = line.Count,
                Adjustment = line.Adjustment,
                SpawnZone = SpawnZone.Front,
            });
        }
        return new EncounterDefinition
        {
            EncounterId = spec.Id,
            EncounterName = spec.Id,
            EnemySpawns = spawns.ToArray(),
        };
    }
}
