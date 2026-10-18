using Godot;

namespace Delve.Dungeon;

/// <summary>Which of the menu bar, pack, prompts, party cards and floor plan show over the room.</summary>
public partial class DungeonHud
{
    private bool _fighting, _choosingDoor, _overlayOpen, _fullScreen;

    /// <summary>A panel over the room (a character sheet, an event) holds the screen: the buttons,
    /// the party cards and the floor plan step aside instead of showing through it. A full
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
        bool commands = _choosingDoor && !_overlayOpen;
        _prompts.Visible = commands;
        _menuBar.Visible = commands;
        _pack.Visible = commands;
        if (!_overlayOpen) return;
        HideDoorTip();
        HideRoomCard();
    }

    /// <summary>Top of the clear view: below the room banner's title.</summary>
    [Export] public float ClearViewTop { get; set; } = 112;

    /// <summary>Breathing room kept between a framed room and the HUD.</summary>
    [Export] public float ClearViewMargin { get; set; } = 48;

    /// <summary>The part of the screen the exploration HUD leaves open, in viewport coordinates:
    /// under the room banner, above the prompts and the floor plan, right of <paramref name="left"/>
    /// (a panel docked at the left edge). The camera frames each room inside it.</summary>
    public Rect2 ClearView(float left = 0)
    {
        var size = GetViewportRect().Size;
        float bottom = Mathf.Min(_prompts.GetGlobalRect().Position.Y, _plan.GetGlobalRect().Position.Y);
        return new Rect2(left, ClearViewTop, size.X - left, bottom - ClearViewTop).Grow(-ClearViewMargin);
    }

    /// <summary>The room's verbs above the party cards: Short rest, and Make camp or the way on while open.</summary>
    public Control Prompts => _prompts;

    /// <summary>The Party and Journal buttons, top right.</summary>
    public Control MenuBar => _menuBar;

    /// <summary>The Journal row needs a campaign; the standalone crawl has none.</summary>
    public void SetJournalAvailable(bool available)
    {
        var row = GetNode<Delve.UI.CaptionButton>("%JournalRow");
        row.SetEnabled(available);
        row.TooltipText = available ? "" : "Unavailable: no campaign loaded";
    }
}
