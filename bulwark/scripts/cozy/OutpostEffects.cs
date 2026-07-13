using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// Phase-4 BUILDING-EFFECT APPLICATION FRAMEWORK — the aggregator that turns the declarative
/// <see cref="BuildingEffect"/> data (carried inert by the Phase-2 building tiers) into a single
/// queryable capability state the game systems consult. Pure C# and unit-testable.
///
/// It is DECOUPLED from <see cref="BuildingSystem"/>: it consumes whatever flat sequence of ACTIVE
/// effects a source function yields (GameState wires <see cref="BuildingSystem.ActiveEffects"/> — the
/// cumulative effects of commissioned buildings — but a spike can inject a synthetic source to prove
/// the wiring without touching the shipped registry). Nothing here commits any specific upgrade
/// value or mechanic; it aggregates generically per <see cref="BuildingEffectType"/> category.
///
/// Aggregation model per category:
///  - NUMERIC SUMS (FarmPlots, InfirmaryHealing): magnitudes added across every active tier (a grown
///    building keeps earlier tiers' effects, so "+2" then "+2 more" totals +4).
///  - BOOLEAN FLAGS (WateringAutomation, Greenhouse): present when any active effect declares them.
///  - UNLOCK CEILING (SmithyTier): the MAX magnitude reached (tiers are a ladder, not additive),
///    defaulting to <see cref="SmithyTier.Base"/> when no smithy effect is active.
///  - UNLOCK SET (CategoryUnlock): the set of category ids (the effect's <see cref="BuildingEffect.Detail"/>).
///
/// BASELINE: with an empty source (no commissioned buildings) every query returns its ungated default
/// — that IS "anything not gated by progression", available always; effects only ADD on top.
/// </summary>
public sealed class OutpostEffects
{
    private readonly Func<IEnumerable<BuildingEffect>> _source;

    private readonly Dictionary<BuildingEffectType, int> _sums = new();
    private readonly HashSet<BuildingEffectType> _present = new();
    private readonly HashSet<string> _categories = new();
    private SmithyTier _smithyTier = SmithyTier.Base;

    /// <summary>Raised whenever the aggregated state is recomputed (GameState re-exposes as EffectsChanged).</summary>
    public event Action? Changed;

    public OutpostEffects(Func<IEnumerable<BuildingEffect>> activeEffectsSource)
    {
        _source = activeEffectsSource ?? throw new ArgumentNullException(nameof(activeEffectsSource));
        Recompute(); // establish baseline defaults from the (possibly empty) source
    }

    /// <summary>
    /// Rebuild the aggregated state from the current active-effect source. Call on BuildingChanged and
    /// after a load (the state is DERIVED from building state, so it is never itself serialized).
    /// </summary>
    public void Recompute()
    {
        _sums.Clear();
        _present.Clear();
        _categories.Clear();

        int smithyMag = 0;
        bool anySmithy = false;

        foreach (var e in _source())
        {
            _present.Add(e.Type);
            _sums[e.Type] = (_sums.TryGetValue(e.Type, out var n) ? n : 0) + e.Magnitude;

            switch (e.Type)
            {
                case BuildingEffectType.SmithyTier:
                    anySmithy = true;
                    if (e.Magnitude > smithyMag) smithyMag = e.Magnitude;
                    break;
                case BuildingEffectType.CategoryUnlock:
                    if (!string.IsNullOrEmpty(e.Detail))
                        _categories.Add(e.Detail!);
                    break;
            }
        }

        _smithyTier = anySmithy ? ClampTier(smithyMag) : SmithyTier.Base;
        Changed?.Invoke();
    }

    // ===================== Generic queries =====================

    /// <summary>Summed magnitude for an effect type (0 when none active).</summary>
    public int Sum(BuildingEffectType type) => _sums.TryGetValue(type, out var n) ? n : 0;

    /// <summary>Whether any active effect of this type is present (the flag/presence query).</summary>
    public bool Has(BuildingEffectType type) => _present.Contains(type);

    // ===================== Per-category typed queries =====================

    /// <summary>Refinement 2 — the farm TILLABLE-AREA expansion level: the summed FarmPlots-effect
    /// magnitude across active farmhouse tiers (baseline 0). This is a LEVEL, not a plot count — it
    /// unlocks farmable tile zones ≤ level (see <see cref="FarmZones"/>), expanding the legal tilling
    /// area as the farm grows.</summary>
    public int TillableAreaLevel => Sum(BuildingEffectType.FarmPlots);

    /// <summary>Auto-watering active (baseline false).</summary>
    public bool AutoWatering => Has(BuildingEffectType.WateringAutomation);

    /// <summary>Greenhouse active (baseline false).</summary>
    public bool Greenhouse => Has(BuildingEffectType.Greenhouse);

    /// <summary>The smithy catalog/rune unlock ceiling (baseline <see cref="SmithyTier.Base"/>).</summary>
    public SmithyTier SmithyTier => _smithyTier;

    /// <summary>Additive Treat-Wounds/rest healing bonus (baseline 0).</summary>
    public int InfirmaryHealingBonus => Sum(BuildingEffectType.InfirmaryHealing);

    /// <summary>The set of unlocked category ids (CategoryUnlock effects' Detail). Empty at baseline.</summary>
    public IReadOnlyCollection<string> UnlockedCategories => _categories;

    /// <summary>Generic membership test any system can gate on without new framework.</summary>
    public bool IsCategoryUnlocked(string categoryId) => categoryId != null && _categories.Contains(categoryId);

    /// <summary>Bundle of the farm's building-granted capabilities (baseline = <see cref="FarmCapabilities.Baseline"/>).</summary>
    public FarmCapabilities FarmCapabilities => new()
    {
        TillableAreaLevel = TillableAreaLevel,
        AutoWater = AutoWatering,
        Greenhouse = Greenhouse,
    };

    private static SmithyTier ClampTier(int magnitude)
        => (SmithyTier)Math.Clamp(magnitude, (int)SmithyTier.Base, (int)SmithyTier.Advanced);
}
