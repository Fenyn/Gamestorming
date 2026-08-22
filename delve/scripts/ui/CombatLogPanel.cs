using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>
/// Two-stage combat log. The passive surface is a 3-line ticker of the most recent non-detail
/// entries, hidden entirely while it has none (combat start, after <see cref="ClearLog"/>) so no
/// empty strip sits in the corner; the full severity-colored history (details indented and
/// dimmed) lives in an expandable column toggled by L (via <see cref="HudRoot"/>) or by clicking
/// the ticker. L still works with zero entries — only the passive empty ticker disappears.
/// Non-modal — the game stays playable with the history open. Passive: <c>CombatScene</c>
/// forwards engine log entries as plain (message, severity, isDetail) tuples so no engine type
/// reaches this Control.
/// </summary>
public partial class CombatLogPanel : Control
{
    private const int TickerLines = 3;

    private PanelContainer _ticker = null!;
    private readonly Label[] _tickerLabels = new Label[TickerLines];
    private Control _expanded = null!;
    private RichTextLabel _history = null!;

    private readonly Queue<(string Message, int Severity)> _tickerEntries = new();

    public override void _Ready()
    {
        _ticker = GetNode<PanelContainer>("%Ticker");
        _tickerLabels[0] = GetNode<Label>("%TickerLine0");
        _tickerLabels[1] = GetNode<Label>("%TickerLine1");
        _tickerLabels[2] = GetNode<Label>("%TickerLine2");
        _expanded = GetNode<Control>("%Expanded");
        _history = GetNode<RichTextLabel>("%Log");

        _expanded.Visible = false;
        _ticker.GuiInput += OnTickerGuiInput;
    }

    /// <summary>Append one entry: always into the full history; non-detail entries also rotate
    /// through the ticker. Severity is the PF2e.Core.CombatLogSeverity ordinal (kept as an int so
    /// this Control stays engine-free), colored via <see cref="UiColors.LogSeverity"/>.</summary>
    public void AppendEntry(string message, int severity, bool isDetail)
    {
        var colors = UiColors.LogSeverity;
        Color color = severity >= 0 && severity < colors.Length ? colors[severity] : colors[0];

        // Full history: details indented and dimmed under their parent entry.
        Color lineColor = isDetail ? new Color(color, color.A * 0.65f) : color;
        string indent = isDetail ? "    " : "";
        string escaped = message.Replace("[", "[lb]");
        _history.AppendText($"{indent}[color=#{lineColor.ToHtml(true)}]{escaped}[/color]\n");

        if (isDetail) return;

        _tickerEntries.Enqueue((message, severity));
        while (_tickerEntries.Count > TickerLines)
            _tickerEntries.Dequeue();
        RefreshTicker();
    }

    public void ClearLog()
    {
        _history.Clear();
        _tickerEntries.Clear();
        RefreshTicker();
    }

    /// <summary>Show/hide the full-history column. Driven by <see cref="HudRoot"/> on L and by
    /// clicking the ticker. Non-modal — never touches HudRoot's modal state.</summary>
    public void SetExpanded(bool expanded) => _expanded.Visible = expanded;

    public void ToggleExpanded() => SetExpanded(!_expanded.Visible);

    private void RefreshTicker()
    {
        // No entries -> no ticker at all; the panel sizes to however many lines it holds.
        _ticker.Visible = _tickerEntries.Count > 0;

        var colors = UiColors.LogSeverity;
        int i = 0;
        foreach (var (message, severity) in _tickerEntries)
        {
            var label = _tickerLabels[i++];
            label.Text = message;
            label.AddThemeColorOverride("font_color",
                severity >= 0 && severity < colors.Length ? colors[severity] : colors[0]);
            label.Visible = true;
        }
        for (; i < TickerLines; i++)
        {
            _tickerLabels[i].Text = "";
            _tickerLabels[i].Visible = false;
        }
    }

    private void OnTickerGuiInput(InputEvent @event)
    {
        if (@event is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true })
        {
            ToggleExpanded();
            AcceptEvent();
        }
    }
}
