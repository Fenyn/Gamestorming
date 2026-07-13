using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// One squad member's personally-carried stacks and the PF2e Bulk they sum to. Pure C# data —
/// the party-level <see cref="Inventory"/> facade owns the distribution/encumbrance rules and the
/// events; this type only stores what the member holds and reports its carried Bulk.
///
/// Bulk is accumulated in TENTHS of a Bulk (PF2e's "Light" unit: 10 Light = 1 Bulk) as an integer
/// so the carry-limit comparisons are exact — floating-point sums of 0.1-Bulk forageables would
/// otherwise drift (0.1 × 3 == 0.30000000004) and spuriously trip the encumbered threshold.
/// </summary>
public sealed class MemberInventory
{
    private readonly Dictionary<string, int> _stacks = new();

    public MemberInventory(string memberId)
    {
        MemberId = memberId ?? throw new ArgumentNullException(nameof(memberId));
    }

    /// <summary>The stable preset id of the member who carries these items.</summary>
    public string MemberId { get; }

    /// <summary>Read-only view of this member's non-empty stacks (item id → quantity).</summary>
    public IReadOnlyDictionary<string, int> Stacks => _stacks;

    /// <summary>Quantity of <paramref name="itemId"/> this member carries (0 if none).</summary>
    public int Count(string itemId) => _stacks.TryGetValue(itemId, out int n) ? n : 0;

    /// <summary>Total carried Bulk in tenths (PF2e Light units) — the exact comparison currency.</summary>
    public int CarriedBulkTenths { get; private set; }

    /// <summary>Total carried Bulk as a fractional Bulk value, for display/view-models.</summary>
    public double CarriedBulk => CarriedBulkTenths / 10.0;

    /// <summary>Bulk of one unit of <paramref name="itemId"/> in tenths (0 for an unknown item).</summary>
    public static int BulkTenths(string itemId)
        => Items.TryGet(itemId, out var def) ? (int)Math.Round(def.Bulk * 10f) : 0;

    /// <summary>Add <paramref name="qty"/> units (no limit check here — the facade gates capacity).</summary>
    public void Add(string itemId, int qty)
    {
        if (qty <= 0)
            return;
        _stacks[itemId] = Count(itemId) + qty;
        CarriedBulkTenths += BulkTenths(itemId) * qty;
    }

    /// <summary>Remove up to <paramref name="qty"/> units; returns how many were actually removed.</summary>
    public int Remove(string itemId, int qty)
    {
        if (qty <= 0)
            return 0;
        int have = Count(itemId);
        int removed = Math.Min(have, qty);
        if (removed == 0)
            return 0;

        int remaining = have - removed;
        if (remaining == 0)
            _stacks.Remove(itemId);
        else
            _stacks[itemId] = remaining;

        CarriedBulkTenths -= BulkTenths(itemId) * removed;
        return removed;
    }

    /// <summary>Empty the member (used by save-restore before repopulating).</summary>
    public void Clear()
    {
        _stacks.Clear();
        CarriedBulkTenths = 0;
    }
}
