using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.UI;

/// <summary>Recent clickable actions, with optional history in a wider sidebar.</summary>
public partial class CombatLogPanel : Control
{
    public event System.Action<CombatRoll, string>? RollObserved;
    public event System.Action<bool>? DiceVisibilityChanged;
    private string _actionTitle = "";
    [Export] public PackedScene EntryScene { get; set; } = null!;
    [Export] public float CompactWidth { get; set; } = 440;
    [Export] public float HistoryWidth { get; set; } = 560;
    [Export] public float CompactMaxHeight { get; set; } = 360;
    [Export] public float DetailsMaxHeight { get; set; } = 620;
    [Export] public int CompactActions { get; set; } = 3;
    private PanelContainer _shell = null!;
    private Button _toggle = null!;
    private ScrollContainer _scroll = null!;
    private VBoxContainer _entries = null!;
    private Control _footer = null!;
    private Button _latest = null!;
    private Label _count = null!;
    private readonly CombatLogFormat _format = new();
    private readonly List<CombatLogEntryView> _rows = new();
    private CombatLogEntryView? _action;
    private int _unread;
    private bool _follow = true;
    private int _settle;
    private CombatLogEntryView? _revealRow;
    public bool Expanded { get; private set; }
    public int EntryCount { get; private set; }
    public string HistoryText => string.Join("\n", _rows.Select(r => r.PlainText));
    public IReadOnlyList<CombatLogEntryView> Rows => _rows;

    public override void _Ready()
    {
        _shell = GetNode<PanelContainer>("%Shell");
        _toggle = GetNode<Button>("%ToggleLog");
        _scroll = GetNode<ScrollContainer>("%LogScroll");
        _entries = GetNode<VBoxContainer>("%Entries");
        _footer = GetNode<Control>("%Footer");
        _latest = GetNode<Button>("%Latest");
        _count = GetNode<Label>("%EntryCount");
        _format.RollFontSize = GetThemeConstant("roll_font_size", "CombatLogText");
        var dice = GetNode<CheckButton>("%DiceToggle");
        dice.SetPressedNoSignal(Delve.Settings.ViewPreferences.ShowDiceRolls);
        dice.Toggled += enabled =>
        {
            Delve.Settings.ViewPreferences.ShowDiceRolls = enabled;
            DiceVisibilityChanged?.Invoke(enabled);
        };
        _toggle.Pressed += ToggleExpanded;
        _latest.Pressed += JumpToLatest;
        _scroll.GetVScrollBar().ValueChanged += _ =>
        {
            if (_settle > 0) return;
            _follow = AtBottom();
            RefreshFollowing();
        };
        SetExpanded(false);
    }

    public void SetActors(IEnumerable<(string Name, Color Color)> actors) => _format.SetActors(actors);

    public void BeginTurn(string name)
    {
        AddRow(_format.Turn(name), true);
        _action = null;
        Record();
    }

    public void AppendEntry(string message, int severity, bool isDetail)
    {
        if (!isDetail || _action == null)
        {
            _actionTitle = message;
            _action = AddRow(_format.Entry(message, severity, false));
        }
        else
            _action.AddDetail(_format.Entry(message, severity, true), _format.Summary(message, severity));
        if (CombatRoll.Parse(message) is { } roll) RollObserved?.Invoke(roll, _actionTitle);
        Record();
    }

    private CombatLogEntryView AddRow(string title, bool turn = false)
    {
        var row = EntryScene.Instantiate<CombatLogEntryView>();
        _entries.AddChild(row);
        row.Configure(title, turn);
        row.DisclosureChanged += () =>
        {
            // An opened entry stays visible as new actions arrive, until the reader collapses it.
            _follow = false;
            _revealRow = row.DetailsExpanded ? row : null;
            RefreshRows();
            _settle = 4;
        };
        _rows.Add(row);
        return row;
    }

    private void Record()
    {
        EntryCount++;
        if (!_follow) _unread++;
        _count.Text = $"{EntryCount} entries";
        _shell.Visible = true;
        RefreshRows();
        _settle = 4;
        RefreshFollowing();
    }

    private void RefreshRows()
    {
        int actions = 0;
        bool latestTurn = false;
        for (int i = _rows.Count - 1; i >= 0; i--)
        {
            var row = _rows[i];
            bool recent = row.IsTurn ? !latestTurn : ++actions <= CompactActions;
            if (row.IsTurn) latestTurn = true;
            row.Visible = Expanded || recent || row.DetailsExpanded;
        }
    }

    public override void _Process(double delta)
    {
        if (_settle <= 0) return;
        float heightCap = _rows.Any(r => r.Visible && r.DetailsExpanded) ? DetailsMaxHeight : CompactMaxHeight;
        _scroll.CustomMinimumSize = new Vector2(0, Expanded ? 0
            : Mathf.Min(_entries.GetCombinedMinimumSize().Y, Mathf.Min(heightCap, Mathf.Max(80, Size.Y - 100))));
        if (_follow) _scroll.ScrollVertical = (int)_scroll.GetVScrollBar().MaxValue;
        if (_settle == 1 && _revealRow != null)
        {
            _scroll.EnsureControlVisible(_revealRow);
            _revealRow = null;
        }
        _settle--;
        RefreshFollowing();
    }

    private bool AtBottom()
    {
        var bar = _scroll.GetVScrollBar();
        return bar.Value >= bar.MaxValue - bar.Page - 2;
    }

    private void RefreshFollowing()
    {
        if (_follow) _unread = 0;
        _latest.Text = _unread > 0 ? $"Latest ({_unread} new)" : "Jump to latest";
        _latest.Disabled = _follow && AtBottom();
    }

    public void JumpToLatest()
    {
        _follow = true;
        _unread = 0;
        _settle = 4;
    }

    public void ClearLog()
    {
        foreach (var row in _rows) { _entries.RemoveChild(row); row.QueueFree(); }
        _rows.Clear();
        _action = null;
        _revealRow = null;
        EntryCount = 0;
        _count.Text = "No entries yet";
        _format.SetActors(System.Array.Empty<(string, Color)>());
        _follow = true;
        _unread = 0;
        SetExpanded(false);
    }

    public void SetExpanded(bool expanded)
    {
        Expanded = expanded;
        OffsetLeft = OffsetRight - (expanded ? HistoryWidth : CompactWidth);
        _shell.SizeFlagsVertical = expanded ? SizeFlags.ExpandFill : SizeFlags.ShrinkBegin;
        _scroll.SizeFlagsVertical = expanded ? SizeFlags.ExpandFill : SizeFlags.ShrinkBegin;
        _footer.Visible = expanded;
        _toggle.Text = $"Combat log    {InputNames.KeyLabelFor(InputNames.LogToggle)}    {(expanded ? "Less history −" : "More history +")}";
        _shell.Visible = expanded || EntryCount > 0;
        RefreshRows();
        JumpToLatest();
    }

    public void ToggleExpanded()
    {
        if (HudRoot.Find(this)?.ModalActive != true) SetExpanded(!Expanded);
    }
}
