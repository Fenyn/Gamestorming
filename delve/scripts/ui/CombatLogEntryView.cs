using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.UI;

/// <summary>One action and its optional details. The row owns its disclosure state.</summary>
public partial class CombatLogEntryView : VBoxContainer
{
    public event Action? DisclosureChanged;
    public bool DetailsExpanded => _toggle.ButtonPressed;
    public bool IsTurn { get; private set; }

    /// <summary>A movement line. The compact panel leaves it to history.</summary>
    public bool IsMove { get; private set; }

    public string PlainText => (Plain(_title) + "\n" + string.Join("  ", _summaries.Select(s => Plain(s.Text.Full)))
        + "\n" + _details.GetParsedText()).Replace(CombatLogFormat.Tie, ' ');

    /// <summary>The header as printed, with its figure groups untied.</summary>
    public string HeaderText => _header.GetParsedText().Replace(CombatLogFormat.Tie, ' ');

    private static string Plain(string bbcode)
        => System.Text.RegularExpressions.Regex.Replace(bbcode, @"\[(?!lb\])/?[^\]]*\]", "").Replace("[lb]", "[");
    private Button _toggle = null!;
    private RichTextLabel _header = null!;
    private RichTextLabel _details = null!;
    private Control _detailsInset = null!;
    private string _title = "";
    private LogText _compactTitle;
    private int _detailCount;
    private readonly List<(LogText Text, bool Lead)> _summaries = new();
    private bool _compact;

    /// <summary>Minimum height of a row in the compact panel.</summary>
    [Export] public float CompactRowHeight { get; set; } = 28;

    /// <summary>Lines a collapsed compact row shows. A longer row hides whole lines, never part of a
    /// word, and its hover carries the rest.</summary>
    [Export] public int CompactMaxLines { get; set; } = 2;

    public void SetCompact(bool compact)
    {
        _compact = compact;
        Refresh();
    }

    public override void _Ready()
    {
        _toggle = GetNode<Button>("%Disclosure");
        _header = GetNode<RichTextLabel>("%EntryHeader");
        _details = GetNode<RichTextLabel>("%EntryDetails");
        _detailsInset = GetNode<Control>("%DetailsInset");
        _header.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _header.FitContent = true;
        _header.Resized += () => { if (Clamped || _compact) Callable.From(ClampLines).CallDeferred(); };
        _toggle.Toggled += _ => { Refresh(); DisclosureChanged?.Invoke(); };
        _header.GuiInput += input =>
        {
            if (input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true }
                && !_toggle.Disabled && HudRoot.Find(this)?.ModalActive != true)
            {
                _toggle.ButtonPressed = !_toggle.ButtonPressed;
                _header.AcceptEvent();
            }
        };
    }

    public void Configure(string title, LogText compactTitle, bool turn = false, bool move = false)
    {
        _title = title;
        _compactTitle = compactTitle;
        IsTurn = turn;
        IsMove = move;
        _toggle.Disabled = true;
        Refresh();
    }

    public void AddDetail(string fullText, LogText summary, bool lead)
    {
        _details.AppendText((_detailCount++ > 0 ? "\n\n" : "") + fullText);
        if (summary.Full.Length > 0) _summaries.Add((summary, lead));
        _toggle.Disabled = false;
        Refresh();
    }

    /// <summary>Rolls first, then the title, then the other figures: "CRIT 29 vs 17  Aldric → Spider A  18 slashing".</summary>
    private string OneLine(bool shortNames)
    {
        var parts = _summaries.Where(s => s.Lead).Select(s => s.Text.For(shortNames))
            .Append(_compactTitle.For(shortNames))
            .Concat(_summaries.Where(s => !s.Lead).Select(s => s.Text.For(shortNames)));
        return string.Join("  ", parts);
    }

    /// <summary>A collapsed compact row stops after <see cref="CompactMaxLines"/> whole lines.</summary>
    private void ClampLines()
    {
        if (!IsInstanceValid(_header)) return;
        bool clamp = _compact && !DetailsExpanded && !IsTurn && _header.GetLineCount() > CompactMaxLines;
        Clamped = clamp;
        _header.FitContent = !clamp;
        _header.CustomMinimumSize = new Vector2(0, clamp ? _header.GetLineOffset(CompactMaxLines) : _compact ? CompactRowHeight : 0);
    }

    /// <summary>True while the row hides lines past <see cref="CompactMaxLines"/>.</summary>
    public bool Clamped { get; private set; }

    private void Refresh()
    {
        _toggle.Text = DetailsExpanded ? "-" : "+";
        string hint = _toggle.Disabled ? "Details appear as the action resolves."
            : DetailsExpanded ? "Collapse details" : "Expand details";
        _toggle.TooltipText = hint;
        _header.Text = IsTurn ? _title : OneLine(_compact);
        _details.Visible = DetailsExpanded;
        _detailsInset.Visible = DetailsExpanded;
        _toggle.Visible = !IsTurn && !(_compact && !DetailsExpanded);
        _header.CustomMinimumSize = new Vector2(0, _compact ? CompactRowHeight : 0);
        _header.FitContent = true;
        Callable.From(ClampLines).CallDeferred();
        _header.TooltipText = IsTurn ? ""
            : $"{Plain(_title)}\n{Plain(OneLine(false)).Replace(CombatLogFormat.Tie, ' ')}\n{hint}";
    }
}
