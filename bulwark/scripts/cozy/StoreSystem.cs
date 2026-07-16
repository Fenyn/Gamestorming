using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// The Trading Post — the outpost's gold STORE, and the single home of the general buy/sell-for-gold
/// economy (Trading-Post reframe: this moved off the Smithy, which now only forges gear + applies
/// runes). Plain C# and unit-testable.
///
/// BUY: purchase a catalog good (<see cref="TradingPost"/>) for gold, validating the offer is stocked
/// at the current smithy ceiling (smithy upgrades widen the stock), gold covers the cost, and the good
/// FITS the party's PF2e Bulk carry cap — all BEFORE any mutation, so a rejected buy consumes nothing.
/// SELL: any carried item with <see cref="ItemDefinition.SellValue"/> &gt; 0 → gold; the sell shelf is
/// DERIVED from carried stacks (the enumeration the SmithyView never had lives here now).
///
/// Currency plumbing: spending goes through the <see cref="Wallet"/> directly; CREDITS route through the
/// injected <paramref name="earnGold"/> callback (GameState.EarnGold) so sale gold still flows through
/// the day-ledger choke point. The smithy ceiling is read live via <paramref name="smithyTier"/>.
/// </summary>
public sealed class StoreSystem
{
    private readonly Inventory _inventory;
    private readonly Wallet _wallet;
    private readonly Action<int> _earnGold;
    private readonly Func<SmithyTier> _smithyTier;
    private readonly Func<int>? _discountPercent;

    /// <summary>Raised after a successful sell (itemId, qty) — GameState re-exposes it as ItemSold.</summary>
    public event Action<string, int>? ItemSold;

    /// <summary>Raised after a successful buy (itemId, qty) — GameState re-exposes it as TradingPostChanged.</summary>
    public event Action<string, int>? GoodBought;

    /// <param name="discountPercent">Optional live BUY-price discount percent (the OutpostEffects
    /// StorePriceDiscount aggregate — e.g. granted by friendship heart perks). Null or 0 = catalog
    /// prices unchanged (the baseline); a discounted price never drops below 1 gold.</param>
    public StoreSystem(Inventory inventory, Wallet wallet, Action<int> earnGold, Func<SmithyTier> smithyTier,
        Func<int>? discountPercent = null)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _wallet = wallet ?? throw new ArgumentNullException(nameof(wallet));
        _earnGold = earnGold ?? throw new ArgumentNullException(nameof(earnGold));
        _smithyTier = smithyTier ?? throw new ArgumentNullException(nameof(smithyTier));
        _discountPercent = discountPercent;
    }

    /// <summary>A catalog price after the live discount (baseline: unchanged; floor 1 gold).</summary>
    private int PriceOf(TradingPostEntry entry)
    {
        int discount = Math.Clamp(_discountPercent?.Invoke() ?? 0, 0, 90);
        return discount <= 0 ? entry.Price : Math.Max(1, entry.Price * (100 - discount) / 100);
    }

    // ===================== Commands =====================

    /// <summary>
    /// Buy <paramref name="count"/> units of a catalog good. Validates the offer is stocked at the
    /// smithy ceiling, gold covers <c>Price × count</c>, AND the goods fit the party's carry cap —
    /// BEFORE spending. A rejected buy (unknown/locked offer, non-positive count, short gold, or
    /// won't-fit) consumes NOTHING and returns false. On success spends the gold, adds the goods
    /// (guaranteed to fit, so they land in full), and emits <see cref="GoodBought"/>.
    /// </summary>
    public bool Buy(string itemId, int count = 1)
    {
        if (count <= 0)
            return false;
        if (!TradingPost.TryGetAvailable(itemId, out var entry, _smithyTier()))
            return false;

        int cost = PriceOf(entry) * count;
        if (_wallet.Gold < cost)
            return false;
        if (!_inventory.WouldFit(itemId, count))
            return false;

        if (!_wallet.TrySpendGold(cost))
            return false;
        _inventory.AddItem(itemId, count);

        GoodBought?.Invoke(itemId, count);
        return true;
    }

    /// <summary>
    /// Sell <paramref name="qty"/> of a sellable item for gold (qty × SellValue). Validates the item is
    /// defined + sellable and the party holds the quantity BEFORE any mutation; removes the items and
    /// credits the gold through the ledger-aware earn callback. Rejects cleanly (false, no change)
    /// otherwise. Emits <see cref="ItemSold"/>.
    /// </summary>
    public bool Sell(string itemId, int qty)
    {
        if (qty <= 0 || !Items.TryGet(itemId, out var def) || def.SellValue <= 0)
            return false;
        if (!_inventory.RemoveItem(itemId, qty))
            return false;

        _earnGold(qty * def.SellValue);
        ItemSold?.Invoke(itemId, qty);
        return true;
    }

    // ===================== View-model =====================

    /// <summary>Build the Trading Post view: gold, every catalog offer (locked ones included, flagged),
    /// and the derived sell shelf (carried sellable stacks).</summary>
    public TradingPostView BuildView()
    {
        int gold = _wallet.Gold;
        SmithyTier tier = _smithyTier();

        var offers = new List<TradingPostOffer>(TradingPost.All.Count);
        foreach (var e in TradingPost.All)
        {
            bool unlocked = e.RequiredTier <= tier;
            int price = PriceOf(e); // live discounted price (baseline: the catalog price)
            offers.Add(new TradingPostOffer
            {
                ItemId = e.ItemId,
                DisplayName = NameOf(e.ItemId),
                Price = price,
                Unlocked = unlocked,
                CanAfford = unlocked && gold >= price,
                Fits = _inventory.WouldFit(e.ItemId, 1),
            });
        }

        var sellShelf = new List<TradingPostSellStack>();
        foreach (var (itemId, qty) in _inventory.Stacks)
        {
            if (qty <= 0 || !Items.TryGet(itemId, out var def) || def.SellValue <= 0)
                continue;
            sellShelf.Add(new TradingPostSellStack
            {
                ItemId = itemId,
                DisplayName = def.DisplayName,
                Quantity = qty,
                UnitValue = def.SellValue,
            });
        }

        return new TradingPostView { Gold = gold, Offers = offers, SellShelf = sellShelf };
    }

    private static string NameOf(string itemId)
        => Items.TryGet(itemId, out var def) ? def.DisplayName : itemId;
}
