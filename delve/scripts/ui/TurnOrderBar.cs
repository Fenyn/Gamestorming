using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Horizontal initiative strip: one name chip per combatant in turn order, the current actor
/// highlighted and dead combatants grayed. Passive — renders from <see cref="UnitView"/> data.
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

            // Per-chip stylebox: duplicate the authored override so each chip owns its colors.
            // Active = bright bronze, allies = moss, enemies = rust, dead = grayed via modulate.
            // This cast is why turn_order_chip.tscn keeps a StyleBoxFlat while the rest of the
            // theme moved to nine-patch StyleBoxTextures — a texture box has no BgColor to write.
            var style = (StyleBoxFlat)chip.GetThemeStylebox("panel").Duplicate();
            style.BgColor = unit.IsCurrent
                ? UiPalette.Gold
                : unit.TeamId == 1 ? UiPalette.AllyGreen : UiPalette.EnemyRed;
            style.BorderColor = unit.IsCurrent ? UiPalette.Parchment : UiPalette.DarkWood;
            chip.AddThemeStyleboxOverride("panel", style);

            var label = chip.GetNode<Label>("%Label");
            label.Text = unit.Name;
            Color fg = unit.IsCurrent ? UiPalette.InkDark : UiPalette.Cream;
            if (unit.IsDead) fg = new Color(fg.R, fg.G, fg.B, 0.35f);
            label.AddThemeColorOverride("font_color", fg);
            // Slight enlargement for the active combatant so the current turn pops.
            label.AddThemeFontSizeOverride("font_size", unit.IsCurrent ? 15 : 13);
            chip.Modulate = unit.IsDead ? new Color(1, 1, 1, 0.5f) : Colors.White;

            // Thin HP fill strip: dark trough, team-colored fill (not HP-fraction tinted — the
            // team color IS the chip's own color language). Dead chips fade with the rest via
            // the Modulate above, so no extra dead-state handling is needed here.
            var hpBar = chip.GetNode<ProgressBar>("%HpBar");
            int maxHp = Math.Max(1, unit.MaxHp);
            hpBar.MaxValue = maxHp;
            hpBar.Value = Math.Clamp(unit.Hp, 0, maxHp);
            hpBar.AddThemeStyleboxOverride("background", new StyleBoxFlat { BgColor = UiPalette.DarkWood });
            hpBar.AddThemeStyleboxOverride("fill", new StyleBoxFlat
            {
                BgColor = unit.TeamId == 1 ? UiPalette.AllyGreen : UiPalette.EnemyRed
            });

            _row.AddChild(chip);
        }
    }
}
