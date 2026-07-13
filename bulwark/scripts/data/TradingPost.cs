using System.Collections.Generic;
using System.Linq;

namespace Bulwark.Data;

/// <summary>
/// One BUY offering at the Trading Post (the gold store): an item the player can purchase for gold,
/// plus an unlock gate. Refinement (Trading-Post reframe): the Trading Post owns the general
/// buy/sell-for-gold economy, and SMITHY UPGRADES widen its stock — an offer becomes buyable once the
/// outpost's smithy ceiling (<see cref="Bulwark.Cozy.OutpostEffects.SmithyTier"/>) reaches
/// <see cref="RequiredTier"/>. Base offers (seeds, basic supplies) ship unlocked; higher-tier offers
/// (the smithy's own metal/rune materials) open as the smithy grows. Data-only per CLAUDE.md — adding
/// an offering touches <see cref="TradingPost"/> only. Prices are PLACEHOLDER/modest; tunable, and
/// always above the item's <see cref="ItemDefinition.SellValue"/> so buy↔sell is never free money.
/// </summary>
public sealed class TradingPostEntry
{
    /// <summary>The item id sold (must be a defined <see cref="Items"/> id).</summary>
    public required string ItemId { get; init; }

    /// <summary>Gold cost of ONE unit.</summary>
    public required int Price { get; init; }

    /// <summary>Smithy ceiling that unlocks this offer (Base = always stocked). Higher tiers open as
    /// the smithy building upgrades — the "smithy upgrade → new Trading Post offerings" link.</summary>
    public SmithyTier RequiredTier { get; init; } = SmithyTier.Base;
}

/// <summary>
/// The Trading Post's BUY catalog — the store's stock. Base tier ships seeds + basic supplies always
/// available; higher-tier entries are gated to a smithy tier so restoring/upgrading the Smithy expands
/// what the store carries (notably the smithy's own crafting materials: copper ingots at Improved, the
/// magical rune reagent at Advanced). SELLING is not catalog-driven — any carried item with
/// <see cref="ItemDefinition.SellValue"/> &gt; 0 sells (the sell shelf is derived from carried stacks,
/// see <see cref="Bulwark.Cozy.StoreSystem"/>). Data-only per CLAUDE.md.
/// </summary>
public static class TradingPost
{
    private static readonly TradingPostEntry[] Entries =
    {
        // --- Base tier: seeds + basic supplies, always stocked ---
        new() { ItemId = "turnip_seed", Price = 6 },
        new() { ItemId = "potato_seed", Price = 10 },
        new() { ItemId = "wheat_seed", Price = 14 },
        new() { ItemId = "tomato_seed", Price = 18 },
        new() { ItemId = "wood", Price = 4 },
        new() { ItemId = "stone", Price = 4 },
        new() { ItemId = "herb", Price = 8 },

        // --- Higher-tier stock unlocked by smithy upgrades (the smithy's own crafting materials, so a
        //     grown smithy lets the store supply the metal/reagent its forge + rune bench consume) ---
        new() { ItemId = "copper_ingot", Price = 45, RequiredTier = SmithyTier.Improved },
        new() { ItemId = "arcane_essence", Price = 70, RequiredTier = SmithyTier.Advanced },
    };

    /// <summary>Every catalog entry (all tiers).</summary>
    public static IReadOnlyList<TradingPostEntry> All => Entries;

    /// <summary>Entries stocked at or below <paramref name="maxTier"/> (the buyable shelf).</summary>
    public static IEnumerable<TradingPostEntry> Available(SmithyTier maxTier = SmithyTier.Base)
        => Entries.Where(e => e.RequiredTier <= maxTier);

    /// <summary>Look up a STOCKED offer by item id. False when the id is unknown to the catalog or its
    /// tier is still locked at <paramref name="maxTier"/> (the shared buy gate).</summary>
    public static bool TryGetAvailable(string itemId, out TradingPostEntry entry,
        SmithyTier maxTier = SmithyTier.Base)
    {
        entry = Entries.FirstOrDefault(e => e.RequiredTier <= maxTier && e.ItemId == itemId)!;
        return entry != null;
    }
}
