using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Autoload;
using Godot;

namespace Delve.UI;

/// <summary>
/// The one frame every out-of-combat screen opens in: a scrim, an opaque panel, a header row with
/// the title, the page tabs and "Back Esc", then the body. A screen is an inherited scene that adds
/// its content under Frame/Box/Body (one child per page when <see cref="Pages"/> is set) and its
/// buttons under Frame/Box/Footer.
///
/// The frame owns the modal contract: it holds <see cref="ModalStack"/> while shown, Esc closes it,
/// the number keys pick a page, and focus returns to whatever had it before the frame opened.
/// </summary>
public partial class ScreenFrame : Control
{
    public enum FrameDock { Center, Left, Right }

    [Export] public string Title { get; set; } = "";

    /// <summary>Fill the screen inside <see cref="Margin"/>, capped at <see cref="MaxSize"/>.
    /// Otherwise the frame takes its content's size.</summary>
    [Export] public bool Full { get; set; }

    [Export] public Vector2 MaxSize { get; set; } = new(1856, 1016);
    [Export] public float Margin { get; set; } = 32f;

    /// <summary>Width of a compact frame; zero lets the content decide.</summary>
    [Export] public float CompactWidth { get; set; }

    [Export] public FrameDock Dock { get; set; } = FrameDock.Center;

    /// <summary>A different panel style for the frame (the run end keeps the bone ResultFrame);
    /// empty keeps ScreenFrame.</summary>
    [Export] public StringName FrameVariation { get; set; } = "";
    [Export] public bool Dimmed { get; set; } = true;

    /// <summary>Hold <see cref="ModalStack"/> while shown, which keeps the pause menu shut. A frame
    /// with no close yet (a room event before its result) lets Esc reach the pause menu instead.</summary>
    [Export] public bool HoldsModal { get; set; } = true;

    /// <summary>The close caption; empty hides it, and then Esc does nothing either.</summary>
    [Export] public string CloseText { get; set; } = "Back";

    /// <summary>Tab captions, one per Body child in order. Empty shows the whole Body.</summary>
    [Export] public string[] Pages { get; set; } = Array.Empty<string>();

    /// <summary>Tab button, keyed by <see cref="PageKeys"/> in order.</summary>
    [Export] public PackedScene? TabScene { get; set; }
    [Export] public StringName[] PageKeys { get; set; } = Array.Empty<StringName>();

    public event Action? Closed;
    public event Action<int>? PageChanged;

    public int Page { get; private set; }
    public PanelContainer FramePanel { get; private set; } = null!;
    public Button CloseButton { get; private set; } = null!;
    public IReadOnlyList<Button> Tabs => _tabs;

    protected Control Body { get; private set; } = null!;
    protected Control Footer { get; private set; } = null!;

    private readonly List<Button> _tabs = new();
    private Control? _opener;

    public override void _Ready()
    {
        FramePanel = GetNode<PanelContainer>("%Frame");
        Body = GetNode<Control>("%Body");
        Footer = GetNode<Control>("%Footer");
        CloseButton = GetNode<Button>("%FrameClose");
        CloseButton.Pressed += Close;
        if (!FrameVariation.IsEmpty) FramePanel.ThemeTypeVariation = FrameVariation;
        var scrim = GetNode<Control>("%Scrim");
        scrim.Visible = Dimmed;
        // A full frame takes the whole screen, so what shows around it is shade, not the HUD.
        if (Full) scrim.ThemeTypeVariation = ThemeNames.ScreenScrim;
        SetTitle(Title);
        SetCloseText(CloseText);
        BuildTabs();
        foreach (var button in Footer.GetChildren().OfType<Control>()) button.VisibilityChanged += SyncFooter;
        SyncFooter();
        FramePanel.MinimumSizeChanged += QueueLayout;
        Resized += QueueLayout;
        VisibilityChanged += () =>
        {
            if (Visible)
            {
                if (HoldsModal) ModalStack.Instance?.Push(this);
                Layout();
            }
            else ModalStack.Instance?.Pop(this);
        };
        Hide();
    }

    public string TitleText => GetNode<Label>("%FrameTitle").Text;

    /// <summary>Relabel the close caption; empty hides it, and Esc with it.</summary>
    public void SetCloseText(string text)
    {
        CloseButton.Visible = text.Length > 0;
        if (text.Length > 0) ((CaptionButton)CloseButton).SetActionText(text);
    }

    public void SetTitle(string title)
    {
        var label = GetNode<Label>("%FrameTitle");
        label.Text = title;
        label.Visible = title.Length > 0;
    }

    /// <summary>Show the frame and remember who opened it (by default whoever had focus), so
    /// closing gives focus back.</summary>
    public void OpenFrame(Control? opener = null)
    {
        _opener = opener ?? GetViewport().GuiGetFocusOwner();
        Layout();
        Show();
        SyncFooter();
    }

    public virtual void Close()
    {
        if (!Visible) return;
        Hide();
        Closed?.Invoke();
        UiFocus.Grab(_opener);
        _opener = null;
    }

    public void SelectPage(int page)
    {
        if (Pages.Length == 0 || page < 0 || page >= Pages.Length) return;
        if (page < _tabs.Count && !_tabs[page].Visible) return;
        Page = page;
        int index = 0;
        foreach (var child in Body.GetChildren())
            if (child is Control control) control.Visible = index++ == page;
        for (int i = 0; i < _tabs.Count; i++) _tabs[i].SetPressedNoSignal(i == page);
        PageChanged?.Invoke(page);
    }

    public void SetPageCaption(int page, string text)
    {
        if (page < 0 || page >= _tabs.Count) return;
        if (_tabs[page] is CaptionButton { ActionLabel: { } label }) label.Text = text;
        else _tabs[page].Text = text;
    }

    public override void _Input(InputEvent e)
    {
        if (!IsVisibleInTree() || e.IsEcho()) return;
        if (CloseButton.Visible && e.IsActionPressed(InputNames.UiCancel))
        {
            Close();
            GetViewport().SetInputAsHandled();
            return;
        }
        for (int i = 0; i < Math.Min(PageKeys.Length, Pages.Length); i++)
        {
            if (!e.IsActionPressed(PageKeys[i])) continue;
            SelectPage(i);
            GetViewport().SetInputAsHandled();
            return;
        }
    }

    private void BuildTabs()
    {
        var row = GetNode<Control>("%FrameTabs");
        row.Visible = Pages.Length > 0 && TabScene != null;
        if (!row.Visible) return;
        var group = new ButtonGroup();
        for (int i = 0; i < Pages.Length; i++)
        {
            var tab = TabScene!.Instantiate<Button>();
            if (tab is CaptionButton caption)
            {
                caption.ActionText = Pages[i];
                caption.InputAction = i < PageKeys.Length ? PageKeys[i] : "";
            }
            else tab.Text = Pages[i];
            tab.ToggleMode = true;
            tab.ButtonGroup = group;
            tab.ThemeTypeVariation = ThemeNames.FrameTab;
            int page = i;
            tab.Pressed += () => SelectPage(page);
            row.AddChild(tab);
            _tabs.Add(tab);
        }
        SelectPage(0);
    }

    /// <summary>The footer row takes space only while one of its buttons shows.</summary>
    private void SyncFooter() => Footer.Visible = Footer.GetChildren().OfType<Control>().Any(c => c.Visible);

    private void QueueLayout() => Callable.From(Layout).CallDeferred();

    private void Layout()
    {
        if (!IsInsideTree()) return;
        var screen = Size;
        var room = screen - new Vector2(Margin, Margin) * 2;
        var min = FramePanel.GetCombinedMinimumSize();
        var size = Full
            ? new Vector2(Mathf.Min(room.X, MaxSize.X), Mathf.Min(room.Y, MaxSize.Y))
            : new Vector2(Mathf.Min(Mathf.Max(min.X, CompactWidth), MaxSize.X), Mathf.Min(min.Y, MaxSize.Y));
        size = new Vector2(Mathf.Max(size.X, min.X), Mathf.Max(size.Y, Mathf.Min(min.Y, room.Y)));
        float x = Dock switch
        {
            FrameDock.Left => Margin,
            FrameDock.Right => screen.X - Margin - size.X,
            _ => (screen.X - size.X) / 2,
        };
        FramePanel.Position = new Vector2(Mathf.Round(x), Mathf.Round((screen.Y - size.Y) / 2));
        FramePanel.Size = size;
    }
}
