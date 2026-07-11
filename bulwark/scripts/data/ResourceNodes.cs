using System.Collections.Generic;
using Bulwark.Cozy;

namespace Bulwark.Data;

/// <summary>
/// Declarative definition of a harvestable territory resource node. Data-only per CLAUDE.md —
/// adding a node type touches <see cref="ResourceNodes"/> only, no system code. Harvest costs
/// game-minutes through the day clock (the PF2e exploration-activity seam), not real time.
/// </summary>
public sealed class ResourceNodeDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }

    /// <summary>Tool-belt verb required to harvest (Hand = forage).</summary>
    public required ToolKind Tool { get; init; }

    /// <summary>Item added to the shared inventory on harvest (an <see cref="ItemDefinition.Id"/>).</summary>
    public required string YieldItemId { get; init; }

    /// <summary>How many yield items one harvest produces.</summary>
    public int YieldCount { get; init; } = 1;

    /// <summary>Game-minutes the harvest interaction costs (charged via DayClock.SpendTime).</summary>
    public int HarvestMinutes { get; init; } = 10;

    /// <summary>When true, a depleted node respawns on day change; when false it stays gone.</summary>
    public bool RespawnsDaily { get; init; } = true;
}

/// <summary>Static registry of resource-node definitions. T1 MVP set; additions are data-only.</summary>
public static class ResourceNodes
{
    public static readonly ResourceNodeDefinition Rock = new()
    {
        Id = "rock", DisplayName = "Rock", Tool = ToolKind.Pick,
        YieldItemId = "stone", YieldCount = 2, HarvestMinutes = 15,
    };

    public static readonly ResourceNodeDefinition HerbPatch = new()
    {
        Id = "herb_patch", DisplayName = "Herb Patch", Tool = ToolKind.Hand,
        YieldItemId = "herb", YieldCount = 2, HarvestMinutes = 10,
    };

    public static readonly ResourceNodeDefinition BerryBush = new()
    {
        Id = "berry_bush", DisplayName = "Berry Bush", Tool = ToolKind.Hand,
        YieldItemId = "berries", YieldCount = 3, HarvestMinutes = 10,
    };

    // One-shot windfall: once collected it does not respawn (exercises the flag both ways).
    public static readonly ResourceNodeDefinition FallenWood = new()
    {
        Id = "fallen_wood", DisplayName = "Fallen Wood", Tool = ToolKind.Axe,
        YieldItemId = "wood", YieldCount = 2, HarvestMinutes = 15, RespawnsDaily = false,
    };

    private static readonly Dictionary<string, ResourceNodeDefinition> ById = BuildIndex(
        Rock, HerbPatch, BerryBush, FallenWood);

    public static IReadOnlyCollection<ResourceNodeDefinition> All => ById.Values;

    public static bool IsDefined(string id) => ById.ContainsKey(id);

    public static ResourceNodeDefinition Get(string id) => ById[id];

    public static bool TryGet(string id, out ResourceNodeDefinition def) => ById.TryGetValue(id, out def!);

    private static Dictionary<string, ResourceNodeDefinition> BuildIndex(params ResourceNodeDefinition[] defs)
    {
        var index = new Dictionary<string, ResourceNodeDefinition>(defs.Length);
        foreach (var def in defs)
            index[def.Id] = def;
        return index;
    }
}
