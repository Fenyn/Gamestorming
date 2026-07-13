namespace Bulwark.Cozy;

/// <summary>
/// The farm's building-granted capabilities, resolved from the <see cref="OutpostEffects"/>
/// aggregator and pushed into <see cref="FarmSystem"/> via <see cref="FarmSystem.SetCapabilities"/>.
/// The <see cref="Baseline"/> (default) value reproduces today's no-building behaviour exactly:
/// tillable-area level 0, no auto-watering, no greenhouse.
/// </summary>
public readonly struct FarmCapabilities
{
    /// <summary>
    /// Refinement 2 — the farm TILLABLE-AREA expansion level (summed FarmPlots effect magnitude). NOT a
    /// plot count: it unlocks farmable tile ZONES ≤ this level (see <see cref="FarmZones"/>), so farm
    /// upgrades widen the legal-tilling AREA. Baseline 0 = only the base zone (or unauthored tiles) is
    /// tillable — byte-identical to the pre-refinement map-driven rule.
    /// </summary>
    public int TillableAreaLevel { get; init; }

    /// <summary>When true, planted plots count as watered each night without a manual water action.</summary>
    public bool AutoWater { get; init; }

    /// <summary>When true, crops may be planted and grown out of their normal season.</summary>
    public bool Greenhouse { get; init; }

    /// <summary>The ungated default: reproduces current behaviour (area level 0, no auto-water, no greenhouse).</summary>
    public static FarmCapabilities Baseline => default;
}
