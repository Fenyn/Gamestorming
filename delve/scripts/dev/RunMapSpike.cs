using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Headless regression for <see cref="RunMapGenerator"/>. Generates the map for 200 seeds and
/// asserts the shape contract the flow layer relies on: every entrance reaches the boss, every node
/// is reachable from some entrance, the kind rules of design/core_concept.md hold, the floor before
/// the boss is always a Campsite, and the same seed always produces the identical map.
/// </summary>
public partial class RunMapSpike : SpikeBase
{
    private const int Seeds = 200;

    protected override string Banner => "==================== RUN MAP SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        var cfg = new RunMapConfig();

        int bossUnreachable = 0;
        int orphanNodes = 0;
        int badFloorZero = 0;
        int badBossFloor = 0;
        int badRestFloor = 0;
        int earlyElite = 0;
        int adjacentSameKind = 0;
        int reservedKinds = 0;
        int notDeterministic = 0;

        for (int seed = 0; seed < Seeds; seed++)
        {
            var map = RunMapGenerator.Generate(seed, cfg);

            // (1) Every entrance reaches the boss.
            foreach (int start in map.StartIds)
            {
                if (!Reaches(map, start, map.BossId)) bossUnreachable++;
            }

            // (2) Every node is reachable from some entrance.
            var seen = new HashSet<int>();
            foreach (int start in map.StartIds)
                Flood(map, start, seen);
            foreach (var node in map.Nodes)
            {
                if (!seen.Contains(node.Id)) orphanNodes++;
            }

            // (3) Kind rules.
            var predecessors = Predecessors(map);
            foreach (var node in map.Nodes)
            {
                if (node.Floor == 0 && node.Kind != NodeKind.Combat) badFloorZero++;
                if (node.Floor == map.Floors - 1 && node.Kind != NodeKind.Boss) badBossFloor++;
                if (node.Floor == map.Floors - 2 && node.Kind != NodeKind.Rest) badRestFloor++;
                if (node.Kind == NodeKind.Elite && node.Floor < cfg.MinEliteFloor) earlyElite++;
                if (node.Kind == NodeKind.Shop || node.Kind == NodeKind.Treasure) reservedKinds++;

                if (node.Kind != NodeKind.Rest && node.Kind != NodeKind.Elite) continue;
                if (!predecessors.TryGetValue(node.Id, out var prev)) continue;
                foreach (int id in prev)
                {
                    if (map.Nodes[id].Kind == node.Kind) adjacentSameKind++;
                }
            }

            // (4) Same seed, same map.
            var twin = RunMapGenerator.Generate(seed, cfg);
            if (!SameMap(map, twin)) notDeterministic++;
        }

        Check($"({Seeds} seeds) every entrance reaches the boss", bossUnreachable == 0);
        Check($"({Seeds} seeds) every node is reachable from an entrance", orphanNodes == 0);
        Check($"({Seeds} seeds) floor 0 is always Combat", badFloorZero == 0);
        Check($"({Seeds} seeds) the last floor is a single Boss node", badBossFloor == 0);
        Check($"({Seeds} seeds) the floor before the boss is always Rest", badRestFloor == 0);
        Check($"({Seeds} seeds) no Elite before floor {cfg.MinEliteFloor}", earlyElite == 0);
        Check($"({Seeds} seeds) no Rest or Elite follows its own kind on a path", adjacentSameKind == 0);
        Check($"({Seeds} seeds) reserved kinds (Shop/Treasure) are never generated", reservedKinds == 0);
        Check($"({Seeds} seeds) the same seed yields the identical map", notDeterministic == 0);

        var sample = RunMapGenerator.Generate(7, cfg);
        Check("boss floor holds exactly one node", CountOnFloor(sample, sample.Floors - 1) == 1);
        Check("Reachable(null) returns the entrances", sample.Reachable(null).Count == sample.StartIds.Count);
        Check("Reachable(boss) is empty", sample.Reachable(sample.BossId).Count == 0);
        GD.Print($"  seed 7: {sample.Nodes.Count} nodes, {sample.StartIds.Count} entrances, "
                 + $"{sample.Floors} floors x {sample.Lanes} lanes.");

        return Task.CompletedTask;
    }

    private static Dictionary<int, List<int>> Predecessors(RunMap map)
    {
        var predecessors = new Dictionary<int, List<int>>();
        foreach (var node in map.Nodes)
        {
            foreach (int next in node.Next)
            {
                if (!predecessors.TryGetValue(next, out var list))
                    predecessors[next] = list = new List<int>();
                list.Add(node.Id);
            }
        }
        return predecessors;
    }

    private static void Flood(RunMap map, int from, HashSet<int> seen)
    {
        if (!seen.Add(from)) return;
        foreach (int next in map.Nodes[from].Next)
            Flood(map, next, seen);
    }

    private static bool Reaches(RunMap map, int from, int target)
    {
        var seen = new HashSet<int>();
        Flood(map, from, seen);
        return seen.Contains(target);
    }

    private static int CountOnFloor(RunMap map, int floor)
    {
        int count = 0;
        foreach (var node in map.Nodes)
        {
            if (node.Floor == floor) count++;
        }
        return count;
    }

    private static bool SameMap(RunMap a, RunMap b)
    {
        if (a.Nodes.Count != b.Nodes.Count || a.BossId != b.BossId) return false;
        for (int i = 0; i < a.Nodes.Count; i++)
        {
            var x = a.Nodes[i];
            var y = b.Nodes[i];
            if (x.Floor != y.Floor || x.Lane != y.Lane || x.Kind != y.Kind) return false;
            if (x.Next.Count != y.Next.Count) return false;
            for (int j = 0; j < x.Next.Count; j++)
            {
                if (x.Next[j] != y.Next[j]) return false;
            }
        }
        return true;
    }
}
