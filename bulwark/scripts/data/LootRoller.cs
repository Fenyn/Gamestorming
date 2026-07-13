using System;
using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>The accumulated result of rolling an encounter's loot: monster parts (item id → qty)
/// and total coin. Applied by GameState on victory (parts → Inventory.AddItem so they flow into the
/// day ledger; coin → Wallet.EarnGold).</summary>
public sealed class LootDrop
{
    public Dictionary<string, int> Items { get; } = new();
    public int Gold { get; private set; }

    internal void AddItem(string itemId, int qty)
    {
        if (qty <= 0) return;
        Items[itemId] = (Items.TryGetValue(itemId, out int n) ? n : 0) + qty;
    }

    internal void AddGold(int gold)
    {
        if (gold > 0) Gold += gold;
    }
}

/// <summary>
/// Rolls loot for a defeated encounter: each creature LINE (from the encounter definition) rolls
/// its creature's <see cref="DropTable"/> once per instance in the line, accumulating parts + coin.
/// Rolling off the encounter definition (not the live combatants) keeps the mapping trivial — the
/// TerritoryEncounter carries the EncounterId. The RNG is injected so callers own determinism; the
/// Phase-1 forest tables are min == max so results are fixed regardless of the roll.
/// </summary>
public static class LootRoller
{
    public static LootDrop RollEncounter(EncounterDefinition encounter, Random rng)
    {
        if (encounter == null) throw new ArgumentNullException(nameof(encounter));
        rng ??= new Random();

        var drop = new LootDrop();
        foreach (var line in encounter.Creatures)
        {
            string? tableId = line.Creature.DropTableId;
            if (string.IsNullOrEmpty(tableId) || !DropTables.TryGet(tableId, out var table))
                continue;

            for (int i = 0; i < line.Count; i++)
                RollOne(table, rng, drop);
        }
        return drop;
    }

    private static void RollOne(DropTable table, Random rng, LootDrop drop)
    {
        if (table.Entries.Count > 0)
        {
            var entry = PickWeighted(table.Entries, rng);
            int qty = RollRange(entry.MinQty, entry.MaxQty, rng);
            drop.AddItem(entry.ItemId, qty);
        }
        drop.AddGold(RollRange(table.CoinMin, table.CoinMax, rng));
    }

    private static int RollRange(int min, int max, Random rng)
    {
        if (max <= min) return min;
        return rng.Next(min, max + 1);
    }

    private static DropEntry PickWeighted(IReadOnlyList<DropEntry> entries, Random rng)
    {
        int total = 0;
        foreach (var e in entries)
            total += Math.Max(1, e.Weight);

        int roll = rng.Next(total);
        foreach (var e in entries)
        {
            roll -= Math.Max(1, e.Weight);
            if (roll < 0)
                return e;
        }
        return entries[^1];
    }
}
