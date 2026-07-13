using System;
using System.Collections.Generic;
using Bulwark.Data;
using PF2e.Conditions;
using PF2e.Data;

namespace Bulwark.Cozy;

/// <summary>
/// The party's carry system: the single facade the cozy/territory systems and GameState talk to,
/// aggregating each squad member's personally-carried <see cref="MemberInventory"/> plus the shared
/// outpost <see cref="Warehouse"/>. Replaces the old flat shared pool with PF2e Bulk-driven,
/// per-member carry — but keeps the same party-level surface (AddItem / RemoveItem / Count / Has /
/// Stacks + <see cref="InventoryChanged"/>/<see cref="ItemAdded"/>) so existing call sites are
/// unchanged.
///
/// Carry rules (per member, from Strength): ENCUMBERED above <c>5 + Str mod</c> Bulk (engine
/// Encumbered condition applied → −10 ft Speed into combat); HARD CAP at <c>10 + Str mod</c> Bulk
/// (cannot receive more). <see cref="AddItem"/> auto-distributes a gain across members preferring to
/// keep everyone UNDER their encumbered threshold, only spilling into the encumbered range (up to
/// the cap) when the party's comfortable capacity is exceeded. Encumbrance is DERIVED and recomputed
/// after every mutation and on load — never persisted as a standalone condition.
///
/// Unbound (headless/tests with no squad, or the data-drive-missing degraded mode): the facade has
/// no members, so everything lives in the warehouse and behaves exactly like the old flat pool.
/// </summary>
public sealed class Inventory
{
    private readonly List<MemberInventory> _members = new();
    private readonly Dictionary<string, MemberInventory> _byId = new();
    private readonly Warehouse _warehouse = new();
    private SquadRoster? _squad;

    /// <summary>PF2e encumbered kicks in ABOVE this many Bulk plus the member's Str mod.</summary>
    public const int BaseEncumberedBulk = 5;

    /// <summary>PF2e hard carry cap: this many Bulk plus the member's Str mod (can't carry past).</summary>
    public const int BaseMaxBulk = 10;

    /// <summary>Raised after a stack changes anywhere (add, remove, deposit, withdraw, load).</summary>
    public event Action<string>? InventoryChanged;

    /// <summary>
    /// Raised after <see cref="AddItem"/> actually places units, with the item id and the quantity
    /// placed — the single party-level choke point every GAIN flows through (farm harvests, territory
    /// node yields, combat loot), regardless of which member received the items. The day ledger
    /// subscribes here. NOT raised by warehouse transfers (deposit/withdraw are moves, not gains) nor
    /// by save-restore (a repopulation is not a gain).
    /// </summary>
    public event Action<string, int>? ItemAdded;

    /// <summary>True once a squad is bound (per-member carry active); false = flat warehouse mode.</summary>
    public bool IsBound => _squad != null && _members.Count > 0;

    /// <summary>
    /// Refinement 1 — is the outpost <see cref="Warehouse"/> physically reachable right now? The
    /// warehouse is OUTPOST-ONLY storage: in the field (territory/combat) the party has only what its
    /// members personally carry. GameState mirrors <see cref="Bulwark.Autoload.SceneRouter"/>'s mode
    /// onto this flag (true in the Outpost mode, false in Territory/Combat). When FALSE the warehouse
    /// is invisible to <see cref="Count"/>/<see cref="Has"/>/<see cref="RemoveItem"/>/<see cref="WouldFit"/>
    /// and the merged <see cref="Stacks"/>/<see cref="BuildView"/>, and deposit/withdraw refuse — reads
    /// and consumes see only member carry. Defaults TRUE so unbound/headless baselines are unchanged.
    /// </summary>
    public bool WarehouseAccessible { get; set; } = true;

    /// <summary>
    /// Bind the live squad so gains distribute per-member and encumbrance can be applied. Creates one
    /// <see cref="MemberInventory"/> per member (keyed by the stable preset id, so a save-restore that
    /// rebuilds the PF2eCharacter instances doesn't invalidate the stored stacks). Call once after the
    /// squad is built, before seeding/loading.
    /// </summary>
    public void BindSquad(SquadRoster squad)
    {
        _squad = squad ?? throw new ArgumentNullException(nameof(squad));
        _members.Clear();
        _byId.Clear();
        foreach (var m in squad.Members)
        {
            var inv = new MemberInventory(m.Id);
            _members.Add(inv);
            _byId[m.Id] = inv;
        }
    }

    // ===================== Queries =====================

    /// <summary>Total quantity of <paramref name="itemId"/> across every member plus the warehouse
    /// when it is accessible (see <see cref="WarehouseAccessible"/>); in the field, member carry only.</summary>
    public int Count(string itemId)
    {
        int total = WarehouseAccessible ? _warehouse.Count(itemId) : 0;
        foreach (var m in _members)
            total += m.Count(itemId);
        return total;
    }

    /// <summary>True if the reachable pool (members, plus the warehouse when accessible) holds at
    /// least <paramref name="qty"/>.</summary>
    public bool Has(string itemId, int qty = 1) => Count(itemId) >= qty;

    /// <summary>
    /// Non-mutating capacity probe: could a <see cref="AddItem"/> of <paramref name="qty"/> units be
    /// placed IN FULL? Mirrors the greedy per-member fill exactly — each member can accept
    /// floor(room / bulk) units up to their hard cap (10 + Str mod), so the party fits the gain when
    /// those unit capacities sum to at least <paramref name="qty"/>. Negligible-Bulk and unbound
    /// (warehouse) items always fit. Used by <see cref="Bulwark.Cozy.CraftingSystem"/> to reject a
    /// carry-cap overflow BEFORE consuming any inputs.
    /// </summary>
    public bool WouldFit(string itemId, int qty)
    {
        if (qty <= 0)
            return true;
        if (!IsBound)
            return WarehouseAccessible; // reachable warehouse is unbounded; in the field an unbound party has no carry
        int bulk = MemberInventory.BulkTenths(itemId);
        if (bulk <= 0)
            return true; // negligible Bulk never consumes capacity

        int capacityUnits = 0;
        foreach (var m in _members)
        {
            int room = MaxTenths(m.MemberId) - m.CarriedBulkTenths;
            if (room > 0)
                capacityUnits += room / bulk;
            if (capacityUnits >= qty)
                return true;
        }
        return capacityUnits >= qty;
    }

    /// <summary>
    /// Merged read-only view of every non-empty stack (members + warehouse summed by item id).
    /// The party-wide aggregate the save system used to read directly; still handy for whole-party
    /// queries (e.g. the defeat resource penalty).
    /// </summary>
    public IReadOnlyDictionary<string, int> Stacks
    {
        get
        {
            var merged = new Dictionary<string, int>();
            foreach (var m in _members)
                Accumulate(merged, m.Stacks);
            if (WarehouseAccessible)
                Accumulate(merged, _warehouse.Stacks);
            return merged;
        }
    }

    private static void Accumulate(Dictionary<string, int> into, IReadOnlyDictionary<string, int> from)
    {
        foreach (var (id, qty) in from)
            into[id] = (into.TryGetValue(id, out int n) ? n : 0) + qty;
    }

    // ===================== Gains (auto-distributed) =====================

    /// <summary>
    /// Add a GAIN of <paramref name="qty"/> units, auto-distributed across members (see the class
    /// summary for the fill rule). Fires <see cref="ItemAdded"/> once for the amount actually placed
    /// and recomputes encumbrance. Throws for an unknown item id or non-positive qty (programmer
    /// errors). Returns how much was placed vs rejected at the hard cap.
    /// </summary>
    public InventoryAddResult AddItem(string itemId, int qty)
    {
        if (qty <= 0)
            throw new ArgumentOutOfRangeException(nameof(qty), qty, "Quantity must be positive.");
        if (!Items.IsDefined(itemId))
            throw new ArgumentException($"Unknown item id '{itemId}'.", nameof(itemId));

        int placed = Distribute(itemId, qty);
        if (placed > 0)
        {
            InventoryChanged?.Invoke(itemId);
            ItemAdded?.Invoke(itemId, placed);
            RecomputeEncumbrance();
        }
        return new InventoryAddResult(placed, qty - placed);
    }

    /// <summary>
    /// Give a specific member up to their hard cap (10 + Str mod). Returns false with NO mutation if
    /// the member is unknown or the add would exceed the cap. A placement primitive, NOT a gain — it
    /// does not fire <see cref="ItemAdded"/> (the party gain choke point is <see cref="AddItem"/>).
    /// </summary>
    public bool TryGiveToMember(string memberId, string itemId, int qty)
    {
        if (qty <= 0 || !Items.IsDefined(itemId) || !_byId.TryGetValue(memberId, out var inv))
            return false;

        int bulk = MemberInventory.BulkTenths(itemId);
        if (inv.CarriedBulkTenths + bulk * qty > MaxTenths(memberId))
            return false;

        inv.Add(itemId, qty);
        InventoryChanged?.Invoke(itemId);
        RecomputeEncumbrance();
        return true;
    }

    /// <summary>
    /// Distribute <paramref name="qty"/> units silently (no events). Bound: stack-consolidating greedy
    /// fill (Refinement 2) — priority (a) members who ALREADY hold this item and have unencumbered
    /// room (most-room-first), consolidating the stack onto an existing carrier; (b) then any other
    /// member with unencumbered room (most-room-first); (c) then into the encumbered range up to the
    /// hard cap; (d) leftover units (all members capped) are rejected. Unbound: straight to the
    /// warehouse. Returns the number of units actually placed.
    /// </summary>
    private int Distribute(string itemId, int qty)
    {
        if (!IsBound)
        {
            _warehouse.Add(itemId, qty);
            return qty;
        }

        int bulk = MemberInventory.BulkTenths(itemId);

        // Negligible-Bulk items never affect capacity — pile them on the first member.
        if (bulk <= 0)
        {
            _members[0].Add(itemId, qty);
            return qty;
        }

        // Snapshot who already carries a stack of this item BEFORE any placement mutates carriage, so
        // the gain consolidates onto an existing holder before spreading to a fresh carrier.
        var holders = new HashSet<string>();
        foreach (var m in _members)
            if (m.Count(itemId) > 0)
                holders.Add(m.MemberId);

        int remaining = qty;
        remaining -= FillUnits(itemId, bulk, remaining, ThresholdTenths, m => holders.Contains(m.MemberId)); // (a) consolidate onto holders
        remaining -= FillUnits(itemId, bulk, remaining, ThresholdTenths, null);                              // (b) other members, stay unencumbered
        remaining -= FillUnits(itemId, bulk, remaining, MaxTenths, null);                                    // (c) into the encumbered range
        return qty - remaining;                                                                              // (d) leftover = hard-capped
    }

    /// <summary>
    /// Place up to <paramref name="units"/> units one at a time, each onto the eligible member with
    /// the most room below <paramref name="ceilingTenths"/> that can still fit one unit. When
    /// <paramref name="eligible"/> is non-null only members it accepts are considered. Returns units placed.
    /// </summary>
    private int FillUnits(string itemId, int bulk, int units, Func<string, int> ceilingTenths, Func<MemberInventory, bool>? eligible)
    {
        int placed = 0;
        while (placed < units)
        {
            MemberInventory? best = null;
            int bestRoom = -1;
            foreach (var m in _members)
            {
                if (eligible != null && !eligible(m))
                    continue;
                int room = ceilingTenths(m.MemberId) - m.CarriedBulkTenths;
                if (room >= bulk && room > bestRoom)
                {
                    bestRoom = room;
                    best = m;
                }
            }
            if (best == null)
                break;
            best.Add(itemId, 1);
            placed++;
        }
        return placed;
    }

    // ===================== Removal (members first, then warehouse) =====================

    /// <summary>
    /// Remove <paramref name="qty"/> units from the party. Returns false (no mutation) when the party
    /// doesn't hold that many — the validation path command methods rely on. Consumes carried stacks
    /// first (member order), then the warehouse. Recomputes encumbrance. Throws on non-positive qty.
    /// </summary>
    public bool RemoveItem(string itemId, int qty)
    {
        if (qty <= 0)
            throw new ArgumentOutOfRangeException(nameof(qty), qty, "Quantity must be positive.");
        if (Count(itemId) < qty)
            return false;

        int need = qty;
        foreach (var m in _members)
        {
            if (need == 0)
                break;
            need -= m.Remove(itemId, need);
        }
        if (WarehouseAccessible && need > 0)
            need -= _warehouse.Remove(itemId, need);

        InventoryChanged?.Invoke(itemId);
        RecomputeEncumbrance();
        return true;
    }

    /// <summary>Units of <paramref name="itemId"/> a specific member personally carries (0 if the member
    /// is unknown or bound state is empty). The carry-scoped read combat uses to gate "use a carried item".</summary>
    public int MemberCount(string memberId, string itemId)
        => _byId.TryGetValue(memberId, out var inv) ? inv.Count(itemId) : 0;

    private static readonly IReadOnlyDictionary<string, int> EmptyStacks = new Dictionary<string, int>();

    /// <summary>A member's personally-carried stacks (item id → qty), or an empty map for an unknown member.
    /// The combat action bar reads this to list which consumables that member may use this turn.</summary>
    public IReadOnlyDictionary<string, int> MemberStacks(string memberId)
        => _byId.TryGetValue(memberId, out var inv) ? inv.Stacks : EmptyStacks;

    /// <summary>
    /// Remove <paramref name="qty"/> units of an item from ONE member's carry (not the warehouse) — how a
    /// combatant spends a consumable they are carrying. Returns false with NO mutation when the member is
    /// unknown or doesn't carry that many. Recomputes encumbrance and raises <see cref="InventoryChanged"/>.
    /// </summary>
    public bool RemoveFromMember(string memberId, string itemId, int qty)
    {
        if (qty <= 0 || !_byId.TryGetValue(memberId, out var inv) || inv.Count(itemId) < qty)
            return false;

        inv.Remove(itemId, qty);
        InventoryChanged?.Invoke(itemId);
        RecomputeEncumbrance();
        return true;
    }

    // ===================== Warehouse transfers (outpost) =====================

    /// <summary>
    /// Move <paramref name="qty"/> of an item from a member's carry to the shared warehouse — how the
    /// squad offloads to clear encumbrance and free field capacity. Validates the member holds enough;
    /// no Bulk limit on the warehouse. A transfer, not a gain (no <see cref="ItemAdded"/>). Returns
    /// false with no mutation on any validation failure.
    /// </summary>
    public bool DepositToWarehouse(string memberId, string itemId, int qty)
    {
        if (!WarehouseAccessible) // outpost-only action: the warehouse is out of reach in the field
            return false;
        if (qty <= 0 || !Items.IsDefined(itemId) || !_byId.TryGetValue(memberId, out var inv))
            return false;
        if (inv.Count(itemId) < qty)
            return false;

        inv.Remove(itemId, qty);
        _warehouse.Add(itemId, qty);
        InventoryChanged?.Invoke(itemId);
        RecomputeEncumbrance();
        return true;
    }

    /// <summary>
    /// Move <paramref name="qty"/> of an item from the warehouse into a member's carry. Validates the
    /// warehouse holds enough AND that the member can take it without exceeding their hard cap
    /// (10 + Str mod) — a withdrawal that would break the cap is rejected. A transfer, not a gain.
    /// Returns false with no mutation on any validation failure.
    /// </summary>
    public bool WithdrawFromWarehouse(string memberId, string itemId, int qty)
    {
        if (!WarehouseAccessible) // outpost-only action: the warehouse is out of reach in the field
            return false;
        if (qty <= 0 || !Items.IsDefined(itemId) || !_byId.TryGetValue(memberId, out var inv))
            return false;
        if (_warehouse.Count(itemId) < qty)
            return false;

        int bulk = MemberInventory.BulkTenths(itemId);
        if (inv.CarriedBulkTenths + bulk * qty > MaxTenths(memberId))
            return false;

        _warehouse.Remove(itemId, qty);
        inv.Add(itemId, qty);
        InventoryChanged?.Invoke(itemId);
        RecomputeEncumbrance();
        return true;
    }

    // ===================== Encumbrance (derived) =====================

    private int StrModOf(string memberId)
        => _squad?.FindMember(memberId)?.Stats?.GetAbilityModifier(AbilityScore.Strength) ?? 0;

    private int ThresholdTenths(string memberId) => (BaseEncumberedBulk + StrModOf(memberId)) * 10;
    private int MaxTenths(string memberId) => (BaseMaxBulk + StrModOf(memberId)) * 10;

    /// <summary>
    /// Recompute every member's carried Bulk versus their Strength limit and apply or remove the
    /// engine <c>Encumbered</c> condition accordingly — the teeth that carry into combat (−10 ft
    /// Speed) until offloaded. Idempotent; called after every mutation and on load. GameState also
    /// calls it after post-combat cleanup (which strips encounter-scoped conditions) and after a rest,
    /// so the derived condition is always reconciled with the actual carried weight. No-op when
    /// unbound or the condition database isn't loaded.
    /// </summary>
    public void RecomputeEncumbrance()
    {
        if (_squad == null)
            return;
        var def = ConditionDatabase.Instance?.GetCondition(Condition.Encumbered);
        if (def == null)
            return;

        foreach (var inv in _members)
        {
            var conds = _squad.FindMember(inv.MemberId)?.Conditions;
            if (conds == null)
                continue;

            bool encumbered = inv.CarriedBulkTenths > ThresholdTenths(inv.MemberId);
            bool has = conds.HasCondition(Condition.Encumbered);
            if (encumbered && !has)
                conds.AddCondition(def, value: 0, duration: 0);
            else if (!encumbered && has)
                conds.RemoveCondition(def);
        }
    }

    // ===================== View-model =====================

    /// <summary>
    /// Build the per-member + warehouse view-model for a future inventory screen. <paramref name="gold"/>
    /// is supplied by the caller (the wallet lives in GameState, not here).
    /// </summary>
    public InventoryView BuildView(int gold)
    {
        var members = new List<MemberInventoryView>(_members.Count);
        foreach (var inv in _members)
        {
            int strMod = StrModOf(inv.MemberId);
            members.Add(new MemberInventoryView
            {
                MemberId = inv.MemberId,
                Name = _squad?.FindMember(inv.MemberId)?.Name ?? inv.MemberId,
                Stacks = new Dictionary<string, int>(inv.Stacks),
                CarriedBulk = inv.CarriedBulk,
                EncumberedThreshold = BaseEncumberedBulk + strMod,
                MaxBulk = BaseMaxBulk + strMod,
                Encumbered = inv.CarriedBulkTenths > ThresholdTenths(inv.MemberId),
            });
        }

        return new InventoryView
        {
            Members = members,
            // Field view (warehouse out of reach) shows an empty warehouse — the party sees only carry.
            Warehouse = WarehouseAccessible
                ? new Dictionary<string, int>(_warehouse.Stacks)
                : new Dictionary<string, int>(),
            Gold = gold,
        };
    }

    // ===================== Save / restore =====================

    /// <summary>Snapshot each member's carried stacks (used by the save system).</summary>
    public List<MemberInventoryDto> CaptureMemberInventories()
    {
        var list = new List<MemberInventoryDto>(_members.Count);
        foreach (var inv in _members)
            list.Add(new MemberInventoryDto
            {
                MemberId = inv.MemberId,
                Stacks = new Dictionary<string, int>(inv.Stacks),
            });
        return list;
    }

    /// <summary>Snapshot the warehouse stacks (used by the save system).</summary>
    public Dictionary<string, int> CaptureWarehouse() => new(_warehouse.Stacks);

    /// <summary>
    /// Restore per-member + warehouse contents from a save (silent — no <see cref="ItemAdded"/>).
    /// Stacks for a known member id go to that member; any orphaned member's stacks fall to the
    /// warehouse defensively. Recomputes encumbrance from the restored weights, then signals a
    /// wholesale refresh.
    /// </summary>
    public void LoadState(List<MemberInventoryDto>? members, Dictionary<string, int>? warehouse)
    {
        foreach (var inv in _members)
            inv.Clear();
        _warehouse.Clear();

        if (members != null)
        {
            foreach (var dto in members)
            {
                if (dto.Stacks == null)
                    continue;
                bool known = _byId.TryGetValue(dto.MemberId, out var inv);
                foreach (var (id, qty) in dto.Stacks)
                {
                    if (qty <= 0 || !Items.IsDefined(id))
                        continue;
                    if (known)
                        inv!.Add(id, qty);
                    else
                        _warehouse.Add(id, qty);
                }
            }
        }
        if (warehouse != null)
        {
            foreach (var (id, qty) in warehouse)
                if (qty > 0 && Items.IsDefined(id))
                    _warehouse.Add(id, qty);
        }

        RecomputeEncumbrance();
        InventoryChanged?.Invoke(string.Empty);
    }

    /// <summary>
    /// Legacy migration: repopulate from a flat pre-per-member save (item id → quantity). Distributes
    /// across members when bound (any hard-cap overflow lands in the warehouse rather than being lost),
    /// or straight to the warehouse when unbound. Silent; recomputes encumbrance.
    /// </summary>
    public void LoadFrom(IReadOnlyDictionary<string, int> stacks)
    {
        foreach (var inv in _members)
            inv.Clear();
        _warehouse.Clear();

        if (stacks != null)
        {
            foreach (var (id, qty) in stacks)
            {
                if (qty <= 0 || !Items.IsDefined(id))
                    continue;
                int placed = Distribute(id, qty);
                if (placed < qty)
                    _warehouse.Add(id, qty - placed);
            }
        }

        RecomputeEncumbrance();
        InventoryChanged?.Invoke(string.Empty);
    }
}
