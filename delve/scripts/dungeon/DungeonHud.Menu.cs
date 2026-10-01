using Godot;

namespace Delve.Dungeon;

/// <summary>Which of the party menu, party cards and floor plan show over the room.</summary>
public partial class DungeonHud
{
    private bool _fighting, _choosingDoor, _overlayOpen, _fullScreen;

    /// <summary>A panel over the room (a character sheet, an event) holds the screen: the party
    /// menu, the party cards and the floor plan step aside instead of showing through it. A full
    /// screen (the party screen, the journal) also hides the Wardstone panel behind its margin.</summary>
    public void SetOverlayOpen(bool open, bool fullScreen = false)
    {
        if (_overlayOpen == open && _fullScreen == fullScreen) return;
        _overlayOpen = open;
        _fullScreen = fullScreen;
        ApplyOverlay();
    }

    private void ApplyOverlay()
    {
        _expedition.Visible = !_fighting && !_fullScreen;
        _notice.Visible = !_fighting && !_fullScreen;
        _plan.Visible = !_fighting && !_overlayOpen;
        _party.Visible = !_fighting && !_overlayOpen;
        _partyMenu.Visible = _choosingDoor && !_overlayOpen;
        if (!_overlayOpen) return;
        HideDoorTip();
        HideRoomCard();
    }

    public Control PartyMenu => _partyMenu;

    /// <summary>The Journal row needs a campaign; the standalone crawl has none.</summary>
    public void SetJournalAvailable(bool available)
    {
        var row = GetNode<Delve.UI.CaptionButton>("%JournalRow");
        row.SetEnabled(available);
        row.TooltipText = available ? "The bestiary and the unlock journal." : "Unavailable: no campaign loaded";
    }
}
