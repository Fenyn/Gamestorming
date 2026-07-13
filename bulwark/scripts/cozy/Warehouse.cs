using System;
using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// The outpost's shared, effectively-unlimited storage — no Bulk limit, so it is where the squad
/// offloads to clear encumbrance and free field capacity. Baseline outpost infrastructure this
/// phase (its being a buildable/upgradeable structure is a later phase). Pure C# stacks; the
/// party-level <see cref="Inventory"/> facade owns the deposit/withdraw commands and events.
/// </summary>
public sealed class Warehouse
{
    private readonly Dictionary<string, int> _stacks = new();

    /// <summary>Read-only view of all non-empty warehouse stacks (item id → quantity).</summary>
    public IReadOnlyDictionary<string, int> Stacks => _stacks;

    /// <summary>Quantity of <paramref name="itemId"/> stored (0 if none).</summary>
    public int Count(string itemId) => _stacks.TryGetValue(itemId, out int n) ? n : 0;

    /// <summary>Add <paramref name="qty"/> units. No capacity limit.</summary>
    public void Add(string itemId, int qty)
    {
        if (qty <= 0)
            return;
        _stacks[itemId] = Count(itemId) + qty;
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
        return removed;
    }

    /// <summary>Empty the warehouse (used by save-restore before repopulating).</summary>
    public void Clear() => _stacks.Clear();
}
