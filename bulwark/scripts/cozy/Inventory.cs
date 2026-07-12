using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// Simple stacking inventory. Pure C# — the shared resource pool for farming, gathering and (later)
/// restoration costs. Mutations validate against <see cref="Items"/> and raise
/// <see cref="InventoryChanged"/> so the UI can render passively.
/// </summary>
public sealed class Inventory
{
    private readonly Dictionary<string, int> _stacks = new();

    /// <summary>Raised after a stack changes, with the affected item id.</summary>
    public event Action<string>? InventoryChanged;

    /// <summary>
    /// Raised after <see cref="AddItem"/> grows a stack, with the item id and the quantity added —
    /// the single choke point every gain flows through (farm harvests, territory node yields,
    /// direct grants). NOT raised by <see cref="LoadFrom"/>: a save-restore repopulation is not a
    /// gain, so day-ledger style subscribers stay clean across loads.
    /// </summary>
    public event Action<string, int>? ItemAdded;

    /// <summary>Current quantity of <paramref name="itemId"/> (0 if none).</summary>
    public int Count(string itemId) => _stacks.TryGetValue(itemId, out int n) ? n : 0;

    /// <summary>True if at least <paramref name="qty"/> of the item is held.</summary>
    public bool Has(string itemId, int qty = 1) => Count(itemId) >= qty;

    /// <summary>Read-only view of all non-empty stacks (item id → quantity).</summary>
    public IReadOnlyDictionary<string, int> Stacks => _stacks;

    /// <summary>
    /// Add <paramref name="qty"/> of an item. Throws for an unknown item id or non-positive qty —
    /// those are programmer errors, not runtime conditions.
    /// </summary>
    public void AddItem(string itemId, int qty)
    {
        if (qty <= 0)
            throw new ArgumentOutOfRangeException(nameof(qty), qty, "Quantity must be positive.");
        if (!Items.IsDefined(itemId))
            throw new ArgumentException($"Unknown item id '{itemId}'.", nameof(itemId));

        _stacks[itemId] = Count(itemId) + qty;
        InventoryChanged?.Invoke(itemId);
        ItemAdded?.Invoke(itemId, qty);
    }

    /// <summary>
    /// Remove <paramref name="qty"/> of an item. Returns false (no mutation) if the stack is too
    /// small — this is the validation path for command methods. Throws only for non-positive qty.
    /// </summary>
    public bool RemoveItem(string itemId, int qty)
    {
        if (qty <= 0)
            throw new ArgumentOutOfRangeException(nameof(qty), qty, "Quantity must be positive.");

        int have = Count(itemId);
        if (have < qty)
            return false;

        int remaining = have - qty;
        if (remaining == 0)
            _stacks.Remove(itemId);
        else
            _stacks[itemId] = remaining;

        InventoryChanged?.Invoke(itemId);
        return true;
    }

    /// <summary>Replace all contents (used by the save system). Silently skips unknown/empty entries.</summary>
    public void LoadFrom(IReadOnlyDictionary<string, int> stacks)
    {
        _stacks.Clear();
        foreach (var (id, qty) in stacks)
        {
            if (qty > 0 && Items.IsDefined(id))
                _stacks[id] = qty;
        }
        InventoryChanged?.Invoke(string.Empty); // signal a wholesale refresh
    }
}
