using Godot;

namespace Delve.UI;

/// <summary>Spell artwork shared across heightened ranks and casting variants.</summary>
public partial class SpellIconCatalog : ItemIconCatalog
{
    public Texture2D? ForSpell(string spellId)
    {
        int rank = spellId.LastIndexOf("-rank-", System.StringComparison.Ordinal);
        return For(rank < 0 ? spellId : spellId[..rank]);
    }
}
