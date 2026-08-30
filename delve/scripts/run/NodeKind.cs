using System.Collections.Generic;

namespace Delve.Run;

/// <summary>Kind of a node on the run map. Shop and Treasure are reserved and never generated.</summary>
public enum NodeKind
{
    Combat,
    Elite,
    Event,
    Rest,
    Boss,
    Shop,
    Treasure,
}

/// <summary>Presentation data for one node kind: the delve-fiction name, the one-line tooltip
/// blurb, and the medallion size the map draws it at. Threat scales the medallion - a Lair
/// outsizes a Skirmish, the Warden dwarfs both.</summary>
public sealed record NodeKindEntry(
    NodeKind Kind, string DisplayName, string Blurb, float MapDiameter, bool Generated);

/// <summary>
/// The single per-kind table (CLAUDE.md: per-kind behaviour lives in one data table). The generator
/// reads <see cref="Generated"/> to know which kinds it may place; the map UI reads the name/size,
/// and <see cref="Delve.UI.MapNodeShapes"/> pairs each kind with its silhouette.
/// </summary>
public static class NodeKindInfo
{
    private static readonly IReadOnlyDictionary<NodeKind, NodeKindEntry> Table =
        new Dictionary<NodeKind, NodeKindEntry>
        {
            [NodeKind.Combat] = new(NodeKind.Combat, "Skirmish",
                "A fight against this floor's creatures.", 60f, true),
            [NodeKind.Elite] = new(NodeKind.Elite, "Lair",
                "An elite den. A harder fight than a skirmish.", 72f, true),
            [NodeKind.Event] = new(NodeKind.Event, "Happenstance",
                "A chance encounter. Something to gain or lose.", 60f, true),
            [NodeKind.Rest] = new(NodeKind.Rest, "Campsite",
                "Make camp: a new day, fresh rests, and the ward regains strength.", 64f, true),
            [NodeKind.Boss] = new(NodeKind.Boss, "Depths Warden",
                "The floor's guardian. Defeat it to delve deeper.", 98f, true),
            [NodeKind.Shop] = new(NodeKind.Shop, "Trader",
                "Spend gold on gear and supplies.", 60f, false),
            [NodeKind.Treasure] = new(NodeKind.Treasure, "Cache",
                "A stash of loot.", 60f, false),
        };

    /// <summary>Table row for a kind.</summary>
    public static NodeKindEntry Get(NodeKind kind) => Table[kind];

    /// <summary>Fiction name shown on the map.</summary>
    public static string DisplayName(NodeKind kind) => Table[kind].DisplayName;

    /// <summary>False for the reserved kinds the generator must never place.</summary>
    public static bool IsGenerated(NodeKind kind) => Table[kind].Generated;
}
