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
    private Control? _menuRow;

    /// <summary>Below this scale (the two-thirds step) the keycaps, the quick-slot rows and the
    /// header's pips and Focus label would fall under the 18 px text floor, so the zoomed-out menu
    /// drops them and keeps only its name and command rows.</summary>
    [Export(PropertyHint.Range, "0.5,1,0.05")] public float CompactBelowScale { get; set; } = 0.8f;

    private bool _compact;
    private Control? _economy;

    private void SetCompact(bool compact)
    {
        if (_compact == compact) return;
        _compact = compact;
        foreach (var caption in _captions) caption.SetKeycapShown(!compact);
        _economy ??= GetNode<Control>("%Economy");
        _economy.Visible = !compact;
        RebuildSignatures();
    }

    /// <summary>Place the command menu beside the active unit, FFT style: its main panel to the
    /// unit's right and centred on it, flipping to the left side when the right runs out of room.
    /// The flip reads the main panel only, so opening a sub-menu never moves the menu; a sub-menu
    /// opens on the side away from the unit. <paramref name="scale"/> shrinks the whole menu, gap
    /// included, with the unit when the camera zooms out.</summary>
    /// <param name="rightLimit">A right edge the menu must stay left of, such as an open journal.</param>
    public void AnchorMenu(Vector2 unitScreen, float scale = 1f, float rightLimit = float.PositiveInfinity)
    {
        var rect = GetRect();
        var bounds = new Rect2(rect.Position.X + MenuMargins.X, rect.Position.Y + MenuMargins.Y,
            rect.Size.X - MenuMargins.X - MenuMargins.Z, rect.Size.Y - MenuMargins.Y - MenuMargins.W);
        if (rightLimit < bounds.End.X) bounds.End = new Vector2(Mathf.Max(bounds.Position.X, rightLimit - MenuMargins.Z), bounds.End.Y);
        _stack.Scale = new Vector2(scale, scale);
        SetCompact(scale < CompactBelowScale);
        float gap = MenuGap * scale;
        float barWidth = _bar.Size.X * scale;
        float rightEdge = unitScreen.X + gap + barWidth;
        _menuFlipped = _menuFlipped ? rightEdge > bounds.End.X - FlipHysteresis : rightEdge > bounds.End.X;
        _menuRow ??= GetNode<Control>("%MenuRow");
        _menuRow.MoveChild(_flyout, _menuFlipped ? 0 : _menuRow.GetChildCount() - 1);

        var size = _stack.GetCombinedMinimumSize();
        _stack.Size = size;
        size *= scale;
        // Global positions already carry the stack's scale.
        var barOffset = _bar.GlobalPosition - _stack.GlobalPosition;
        float x = _menuFlipped ? unitScreen.X - gap - size.X : unitScreen.X + gap - barOffset.X;
        float y = unitScreen.Y - _bar.Size.Y * scale * 0.5f - barOffset.Y;
        // Whole pixels, so the pixel font lands on the screen grid and stays crisp.
        _stack.Position = new Vector2(
            Mathf.Clamp(x, bounds.Position.X, Mathf.Max(bounds.Position.X, bounds.End.X - size.X)),
            Mathf.Clamp(y, bounds.Position.Y, Mathf.Max(bounds.Position.Y, bounds.End.Y - size.Y))).Round();
    }

    /// <summary>FFT style: the menu closes while the player picks a tile or a target, and opens
    /// again on cancel or when the action ends. While it is closed only Move, Confirm and Esc answer.</summary>
    public void SetMenuShown(bool shown)
    {
        _stack.Visible = shown;
        if (!shown) CloseFlyout();
    }

    public bool MenuShown => _stack.Visible;

    /// <summary>The menu's current zoom scale (1 at the planning distance).</summary>
    public float MenuScale => _stack.Scale.X;
}
