using System;
using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>One action and its optional details. The row owns its disclosure state.</summary>
public partial class CombatLogEntryView : VBoxContainer
{
    public event Action? DisclosureChanged;
    public bool DetailsExpanded => _toggle.ButtonPressed;
    public bool IsTurn { get; private set; }
    public string PlainText => _header.GetParsedText() + "\n" + _details.GetParsedText();
    private Button _toggle = null!;
    private RichTextLabel _header = null!;
    private RichTextLabel _details = null!;
    private string _title = "";
    private int _detailCount;
    private readonly List<string> _summaries = new();

    public override void _Ready()
    {
        _toggle = GetNode<Button>("%Disclosure");
        _header = GetNode<RichTextLabel>("%EntryHeader");
        _details = GetNode<RichTextLabel>("%EntryDetails");
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

    public void Configure(string title, bool turn = false)
    {
        _title = title;
        IsTurn = turn;
        _toggle.Visible = !turn;
        _toggle.Disabled = true;
        Refresh();
    }

    public void AddDetail(string fullText, string summary)
    {
        _details.AppendText((_detailCount++ > 0 ? "\n" : "") + fullText);
        if (summary.Length > 0)
        {
            _summaries.Add(summary);
            if (_summaries.Count > 2) _summaries.RemoveAt(1);
        }
        _toggle.Disabled = false;
        Refresh();
    }

    private void Refresh()
    {
        _toggle.Text = DetailsExpanded ? "-" : "+";
        string hint = _toggle.Disabled ? "Details appear as the action resolves."
            : DetailsExpanded ? "Collapse details" : "Expand details";
        _toggle.TooltipText = hint;
        _header.TooltipText = IsTurn ? "" : hint;
        _header.Text = _title + (!DetailsExpanded && _summaries.Count > 0 ? "\n" + string.Join(" · ", _summaries) : "");
        _details.Visible = DetailsExpanded;
    }
}
