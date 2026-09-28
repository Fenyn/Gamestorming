using Godot;

namespace Delve.UI;

/// <summary>
/// Centered controls-help card, hidden by default and toggled by <see cref="HudRoot"/> on
/// combat_help (Tab/H). Non-modal: every node ignores the mouse, so the game stays fully playable
/// underneath. The rows live in the shared <see cref="KeyLegend"/> scene.
/// </summary>
public partial class HelpOverlay : Control
{
    public override void _Ready() => Visible = false;

    public void Toggle() => Visible = !Visible;
}
