using System.Collections.Generic;
using Delve.Data;

namespace Delve.Run;

/// <summary>How a run ended, or that it has not.</summary>
public enum RunOutcome
{
    InProgress,
    Victory,
    Defeat,
}

/// <summary>
/// Everything one run is: its seed, its party, the day clock, the Wardstone, and the floor
/// (stratum) the party is on with that floor's map, position and history. A run descends through
/// <see cref="FloorThemes.Count"/> floors; beating a floor's boss calls
/// <see cref="AdvanceStratum"/> for a fresh map. Pure state - the flow layer owns the transitions
/// and node dispatch. (The design doc says "floor" for what this class calls a stratum;
/// <see cref="MapNode.Floor"/> already means a row inside one map.)
/// </summary>
public sealed class RunState
{
    private readonly List<int> _history = new();
    private readonly RunMapConfig _config;

    private RunState(
        int seed, Party party, RunMapConfig config, DayClock clock, Wardstone wardstone,
        LevelingRules leveling)
    {
        Seed = seed;
        _config = config;
        Party = party;
        Clock = clock;
        Wardstone = wardstone;
        Leveling = leveling;
        Map = GenerateMap();
    }

    /// <summary>Run seed. Every deterministic roll mixes it through <see cref="RunRng"/>.</summary>
    public int Seed { get; }

    /// <summary>Floor index, 0-based. The doc's floor N is stratum N-1.</summary>
    public int Stratum { get; private set; }

    /// <summary>Seed for this floor's node-scoped rolls, so the same node id on a deeper floor
    /// rolls fresh terrain, fights and tiers.</summary>
    public int StratumSeed => RunRng.StableSeed(Seed, Stratum, "stratum");

    /// <summary>True on the last floor; its boss is the Depths Warden and ends the run.</summary>
    public bool OnFinalStratum => Stratum >= FloorThemes.Count - 1;

    public RunMap Map { get; private set; }

    public Party Party { get; }

    public DayClock Clock { get; }

    /// <summary>The ward the party carries. Its cap feeds the encounter generator.</summary>
    public Wardstone Wardstone { get; }

    /// <summary>Names of recently generated encounters, newest last. The generator reads this to
    /// avoid repeating a composition; <see cref="Run.GeneratedEncounters"/> maintains the cap.</summary>
    public List<string> RecentTemplates { get; } = new();

    /// <summary>Node the party stands on, or null before the first pick.</summary>
    public int? CurrentNodeId { get; private set; }

    /// <summary>Node ids in visit order.</summary>
    public IReadOnlyList<int> History => _history;

    /// <summary>Floor the party stands on. 0 before the first pick.</summary>
    public int Floor { get; private set; }

    public RunOutcome Outcome { get; set; } = RunOutcome.InProgress;

    /// <summary>Run currency. Events move it; spending lands with the reward layer.</summary>
    public int Gold { get; set; }

    /// <summary>XP toward the next party level. <see cref="PartyLeveling.Award"/> owns it.</summary>
    public int Xp { get; set; }

    /// <summary>The run's leveling tunables.</summary>
    public LevelingRules Leveling { get; }

    /// <summary>Ids the party may pick from right now.</summary>
    public IReadOnlyList<int> Reachable() => Map.Reachable(CurrentNodeId);

    /// <summary>The node the party stands on, or null before the first pick.</summary>
    public MapNode? CurrentNode => CurrentNodeId == null ? null : Map.Node(CurrentNodeId.Value);

    /// <summary>
    /// Move onto a node. Refuses (false, no change) any node the map does not list as reachable from
    /// the current one, so an out-of-order UI click can never skip a floor.
    /// </summary>
    public bool Advance(int nodeId)
    {
        var node = Map.Node(nodeId);
        if (node == null) return false;

        bool legal = false;
        foreach (int id in Map.Reachable(CurrentNodeId))
        {
            if (id == nodeId) { legal = true; break; }
        }
        if (!legal) return false;

        CurrentNodeId = nodeId;
        Floor = node.Floor;
        node.Visited = true;
        _history.Add(nodeId);
        return true;
    }

    /// <summary>
    /// Beaten this floor's boss: step onto the next floor with a fresh map, standing before its
    /// first pick. The caller (RunDirector) refills the ward and decides victory on the final
    /// floor; this only moves the state down.
    /// </summary>
    public void AdvanceStratum()
    {
        Stratum++;
        Map = GenerateMap();
        CurrentNodeId = null;
        Floor = 0;
        _history.Clear();
    }

    private RunMap GenerateMap() => RunMapGenerator.Generate(StratumSeed, _config);

    /// <summary>Generate floor 1's map for a seed and stand the party at the entrance, before any pick.</summary>
    public static RunState Start(
        int seed, Party party, RunMapConfig config, int shortRestsPerDay = 3,
        WardstoneRules? wardRules = null, LevelingRules? leveling = null)
    {
        return new RunState(
            seed, party, config, new DayClock(shortRestsPerDay), new Wardstone(wardRules),
            leveling ?? new LevelingRules());
    }
}
