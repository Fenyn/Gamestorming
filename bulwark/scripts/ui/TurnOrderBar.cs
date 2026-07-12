using System.Collections.Generic;
using Bulwark.Combat;
using Godot;

namespace Bulwark.UI;

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
            // Warm palette (UiPalette): active = bright gold, allies = green-brown,
            // enemies = red-brown, dead = grayed via modulate.
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

            _row.AddChild(chip);
        }
    }
}
