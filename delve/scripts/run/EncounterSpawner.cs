using System;
using System.Collections.Generic;
using Delve.Combat;
using PF2e.Core;
using PF2e.Data;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Run;

/// <summary>
/// Materializes an <see cref="EncounterDefinition"/> onto a <see cref="CombatSetup"/>: one live
/// combatant per spawn count, Elite/Weak applied through the factory, placed on the enemy
/// deployment anchors. SpawnZone is honored only as an ordering hint - Front-zone spawns are listed
/// first and take the earlier (closer) anchors; true zone-aware placement waits for a
/// deployment-zone feature.
/// </summary>
public static class EncounterSpawner
{
    /// <summary>Spawn the encounter's enemies onto the setup. Count clamps at
    /// <paramref name="maxEnemies"/> - the deployment zone's capacity.</summary>
    public static void Spawn(
        EncounterDefinition encounter, MapLayout layout, CombatSetup setup, int maxEnemies)
    {
        var spawns = new List<EnemySpawn>(encounter.EnemySpawns ?? Array.Empty<EnemySpawn>());
        spawns.Sort((a, b) => a.SpawnZone.CompareTo(b.SpawnZone)); // Front first (enum order)

        var enemies = new List<ICharacter>();
        foreach (var spawn in spawns)
        {
            if (spawn.Definition == null) continue;
            for (int i = 0; i < spawn.Count && enemies.Count < maxEnemies; i++)
                enemies.Add(CreatureFactory.Create(spawn.Definition, teamId: 2, spawn.Adjustment));
        }

        var anchors = DeploymentPlanner.GetAnchors(layout, teamId: 1, count: enemies.Count);
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], AnchorAt(anchors, i)));
    }

    /// <summary>
    /// The i-th anchor, falling back to the last one when the zone held fewer walkable tiles than
    /// the team has members. A duplicate anchor is legal input: <c>CombatSetup.Normalize</c>
    /// spreads the stack onto the nearest free walkable cells.
    /// </summary>
    internal static PF2eVec AnchorAt(List<PF2eVec> anchors, int index) =>
        anchors.Count == 0 ? default : anchors[Math.Min(index, anchors.Count - 1)];
}
