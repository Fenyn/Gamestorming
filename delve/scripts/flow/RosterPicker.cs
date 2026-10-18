using System;
using System.Collections.Generic;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// Party assembly's roster: every resident who could fill the chosen slot, as face tiles. A tile
/// click picks that resident; the footer opens the party screen on the focused one. Who is offered
/// is the caller's choice; this screen only lists and reports.
/// </summary>
public partial class RosterPicker : ScreenFrame
{
    [Export] public PackedScene TileScene { get; set; } = null!;

    public event Action<string>? Chosen;
    public event Action<string>? DetailsRequested;
    public event Action? VacateRequested;

    /// <summary>One offered resident: id, name and the tile's status line.</summary>
    public readonly record struct Entry(string Id, string Name, string Line);

    private GridContainer _tiles = null!;
    private Button _details = null!;
    private Button _vacate = null!;
    private string? _focused;

    public IReadOnlyList<string> Offered => _offered;
    private readonly List<string> _offered = new();

    public override void _Ready()
    {
        base._Ready();
        _tiles = GetNode<GridContainer>("%Tiles");
        _details = GetNode<Button>("%PickerDetails");
        _details.Pressed += () =>
        {
            if (_focused != null) DetailsRequested?.Invoke(_focused);
        };
        _vacate = GetNode<Button>("%PickerVacate");
        _vacate.Pressed += () => VacateRequested?.Invoke();
    }

    /// <summary>Offer to send the slot's occupant back to town.</summary>
    public void ShowVacate(bool show) => _vacate.Visible = show;

    public void Open(IReadOnlyList<Entry> entries, int slot, Control? opener)
    {
        foreach (var child in _tiles.GetChildren())
        {
            _tiles.RemoveChild(child);
            child.QueueFree();
        }
        _offered.Clear();
        _focused = null;
        SetTitle($"Slot {slot + 1}");
        foreach (var entry in entries)
        {
            var tile = TileScene.Instantiate<MemberTile>();
            tile.ToggleMode = false;
            _tiles.AddChild(tile);
            tile.Show(entry.Id, entry.Name, entry.Line, false);
            string id = entry.Id;
            tile.Pressed += () => Chosen?.Invoke(id);
            tile.FocusEntered += () => _focused = id;
            tile.MouseEntered += () => _focused = id;
            _offered.Add(id);
        }
        _focused = _offered.Count > 0 ? _offered[0] : null;
        _details.Disabled = _focused == null;
        _details.TooltipText = _focused == null ? "Unavailable: nobody is free to join" : "";
        OpenFrame(opener);
        if (_tiles.GetChildCount() > 0) UiFocus.Grab(_tiles.GetChild<Control>(0));
    }
}
