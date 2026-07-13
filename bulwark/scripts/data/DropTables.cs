using System;
using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>One weighted item line of a <see cref="DropTable"/>: which item, and the quantity band
/// rolled when this entry is picked. Min == Max makes the entry deterministic.</summary>
public sealed class DropEntry
{
    public required string ItemId { get; init; }
    public int MinQty { get; init; } = 1;
    public int MaxQty { get; init; } = 1;

    /// <summary>Relative weight in the table's single weighted pick.</summary>
    public int Weight { get; init; } = 1;
}

/// <summary>
/// A weighted loot table: a single weighted item pick (from <see cref="Entries"/>) plus a coin
/// (gold) band, rolled once per defeated creature that references it. Coin min == max makes the
/// gold deterministic (the Phase-1 forest tables are built that way so the economy spike can force
/// exact results without an RNG seam). Data-only per CLAUDE.md.
/// </summary>
public sealed class DropTable
{
    public required string Id { get; init; }

    /// <summary>Weighted item candidates; empty = coin only.</summary>
    public IReadOnlyList<DropEntry> Entries { get; init; } = Array.Empty<DropEntry>();

    public int CoinMin { get; init; }
    public int CoinMax { get; init; }
}

/// <summary>
/// Static registry of loot tables, keyed by <see cref="CreatureRef.DropTableId"/>. Phase-1 forest
/// set: goblins → fang + coin, rats → pelt + coin, beasts → hide + coin (beast table authored ahead
/// of the creature for a future biome). Additions are data-only.
/// </summary>
public static class DropTables
{
    public static readonly DropTable GoblinDrops = new()
    {
        Id = "goblin_drops",
        Entries = new[] { new DropEntry { ItemId = "goblin_fang", MinQty = 1, MaxQty = 1 } },
        CoinMin = 4, CoinMax = 4,
    };
    public static readonly DropTable RatDrops = new()
    {
        Id = "rat_drops",
        Entries = new[] { new DropEntry { ItemId = "rat_pelt", MinQty = 1, MaxQty = 1 } },
        CoinMin = 2, CoinMax = 2,
    };
    public static readonly DropTable BeastDrops = new()
    {
        Id = "beast_drops",
        Entries = new[] { new DropEntry { ItemId = "beast_hide", MinQty = 1, MaxQty = 1 } },
        CoinMin = 6, CoinMax = 6,
    };

    private static readonly DefinitionRegistry<DropTable> Registry = new(d => d.Id,
        GoblinDrops, RatDrops, BeastDrops);

    public static IReadOnlyCollection<DropTable> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static DropTable Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out DropTable def) => Registry.TryGet(id, out def);
}
