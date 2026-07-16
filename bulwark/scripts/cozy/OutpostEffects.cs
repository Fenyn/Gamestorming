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
///  - BOOLEAN FLAGS (WateringAutomation, Greenhouse, Performances, FastTravel, Resurrection): present
///    when any active effect declares them.
///  - UNLOCK CEILING (SmithyTier, Husbandry, Boarding, Fishing): the MAX magnitude reached (tiers are
///    a ladder, not additive); SmithyTier defaults to <see cref="SmithyTier.Base"/>, the generic
///    leveled ones default to 0 (see <see cref="Max"/>).
///  - UNLOCK SET (CategoryUnlock, BiomeUnlock): the set of ids (the effect's <see cref="BuildingEffect.Detail"/>).
///
/// BASELINE: with an empty source (no commissioned buildings) every query returns its ungated default
/// — that IS "anything not gated by progression", available always; effects only ADD on top.
/// </summary>
public sealed class OutpostEffects
{
    private readonly List<Func<IEnumerable<BuildingEffect>>> _sources = new();

    private readonly Dictionary<BuildingEffectType, int> _sums = new();
    private readonly HashSet<BuildingEffectType> _present = new();
    private readonly HashSet<string> _categories = new();
    private readonly HashSet<string> _biomes = new();
    private readonly Dictionary<BuildingEffectType, int> _max = new();
    private SmithyTier _smithyTier = SmithyTier.Base;

    /// <summary>Raised whenever the aggregated state is recomputed (GameState re-exposes as EffectsChanged).</summary>
    public event Action? Changed;

    public OutpostEffects(Func<IEnumerable<BuildingEffect>> activeEffectsSource)
    {
        _sources.Add(activeEffectsSource ?? throw new ArgumentNullException(nameof(activeEffectsSource)));
        Recompute(); // establish baseline defaults from the (possibly empty) source
    }

    /// <summary>
    /// Register an ADDITIONAL active-effect source — effects from every source aggregate together
    /// under the identical per-category rules (sums add, flags OR, ceilings max, unlock sets union).
    /// The friendship system feeds its earned heart-perk effects in through here; a spike can feed a
    /// synthetic source. Recomputes immediately (a no-op change when the new source is empty).
    /// </summary>
    public void AddSource(Func<IEnumerable<BuildingEffect>> source)
    {
        _sources.Add(source ?? throw new ArgumentNullException(nameof(source)));
        Recompute();
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
        _biomes.Clear();
        _max.Clear();

        int smithyMag = 0;
        bool anySmithy = false;

        foreach (var e in ActiveEffects())
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
                case BuildingEffectType.BiomeUnlock:
                    if (!string.IsNullOrEmpty(e.Detail))
                        _biomes.Add(e.Detail!);
                    break;
                case BuildingEffectType.Husbandry:
                case BuildingEffectType.Boarding:
                case BuildingEffectType.Fishing:
                    if (!_max.TryGetValue(e.Type, out var cur) || e.Magnitude > cur)
                        _max[e.Type] = e.Magnitude;
                    break;
            }
        }

        _smithyTier = anySmithy ? ClampTier(smithyMag) : SmithyTier.Base;
        Changed?.Invoke();
    }

    private IEnumerable<BuildingEffect> ActiveEffects()
    {
        foreach (var source in _sources)
            foreach (var e in source())
                yield return e;
    }

    // ===================== Generic queries =====================

    /// <summary>Summed magnitude for an effect type (0 when none active).</summary>
    public int Sum(BuildingEffectType type) => _sums.TryGetValue(type, out var n) ? n : 0;

    /// <summary>Whether any active effect of this type is present (the flag/presence query).</summary>
    public bool Has(BuildingEffectType type) => _present.Contains(type);

    /// <summary>MAX magnitude reached across active effects of this type (0 when none active) — the
    /// ladder-aggregation counterpart to <see cref="Sum"/> for generic leveled unlocks (Husbandry,
    /// Boarding, Fishing). SmithyTier keeps its own typed enum ceiling (<see cref="SmithyTier"/>).</summary>
    public int Max(BuildingEffectType type) => _max.TryGetValue(type, out var n) ? n : 0;

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

    /// <summary>Trading Post BUY-price discount percent (baseline 0 — prices unchanged). Summed
    /// across sources and clamped to 90 so a price can never reach zero from stacked discounts.</summary>
    public int StorePriceDiscountPercent => Math.Clamp(Sum(BuildingEffectType.StorePriceDiscount), 0, 90);

    /// <summary>The set of unlocked category ids (CategoryUnlock effects' Detail). Empty at baseline.</summary>
    public IReadOnlyCollection<string> UnlockedCategories => _categories;

    /// <summary>Generic membership test any system can gate on without new framework.</summary>
    public bool IsCategoryUnlocked(string categoryId) => categoryId != null && _categories.Contains(categoryId);

    /// <summary>Husbandry unlock level (Magnitude ladder: 1 = coop animals, 2 = barn animals) — the
    /// MAX magnitude reached, not summed. Baseline 0 (no husbandry unlocked). Declarative only this
    /// pass — no consumer reads it yet.</summary>
    public int HusbandryLevel => Max(BuildingEffectType.Husbandry);

    /// <summary>Fishing unlock level (Magnitude ladder: 1 = rod fishing, 2 = traps + deeper waters) —
    /// the MAX magnitude reached. Baseline 0. Declarative only this pass.</summary>
    public int FishingLevel => Max(BuildingEffectType.Fishing);

    /// <summary>Tavern boarding-room level (Magnitude ladder) — the MAX magnitude reached. Baseline 0
    /// (no boarders). Declarative only this pass.</summary>
    public int BoardingLevel => Max(BuildingEffectType.Boarding);

    /// <summary>Tavern stage exists + morale performances possible (baseline false). Declarative only
    /// this pass — no consumer reads it yet.</summary>
    public bool Performances => Has(BuildingEffectType.Performances);

    /// <summary>Watchtower fast travel available (baseline false). Declarative only this pass.</summary>
    public bool FastTravel => Has(BuildingEffectType.FastTravel);

    /// <summary>Command-post resurrection service available (baseline false). Declarative only this
    /// pass.</summary>
    public bool Resurrection => Has(BuildingEffectType.Resurrection);

    /// <summary>The set of unlocked territory/biome ids (BiomeUnlock effects' Detail). Empty at
    /// baseline. Declarative only this pass — the travel/gate system is the future consumer.</summary>
    public IReadOnlyCollection<string> UnlockedBiomes => _biomes;

    /// <summary>Generic membership test for a territory/biome id (the CategoryUnlock/IsCategoryUnlocked
    /// precedent).</summary>
    public bool IsBiomeUnlocked(string territoryId) => territoryId != null && _biomes.Contains(territoryId);

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
