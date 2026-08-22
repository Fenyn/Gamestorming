using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Horizontal initiative strip: one chip per combatant in turn order — name, a thin team-colored
/// HP bar, a hard highlight on the current actor, dead combatants dimmed. Passive — renders from
/// <see cref="UnitView"/> data. All chip styling comes from theme variations
/// (TurnChipAlly/Enemy/Active, HpBarAlly/Enemy) — no stylebox duplication.
/// </summary>
public partial class TurnOrderBar : Control
{
    private const string ChipScenePath = "res://scenes/ui/turn_order_chip.tscn";

    private HBoxContainer _row = null!;
    private PackedScene _chipScene = null!;

    public override void _Ready()
    {
        _row = GetNode<HBoxContainer>("%Row");
        _chipScene = GD.Load<PackedScene>(ChipScenePath);
    }

    public void Render(IReadOnlyList<UnitView> units)
    {
        foreach (var child in _row.GetChildren())
            child.QueueFree();

        foreach (var unit in units)
        {
            var chip = _chipScene.Instantiate<PanelContainer>();
            chip.ThemeTypeVariation = unit.IsCurrent
                ? ThemeNames.TurnChipActive
                : unit.TeamId == 1 ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;

            var label = chip.GetNode<Label>("%Label");
            label.Text = unit.Name;
            // The active chip sits on the accent fill, so its text flips to the dark inverse and
            // grows a step so the current turn pops.
            label.AddThemeFontSizeOverride("font_size", unit.IsCurrent ? 18 : 16);
            label.AddThemeColorOverride("font_color",
                unit.IsCurrent ? UiColors.TextInverse : UiColors.Text);

            var hpBar = chip.GetNode<ProgressBar>("%HpBar");
            hpBar.ThemeTypeVariation = unit.TeamId == 1 ? ThemeNames.HpBarAlly : ThemeNames.HpBarEnemy;
            int maxHp = Math.Max(1, unit.MaxHp);
            hpBar.MaxValue = maxHp;
            hpBar.Value = Math.Clamp(unit.Hp, 0, maxHp);

            // Dead chips fade as a whole; the chip keeps its slot so the order stays readable.
            chip.Modulate = unit.IsDead ? new Color(1, 1, 1, 0.45f) : Colors.White;

            _row.AddChild(chip);
        }
    }
}
