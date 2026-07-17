using System;
using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive smithy screen (reframe: crafting bench, NOT a store — buy/sell-for-gold lives at the Trading
/// Post now). Two functions: FORGE catalog weapons from materials (gold + metal for higher tiers,
/// equipped to a chosen member), and apply fundamental RUNES (gold + magical reagent). Renders the
/// <see cref="SmithyView"/> pushed via <see cref="Render"/>. Every physical material cost is shown so
/// the metal/reagent model is legible; unaffordable actions are disabled. Raises
/// <see cref="ApplyRuneRequested"/>/<see cref="BuyWeaponRequested"/> the host forwards to GameState —
/// no game rules, no engine types, per CLAUDE.md.
/// Toggled by the "toggle_smithy_panel" input action (G); Esc closes.
/// </summary>
public partial class SmithyPanel : TogglePanel
{
    /// <summary>Intent: apply a fundamental rune to a member's main-hand weapon (memberId, kind).</summary>
    public event Action<string, RuneKind>? ApplyRuneRequested;

    /// <summary>Intent: forge a catalog weapon from materials and equip it to a member (memberId, weaponSlug).</summary>
    public event Action<string, string>? BuyWeaponRequested;

    private VBoxContainer _body = null!;
    private Label _gold = null!;

    private SmithyView? _view;
    private string? _buyTargetId; // member a forged weapon equips to

    public SmithyPanel() => ToggleAction = "toggle_smithy_panel";

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        _gold = GetNode<Label>("%GoldLabel");
        Visible = false;
    }

    /// <summary>Render a fresh smithy view (forge + runes only — selling moved to the Trading Post).</summary>
    public void Render(SmithyView view)
    {
        _view = view;
        _gold.Text = $"Gold: {view.Gold}";

        if (_buyTargetId == null || FindMember(view, _buyTargetId) == null)
            _buyTargetId = view.Members.Count > 0 ? view.Members[0].MemberId : null;

        foreach (Node child in _body.GetChildren())
            child.QueueFree();

        // 1) Per-member weapon + rune upgrades.
        foreach (var m in view.Members)
            _body.AddChild(BuildMemberSection(m));

        // 2) Forge shelf (forge a weapon from materials + equip to selected member).
        _body.AddChild(BuildShelfSection(view));
    }

    // ------------------------------------------------------------------ Runes (per member)

    private Control BuildMemberSection(SmithyMemberView m)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        string striking = m.HasStriking ? ", striking" : "";
        col.AddChild(new Label
        {
            Text = $"{m.Name} — {m.WeaponName}  (+{m.PotencyBonus} potency{striking})",
            ThemeTypeVariation = "TitleLabel",
        });

        if (m.RuneUpgrades.Count == 0)
        {
            col.AddChild(new Label { Text = "No rune upgrades available.", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        foreach (var r in m.RuneUpgrades)
            col.AddChild(BuildRuneRow(m.MemberId, r));

        return panel;
    }

    private Control BuildRuneRow(string memberId, SmithyRuneOption r)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(new Label { Text = r.Label, CustomMinimumSize = new Vector2(220, 0) });

        row.AddChild(new Label
        {
            Text = CostText(r.Cost, r.ReagentCost, r.ReagentItemId),
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            ThemeTypeVariation = "HintLabel",
        });

        RuneKind kind = r.Kind;
        var apply = new Button
        {
            Text = r.Available ? "Apply" : "Maxed",
            ThemeTypeVariation = "AccentButton",
            Disabled = !r.Available || !r.CanAfford,
        };
        apply.Pressed += () => ApplyRuneRequested?.Invoke(memberId, kind);
        row.AddChild(apply);
        return row;
    }

    // ------------------------------------------------------------------ Forge shelf (forge + equip)

    private Control BuildShelfSection(SmithyView view)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        col.AddChild(new Label { Text = "Forge Weapons", ThemeTypeVariation = "TitleLabel" });

        // Equip-to target selector.
        var targetRow = new HBoxContainer();
        targetRow.AddThemeConstantOverride("separation", 8);
        targetRow.AddChild(new Label { Text = "Equip to:" });
        foreach (var m in view.Members)
        {
            string id = m.MemberId;
            var chip = new Button { Text = m.Name, ThemeTypeVariation = "ActionChip", ToggleMode = true };
            chip.SetPressedNoSignal(id == _buyTargetId);
            chip.Pressed += () => { _buyTargetId = id; Render(view); };
            targetRow.AddChild(chip);
        }
        col.AddChild(targetRow);

        if (view.Weapons.Count == 0)
        {
            col.AddChild(new Label { Text = "Nothing to forge yet.", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        foreach (var w in view.Weapons)
            col.AddChild(BuildWeaponRow(w));

        return panel;
    }

    private Control BuildWeaponRow(SmithyWeaponOption w)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(new Label { Text = w.DisplayName, CustomMinimumSize = new Vector2(220, 0) });

        row.AddChild(new Label
        {
            Text = CostText(w.Price, w.MetalCost, w.MetalItemId),
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            ThemeTypeVariation = "HintLabel",
        });

        string slug = w.WeaponSlug;
        string? target = _buyTargetId;
        var forge = new Button
        {
            Text = "Forge",
            ThemeTypeVariation = "AccentButton",
            Disabled = !w.CanAfford || target == null,
        };
        forge.Pressed += () => { if (target != null) BuyWeaponRequested?.Invoke(target, slug); };
        row.AddChild(forge);
        return row;
    }

    // ------------------------------------------------------------------ helpers

    private static string CostText(int gold, int materialQty, string materialItemId)
    {
        if (materialQty <= 0)
            return $"{gold}g";
        string mat = Items.TryGet(materialItemId, out ItemDefinition def) ? def.DisplayName : materialItemId;
        return $"{gold}g + {materialQty} {mat}";
    }

    private static SmithyMemberView? FindMember(SmithyView view, string id)
    {
        foreach (var m in view.Members)
            if (m.MemberId == id)
                return m;
        return null;
    }
}
