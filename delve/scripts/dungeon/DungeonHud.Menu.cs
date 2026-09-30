using Godot;

namespace Delve.Dungeon;

/// <summary>Which of the party menu, party cards and floor plan show over the room.</summary>
public partial class DungeonHud
{
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
}
