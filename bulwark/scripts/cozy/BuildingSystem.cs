using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// The expanding-outpost build loop (Phase 2). Pure C# and unit-testable: it holds per-building
/// state (not commissioned / built at tier N, plus contributions accumulated toward the NEXT tier's
/// bundle) and validates every mutation before touching the party <see cref="Inventory"/>.
///
/// Two-stage model:
///  1. COMMISSION — pay the building's construction bundle (+ its gold cost) all-at-once (must be
///     fully affordable) → the building is Built at tier 1.
///  2. UPGRADE — CONTRIBUTE items from the inventory that ACCUMULATE on the building toward the next
///     tier's upgrade bundle (partials allowed); once the whole set is met AND the tier's gold cost is
///     affordable, UPGRADE advances the tier (gold is charged all-at-once at the Upgrade step, never
///     contributed piecemeal like the bundle).
///
/// Both COMMISSION and UPGRADE occupy Tharr, the outpost's one mason, for a per-building construction
/// window (design/tutorial.md; <see cref="SetConstructionDays"/>) — <see cref="AnyUnderConstruction"/>
/// enforces one job at a time across both. The tier number advances immediately at either step; what
/// waits for the window to close is the INCOMING tier's effects — a commission's building has nothing
/// live yet, but an upgrading building keeps its prior tiers' effects live throughout (see
/// <see cref="ActiveEffects"/>).
///
/// Every successful mutation raises <see cref="Changed"/> with the building id (GameState re-exposes
/// it as BuildingChanged). Effects the tiers carry are declarative data only this phase — nothing
/// here consumes them.
///
/// Gold is a live-read dependency, not a direct <c>Wallet</c> reference (kept out of Bulwark.Cozy's
/// currency-owning type so this class stays a pure accounting system, same shape as
/// <see cref="TreatWoundsSystem"/>'s injected healing-bonus provider): <paramref name="goldBalance"/>
/// () queries the current balance for affordability checks/the view-model, <paramref
/// name="trySpendGold"/> performs the atomic spend. Both default to an inert 0-balance/always-reject
/// pair, but since every shipped <see cref="BuildingDefinition.GoldCost"/> / <see
/// cref="BuildingTier.GoldCost"/> is 0 and a non-positive cost always short-circuits true, that
/// default is never exercised by shipped content — behavior is byte-identical without a wallet wired.
/// </summary>
public sealed class BuildingSystem
{
    /// <summary>Live state for one building.</summary>
    private sealed class State
    {
        /// <summary>0 = not commissioned; 1..N once built.</summary>
        public int Tier;

        /// <summary>Days remaining under construction (0 = complete or not yet started).</summary>
        public int ConstructionDaysRemaining;

        /// <summary>Items accumulated toward the NEXT tier's upgrade bundle (item id → qty).</summary>
        public readonly Dictionary<string, int> Contributions = new();

        public bool Commissioned => Tier >= 1;
    }

    /// <summary>Per-building construction durations in days. Override via <see cref="SetConstructionDays"/>
    /// once game content needs paced building (tutorial flow). Default 0 = instant completion,
    /// preserving existing behavior.</summary>
    private readonly Dictionary<string, int> _constructionDays = new();
    private int _defaultConstructionDays;

    private readonly Inventory _inventory;
    private readonly Func<int> _goldBalance;
    private readonly Func<int, bool> _trySpendGold;
    private readonly Dictionary<string, BuildingDefinition> _catalog;
    private readonly Dictionary<string, State> _states = new();

    /// <summary>Raised after any successful commission / contribution / upgrade, with the building id.</summary>
    public event Action<string>? Changed;

    /// <summary>
    /// Raised ONLY when a building's construction timer completes (<see cref="TickDay"/> reaches 0
    /// remaining days), with the building id — distinct from <see cref="Changed"/> (which ALSO fires
    /// on commission/contribute/upgrade) so a subscriber can show a one-shot "construction complete"
    /// notice without re-deriving it from a tier/day diff.
    /// </summary>
    public event Action<string>? ConstructionCompleted;

    /// <param name="goldBalance">Live current-gold query (e.g. <c>() => wallet.Gold</c>). Null → baseline
    /// 0 — harmless while every shipped GoldCost is 0.</param>
    /// <param name="trySpendGold">Atomic spend (e.g. <c>wallet.TrySpendGold</c>): true and deducts if the
    /// balance covers the amount, false otherwise. Null → always rejects; never called with a
    /// non-positive amount regardless (0-cost is treated as a free no-op, not a spend attempt).</param>
    /// <param name="catalog">The building set this instance operates over. Null → the shipped
    /// <see cref="Buildings.All"/> registry (every production caller). A spike/test may pass its own
    /// definitions (e.g. one with a non-zero GoldCost) without touching the shared registry.</param>
    public BuildingSystem(Inventory inventory, Func<int>? goldBalance = null, Func<int, bool>? trySpendGold = null,
        IEnumerable<BuildingDefinition>? catalog = null)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _goldBalance = goldBalance ?? (static () => 0);
        _trySpendGold = trySpendGold ?? (static _ => false);
        _catalog = new Dictionary<string, BuildingDefinition>();
        foreach (var def in catalog ?? Buildings.All)
            _catalog[def.Id] = def;
        foreach (var def in _catalog.Values)
            _states[def.Id] = new State();
    }

    /// <summary>Configure construction durations for the one-at-a-time pacing system (tutorial flow).
    /// Call once after construction. Buildings not listed complete instantly (default 0).</summary>
    public void SetConstructionDays(Dictionary<string, int> perBuilding, int defaultDays = 0)
    {
        _constructionDays.Clear();
        foreach (var (id, days) in perBuilding)
            _constructionDays[id] = days;
        _defaultConstructionDays = defaultDays;
    }

    // ===================== Queries =====================

    /// <summary>Current tier of a building (0 = not commissioned; also 0 for an unknown id).</summary>
    public int GetTier(string id) => _states.TryGetValue(id, out var s) ? s.Tier : 0;

    /// <summary>True once the building's construction bundle has been paid.</summary>
    public bool IsCommissioned(string id) => GetTier(id) >= 1;

    /// <summary>Count of every building currently at tier ≥ 1 (commissioned), across the whole
    /// catalog. A milestone-flag query seam (e.g. GameState's "eight buildings" story flag); callers
    /// that need to exclude a specific start-state building (command_post) subtract it themselves.</summary>
    public int CommissionedCount()
    {
        int count = 0;
        foreach (var s in _states.Values)
            if (s.Tier >= 1)
                count++;
        return count;
    }

    /// <summary>
    /// Every ACTIVE building effect — the cumulative effects of tiers 1..current for each commissioned
    /// building (a grown building keeps its earlier tiers' effects). This is the DERIVED feed the
    /// Phase-4 <see cref="OutpostEffects"/> aggregator consumes; the declarative Effects data is
    /// otherwise inert. Empty when nothing is commissioned (the ungated baseline).
    ///
    /// While a building is under construction, the window means two different things depending on
    /// WHICH construction it is: a COMMISSION window means the building isn't built yet, so NOTHING is
    /// live (tier is 1 but effects wait — the loop below tops out at <c>Tier - 1 == 0</c>, yielding
    /// nothing). An UPGRADE window means the building already exists at its PRIOR tier and is merely
    /// growing — Elara's store must not close while the addition goes up — so tiers 1..Tier-1 stay
    /// live and only the incoming tier's effects wait for completion. One loop bound (<c>Tier - 1</c>
    /// while under construction, <c>Tier</c> once complete) expresses both cases correctly because
    /// commission's Tier is always 1.
    /// </summary>
    public IEnumerable<BuildingEffect> ActiveEffects()
    {
        foreach (var def in _catalog.Values)
        {
            var s = _states[def.Id];
            int maxTier = s.ConstructionDaysRemaining > 0 ? s.Tier - 1 : s.Tier;
            for (int t = 1; t <= maxTier; t++)
                if (def.TryGetTier(t, out var td))
                    foreach (var e in td.Effects)
                        yield return e;
        }
    }

    /// <summary>True when the construction bundle AND gold cost are fully affordable from the party
    /// inventory/wallet and the building is not already commissioned.</summary>
    public bool CanCommission(string id)
    {
        if (!_catalog.TryGetValue(id, out var def) || _states[id].Commissioned)
            return false;
        if (AnyUnderConstruction())
            return false;
        if (!HasGold(def.GoldCost))
            return false;
        foreach (var r in def.ConstructionBundle)
            if (!_inventory.Has(r.ItemId, r.Quantity))
                return false;
        return true;
    }

    /// <summary>True when the next-tier upgrade bundle has been fully accumulated AND that tier's gold
    /// cost is affordable right now. Also blocked while ANY building is under construction (the same
    /// one-at-a-time constraint as <see cref="CanCommission"/> — Tharr is one mason: an upgrade can't
    /// start while a commission (or another upgrade) is already occupying him, and a commission can't
    /// start while an upgrade is underway).</summary>
    public bool CanUpgrade(string id)
    {
        if (!_catalog.TryGetValue(id, out var def))
            return false;
        var s = _states[id];
        if (!s.Commissioned || !def.TryGetTier(s.Tier + 1, out var next))
            return false;
        if (AnyUnderConstruction())
            return false;
        if (!HasGold(next.GoldCost))
            return false;
        foreach (var r in next.UpgradeBundle)
        {
            int have = s.Contributions.TryGetValue(r.ItemId, out int n) ? n : 0;
            if (have < r.Quantity)
                return false;
        }
        return true;
    }

    // ===================== Commands (validate → consume → mutate → event) =====================

    /// <summary>
    /// Commission a building: validate the construction bundle AND gold cost are fully affordable
    /// BEFORE touching either, then spend the gold and consume the bundle from the party inventory,
    /// and mark the building Built at tier 1. Rejects cleanly (false, nothing consumed) when the id is
    /// unknown, the building is already commissioned, or the bundle/gold is unaffordable.
    /// </summary>
    public bool Commission(string id)
    {
        if (!CanCommission(id))
            return false;

        var def = _catalog[id];
        // Validated affordable above, so the spend and each removal succeed.
        SpendGold(def.GoldCost);
        foreach (var r in def.ConstructionBundle)
            _inventory.RemoveItem(r.ItemId, r.Quantity);

        var s = _states[id];
        s.Tier = 1;
        int days = _constructionDays.TryGetValue(id, out int d) ? d : _defaultConstructionDays;
        s.ConstructionDaysRemaining = days;
        s.Contributions.Clear();
        Changed?.Invoke(id);
        return true;
    }

    /// <summary>
    /// Contribute <paramref name="qty"/> of an item toward the building's NEXT tier bundle. Consumes
    /// from the party inventory and accumulates on the building (partials allowed). Rejects cleanly
    /// (false, nothing consumed) when: qty ≤ 0, the building is not commissioned or already at max
    /// tier, the item is not part of the next bundle, the line is already satisfied, qty would
    /// overshoot the remaining need, or the inventory does not hold that many.
    /// </summary>
    public bool Contribute(string id, string itemId, int qty)
    {
        if (qty <= 0 || !_catalog.TryGetValue(id, out var def))
            return false;

        var s = _states[id];
        if (!s.Commissioned || !def.TryGetTier(s.Tier + 1, out var next))
            return false;

        var req = FindRequirement(next.UpgradeBundle, itemId);
        if (req == null)
            return false;

        int already = s.Contributions.TryGetValue(itemId, out int n) ? n : 0;
        int remaining = req.Quantity - already;
        if (remaining <= 0 || qty > remaining)
            return false;

        if (!_inventory.RemoveItem(itemId, qty))
            return false;

        s.Contributions[itemId] = already + qty;
        Changed?.Invoke(id);
        return true;
    }

    /// <summary>
    /// Advance a building to its next tier when the upgrade bundle is fully accumulated AND the tier's
    /// gold cost is affordable. Charges the gold all-at-once (never contributed piecemeal like the
    /// bundle), clears the contributions (they are consumed by the advance), and raises
    /// <see cref="Changed"/>. Rejects cleanly when the bundle is incomplete, gold is short, or there is
    /// no higher tier.
    ///
    /// Tharr is busy for the upgrade too (design/tutorial.md): starts the SAME per-building
    /// construction timer <see cref="Commission"/> uses (<see cref="SetConstructionDays"/>), during
    /// which the new tier's effects wait (see <see cref="ActiveEffects"/>) while the building's prior
    /// tiers stay live — the tier number itself (and so <see cref="GetTier"/>/the visual stage) advances
    /// immediately, mirroring Commission's immediate tier-1 bump.
    /// </summary>
    public bool Upgrade(string id)
    {
        if (!CanUpgrade(id))
            return false;

        var def = _catalog[id];
        var s = _states[id];
        def.TryGetTier(s.Tier + 1, out var next); // guaranteed to exist — CanUpgrade validated it above
        // Validated affordable above, so the spend succeeds.
        SpendGold(next.GoldCost);

        s.Tier += 1;
        int days = _constructionDays.TryGetValue(id, out int d) ? d : _defaultConstructionDays;
        s.ConstructionDaysRemaining = days;
        s.Contributions.Clear();
        Changed?.Invoke(id);
        return true;
    }

    // ===================== Construction time =====================

    /// <summary>True when any building is currently under construction (one-at-a-time constraint).</summary>
    public bool AnyUnderConstruction()
    {
        foreach (var s in _states.Values)
            if (s.ConstructionDaysRemaining > 0)
                return true;
        return false;
    }

    /// <summary>True when a specific building is under construction.</summary>
    public bool IsUnderConstruction(string id)
        => _states.TryGetValue(id, out var s) && s.ConstructionDaysRemaining > 0;

    /// <summary>Days remaining for a building's construction (0 when not under construction).</summary>
    public int GetConstructionDaysRemaining(string id)
        => _states.TryGetValue(id, out var s) ? s.ConstructionDaysRemaining : 0;

    /// <summary>Advance construction by one day. Called by GameState on day advance. Completes
    /// buildings whose timer reaches 0 and emits Changed for each.</summary>
    public void TickDay()
    {
        foreach (var (id, s) in _states)
        {
            if (s.ConstructionDaysRemaining > 0)
            {
                s.ConstructionDaysRemaining--;
                if (s.ConstructionDaysRemaining == 0)
                {
                    Changed?.Invoke(id);
                    ConstructionCompleted?.Invoke(id);
                }
            }
        }
    }

    // ===================== View-model =====================

    /// <summary>Build the planning-table view-model (per building: state, tier, current target bundle
    /// have/need, gold cost + affordability, commission/upgrade affordability, active + next-tier
    /// effects).</summary>
    public PlanningTableView BuildView()
    {
        var view = new PlanningTableView();
        foreach (var def in _catalog.Values)
        {
            var s = _states[def.Id];

            // One-at-a-time constraint: at most one building is ever under construction, so this
            // assignment fires for exactly one def per call (or never, when nothing is building).
            if (s.ConstructionDaysRemaining > 0)
            {
                view.BuilderBusy = true;
                view.BusyBuildingName = def.DisplayName;
                view.BusyDaysRemaining = s.ConstructionDaysRemaining;
            }

            var bv = new BuildingView
            {
                Id = def.Id,
                DisplayName = def.DisplayName,
                Commissioned = s.Commissioned,
                Tier = s.Tier,
                MaxTier = def.MaxTier,
                AtMaxTier = s.Commissioned && s.Tier >= def.MaxTier,
            };

            if (!s.Commissioned)
            {
                bv.StatusText = "Not built";
                bv.TargetLabel = "Commission";
                bv.HasTarget = true;
                bv.GoldCost = def.GoldCost;
                bv.CanAffordGold = HasGold(def.GoldCost);
                foreach (var r in def.ConstructionBundle)
                {
                    int inv = _inventory.Count(r.ItemId);
                    bv.Bundle.Add(new BundleLineView
                    {
                        ItemId = r.ItemId,
                        DisplayName = NameOf(r.ItemId),
                        Need = r.Quantity,
                        Contributed = 0,               // construction is paid all-at-once, not accumulated
                        InventoryCount = inv,
                        ContributableNow = 0,
                        Complete = inv >= r.Quantity,
                    });
                }
                bv.CanCommission = CanCommission(def.Id);
            }
            else if (def.TryGetTier(s.Tier + 1, out var next))
            {
                bv.StatusText = $"Tier {s.Tier}";
                bv.TargetLabel = $"Upgrade to Tier {next.Tier}";
                bv.HasTarget = true;
                bv.GoldCost = next.GoldCost;
                bv.CanAffordGold = HasGold(next.GoldCost);
                foreach (var r in next.UpgradeBundle)
                {
                    int have = s.Contributions.TryGetValue(r.ItemId, out int n) ? n : 0;
                    int inv = _inventory.Count(r.ItemId);
                    int remaining = Math.Max(0, r.Quantity - have);
                    bv.Bundle.Add(new BundleLineView
                    {
                        ItemId = r.ItemId,
                        DisplayName = NameOf(r.ItemId),
                        Need = r.Quantity,
                        Contributed = have,
                        InventoryCount = inv,
                        ContributableNow = Math.Min(remaining, inv),
                        Complete = have >= r.Quantity,
                    });
                }
                foreach (var e in next.Effects)
                    bv.NextEffects.Add(new EffectLineView { Text = DescribeEffect(e) });
                bv.CanUpgrade = CanUpgrade(def.Id);
            }
            else
            {
                bv.StatusText = $"Tier {s.Tier} (max)";
                bv.HasTarget = false;
            }

            if (s.Commissioned && def.TryGetTier(s.Tier, out var cur))
                foreach (var e in cur.Effects)
                    bv.ActiveEffects.Add(new EffectLineView { Text = DescribeEffect(e) });

            view.Buildings.Add(bv);
        }
        return view;
    }

    // ===================== Save / restore =====================

    /// <summary>Snapshot every touched building's state (skips pristine not-commissioned ones).</summary>
    public List<BuildingStateDto> Capture()
    {
        var list = new List<BuildingStateDto>();
        foreach (var (id, s) in _states)
        {
            if (s.Tier == 0 && s.Contributions.Count == 0 && s.ConstructionDaysRemaining == 0)
                continue;
            list.Add(new BuildingStateDto
            {
                Id = id,
                Tier = s.Tier,
                Contributions = new Dictionary<string, int>(s.Contributions),
                ConstructionDaysRemaining = s.ConstructionDaysRemaining,
            });
        }
        return list;
    }

    /// <summary>
    /// Restore building states from a save. Version-tolerant: null (pre-Phase-2 save) resets every
    /// building to not-commissioned; unknown building ids and unknown/zero contribution items are
    /// dropped; tiers clamp into the definition's valid range. Silent (no <see cref="Changed"/>).
    /// </summary>
    public void Restore(List<BuildingStateDto>? dtos)
    {
        foreach (var s in _states.Values)
        {
            s.Tier = 0;
            s.ConstructionDaysRemaining = 0;
            s.Contributions.Clear();
        }
        if (dtos == null)
            return;

        foreach (var dto in dtos)
        {
            if (dto.Id == null || !_catalog.TryGetValue(dto.Id, out var def))
                continue;
            var s = _states[dto.Id];
            s.Tier = Math.Clamp(dto.Tier, 0, def.MaxTier);
            s.ConstructionDaysRemaining = Math.Max(0, dto.ConstructionDaysRemaining);
            if (dto.Contributions != null)
                foreach (var (item, q) in dto.Contributions)
                    if (q > 0 && Items.IsDefined(item))
                        s.Contributions[item] = q;
        }
    }

    // ===================== Internals =====================

    /// <summary>True when a gold cost is affordable right now. A non-positive cost is always true
    /// without consulting <see cref="_goldBalance"/> — the baseline (every shipped GoldCost is 0).</summary>
    private bool HasGold(int cost) => cost <= 0 || _goldBalance() >= cost;

    /// <summary>Spend a gold cost (call only after <see cref="HasGold"/> validated it). A non-positive
    /// cost is a free no-op — <see cref="_trySpendGold"/> is never invoked with 0/negative amounts.</summary>
    private bool SpendGold(int cost) => cost <= 0 || _trySpendGold(cost);

    private static BundleRequirement? FindRequirement(IReadOnlyList<BundleRequirement> bundle, string itemId)
    {
        foreach (var r in bundle)
            if (r.ItemId == itemId)
                return r;
        return null;
    }

    private static string NameOf(string itemId)
        => Items.TryGet(itemId, out var def) ? def.DisplayName : itemId;

    private static string DescribeEffect(BuildingEffect e)
    {
        if (!string.IsNullOrEmpty(e.Detail))
            return e.Detail!;
        return e.Type switch
        {
            BuildingEffectType.FarmPlots => $"+{e.Magnitude} farm plots",
            BuildingEffectType.WateringAutomation => "Auto-watering",
            BuildingEffectType.Greenhouse => "Greenhouse",
            BuildingEffectType.SmithyTier => $"Smithy tier {e.Magnitude}",
            BuildingEffectType.InfirmaryHealing => "Infirmary healing",
            BuildingEffectType.CategoryUnlock => "New category unlocked",
            _ => e.Type.ToString(),
        };
    }
}
