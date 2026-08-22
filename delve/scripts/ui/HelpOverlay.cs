using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>
/// Centered controls-help card, hidden by default and toggled by <see cref="HudRoot"/> on
/// combat_help (Tab/H). Non-modal: every node ignores the mouse, so the game stays fully playable
/// underneath. Passive per CLAUDE.md — renders only the (keys, action) rows fed via
/// <see cref="SetRows"/>; it knows nothing about the input map, the host scene owns which
/// bindings to describe.
/// </summary>
public partial class HelpOverlay : Control
{
    private GridContainer _grid = null!;

    public override void _Ready()
    {
        _grid = GetNode<GridContainer>("%Grid");
        Visible = false;
    }

    /// <summary>Rebuild the two-column key/action grid from the given rows.</summary>
    public void SetRows(IReadOnlyList<(string Keys, string Action)> rows)
    {
        foreach (var child in _grid.GetChildren())
            child.QueueFree();

        foreach (var (keys, action) in rows)
        {
            var keyLabel = new Label { Text = keys, MouseFilter = MouseFilterEnum.Ignore };
            keyLabel.AddThemeColorOverride("font_color", UiColors.Accent);
            _grid.AddChild(keyLabel);

            var actionLabel = new Label { Text = action, MouseFilter = MouseFilterEnum.Ignore };
            _grid.AddChild(actionLabel);
        }
    }

    public void Toggle() => Visible = !Visible;
}
