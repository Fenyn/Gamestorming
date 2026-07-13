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
///  1. COMMISSION — pay the building's construction bundle all-at-once (must be fully affordable) →
///     the building is Built at tier 1.
///  2. UPGRADE — CONTRIBUTE items from the inventory that ACCUMULATE on the building toward the next
///     tier's upgrade bundle (partials allowed); once the whole set is met, UPGRADE advances the tier.
///
/// Every successful mutation raises <see cref="Changed"/> with the building id (GameState re-exposes
/// it as BuildingChanged). Effects the tiers carry are declarative data only this phase — nothing
/// here consumes them.
/// </summary>
public sealed class BuildingSystem
{
    /// <summary>Live state for one building.</summary>
    private sealed class State
    {
        /// <summary>0 = not commissioned; 1..N once built.</summary>
        public int Tier;

        /// <summary>Items accumulated toward the NEXT tier's upgrade bundle (item id → qty).</summary>
        public readonly Dictionary<string, int> Contributions = new();

        public bool Commissioned => Tier >= 1;
    }

    private readonly Inventory _inventory;
    private readonly Dictionary<string, State> _states = new();

    /// <summary>Raised after any successful commission / contribution / upgrade, with the building id.</summary>
    public event Action<string>? Changed;

    public BuildingSystem(Inventory inventory)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        foreach (var def in Buildings.All)
            _states[def.Id] = new State();
    }

    // ===================== Queries =====================

    /// <summary>Current tier of a building (0 = not commissioned; also 0 for an unknown id).</summary>
    public int GetTier(string id) => _states.TryGetValue(id, out var s) ? s.Tier : 0;

    /// <summary>True once the building's construction bundle has been paid.</summary>
    public bool IsCommissioned(string id) => GetTier(id) >= 1;

    /// <summary>
    /// Every ACTIVE building effect — the cumulative effects of tiers 1..current for each commissioned
    /// building (a grown building keeps its earlier tiers' effects). This is the DERIVED feed the
    /// Phase-4 <see cref="OutpostEffects"/> aggregator consumes; the declarative Effects data is
    /// otherwise inert. Empty when nothing is commissioned (the ungated baseline).
    /// </summary>
    public IEnumerable<BuildingEffect> ActiveEffects()
    {
        foreach (var def in Buildings.All)
        {
            int tier = GetTier(def.Id);
            for (int t = 1; t <= tier; t++)
                if (def.TryGetTier(t, out var td))
                    foreach (var e in td.Effects)
                        yield return e;
        }
    }

    /// <summary>True when the construction bundle is fully affordable from the party inventory and the
    /// building is not already commissioned.</summary>
    public bool CanCommission(string id)
    {
        if (!Buildings.TryGet(id, out var def) || _states[id].Commissioned)
            return false;
        foreach (var r in def.ConstructionBundle)
            if (!_inventory.Has(r.ItemId, r.Quantity))
                return false;
        return true;
    }

    /// <summary>True when the next-tier upgrade bundle has been fully accumulated.</summary>
    public bool CanUpgrade(string id)
    {
        if (!Buildings.TryGet(id, out var def))
            return false;
        var s = _states[id];
        if (!s.Commissioned || !def.TryGetTier(s.Tier + 1, out var next))
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
    /// Commission a building: validate the construction bundle is fully affordable, consume it from
    /// the party inventory, and mark the building Built at tier 1. Rejects cleanly (false, nothing
    /// consumed) when the id is unknown, the building is already commissioned, or the bundle is
    /// unaffordable.
    /// </summary>
    public bool Commission(string id)
    {
        if (!CanCommission(id))
            return false;

        var def = Buildings.Get(id);
        // Validated affordable above, so each removal succeeds; consume the whole bundle.
        foreach (var r in def.ConstructionBundle)
            _inventory.RemoveItem(r.ItemId, r.Quantity);

        var s = _states[id];
        s.Tier = 1;
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
        if (qty <= 0 || !Buildings.TryGet(id, out var def))
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
    /// Advance a building to its next tier when the upgrade bundle is fully accumulated. Clears the
    /// contributions (they are consumed by the advance) and raises <see cref="Changed"/>. Rejects
    /// cleanly when the bundle is incomplete or there is no higher tier.
    /// </summary>
    public bool Upgrade(string id)
    {
        if (!CanUpgrade(id))
            return false;

        var s = _states[id];
        s.Tier += 1;
        s.Contributions.Clear();
        Changed?.Invoke(id);
        return true;
    }

    // ===================== View-model =====================

    /// <summary>Build the planning-table view-model (per building: state, tier, current target bundle
    /// have/need, commission/upgrade affordability, active + next-tier effects).</summary>
    public PlanningTableView BuildView()
    {
        var view = new PlanningTableView();
        foreach (var def in Buildings.All)
        {
            var s = _states[def.Id];
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
            if (s.Tier == 0 && s.Contributions.Count == 0)
                continue;
            list.Add(new BuildingStateDto
            {
                Id = id,
                Tier = s.Tier,
                Contributions = new Dictionary<string, int>(s.Contributions),
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
            s.Contributions.Clear();
        }
        if (dtos == null)
            return;

        foreach (var dto in dtos)
        {
            if (dto.Id == null || !Buildings.TryGet(dto.Id, out var def))
                continue;
            var s = _states[dto.Id];
            s.Tier = Math.Clamp(dto.Tier, 0, def.MaxTier);
            if (dto.Contributions != null)
                foreach (var (item, q) in dto.Contributions)
                    if (q > 0 && Items.IsDefined(item))
                        s.Contributions[item] = q;
        }
    }

    // ===================== Internals =====================

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
