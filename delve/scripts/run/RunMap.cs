using System.Collections.Generic;

namespace Delve.Run;

/// <summary>
/// A generated run map: floors of merged nodes wired upward to a single boss. Immutable shape;
/// only <see cref="MapNode.Visited"/> changes during a run.
/// </summary>
public sealed class RunMap
{
    private static readonly IReadOnlyList<int> NoIds = new List<int>();

    public RunMap(int floors, int lanes, IReadOnlyList<MapNode> nodes, IReadOnlyList<int> startIds, int bossId)
    {
        Floors = floors;
        Lanes = lanes;
        Nodes = nodes;
        StartIds = startIds;
        BossId = bossId;
    }

    /// <summary>Number of rows, boss floor included.</summary>
    public int Floors { get; }

    /// <summary>Number of columns a node may occupy.</summary>
    public int Lanes { get; }

    /// <summary>Every node, indexed by <see cref="MapNode.Id"/>.</summary>
    public IReadOnlyList<MapNode> Nodes { get; }

    /// <summary>Entrance nodes on floor 0.</summary>
    public IReadOnlyList<int> StartIds { get; }

    /// <summary>The single node on the last floor.</summary>
    public int BossId { get; }

    /// <summary>The node with this id, or null when the id is out of range.</summary>
    public MapNode? Node(int id) => id >= 0 && id < Nodes.Count ? Nodes[id] : null;

    /// <summary>
    /// Ids the party may pick next. Null means "the run has not started" and yields
    /// <see cref="StartIds"/>; otherwise the given node's outgoing edges.
    /// </summary>
    public IReadOnlyList<int> Reachable(int? fromId)
    {
        if (fromId == null)
            return StartIds;
        return Node(fromId.Value)?.Next ?? NoIds;
    }
}
