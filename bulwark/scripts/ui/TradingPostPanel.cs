using System;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive Trading Post screen (the gold STORE): a BUY list of catalog offers (price, unlock, afford,
/// carry-fit — locked offers shown greyed with an "upgrade the smithy" hint) and a SELL shelf of the
/// party's carried sellable stacks. Renders the <see cref="TradingPostView"/> pushed via
/// <see cref="Render"/> and raises <see cref="BuyRequested"/>/<see cref="SellRequested"/> the host
/// forwards to GameState.BuyGood/SellItem — no game rules, no engine types, per CLAUDE.md. Offers carry
/// their own display names in the view-model, so no data lookups happen here.
/// Toggled by the "toggle_trading_post_panel" input action (T); Esc closes.
/// </summary>
public partial class TradingPostPanel : TogglePanel
{
    /// <summary>Intent: buy <c>count</c> units of a catalog good (itemId, count).</summary>
    public event Action<string, int>? BuyRequested;

    /// <summary>Intent: sell a quantity of a carried item for gold (itemId, qty).</summary>
    public event Action<string, int>? SellRequested;

    private VBoxContainer _body = null!;
    private Label _gold = null!;

    public TradingPostPanel() => ToggleAction = "toggle_trading_post_panel";

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        _gold = GetNode<Label>("%GoldLabel");
        Visible = false;
    }

    /// <summary>Render a fresh Trading Post view — rebuilds the buy list + sell shelf.</summary>
    public void Render(TradingPostView view)
    {
        _gold.Text = $"Gold: {view.Gold}";

        foreach (Node child in _body.GetChildren())
            child.QueueFree();

        _body.AddChild(BuildBuySection(view));
        _body.AddChild(BuildSellSection(view));
    }

    // ------------------------------------------------------------------ Buy list

    private Control BuildBuySection(TradingPostView view)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        col.AddChild(new Label { Text = "Buy Goods", ThemeTypeVariation = "TitleLabel" });

        if (view.Offers.Count == 0)
        {
            col.AddChild(new Label { Text = "The store is empty.", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        foreach (var o in view.Offers)
            col.AddChild(BuildOfferRow(o));

        return panel;
    }

    private Control BuildOfferRow(TradingPostOffer o)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(new Label { Text = o.DisplayName, CustomMinimumSize = new Vector2(220, 0) });

        string cost = o.Unlocked ? $"{o.Price}g" : $"{o.Price}g — locked (upgrade the smithy)";
        row.AddChild(new Label
        {
            Text = cost,
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            ThemeTypeVariation = "HintLabel",
        });

        string id = o.ItemId;
        var buy = new Button
        {
            Text = "Buy",
            ThemeTypeVariation = "AccentButton",
            Disabled = !o.CanBuy,
            TooltipText = !o.Unlocked ? "Unlocks as the smithy is upgraded"
                : !o.Fits ? "Won't fit your carry"
                : !o.CanAfford ? "Not enough gold" : "Buy one",
        };
        buy.Pressed += () => BuyRequested?.Invoke(id, 1);
        row.AddChild(buy);
        return row;
    }

    // ------------------------------------------------------------------ Sell shelf

    private Control BuildSellSection(TradingPostView view)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        col.AddChild(new Label { Text = "Sell Surplus", ThemeTypeVariation = "TitleLabel" });

        if (view.SellShelf.Count == 0)
        {
            col.AddChild(new Label { Text = "Nothing surplus to sell.", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        foreach (var s in view.SellShelf)
            col.AddChild(BuildSellRow(s));

        return panel;
    }

    private Control BuildSellRow(TradingPostSellStack s)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(new Label { Text = $"{s.DisplayName} x{s.Quantity}", CustomMinimumSize = new Vector2(220, 0) });
        row.AddChild(new Label
        {
            Text = $"{s.UnitValue}g each",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            ThemeTypeVariation = "HintLabel",
        });

        string id = s.ItemId;
        int qty = s.Quantity;
        var sellOne = new Button { Text = "Sell 1", ThemeTypeVariation = "ActionChip" };
        sellOne.Pressed += () => SellRequested?.Invoke(id, 1);
        row.AddChild(sellOne);

        var sellAll = new Button { Text = $"Sell all ({qty})", ThemeTypeVariation = "ActionChip" };
        sellAll.Pressed += () => SellRequested?.Invoke(id, qty);
        row.AddChild(sellAll);
        return row;
    }
}
