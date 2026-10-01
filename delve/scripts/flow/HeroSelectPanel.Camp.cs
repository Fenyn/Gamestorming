using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

public partial class HeroSelectPanel
{
    public HeroSheet Sheet => _details.Sheet;
    public CharacterDetailsOverlay Details => _details;

    /// <summary>Open the party screen on a resident (by default the one the camp card shows);
    /// Q and E page through every resident and the screen's button adds or removes the one shown.</summary>
    public void OpenDetails(string? id = null)
    {
        if (OverlayOpen) return;
        id ??= ShownId();
        if (id == null) return;
        var roster = new CharacterDetailsOverlay.Roster(
            _cards.Select(c => c.Id).ToList(),
            SheetFor,
            member => _selected.Contains(member) ? "In party" : ClassWord(member),
            _selected.Contains,
            CanPick);
        _details.OpenRoster(roster, id, GetNode<Button>("%DetailsButton"));
    }

    public void CloseDetails() => _details.Close();

    /// <summary>"Fighter" out of "Fighter · front line": what fits on a face tile.</summary>
    private static string ClassWord(string id) => CharacterCatalog.Find(id)?.Role.Split('·')[0].Trim() ?? "";

    /// <summary>The four slots: each pick as a tile that opens its sheet, then empty slots.</summary>
    private void RenderSquad()
    {
        var squad = GetNode<Control>("%Squad");
        foreach (var child in squad.GetChildren()) { squad.RemoveChild(child); child.QueueFree(); }
        if (SquadTileScene == null) return;
        for (int slot = 0; slot < Party.MaxSize; slot++)
        {
            var tile = SquadTileScene.Instantiate<MemberTile>();
            tile.ToggleMode = false;
            squad.AddChild(tile);
            if (slot < _selected.Count && CharacterCatalog.Find(_selected[slot]) is { } def)
            {
                tile.Show(def.Id, def.DisplayName, ClassWord(def.Id), false);
                tile.Pressed += () => OpenDetails(def.Id);
            }
            else
            {
                tile.Show("", "Empty slot", "", false);
                tile.Disabled = true;
            }
        }
    }

    private HeroSheetData SheetFor(string id)
        => _sheets.TryGetValue(id, out var sheet) ? sheet : HeroSheetData.Unknown(CharacterCatalog.Find(id)?.DisplayName ?? id);

    /// <summary>Move the preview without changing formation. Confirm selects the preview.</summary>
    private void Step(int delta)
    {
        if (_cards.Count == 0) return;
        int start = _hovered == null ? -1 : _cards.FindIndex(c => c.Id == _hovered);
        for (int step = 1; step <= _cards.Count; step++)
        {
            int index = ((start + delta * step) % _cards.Count + _cards.Count) % _cards.Count;
            if (!CanPick(_cards[index].Id)) continue;
            _embark.ReleaseFocus();
            Preview(_cards[index].Id);
            _cards[index].GrabFocus();
            return;
        }
    }

    private string? FirstSelectable()
    {
        foreach (var card in _cards)
        {
            if (CanPick(card.Id)) return card.Id;
        }
        return _cards.Count > 0 ? _cards[0].Id : null;
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        foreach (var resident in _cards)
            resident.Position = _camp.SeatPosition(_seats[resident.Id]) - new Vector2(82, 160);
    }
}
