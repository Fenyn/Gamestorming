using System.Collections.Generic;
using System.Linq;
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
        int earlyRest = 0;
        int thinEntrances = 0;
        int adjacentSameKind = 0;
        int reservedKinds = 0;
        int notDeterministic = 0;
        int crossings = 0;
        int noElite = 0;
        int noMidRest = 0;
        int entrances = 0;
        int totalNodes = 0;
        int earliestRest = int.MaxValue;
        var kindCounts = new int[System.Enum.GetValues<NodeKind>().Length];
        int misplacedMeeting = 0, badMeetingCount = 0, forcedMeeting = 0;
        var meetingRows = new HashSet<int>();
        var meetingCounts = new HashSet<int>();

        for (int seed = 0; seed < Seeds; seed++)
        {
            var map = RunMapGenerator.Generate(seed, cfg);
            int meetings = map.Nodes.Count(node => node.Kind == NodeKind.Meeting);
            meetingCounts.Add(meetings);
            if (meetings < cfg.MinMeetingsPerFloor || meetings > cfg.MaxMeetingsPerFloor) badMeetingCount++;
            var withoutMeetings = new HashSet<int>();
            foreach (int start in map.StartIds) Flood(map, start, withoutMeetings, NodeKind.Meeting);
            if (!withoutMeetings.Contains(map.BossId)) forcedMeeting++;

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
                if (node.Kind == NodeKind.Rest && node.Floor < cfg.MinRestFloor) earlyRest++;
                if (node.Kind == NodeKind.Shop || node.Kind == NodeKind.Treasure) reservedKinds++;
                if (node.Kind == NodeKind.Meeting)
                {
                    meetingRows.Add(node.Floor);
                    if (node.Floor == 0 || node.Floor >= map.Floors - 2) misplacedMeeting++;
                }

                if (node.Kind != NodeKind.Rest && node.Kind != NodeKind.Elite) continue;
                if (!predecessors.TryGetValue(node.Id, out var prev)) continue;
                foreach (int id in prev)
                {
                    if (map.Nodes[id].Kind == node.Kind) adjacentSameKind++;
                }
            }

            // (4) No two edges cross between the same pair of floors.
            crossings += CountCrossings(map);

            // (5) Balance sampling.
            int elites = 0, midRests = 0;
            foreach (var node in map.Nodes)
            {
                if (node.Kind == NodeKind.Elite) elites++;
                if (node.Kind == NodeKind.Rest && node.Floor < map.Floors - 2) midRests++;
                if (node.Kind == NodeKind.Rest && node.Floor < earliestRest) earliestRest = node.Floor;
                kindCounts[(int)node.Kind]++;
            }
            if (elites == 0) noElite++;
            if (midRests == 0) noMidRest++;
            entrances += map.StartIds.Count;
            if (map.StartIds.Count < 2) thinEntrances++;
            totalNodes += map.Nodes.Count;

            // (6) Same seed, same map.
            var twin = RunMapGenerator.Generate(seed, cfg);
            if (!SameMap(map, twin)) notDeterministic++;
        }

        Check($"({Seeds} seeds) every entrance reaches the boss", bossUnreachable == 0);
        Check($"({Seeds} seeds) every node is reachable from an entrance", orphanNodes == 0);
        Check($"({Seeds} seeds) floor 0 is always Combat", badFloorZero == 0);
        Check($"({Seeds} seeds) the last floor is a single Boss node", badBossFloor == 0);
        Check($"({Seeds} seeds) the floor before the boss is always Rest", badRestFloor == 0);
        Check($"({Seeds} seeds) no Elite before floor {cfg.MinEliteFloor}", earlyElite == 0);
        Check($"({Seeds} seeds) no Rest before floor {cfg.MinRestFloor}", earlyRest == 0);
        Check($"({Seeds} seeds) no Rest or Elite follows its own kind on a path", adjacentSameKind == 0);
        Check($"({Seeds} seeds) reserved kinds (Shop/Treasure) are never generated", reservedKinds == 0);
        Check($"({Seeds} seeds) one or two Wayfarers per default floor tree", badMeetingCount == 0);
        Check($"({Seeds} seeds) Wayfarers leave the entrance and boss approach intact", misplacedMeeting == 0);
        Check($"({Seeds} seeds) a route can skip all Wayfarers", forcedMeeting == 0);
        Check("Wayfarer counts and rows vary across seeds", meetingCounts.SetEquals(new[] { 1, 2 }) && meetingRows.Count > 2);
        Check($"({Seeds} seeds) the same seed yields the identical map", notDeterministic == 0);

        Check($"({Seeds} seeds) no two map edges cross", crossings == 0);
        Check($"({Seeds} seeds) at least {cfg.MinElites} Lair per map", noElite == 0);
        Check($"({Seeds} seeds) at least {cfg.MinMidRests} mid-run Campsite per map", noMidRest == 0);
        Check($"({Seeds} seeds) at least two entrances per map", thinEntrances == 0);

        GD.Print($"  stats: {totalNodes / (float)Seeds:0.0} nodes, {entrances / (float)Seeds:0.00} entrances per map; "
                 + $"{noElite} maps with no Lair, {noMidRest} with no mid-run Campsite; earliest Rest floor {earliestRest}.");
        for (int k = 0; k < kindCounts.Length; k++)
        {
            if (kindCounts[k] > 0)
                GD.Print($"    {(NodeKind)k}: {kindCounts[k] / (float)Seeds:0.00} per map");
        }

        var sample = RunMapGenerator.Generate(7, cfg);
        Check("boss floor holds exactly one node", CountOnFloor(sample, sample.Floors - 1) == 1);
        Check("Reachable(null) returns the entrances", sample.Reachable(null).Count == sample.StartIds.Count);
        Check("Reachable(boss) is empty", sample.Reachable(sample.BossId).Count == 0);
        GD.Print($"  seed 7: {sample.Nodes.Count} nodes, {sample.StartIds.Count} entrances, "
                 + $"{sample.Floors} floors x {sample.Lanes} lanes.");

        var disabled = RunMapGenerator.Generate(7, cfg with { MinMeetingsPerFloor = 0, MaxMeetingsPerFloor = 0 });
        Check("meeting placement can be disabled", disabled.Nodes.All(node => node.Kind != NodeKind.Meeting));
        var narrow = RunMapGenerator.Generate(7, cfg with { Lanes = 1, Paths = 1 });
        Check("a single route is not forced through a meeting", narrow.Nodes.All(node => node.Kind != NodeKind.Meeting));
        var tiny = RunMapGenerator.Generate(7, cfg with { Floors = 3 });
        Check("tiny maps preserve entrance, campsite and boss", tiny.Nodes.All(node => node.Kind != NodeKind.Meeting));
        var party = Party.Build(Delve.Presets.PresetCharacters.PlayerId, System.Array.Empty<string>(), new UnlockState(), Party.DefaultLevel);
        var run = RunState.Start(7, party, cfg);
        for (int stratum = 0; stratum < Delve.Data.FloorThemes.Count; stratum++)
        {
            Check($"floor {stratum + 1} can offer Wayfarers", run.Map.Nodes.Any(node => node.Kind == NodeKind.Meeting));
            if (!run.OnFinalStratum) run.AdvanceStratum();
        }
        return Task.CompletedTask;
    }

    /// <summary>
    /// Edges (f,a)-(f+1,b) and (f,c)-(f+1,d) cross when a &lt; c and b &gt; d, or a &gt; c and b &lt; d.
    /// </summary>
    private static int CountCrossings(RunMap map)
    {
        int count = 0;
        var edges = new List<(int Floor, int From, int To)>();
        foreach (var node in map.Nodes)
        {
            if (node.Floor >= map.Floors - 2) continue; // the funnel into the boss is allowed to fan.
            foreach (int next in node.Next)
                edges.Add((node.Floor, node.Lane, map.Nodes[next].Lane));
        }
        for (int i = 0; i < edges.Count; i++)
        {
            for (int j = i + 1; j < edges.Count; j++)
            {
                if (edges[i].Floor != edges[j].Floor) continue;
                if ((edges[i].From - edges[j].From) * (edges[i].To - edges[j].To) < 0) count++;
            }
        }
        return count;
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

    private static void Flood(RunMap map, int from, HashSet<int> seen, NodeKind? skip = null)
    {
        if (map.Nodes[from].Kind == skip) return;
        if (!seen.Add(from)) return;
        foreach (int next in map.Nodes[from].Next)
            Flood(map, next, seen, skip);
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
