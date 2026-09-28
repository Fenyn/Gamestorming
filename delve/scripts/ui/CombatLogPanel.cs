using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.UI;

/// <summary>Recent clickable actions, with optional history in a wider sidebar.</summary>
public partial class CombatLogPanel : Control
{
    public event System.Action<CombatRoll, string>? RollObserved;
    private string _actionTitle = "";
    [Export] public PackedScene EntryScene { get; set; } = null!;
    [Export] public float CompactWidth { get; set; } = 440;
    [Export] public float HistoryWidth { get; set; } = 560;
    [Export] public float CompactMaxHeight { get; set; } = 360;
    [Export] public int CompactActions { get; set; } = 3;

    /// <summary>The heading stays up with no rows, because it also holds the Journal button.</summary>
    [Export] public bool KeepHeading { get; set; }
    private string _subject = "";
    private readonly HashSet<string> _enemies = new(System.StringComparer.Ordinal);
    private PanelContainer _shell = null!;
    private Button _toggle = null!;
    private ScrollContainer _scroll = null!;
    private VBoxContainer _entries = null!;
    private Control _footer = null!;
    private Control _rule = null!;
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
        _rule = GetNode<Control>("%Rule");
        _latest = GetNode<Button>("%Latest");
        _count = GetNode<Label>("%EntryCount");
        _format.RollFontSize = GetThemeConstant("roll_font_size", "CombatLogText");
        GetNode<Label>("%LogKey").Text = InputNames.KeyLabelFor(InputNames.LogToggle);
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
        string turn = _format.Turn(name);
        AddRow(turn, new LogText(turn, turn), true);
        _action = null;
        Record();
    }

    private static readonly System.Text.RegularExpressions.Regex MoveLine =
        new(@"^.+ (strides|crawls|steps) \d+ ft$", System.Text.RegularExpressions.RegexOptions.IgnoreCase);

    /// <param name="breakdown">The named modifiers behind a roll line, for the roll row.</param>
    /// <param name="enemyRoll">True when the roller is on the enemy side. The caller knows the roller's
    /// team; without it the panel falls back to the enemy names.</param>
    public void AppendEntry(string message, int severity, bool isDetail, Delve.Combat.RollBreakdown? breakdown = null,
        bool? enemyRoll = null)
    {
        if (!isDetail || _action == null)
        {
            _actionTitle = message;
            _subject = CombatLogFormat.StrikeTarget(message);
            _action = AddRow(_format.Entry(message, severity, false), _format.CompactTitle(message),
                move: MoveLine.IsMatch(message));
        }
        else
            _action.AddDetail(_format.Entry(message, severity, true),
                _format.Summary(message, severity, ref _subject, out bool lead), lead);
        if (CombatRoll.Parse(message) is { } roll)
        {
            string? roller = _format.LeadingActor(roll.Prefix) ?? _format.LeadingActor(_actionTitle);
            var observed = breakdown == null ? roll : roll.WithBreakdown(breakdown);
            bool enemy = enemyRoll ?? (roller != null && _enemies.Contains(roller));
            RollObserved?.Invoke(observed with { EnemyRoll = enemy }, _actionTitle);
        }
        Record();
    }

    /// <summary>Names of the enemy side, so a roll can be read from the party's point of view and the
    /// compact rows can shorten them.</summary>
    public void SetEnemies(IEnumerable<string> names)
    {
        _enemies.Clear();
        _enemies.UnionWith(names);
        _format.SetShortNames(_enemies);
    }

    private CombatLogEntryView AddRow(string title, LogText compactTitle, bool turn = false, bool move = false)
    {
        var row = EntryScene.Instantiate<CombatLogEntryView>();
        _entries.AddChild(row);
        row.Configure(title, compactTitle, turn, move);
        row.SetCompact(!Expanded);
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
        for (int i = _rows.Count - 1; i >= 0; i--)
        {
            var row = _rows[i];
            // Initiative already identifies the actor, and the board shows the move. Turn headings
            // and strides belong to history.
            bool recent = !row.IsTurn && !row.IsMove && ++actions <= CompactActions;
            row.Visible = Expanded || recent || row.DetailsExpanded;
        }
        bool any = _rows.Any(r => r.Visible);
        _scroll.Visible = Expanded || any;
        _shell.Visible = Expanded || any || KeepHeading;
    }

    public override void _Process(double delta)
    {
        if (_settle <= 0) return;
        _scroll.CustomMinimumSize = new Vector2(0, Expanded ? 0
            : Mathf.Min(_entries.GetCombinedMinimumSize().Y, Mathf.Min(CompactMaxHeight, Mathf.Max(80, Size.Y - 100))));
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
        SetEnemies(System.Array.Empty<string>());
        _follow = true;
        _unread = 0;
        SetExpanded(false);
    }

    public void SetExpanded(bool expanded)
    {
        Expanded = expanded;
        float width = expanded ? HistoryWidth : CompactWidth;
        CustomMinimumSize = new Vector2(width, CustomMinimumSize.Y);
        OffsetLeft = OffsetRight - width;
        _shell.SizeFlagsVertical = expanded ? SizeFlags.ExpandFill : SizeFlags.ShrinkBegin;
        _scroll.SizeFlagsVertical = expanded ? SizeFlags.ExpandFill : SizeFlags.ShrinkBegin;
        _footer.Visible = expanded;
        _rule.Visible = expanded;
        foreach (var row in _rows) row.SetCompact(!expanded);
        _toggle.Text = expanded ? "History −" : "Actions +";
        _shell.Visible = expanded || EntryCount > 0;
        RefreshRows();
        JumpToLatest();
    }

    public void ToggleExpanded()
    {
        if (HudRoot.Find(this)?.ModalActive != true) SetExpanded(!Expanded);
    }
}
