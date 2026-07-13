using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>Lifecycle stage of a farm plot.</summary>
public enum PlotStage
{
    Untilled,
    Tilled,
    Planted,
    Mature,
}

/// <summary>
/// Mutable state of a single farm tile. Exposed read-only to the world scene, which renders from
/// <see cref="FarmSystem.PlotChanged"/> events plus <see cref="FarmSystem.GetPlot"/> queries.
/// </summary>
public sealed class Plot
{
    public required Vector2I Tile { get; init; }
    public PlotStage Stage { get; set; } = PlotStage.Untilled;

    /// <summary>Crop growing here (a <see cref="CropDefinition.Id"/>), or null when empty.</summary>
    public string? CropId { get; set; }

    /// <summary>Watered days accumulated toward the next maturity.</summary>
    public int DaysGrown { get; set; }

    /// <summary>Whether the plot was watered during the current day.</summary>
    public bool WateredToday { get; set; }
}

/// <summary>
/// Owns the farm plot grid and the till → plant → water → grow → harvest loop. Pure C# — the
/// world scene is a passive renderer. Growth advances only on <see cref="OnDayEnded"/> (overnight),
/// and only for plots watered that day. Season mismatch kills a growing crop.
///
/// Constructor-injected deps: the shared <see cref="Inventory"/> (seeds consumed / yields added)
/// and a season provider (so the system reads the day clock's current season without owning it).
/// </summary>
public sealed class FarmSystem
{
    private readonly Inventory _inventory;
    private readonly Func<Season> _currentSeason;
    private readonly Dictionary<Vector2I, Plot> _plots = new();
    private Func<Vector2I, bool>? _isTillable;

    /// <summary>
    /// Phase-4 capability provider: the farm's building-granted capabilities from the effect
    /// aggregator (<see cref="OutpostEffects.FarmCapabilities"/>). Null (the default) → baseline
    /// (<see cref="FarmCapabilities.Baseline"/>: no auto-water, no greenhouse, 0 plot allowance), so
    /// with no farmhouse commissioned every rule below is byte-identical to today.
    /// </summary>
    private Func<FarmCapabilities>? _capabilities;

    /// <summary>Raised after a plot's state changes, with the affected tile.</summary>
    public event Action<Vector2I>? PlotChanged;

    public FarmSystem(Inventory inventory, Func<Season> currentSeason)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _currentSeason = currentSeason ?? throw new ArgumentNullException(nameof(currentSeason));
    }

    /// <summary>
    /// Inject the world's tillability predicate (the map's "farmable" flag plus occupancy — the
    /// scene adapter owns map truth, this system owns the rules). Null (the default) is permissive
    /// so pure-C# tests and headless tooling keep running without a world; the world scene binds on
    /// enter and clears on exit so a freed scene is never queried.
    /// </summary>
    public void SetTillable(Func<Vector2I, bool>? isTillable) => _isTillable = isTillable;

    /// <summary>
    /// Inject the building-effect capability provider (GameState binds it to
    /// <see cref="OutpostEffects.FarmCapabilities"/>). Null clears it back to baseline.
    /// </summary>
    public void SetCapabilities(Func<FarmCapabilities>? capabilities) => _capabilities = capabilities;

    private FarmCapabilities Caps => _capabilities?.Invoke() ?? FarmCapabilities.Baseline;

    // --- Capability queries (read the aggregator; DEFAULT to baseline) ---

    /// <summary>Auto-watering active — planted plots grow overnight without a manual water. Baseline false.</summary>
    public bool AutoWaterEnabled => Caps.AutoWater;

    /// <summary>Greenhouse active — crops may be planted/grown out of season. Baseline false.</summary>
    public bool GreenhouseEnabled => Caps.Greenhouse;

    /// <summary>Refinement 2 — the farm TILLABLE-AREA expansion level (summed FarmPlots effect). Unlocks
    /// farmable tile zones ≤ this level (the world's IsTillable gate reads it via GameState); baseline 0
    /// = base zone only. See <see cref="FarmZones"/> and <see cref="FarmCapabilities.TillableAreaLevel"/>.</summary>
    public int TillableAreaLevel => Caps.TillableAreaLevel;

    // --- Queries ---

    /// <summary>The plot at <paramref name="tile"/>, or null if never touched (implicitly untilled).</summary>
    public Plot? GetPlot(Vector2I tile) => _plots.TryGetValue(tile, out var p) ? p : null;

    /// <summary>Every plot the system is tracking.</summary>
    public IReadOnlyCollection<Plot> AllPlots => _plots.Values;

    // --- Commands (validate → mutate → raise PlotChanged) ---

    /// <summary>Till bare ground into a plantable plot. Fails if the world says the cell isn't
    /// tillable (non-farmable ground, occupied cell) or the tile is already tilled/planted.</summary>
    public bool TillPlot(Vector2I tile)
    {
        if (_isTillable != null && !_isTillable(tile))
            return false;

        var plot = GetPlot(tile);
        if (plot != null && plot.Stage != PlotStage.Untilled)
            return false;

        if (plot == null)
        {
            plot = new Plot { Tile = tile };
            _plots[tile] = plot;
        }

        plot.Stage = PlotStage.Tilled;
        plot.CropId = null;
        plot.DaysGrown = 0;
        plot.WateredToday = false;
        PlotChanged?.Invoke(tile);
        return true;
    }

    /// <summary>
    /// Plant <paramref name="cropId"/> on a tilled plot, consuming one seed from the inventory.
    /// Fails if the plot isn't tilled, the crop is unknown, it can't grow this season, or no seed
    /// is held.
    /// </summary>
    public bool PlantCrop(Vector2I tile, string cropId)
    {
        var plot = GetPlot(tile);
        if (plot == null || plot.Stage != PlotStage.Tilled)
            return false;
        if (!Crops.TryGet(cropId, out var crop))
            return false;
        // Greenhouse (Phase-4 farm capability) lifts the season gate; baseline enforces it as before.
        if (!GreenhouseEnabled && !crop.Seasons.Contains(_currentSeason()))
            return false;
        if (!_inventory.RemoveItem(crop.SeedItemId, 1))
            return false;

        plot.Stage = PlotStage.Planted;
        plot.CropId = cropId;
        plot.DaysGrown = 0;
        plot.WateredToday = false;
        PlotChanged?.Invoke(tile);
        return true;
    }

    /// <summary>Water a planted (or maturing) plot for today. Fails on empty/untilled plots.</summary>
    public bool WaterPlot(Vector2I tile)
    {
        var plot = GetPlot(tile);
        if (plot == null || plot.CropId == null)
            return false;
        if (plot.WateredToday)
            return true; // idempotent

        plot.WateredToday = true;
        PlotChanged?.Invoke(tile);
        return true;
    }

    /// <summary>
    /// Harvest a mature plot: adds the crop yield to the inventory, then either resets a regrowing
    /// crop back to a pre-maturity state or clears a one-shot crop back to tilled soil. Fails if the
    /// plot isn't mature.
    /// </summary>
    public bool HarvestPlot(Vector2I tile)
    {
        var plot = GetPlot(tile);
        if (plot == null || plot.Stage != PlotStage.Mature || plot.CropId == null)
            return false;
        if (!Crops.TryGet(plot.CropId, out var crop))
            return false;

        _inventory.AddItem(crop.YieldItemId, crop.YieldCount);

        if (crop.Regrows)
        {
            // Re-mature after RegrowDays: set DaysGrown so that RegrowDays more watered days hit GrowthDays.
            plot.Stage = PlotStage.Planted;
            plot.DaysGrown = Math.Max(0, crop.GrowthDays - crop.RegrowDays);
            plot.WateredToday = false;
        }
        else
        {
            plot.Stage = PlotStage.Tilled;
            plot.CropId = null;
            plot.DaysGrown = 0;
            plot.WateredToday = false;
        }

        PlotChanged?.Invoke(tile);
        return true;
    }

    /// <summary>
    /// Overnight growth pass — call before the calendar advances so crops "grow overnight" for the
    /// day just played. For each planted plot: a season mismatch kills the crop (back to tilled);
    /// otherwise a watered plot advances one growth day (maturing at <see cref="CropDefinition.GrowthDays"/>).
    /// The watered flag is cleared on every plot regardless.
    /// </summary>
    public void OnDayEnded()
    {
        var season = _currentSeason();
        // Phase-4 farm capabilities snapshot for this pass (baseline: false / false).
        bool greenhouse = GreenhouseEnabled;
        bool autoWater = AutoWaterEnabled;

        foreach (var plot in _plots.Values)
        {
            bool changed = false;

            if (plot.CropId != null && Crops.TryGet(plot.CropId, out var crop))
            {
                if (!greenhouse && !crop.Seasons.Contains(season))
                {
                    // Out of season → the crop dies, leaving tilled soil (greenhouse suppresses this).
                    plot.Stage = PlotStage.Tilled;
                    plot.CropId = null;
                    plot.DaysGrown = 0;
                    changed = true;
                }
                else if ((plot.WateredToday || autoWater) && plot.Stage == PlotStage.Planted)
                {
                    // Auto-watering advances growth even when the player didn't water by hand.
                    plot.DaysGrown++;
                    if (plot.DaysGrown >= crop.GrowthDays)
                        plot.Stage = PlotStage.Mature;
                    changed = true;
                }
            }

            if (plot.WateredToday)
            {
                plot.WateredToday = false;
                changed = true;
            }

            if (changed)
                PlotChanged?.Invoke(plot.Tile);
        }
    }

    /// <summary>Replace all plots (used by the save system).</summary>
    public void LoadPlots(IEnumerable<Plot> plots)
    {
        _plots.Clear();
        foreach (var plot in plots)
            _plots[plot.Tile] = plot;

        foreach (var tile in _plots.Keys)
            PlotChanged?.Invoke(tile);
    }
}
