using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>A resource-node placement in a territory: a stable node id bound to a node definition.
/// The territory scene carries a matching <c>%Node_&lt;NodeId&gt;</c> marker for its position.</summary>
public sealed class TerritoryNode
{
    public required string NodeId { get; init; }

    /// <summary>The <see cref="ResourceNodeDefinition.Id"/> this placement instantiates.</summary>
    public required string ResourceId { get; init; }
}

/// <summary>A roaming-enemy spawn in a territory: a stable roamer id with its weighted encounter
/// table. The scene carries a matching <c>%Roamer_&lt;RoamerId&gt;</c> marker for its position.</summary>
public sealed class TerritoryRoamer
{
    public required string RoamerId { get; init; }

    /// <summary>Weighted encounter entries this roamer rolls on contact.</summary>
    public required IReadOnlyList<WeightedEncounter> Encounters { get; init; }
}

/// <summary>
/// Declarative definition of one territory map: scene path plus the node/roamer placements the
/// systems (and the blockout builder) share as the single source of truth for ids.
/// </summary>
public sealed class TerritoryDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public required string ScenePath { get; init; }
    public required IReadOnlyList<TerritoryNode> Nodes { get; init; }
    public required IReadOnlyList<TerritoryRoamer> Roamers { get; init; }
}

/// <summary>Static registry of territory maps. T1 forest only for M3; additions are data-only.</summary>
public static class Territories
{
    public static readonly TerritoryDefinition Forest = new()
    {
        Id = "verdant_fringe",
        DisplayName = "the Verdant Fringe",
        ScenePath = "res://scenes/territory/forest.tscn",
        Nodes = new[]
        {
            new TerritoryNode { NodeId = "rock_1", ResourceId = "rock" },
            new TerritoryNode { NodeId = "rock_2", ResourceId = "rock" },
            new TerritoryNode { NodeId = "rock_3", ResourceId = "rock" },
            new TerritoryNode { NodeId = "herb_1", ResourceId = "herb_patch" },
            new TerritoryNode { NodeId = "herb_2", ResourceId = "herb_patch" },
            new TerritoryNode { NodeId = "berry_1", ResourceId = "berry_bush" },
            new TerritoryNode { NodeId = "berry_2", ResourceId = "berry_bush" },
            new TerritoryNode { NodeId = "berry_3", ResourceId = "berry_bush" },
            new TerritoryNode { NodeId = "wood_1", ResourceId = "fallen_wood" },
            new TerritoryNode { NodeId = "wood_2", ResourceId = "fallen_wood" },
        },
        Roamers = new[]
        {
            // gob_1 is deliberately single-entry (deterministic — the territory spike relies on it).
            new TerritoryRoamer
            {
                RoamerId = "gob_1",
                Encounters = new[] { new WeightedEncounter { EncounterId = "goblin_pair" } },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_2",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "goblin_pair", Weight = 2 },
                    new WeightedEncounter { EncounterId = "goblin_patrol", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_3",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "goblin_patrol", Weight = 2 },
                    new WeightedEncounter { EncounterId = "goblin_warband", Weight = 1 },
                },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_4",
                Encounters = new[] { new WeightedEncounter { EncounterId = "rat_pack" } },
            },
            new TerritoryRoamer
            {
                RoamerId = "gob_5",
                Encounters = new[]
                {
                    new WeightedEncounter { EncounterId = "goblin_pair", Weight = 1 },
                    new WeightedEncounter { EncounterId = "rat_pack", Weight = 1 },
                },
            },
        },
    };

    private static readonly DefinitionRegistry<TerritoryDefinition> Registry = new(d => d.Id, Forest);

    public static IReadOnlyCollection<TerritoryDefinition> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static TerritoryDefinition Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out TerritoryDefinition def) => Registry.TryGet(id, out def);
}
