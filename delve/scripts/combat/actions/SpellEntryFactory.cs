using System.Collections.Generic;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Spellcasting;

namespace Delve.Combat;

/// <summary>
/// Builds the action-bar chips for a caster's spells: one per spell, or one per cost-variant of a
/// variable-cost spell. Query only — nothing here casts anything.
/// </summary>
internal static class SpellEntryFactory
{
    /// <summary>Every castable spell / cost-variant for the action bar, with UI-facing text + gating.</summary>
    internal static List<SpellEntryView> GetSpellEntries(ICharacter character)
    {
        var list = new List<SpellEntryView>();
        var sc = character.Spellcasting;
        if (sc == null) return list;

        foreach (var cantrip in sc.GetUniqueCantrips())
            AppendSpellEntries(list, character, cantrip as SpellCastAction, isCantrip: true);
        foreach (var leveled in sc.GetUniqueLeveledSpells())
            AppendSpellEntries(list, character, leveled as SpellCastAction, isCantrip: false);

        return list;
    }

    private static void AppendSpellEntries(
        List<SpellEntryView> list, ICharacter c, SpellCastAction? spell, bool isCantrip)
    {
        if (spell?.Spell == null || string.IsNullOrEmpty(spell.SpellId)) return;

        int actions = c.Actions?.TotalActionsRemaining ?? 0;
        string slotsText = isCantrip ? "cantrip" : $"x{c.Spellcasting?.GetPreparedCount(spell) ?? 0}";
        bool baseCan = spell.CanPerform(c);

        if (!spell.Spell.HasCostVariants)
        {
            list.Add(BuildSpellEntry(c, spell, isCantrip, actions, baseCan, null, -1, slotsText));
            return;
        }

        var variants = spell.Spell.CostVariants;
        for (int i = 0; i < variants.Count; i++)
            list.Add(BuildSpellEntry(c, spell, isCantrip, actions, baseCan, variants[i], i, slotsText));
    }

    /// <summary>
    /// One action-bar chip for a spell. <paramref name="variant"/> null = the spell's fixed cost
    /// (<paramref name="variantIndex"/> -1); otherwise this is one cost-variant of a variable-cost
    /// spell and the label carries its <c>Label</c>.
    /// </summary>
    private static SpellEntryView BuildSpellEntry(
        ICharacter c, SpellCastAction spell, bool isCantrip, int actions, bool baseCan,
        SpellCostVariant? variant, int variantIndex, string slotsText)
    {
        int cost = variant?.ActionCost ?? spell.ActionCostCount;
        bool castable = baseCan && actions >= cost;

        return new SpellEntryView
        {
            SpellId = spell.SpellId,
            VariantIndex = variantIndex,
            Name = variant == null ? spell.ActionName : $"{spell.ActionName} ({variant.Label})",
            IsCantrip = isCantrip,
            ActionCost = cost,
            CostText = $"{cost}a",
            SlotsText = slotsText,
            Targeting = SpellActions.KindOf(spell, variant),
            Castable = castable,
            Description = spell.Description ?? "",
            UnavailableReason = castable ? "" : SpellUnavailableReason(c, spell, isCantrip, actions, cost),
        };
    }

    /// <summary>
    /// Player-facing reason a spell chip is greyed out, mirroring the exact gates that computed
    /// Castable=false: action economy first, then the checks inside SpellAction.CanPerform
    /// (condition restrictions, focus points, spell slots incl. the divine-font pool). Empty when
    /// the cause isn't determinable — the tooltip then adds nothing. Derived from the actor's own
    /// state only; never from bestiary-masked knowledge.
    /// </summary>
    private static string SpellUnavailableReason(
        ICharacter c, SpellCastAction spell, bool isCantrip, int actions, int cost)
    {
        if (actions < cost)
            return CombatantQuery.NeedsActionsReason(cost, actions);

        string? restriction = c.Conditions?.GetActionRestriction(spell, null);
        if (restriction != null)
            return restriction;

        if (spell.Spell.IsFocusSpell)
            return c.Spellcasting?.HasFocusPoints == true ? "" : "No Focus Points left";

        if (!isCantrip)
        {
            var sc = c.Spellcasting;
            var font = sc?.DivineFont;
            bool fontPays = font != null && spell.Spell.Identity != null
                && font.MatchesSpell(spell.Spell.Identity) && font.HasSlots;
            bool hasSlot = sc != null && (sc.IsPreparedCaster
                ? sc.HasPreparedSpell(spell)
                : sc.HasSlotsAvailableAtOrAbove(spell.Spell.SpellLevel));
            if (!fontPays && !hasSlot)
                return "No spell slots left";
        }
        return "";
    }
}
