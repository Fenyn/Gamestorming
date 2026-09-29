using Godot;

namespace Delve.Dungeon;

/// <summary>Placement of the parchment party menu beside the party.</summary>
public partial class DungeonHud
{
    /// <summary>Screen pixels between the party and the menu's near edge.</summary>
    [Export] public float MenuGap { get; set; } = 150f;

    /// <summary>Margins (left, top, right, bottom) the party menu keeps from the screen edges, clear
    /// of the banner, the Wardstone readout, the party cards and the minimap.</summary>
    [Export] public Vector4 MenuMargins { get; set; } = new(16, 190, 280, 150);

    /// <summary>Pixels the right side must come up short by before the menu flips left, and back,
    /// so a party walking along the threshold does not make the menu jump sides every frame.</summary>
    [Export] public float FlipHysteresis { get; set; } = 24f;

    private bool _menuFlipped;
    private bool _fighting, _choosingDoor, _overlayOpen;

    /// <summary>A full panel over the room (a character sheet, an event) holds the screen: the party
    /// menu, the party cards and the floor plan step aside instead of showing through it.</summary>
    public void SetOverlayOpen(bool open)
    {
        if (_overlayOpen == open) return;
        _overlayOpen = open;
        ApplyOverlay();
    }

    private void ApplyOverlay()
    {
        _plan.Visible = !_fighting && !_overlayOpen;
        _party.Visible = !_fighting && !_overlayOpen;
        _partyMenu.Visible = _choosingDoor && !_overlayOpen;
        if (_overlayOpen) HideDoorTip();
    }

    public Control PartyMenu => _partyMenu;

    /// <summary>Float the party menu beside the party, FFT style: to its right, flipping left
    /// when the right runs out of room.</summary>
    public void AnchorPartyMenu(Vector2 partyScreen)
    {
        var rect = GetRect();
        var bounds = new Rect2(rect.Position.X + MenuMargins.X, rect.Position.Y + MenuMargins.Y,
            rect.Size.X - MenuMargins.X - MenuMargins.Z, rect.Size.Y - MenuMargins.Y - MenuMargins.W);
        var size = _partyMenu.GetCombinedMinimumSize();
        _partyMenu.Size = size;
        float rightEdge = partyScreen.X + MenuGap + size.X;
        _menuFlipped = _menuFlipped ? rightEdge > bounds.End.X - FlipHysteresis : rightEdge > bounds.End.X;
        float x = _menuFlipped ? partyScreen.X - MenuGap - size.X : partyScreen.X + MenuGap;
        float y = partyScreen.Y - size.Y * 0.5f;
        _partyMenu.Position = new Vector2(
            Mathf.Clamp(x, bounds.Position.X, Mathf.Max(bounds.Position.X, bounds.End.X - size.X)),
            Mathf.Clamp(y, bounds.Position.Y, Mathf.Max(bounds.Position.Y, bounds.End.Y - size.Y)));
    }
}
