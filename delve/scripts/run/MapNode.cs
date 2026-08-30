using System.Collections.Generic;

namespace Delve.Run;

/// <summary>
/// One node of the run map. Ids are stable within a map; <see cref="Next"/> holds the ids of the
/// nodes on the following floor this node leads to. Plain data - no Godot types.
/// </summary>
public sealed class MapNode
{
    /// <summary>Index into <see cref="RunMap.Nodes"/>. Also the per-node RNG index.</summary>
    public required int Id { get; init; }

    /// <summary>Row, 0 at the entrance and <c>Floors - 1</c> at the boss.</summary>
    public required int Floor { get; init; }

    /// <summary>Column within the floor.</summary>
    public required int Lane { get; init; }

    /// <summary>What happens here. Assigned by <see cref="RunMapGenerator"/>.</summary>
    public NodeKind Kind { get; set; }

    /// <summary>Ids of the nodes on floor+1 reachable from here.</summary>
    public List<int> Next { get; } = new();

    /// <summary>Set when the party has resolved this node.</summary>
    public bool Visited { get; set; }
}
