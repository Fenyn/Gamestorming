using Godot;

namespace Delve.UI;

/// <summary>Placement of the command menu beside the active unit, and its open state.</summary>
public partial class ActionBar
{
    /// <summary>Screen pixels between the active unit and the menu's near edge.</summary>
    [Export] public float MenuGap { get; set; } = 72f;

    /// <summary>Margins (left, top, right, bottom) the menu keeps from the screen edges: clear of the
    /// timeline on the left and the unit cards along the bottom. Applied to the live HUD rect, so
    /// wide screens give the menu their full width.</summary>
    [Export] public Vector4 MenuMargins { get; set; } = new(232, 16, 16, 198);

    /// <summary>Pixels the right side must come up short by before the menu flips left, and back,
    /// so a unit near the threshold does not make the menu jump every frame.</summary>
    [Export] public float FlipHysteresis { get; set; } = 24f;

    private bool _menuFlipped;

    /// <summary>Place the command menu beside the active unit, FFT style: its main panel to the
    /// unit's right and centred on it, flipping to the left side when the right runs out of room.
    /// The flip reads the main panel only, so opening a sub-menu never moves the menu; a sub-menu
    /// opens on the side away from the unit.</summary>
    public void AnchorMenu(Vector2 unitScreen)
    {
        var rect = GetRect();
        var bounds = new Rect2(rect.Position.X + MenuMargins.X, rect.Position.Y + MenuMargins.Y,
            rect.Size.X - MenuMargins.X - MenuMargins.Z, rect.Size.Y - MenuMargins.Y - MenuMargins.W);
        float barWidth = _bar.Size.X;
        float rightEdge = unitScreen.X + MenuGap + barWidth;
        _menuFlipped = _menuFlipped ? rightEdge > bounds.End.X - FlipHysteresis : rightEdge > bounds.End.X;
        var row = _flyout.GetParent();
        row.MoveChild(_flyout, _menuFlipped ? 0 : row.GetChildCount() - 1);

        var size = _stack.GetCombinedMinimumSize();
        _stack.Size = size;
        var barOffset = _bar.GlobalPosition - _stack.GlobalPosition;
        float x = _menuFlipped ? unitScreen.X - MenuGap - size.X : unitScreen.X + MenuGap - barOffset.X;
        float y = unitScreen.Y - _bar.Size.Y * 0.5f - barOffset.Y;
        _stack.Position = new Vector2(
            Mathf.Clamp(x, bounds.Position.X, Mathf.Max(bounds.Position.X, bounds.End.X - size.X)),
            Mathf.Clamp(y, bounds.Position.Y, Mathf.Max(bounds.Position.Y, bounds.End.Y - size.Y)));
    }

    /// <summary>FFT style: the menu closes while the player picks a tile or a target, and opens
    /// again on cancel or when the action ends. While it is closed only Move, Confirm and Esc answer.</summary>
    public void SetMenuShown(bool shown)
    {
        _stack.Visible = shown;
        if (!shown) CloseFlyout();
    }

    public bool MenuShown => _stack.Visible;
}
