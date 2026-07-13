using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// View-model for the Trading Post screen (the gold store): current gold, the buy OFFERS (with price,
/// unlock, affordability and carry-fit), and the SELL SHELF (the party's carried sellable stacks with
/// their unit sell value). View-model shaped per CLAUDE.md — no engine types leak; item ids/names are
/// plain strings. Built by <see cref="StoreSystem.BuildView"/> from live state.
/// </summary>
public sealed class TradingPostView
{
    public required int Gold { get; init; }

    /// <summary>Everything the store can carry (every catalog entry), locked entries included so the UI
    /// can show "unlock by upgrading the smithy".</summary>
    public required IReadOnlyList<TradingPostOffer> Offers { get; init; }

    /// <summary>The sell shelf: the party's carried stacks whose item is sellable (SellValue &gt; 0).</summary>
    public required IReadOnlyList<TradingPostSellStack> SellShelf { get; init; }
}

/// <summary>One buyable offer on the store shelf.</summary>
public sealed class TradingPostOffer
{
    public required string ItemId { get; init; }
    public required string DisplayName { get; init; }
    public required int Price { get; init; }

    /// <summary>True when the smithy ceiling has reached this offer's required tier (in stock).</summary>
    public required bool Unlocked { get; init; }

    /// <summary>True when gold covers one unit AND the offer is unlocked.</summary>
    public required bool CanAfford { get; init; }

    /// <summary>True when one unit would fit the party's Bulk carry cap.</summary>
    public required bool Fits { get; init; }

    /// <summary>True when a single buy can happen right now (unlocked + affordable + fits).</summary>
    public bool CanBuy => Unlocked && CanAfford && Fits;
}

/// <summary>One carried, sellable stack on the sell shelf.</summary>
public sealed class TradingPostSellStack
{
    public required string ItemId { get; init; }
    public required string DisplayName { get; init; }
    public required int Quantity { get; init; }

    /// <summary>Gold gained per unit sold (<see cref="Bulwark.Data.ItemDefinition.SellValue"/>).</summary>
    public required int UnitValue { get; init; }
}
