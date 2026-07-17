using System;
using System.Collections.Generic;
using Bulwark.Territory;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive gate party-selection panel: shows the fixed leader (the Veteran) and up to three
/// selectable living companions, and raises <see cref="TravelConfirmed"/> with the picked ids.
/// Renders only the <see cref="PartySelectView"/> pushed via <see cref="Open"/> — no game rules,
/// no engine types (per CLAUDE.md). The host scene reacts to <see cref="Toggled"/> to freeze the
/// avatar and the day clock while the panel is modal; Esc or Cancel closes.
/// </summary>
public partial class PartySelectPanel : TogglePanel
{
    private const int CompanionSlots = 3;

    /// <summary>Intent: the player confirmed travel with these companion ids (0..3).</summary>
    public event Action<IReadOnlyList<string>>? TravelConfirmed;

    private Label _title = null!;
    private Label _leaderLabel = null!;
    private readonly Button[] _companionButtons = new Button[CompanionSlots];
    private Button _confirmButton = null!;
    private Button _cancelButton = null!;

    private PartySelectView? _view;
    private readonly HashSet<string> _selected = new();

    public override void _Ready()
    {
        _title = GetNode<Label>("%TitleLabel");
        _leaderLabel = GetNode<Label>("%LeaderLabel");
        for (int i = 0; i < CompanionSlots; i++)
        {
            _companionButtons[i] = GetNode<Button>($"%Companion{i}");
            int index = i; // capture per-button
            _companionButtons[i].Pressed += () => OnCompanionPressed(index);
        }
        _confirmButton = GetNode<Button>("%ConfirmButton");
        _cancelButton = GetNode<Button>("%CancelButton");
        _confirmButton.Pressed += OnConfirmPressed;
        _cancelButton.Pressed += () => SetOpen(false);

        Visible = false;
    }

    /// <summary>Open the panel with a fresh view. Every joinable companion starts SELECTED — the
    /// default is the full party (design/tutorial_quests.md: "take all four on expedition"); the player
    /// deselects anyone they want to leave behind.</summary>
    public void Open(PartySelectView view)
    {
        _view = view;
        _selected.Clear();
        foreach (var c in view.Companions)
            if (c.CanJoin)
                _selected.Add(c.Id);
        Render();
        SetOpen(true);
    }

    private void Render()
    {
        if (_view == null)
            return;

        _title.Text = $"Head out to {_view.DestinationName}?";
        _leaderLabel.Text = $"{_view.LeaderName} leads.";
        _confirmButton.Text = $"Travel ({_view.TravelMinutes} min)";

        for (int i = 0; i < CompanionSlots; i++)
        {
            bool has = i < _view.Companions.Count;
            _companionButtons[i].Visible = has;
            if (!has)
                continue;

            var c = _view.Companions[i];
            _companionButtons[i].Text = $"{c.Name} — {c.HpText}";
            _companionButtons[i].Disabled = !c.CanJoin;
            _companionButtons[i].SetPressedNoSignal(_selected.Contains(c.Id));
        }
    }

    private void OnCompanionPressed(int index)
    {
        if (_view == null || index >= _view.Companions.Count)
            return;

        var c = _view.Companions[index];
        if (!c.CanJoin)
            return;

        if (!_selected.Remove(c.Id))
            _selected.Add(c.Id);
        Render();
    }

    private void OnConfirmPressed()
    {
        if (_view == null)
            return;

        // Emit ids in view order for a stable marching order.
        var ids = new List<string>();
        foreach (var c in _view.Companions)
            if (_selected.Contains(c.Id))
                ids.Add(c.Id);

        SetOpen(false);
        TravelConfirmed?.Invoke(ids);
    }
}
