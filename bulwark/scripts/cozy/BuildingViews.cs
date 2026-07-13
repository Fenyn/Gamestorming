using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// Passive view-model for the planning-table / build-menu UI. Engine + system types never leak here
/// — the UI renders these plain shapes and raises intents (commission / contribute / upgrade) that
/// the host forwards to GameState commands. Built by <see cref="BuildingSystem.BuildView"/>.
/// </summary>
public sealed class PlanningTableView
{
    public List<BuildingView> Buildings { get; } = new();
}

/// <summary>One building's row in the planning table.</summary>
public sealed class BuildingView
{
    public string Id { get; init; } = "";
    public string DisplayName { get; init; } = "";

    /// <summary>False before the construction bundle is paid.</summary>
    public bool Commissioned { get; init; }

    /// <summary>Current tier (0 = not built).</summary>
    public int Tier { get; init; }
    public int MaxTier { get; init; }

    /// <summary>True when the building is built and at its highest tier (nothing more to do).</summary>
    public bool AtMaxTier { get; init; }

    /// <summary>Short status line ("Not built", "Tier 1", "Tier 2 (max)").</summary>
    public string StatusText { get; set; } = "";

    /// <summary>True when there is a bundle to work toward (commission or upgrade).</summary>
    public bool HasTarget { get; set; }

    /// <summary>Label for the current target ("Commission", "Upgrade to Tier 2").</summary>
    public string TargetLabel { get; set; } = "";

    /// <summary>Per-item have/need lines for the current target bundle.</summary>
    public List<BundleLineView> Bundle { get; } = new();

    /// <summary>Declarative effects active at the current tier (for display).</summary>
    public List<EffectLineView> ActiveEffects { get; } = new();

    /// <summary>Declarative effects the next tier would grant (upgrade preview).</summary>
    public List<EffectLineView> NextEffects { get; } = new();

    /// <summary>Construction bundle fully affordable right now.</summary>
    public bool CanCommission { get; set; }

    /// <summary>Next-tier upgrade bundle fully accumulated right now.</summary>
    public bool CanUpgrade { get; set; }
}

/// <summary>One item line of a target bundle: how much is committed/available vs required.</summary>
public sealed class BundleLineView
{
    public string ItemId { get; init; } = "";
    public string DisplayName { get; init; } = "";

    /// <summary>Total offerings the bundle requires.</summary>
    public int Need { get; init; }

    /// <summary>Amount already ACCUMULATED on the building (upgrade targets only; 0 for construction,
    /// which is paid all-at-once).</summary>
    public int Contributed { get; init; }

    /// <summary>How many of this item the party currently holds.</summary>
    public int InventoryCount { get; init; }

    /// <summary>Suggested single-click contribution: min(remaining need, held). 0 for construction
    /// targets (commission consumes the whole bundle at once) or when the line is complete.</summary>
    public int ContributableNow { get; init; }

    /// <summary>True when this line's requirement is satisfied.</summary>
    public bool Complete { get; init; }
}

/// <summary>A declarative effect line (already human-readable text).</summary>
public sealed class EffectLineView
{
    public string Text { get; init; } = "";
}
