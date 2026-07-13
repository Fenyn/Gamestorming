using System;
using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive inventory / warehouse screen — the core inventory-driven view. Renders the
/// <see cref="InventoryView"/> pushed via <see cref="Render"/>: every member's carried physical
/// stacks with a Bulk load/limit bar + Encumbered indicator, and the shared outpost warehouse
/// (hidden with an explanatory note when <c>warehouseAccessible</c> is false — i.e. in the field).
/// Raises <see cref="DepositRequested"/>/<see cref="WithdrawRequested"/> intents the host forwards
/// to GameState.DepositToWarehouse/WithdrawFromWarehouse — no game rules, no engine types, per
/// CLAUDE.md. Item display names resolve through the <see cref="Items"/> data class like the rest of
/// the UI. Member↔member moves are not a GameState command: deposit then withdraw (at the outpost).
/// Toggled by the "toggle_inventory_panel" input action (I); Esc closes.
/// </summary>
public partial class InventoryPanel : CanvasLayer
{
    /// <summary>Intent: move a member's whole stack into the warehouse (memberId, itemId, qty).</summary>
    public event Action<string, string, int>? DepositRequested;

    /// <summary>Intent: move a whole warehouse stack to a member's carry (memberId, itemId, qty).</summary>
    public event Action<string, string, int>? WithdrawRequested;

    /// <summary>Raised when the panel opens (true) or closes (false).</summary>
    public event Action<bool>? Toggled;

    private VBoxContainer _body = null!;
    private Label _gold = null!;

    private InventoryView? _view;
    private bool _warehouseAccessible;
    private string? _withdrawTargetId; // member the warehouse withdraws into

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        _gold = GetNode<Label>("%GoldLabel");
        Visible = false;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("toggle_inventory_panel"))
        {
            SetOpen(!Visible);
            GetViewport().SetInputAsHandled();
        }
        else if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            SetOpen(false);
            GetViewport().SetInputAsHandled();
        }
    }

    /// <summary>Host command: close the panel if open (fires Toggled(false) so the host unfreezes).</summary>
    public void Close() => SetOpen(false);

    /// <summary>
    /// Render a fresh inventory view. <paramref name="warehouseAccessible"/> mirrors
    /// <c>Inventory.WarehouseAccessible</c> (true only at the outpost): when false the warehouse
    /// stacks + deposit/withdraw affordances are withheld and a note explains why.
    /// </summary>
    public void Render(InventoryView view, bool warehouseAccessible)
    {
        _view = view;
        _warehouseAccessible = warehouseAccessible;
        _gold.Text = $"Gold: {view.Gold}";

        // Keep a valid withdraw target across refreshes; default to the first member.
        if (_withdrawTargetId == null || FindMember(view, _withdrawTargetId) == null)
            _withdrawTargetId = view.Members.Count > 0 ? view.Members[0].MemberId : null;

        foreach (Node child in _body.GetChildren())
            child.QueueFree();

        foreach (var m in view.Members)
            _body.AddChild(BuildMemberSection(m));

        _body.AddChild(BuildWarehouseSection(view));
    }

    // ------------------------------------------------------------------ Member carry (Bulk + stacks)

    private Control BuildMemberSection(MemberInventoryView m)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        // Header: name + Bulk load/limit + Encumbered flag.
        var header = new HBoxContainer();
        header.AddThemeConstantOverride("separation", 12);
        header.AddChild(new Label { Text = m.Name, ThemeTypeVariation = "TitleLabel" });
        header.AddChild(new Label
        {
            Text = $"Bulk {m.CarriedBulk:0.0} / {m.MaxBulk:0.0}  (enc ≥ {m.EncumberedThreshold:0.0})",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            HorizontalAlignment = HorizontalAlignment.Right,
        });
        if (m.Encumbered)
        {
            var enc = new Label { Text = "ENCUMBERED" };
            enc.AddThemeColorOverride("font_color", UiPalette.HpRed);
            header.AddChild(enc);
        }
        col.AddChild(header);

        // Bulk load bar: green under the encumbered threshold, red at/over it.
        var bar = new ProgressBar
        {
            MaxValue = Math.Max(0.1, m.MaxBulk),
            Value = Math.Clamp(m.CarriedBulk, 0, Math.Max(0.1, m.MaxBulk)),
            ShowPercentage = false,
            CustomMinimumSize = new Vector2(0, 10),
        };
        TintBar(bar, m.Encumbered ? UiPalette.HpRed : UiPalette.HpGreen);
        col.AddChild(bar);

        // Physical stacks the member carries, each with a "store the stack" affordance.
        if (m.Stacks.Count == 0)
        {
            col.AddChild(new Label { Text = "— carrying nothing —", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        foreach (var (itemId, qty) in m.Stacks)
            col.AddChild(BuildCarryStackRow(m.MemberId, itemId, qty));

        return panel;
    }

    private Control BuildCarryStackRow(string memberId, string itemId, int qty)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(new Label
        {
            Text = $"{Resolve(itemId)} x{qty}",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
        });

        var deposit = new Button
        {
            Text = "Store ▸",
            ThemeTypeVariation = "ActionChip",
            Disabled = !_warehouseAccessible,
            TooltipText = _warehouseAccessible ? "Move this stack to the warehouse" : "Warehouse is only reachable at the outpost",
        };
        deposit.Pressed += () => DepositRequested?.Invoke(memberId, itemId, qty);
        row.AddChild(deposit);
        return row;
    }

    // ------------------------------------------------------------------ Shared warehouse

    private Control BuildWarehouseSection(InventoryView view)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        col.AddChild(new Label { Text = "Warehouse", ThemeTypeVariation = "TitleLabel" });

        if (!_warehouseAccessible)
        {
            col.AddChild(new Label
            {
                Text = "Out in the field — the warehouse is only reachable back at the outpost.",
                ThemeTypeVariation = "HintLabel",
            });
            return panel;
        }

        // Withdraw target selector: the member a taken stack lands in.
        var targetRow = new HBoxContainer();
        targetRow.AddThemeConstantOverride("separation", 8);
        targetRow.AddChild(new Label { Text = "Withdraw to:" });
        foreach (var m in view.Members)
        {
            string id = m.MemberId;
            var chip = new Button
            {
                Text = m.Name,
                ThemeTypeVariation = "ActionChip",
                ToggleMode = true,
            };
            chip.SetPressedNoSignal(id == _withdrawTargetId);
            chip.Pressed += () => { _withdrawTargetId = id; Render(view, _warehouseAccessible); };
            targetRow.AddChild(chip);
        }
        col.AddChild(targetRow);

        if (view.Warehouse.Count == 0)
        {
            col.AddChild(new Label { Text = "— warehouse empty —", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        foreach (var (itemId, qty) in view.Warehouse)
            col.AddChild(BuildWarehouseStackRow(itemId, qty));

        return panel;
    }

    private Control BuildWarehouseStackRow(string itemId, int qty)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(new Label
        {
            Text = $"{Resolve(itemId)} x{qty}",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
        });

        string? target = _withdrawTargetId;
        var withdraw = new Button
        {
            Text = "◂ Take",
            ThemeTypeVariation = "ActionChip",
            Disabled = target == null,
            TooltipText = "Move this stack into the selected member's carry",
        };
        withdraw.Pressed += () => { if (target != null) WithdrawRequested?.Invoke(target, itemId, qty); };
        row.AddChild(withdraw);
        return row;
    }

    // ------------------------------------------------------------------ helpers

    private void SetOpen(bool open)
    {
        if (Visible == open)
            return;
        Visible = open;
        Toggled?.Invoke(open);
    }

    private static MemberInventoryView? FindMember(InventoryView view, string id)
    {
        foreach (var m in view.Members)
            if (m.MemberId == id)
                return m;
        return null;
    }

    private static string Resolve(string itemId)
        => Items.TryGet(itemId, out ItemDefinition def) ? def.DisplayName : itemId;

    private static void TintBar(ProgressBar bar, Color color)
    {
        if (bar.GetThemeStylebox("fill") is StyleBoxFlat themed)
        {
            var fill = (StyleBoxFlat)themed.Duplicate();
            fill.BgColor = color;
            bar.AddThemeStyleboxOverride("fill", fill);
        }
    }
}
