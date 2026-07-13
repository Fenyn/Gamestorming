using PF2e.Core;
using PF2e.Data;

namespace Bulwark.Cozy;

/// <summary>
/// The PF2e SPELL-ACCESS grant seam (the Arcane Study "learn spells" lever). A bulwark CALL into the
/// engine Spellcasting API — NO engine edit — that grants a spell (by its SpellDatabase id) to a
/// caster's KNOWN list via <c>Spellcasting.LearnSpell</c>. Once known, the spell resolves through the
/// engine's normal availability path (<c>GetAvailableSpellsForRank</c>) and can be prepared/cast; the
/// grant is observable via <see cref="KnowsSpell"/>.
///
/// SCOPE NOTE (reported, not stubbed): granting a KNOWN spell is fully functional here. The engine's
/// <c>Spellcasting.OnSpellsChanged</c> event is scoped to PREPARED-LIST mutations (prepare / consume /
/// swap) and <c>LearnSpell</c> deliberately does not raise it — so a granted spell surfaces reactively
/// only once it is prepared (a PrepareSpells / SwapPreparedSpell call fires OnSpellsChanged). Firing
/// OnSpellsChanged directly on a learn would need a one-line engine change, which was NOT made. This
/// seam is plumbing: it is not driven by any committed effect content.
/// </summary>
public static class SpellAccessSeam
{
    /// <summary>
    /// Grant the spell with <paramref name="spellId"/> to <paramref name="caster"/>'s known list.
    /// Returns false when the caster is not a spellcaster, the id is empty/unknown, or the spell is
    /// already known.
    /// </summary>
    public static bool GrantSpell(PF2eCharacter caster, string spellId)
    {
        if (caster?.Spellcasting == null || string.IsNullOrEmpty(spellId))
            return false;
        var spell = SpellDatabase.Instance?.GetById(spellId);
        return spell != null && caster.Spellcasting.LearnSpell(spell);
    }

    /// <summary>Whether the caster already knows the spell (post-grant assertion seam).</summary>
    public static bool KnowsSpell(PF2eCharacter caster, string spellId)
    {
        if (caster?.Spellcasting == null || string.IsNullOrEmpty(spellId))
            return false;
        var spell = SpellDatabase.Instance?.GetById(spellId);
        return spell != null && caster.Spellcasting.KnowsSpell(spell);
    }
}
