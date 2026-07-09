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
    private HBoxContainer _row = null!;

    public override void _Ready()
    {
        var panel = new PanelContainer();
        panel.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(panel);

        _row = new HBoxContainer();
        _row.AddThemeConstantOverride("separation", 6);
        panel.AddChild(_row);
    }

    public void Render(IReadOnlyList<UnitView> units)
    {
        foreach (var child in _row.GetChildren())
            child.QueueFree();

        foreach (var unit in units)
        {
            var chip = new PanelContainer();
            var style = new StyleBoxFlat
            {
                BgColor = unit.IsCurrent
                    ? new Color(1f, 0.85f, 0.35f)
                    : unit.TeamId == 1 ? new Color(0.2f, 0.3f, 0.45f) : new Color(0.45f, 0.22f, 0.2f),
                ContentMarginLeft = 8, ContentMarginRight = 8,
                ContentMarginTop = 3, ContentMarginBottom = 3,
            };
            chip.AddThemeStyleboxOverride("panel", style);

            var label = new Label { Text = unit.Name };
            label.AddThemeFontSizeOverride("font_size", 12);
            Color fg = unit.IsCurrent ? Colors.Black : Colors.White;
            if (unit.IsDead) fg = new Color(fg.R, fg.G, fg.B, 0.35f);
            label.AddThemeColorOverride("font_color", fg);
            chip.AddChild(label);
            chip.Modulate = unit.IsDead ? new Color(1, 1, 1, 0.5f) : Colors.White;

            _row.AddChild(chip);
        }
    }
}
