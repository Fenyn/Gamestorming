using System.Collections.Generic;

namespace Bulwark.Territory;

/// <summary>View-model for the gate party-selection panel. UI-facing only — no engine types.</summary>
public sealed class PartySelectView
{
    /// <summary>Where the gate leads, e.g. "the Verdant Fringe".</summary>
    public string DestinationName { get; set; } = "";

    /// <summary>Travel cost shown on the confirm button.</summary>
    public int TravelMinutes { get; set; }

    /// <summary>The always-present avatar (the Veteran), shown as a fixed row.</summary>
    public string LeaderName { get; set; } = "";

    public List<CompanionOptionView> Companions { get; } = new();
}

/// <summary>One selectable companion row on the party-selection panel.</summary>
public sealed class CompanionOptionView
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string HpText { get; set; } = "";

    /// <summary>False for dead members — they cannot be taken along.</summary>
    public bool CanJoin { get; set; }
}

/// <summary>Outcome of one resource-node harvest, for the HUD toast.</summary>
public sealed class HarvestResultView
{
    public string NodeName { get; set; } = "";
    public string ItemName { get; set; } = "";
    public int Count { get; set; }
    public int MinutesSpent { get; set; }
}

/// <summary>One item stack docked by the defeat penalty.</summary>
public sealed class DefeatLossView
{
    public string ItemName { get; set; } = "";
    public int Lost { get; set; }
}

/// <summary>Summary of a territory defeat, consumed by the outpost wake toast.</summary>
public sealed class DefeatSummaryView
{
    public List<DefeatLossView> Losses { get; } = new();
}

/// <summary>Result of completing a territory encounter — tells the scene where to route.</summary>
public sealed class TerritoryEncounterOutcome
{
    public bool Victory { get; set; }

    /// <summary>Territory to return to on victory (the stored return context's map).</summary>
    public string TerritoryId { get; set; } = "";
}
