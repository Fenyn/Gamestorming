using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Horizontal initiative strip: one chip per combatant in turn order — name, a thin team-colored
/// HP bar, a hard highlight on the current actor, dead combatants dimmed. Passive — renders from
/// <see cref="UnitView"/> data. All chip styling comes from theme variations
/// (TurnChipAlly/Enemy/Active, ChipLabel, HpBarAlly/Enemy) — no stylebox duplication.
/// </summary>
public partial class TurnOrderBar : Control
{
    /// <summary>Chip scene instanced once per combatant. Assigned in turn_order_bar.tscn.</summary>
    [Export] public PackedScene? ChipScene { get; set; }

    private HBoxContainer _row = null!;

    public override void _Ready() => _row = GetNode<HBoxContainer>("%Row");

    public void Render(IReadOnlyList<UnitView> units)
    {
        foreach (var child in _row.GetChildren())
            child.QueueFree();

        if (ChipScene == null)
        {
            GD.PushError("[TurnOrderBar] ChipScene is not assigned.");
            return;
        }

        foreach (var unit in units)
        {
            var chip = ChipScene.Instantiate<PanelContainer>();
            chip.ThemeTypeVariation = unit.IsCurrent
                ? ThemeNames.TurnChipActive
                : unit.IsAlly ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;

            var label = chip.GetNode<Label>("%Label");
            label.Text = unit.Name;
            // The active chip sits on the accent fill, so its text flips to the dark inverse and
            // grows a step. Both sizes live in the theme, on the chip's own variation.
            label.ThemeTypeVariation = unit.IsCurrent ? ThemeNames.TurnChipActive : ThemeNames.ChipLabel;
            label.AddThemeColorOverride("font_color",
                unit.IsCurrent ? UiColors.TextInverse : UiColors.Text);

            var hpBar = chip.GetNode<ProgressBar>("%HpBar");
            hpBar.ThemeTypeVariation = unit.IsAlly ? ThemeNames.HpBarAlly : ThemeNames.HpBarEnemy;
            int maxHp = Math.Max(1, unit.MaxHp);
            hpBar.MaxValue = maxHp;
            hpBar.Value = Math.Clamp(unit.Hp, 0, maxHp);

            // Dead chips fade as a whole; the chip keeps its slot so the order stays readable.
            chip.Modulate = unit.IsDead ? new Color(1, 1, 1, 0.45f) : Colors.White;

            _row.AddChild(chip);
        }
    }
}
