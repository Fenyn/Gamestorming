using System.Collections.Generic;
using Bulwark.Cozy;

namespace Bulwark.Data;

public static class Quests
{
    public static readonly QuestDefinition RepairLodging = new(
        "repair_lodging",
        "Repair the Lodging",
        new QuestObjective[]
        {
            new("Gather timber", "wood", 15),
            new("Gather stone", "stone", 10),
            new("Return to Tharr"),
        });

    public static readonly QuestDefinition FirstRest = new(
        "first_rest",
        "Rest for the Night",
        new QuestObjective[]
        {
            new("Sleep at the outpost"),
        });

    public static readonly QuestDefinition PlanningTable = new(
        "planning_table",
        "The Planning Table",
        new QuestObjective[]
        {
            new("Visit the planning table"),
        });

    public static readonly QuestDefinition FirstBuilding = new(
        "first_building",
        "Commission a Building",
        new QuestObjective[]
        {
            new("Commission a building at the planning table"),
        });

    private static readonly DefinitionRegistry<QuestDefinition> Registry = new(d => d.Id,
        RepairLodging, FirstRest, PlanningTable, FirstBuilding);

    public static IReadOnlyCollection<QuestDefinition> All => Registry.All;
    public static bool TryGet(string id, out QuestDefinition def) => Registry.TryGet(id, out def);
    public static QuestDefinition Get(string id) => Registry.Get(id);
}
