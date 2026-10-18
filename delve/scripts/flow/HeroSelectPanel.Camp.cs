using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

public partial class HeroSelectPanel
{
    public HeroSheet Sheet => _details.Sheet;
    public CharacterDetailsOverlay Details => _details;

    /// <summary>Open the party screen on a resident (by default the previewed one, then the first
    /// pick); Q and E page through every resident and the screen's button adds or removes the one shown.</summary>
    public void OpenDetails(string? id = null)
    {
        if (_journal.Visible || _details.Visible) return;
        id ??= ShownId();
        if (id == null) return;
        var roster = new CharacterDetailsOverlay.Roster(
            Residents().ToList(),
            SheetFor,
            member => _slots.Contains(member) ? "In party" : ClassWord(member),
            member => _slots.Contains(member),
            CanPick);
        _details.OpenRoster(roster, id, _picker.Visible ? _picker : _assemble);
    }

    public void CloseDetails() => _details.Close();

    /// <summary>Put one of the featured sheet's tooltips on screen with no pointer involved,
    /// addressed by its title. The rendered shot uses it; nothing in the game does.</summary>
    public bool ShowTipForTesting(string title) { InspectShown(); return Sheet.ShowTipForTesting(title); }

    /// <summary>See <see cref="HeroSheet.ShowCardForTesting"/>.</summary>
    public bool ShowCardForTesting(SheetTip tip) { InspectShown(); return Sheet.ShowCardForTesting(tip); }

    /// <summary>Open the party screen on the previewed resident, or turn it to them.</summary>
    private void InspectShown()
    {
        if (!_details.Visible) OpenDetails();
        else if (ShownId() is { } id && id != _details.CurrentId) { CloseDetails(); OpenDetails(id); }
    }

    /// <summary>"Fighter" out of "Fighter · front line": what fits on a face tile.</summary>
    private static string ClassWord(string id) => CharacterCatalog.Find(id)?.Role.Split('·')[0].Trim() ?? "";

    private HeroSheetData SheetFor(string id)
        => _sheets.TryGetValue(id, out var sheet) ? sheet : HeroSheetData.Unknown(CharacterCatalog.Find(id)?.DisplayName ?? id);
}
