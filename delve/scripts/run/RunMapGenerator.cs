using System;
using System.Collections.Generic;

namespace Delve.Run;

/// <summary>
/// Slay-the-Spire shaped map builder. <see cref="RunMapConfig.Paths"/> random upward walks start on
/// a random lane and drift by at most one lane per floor; cells shared by two walks merge into one
/// node, so the map branches and re-joins. The last floor holds a single boss node every node on the
/// floor below leads to.
///
/// Deterministic: the whole map comes out of one <c>Random</c> seeded from
/// <c>RunRng.StableSeed(runSeed, 0, "map")</c>, and node ids are assigned by a floor/lane sweep, so
/// the same seed always produces the identical map.
/// </summary>
public static class RunMapGenerator
{
    public static RunMap Generate(int runSeed, RunMapConfig cfg)
    {
        if (cfg.Floors < 3) throw new ArgumentOutOfRangeException(nameof(cfg), "Floors must be at least 3.");
        if (cfg.Lanes < 1) throw new ArgumentOutOfRangeException(nameof(cfg), "Lanes must be at least 1.");
        if (cfg.Paths < 1) throw new ArgumentOutOfRangeException(nameof(cfg), "Paths must be at least 1.");

        var rng = new Random(RunRng.StableSeed(runSeed, 0, "map"));

        int bossFloor = cfg.Floors - 1;
        // Walk floors 0..bossFloor-1; the boss is appended afterwards as the single sink.
        var cells = new HashSet<(int Floor, int Lane)>();
        var edges = new HashSet<((int, int) From, (int, int) To)>();

        for (int p = 0; p < cfg.Paths; p++)
        {
            int lane = rng.Next(cfg.Lanes);
            cells.Add((0, lane));
            for (int floor = 0; floor < bossFloor - 1; floor++)
            {
                int nextLane = Math.Clamp(lane + rng.Next(-1, 2), 0, cfg.Lanes - 1);
                cells.Add((floor + 1, nextLane));
                edges.Add(((floor, lane), (floor + 1, nextLane)));
                lane = nextLane;
            }
        }

        // Ids by floor/lane sweep so ordering never depends on HashSet enumeration.
        var nodes = new List<MapNode>();
        var idOf = new Dictionary<(int, int), int>();
        for (int floor = 0; floor < bossFloor; floor++)
        {
            for (int lane = 0; lane < cfg.Lanes; lane++)
            {
                if (!cells.Contains((floor, lane))) continue;
                idOf[(floor, lane)] = nodes.Count;
                nodes.Add(new MapNode { Id = nodes.Count, Floor = floor, Lane = lane });
            }
        }

        int bossId = nodes.Count;
        nodes.Add(new MapNode { Id = bossId, Floor = bossFloor, Lane = cfg.Lanes / 2, Kind = NodeKind.Boss });

        // Edges, deduped and in id order.
        var ordered = new List<((int, int) From, (int, int) To)>(edges);
        ordered.Sort((a, b) =>
        {
            int c = idOf[a.From].CompareTo(idOf[b.From]);
            return c != 0 ? c : idOf[a.To].CompareTo(idOf[b.To]);
        });
        foreach (var (from, to) in ordered)
            nodes[idOf[from]].Next.Add(idOf[to]);

        // Every node on the floor below the boss funnels into it.
        foreach (var node in nodes)
        {
            if (node.Floor == bossFloor - 1)
                node.Next.Add(bossId);
        }

        var startIds = new List<int>();
        foreach (var node in nodes)
        {
            if (node.Floor == 0) startIds.Add(node.Id);
        }

        AssignKinds(nodes, bossFloor, cfg, rng);
        return new RunMap(cfg.Floors, cfg.Lanes, nodes, startIds, bossId);
    }

    /// <summary>
    /// Kind rules from design/core_concept.md: floor 0 is Combat, the last floor is the Boss, the
    /// floor before it is a Campsite, Elites never appear before <see cref="RunMapConfig.MinEliteFloor"/>,
    /// and no Rest or Elite ever follows one of its own kind along a path. Floors are assigned in
    /// order so every predecessor is already known when a node is rolled.
    /// </summary>
    private static void AssignKinds(List<MapNode> nodes, int bossFloor, RunMapConfig cfg, Random rng)
    {
        var predecessors = new Dictionary<int, List<int>>();
        foreach (var node in nodes)
        {
            foreach (int next in node.Next)
            {
                if (!predecessors.TryGetValue(next, out var list))
                    predecessors[next] = list = new List<int>();
                list.Add(node.Id);
            }
        }

        var weighted = new (NodeKind Kind, int Weight)[]
        {
            (NodeKind.Combat, cfg.CombatWeight),
            (NodeKind.Event, cfg.EventWeight),
            (NodeKind.Rest, cfg.RestWeight),
            (NodeKind.Elite, cfg.EliteWeight),
        };

        var candidates = new List<(NodeKind Kind, int Weight)>(weighted.Length);
        foreach (var node in nodes)
        {
            if (node.Floor == 0) { node.Kind = NodeKind.Combat; continue; }
            if (node.Floor == bossFloor) { node.Kind = NodeKind.Boss; continue; }
            if (node.Floor == bossFloor - 1) { node.Kind = NodeKind.Rest; continue; }

            candidates.Clear();
            foreach (var entry in weighted)
            {
                if (entry.Weight <= 0) continue;
                if (entry.Kind == NodeKind.Elite && node.Floor < cfg.MinEliteFloor) continue;
                // Every node two floors above the boss leads into the forced Campsite floor, so a
                // Rest here would put two Campsites back to back on every path through it.
                if (entry.Kind == NodeKind.Rest && node.Floor == bossFloor - 2) continue;
                if ((entry.Kind == NodeKind.Elite || entry.Kind == NodeKind.Rest)
                    && HasPredecessorOfKind(nodes, predecessors, node.Id, entry.Kind))
                    continue;
                candidates.Add(entry);
            }

            node.Kind = candidates.Count == 0 ? NodeKind.Combat : Pick(candidates, rng);
        }
    }

    private static bool HasPredecessorOfKind(
        List<MapNode> nodes, Dictionary<int, List<int>> predecessors, int id, NodeKind kind)
    {
        if (!predecessors.TryGetValue(id, out var list)) return false;
        foreach (int prev in list)
        {
            if (nodes[prev].Kind == kind) return true;
        }
        return false;
    }

    private static NodeKind Pick(List<(NodeKind Kind, int Weight)> candidates, Random rng)
    {
        int total = 0;
        foreach (var c in candidates) total += c.Weight;

        int roll = rng.Next(total);
        foreach (var c in candidates)
        {
            roll -= c.Weight;
            if (roll < 0) return c.Kind;
        }
        return candidates[^1].Kind;
    }
}
