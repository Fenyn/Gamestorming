using System;
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
    /// <summary>Resolves the legal aim tiles of one spell (variant) for the caster.</summary>
    internal delegate TargetingPlan TargetResolver(string spellId, int variantIndex);

    /// <summary>Why a targeted spell chip is greyed out when nothing legal is in range.</summary>
    internal const string NoTargetReason = "No valid targets in range";

    /// <summary>
    /// Every castable spell / cost-variant for the action bar, with UI-facing text + gating. A
    /// targeted spell with nothing legal to aim at is greyed out here, the same gate the skill chips
    /// apply: selecting it would otherwise enter and leave targeting with no visible effect.
    /// </summary>
    internal static List<SpellEntryView> GetSpellEntries(ICharacter character, TargetResolver targets)
    {
        var list = new List<SpellEntryView>();
        var sc = character.Spellcasting;
        if (sc == null) return list;

        foreach (var cantrip in sc.GetUniqueCantrips())
            AppendSpellEntries(list, character, cantrip as SpellCastAction, isCantrip: true, targets);
        foreach (var leveled in sc.GetUniqueLeveledSpells())
            AppendSpellEntries(list, character, leveled as SpellCastAction, isCantrip: false, targets);

        return list;
    }

    private static void AppendSpellEntries(
        List<SpellEntryView> list, ICharacter c, SpellCastAction? spell, bool isCantrip, TargetResolver targets)
    {
        if (spell?.Spell == null || string.IsNullOrEmpty(spell.SpellId)) return;

        int actions = c.Actions?.TotalActionsRemaining ?? 0;
        string slotsText = isCantrip ? "cantrip" : $"x{c.Spellcasting?.GetPreparedCount(spell) ?? 0}";
        bool baseCan = spell.CanPerform(c);

        if (!spell.Spell.HasCostVariants)
        {
            list.Add(BuildSpellEntry(c, spell, isCantrip, actions, baseCan, null, -1, slotsText, targets));
            return;
        }

        var variants = spell.Spell.CostVariants;
        for (int i = 0; i < variants.Count; i++)
            list.Add(BuildSpellEntry(c, spell, isCantrip, actions, baseCan, variants[i], i, slotsText, targets));
    }

    /// <summary>True when the spell (variant) has something legal to aim at. A self-centered
    /// emanation needs no aim, so it always has.</summary>
    private static bool HasTargets(TargetingPlan plan)
        => plan.Kind == TargetingKind.SelfArea || plan.Tiles.Count > 0;

    /// <summary>
    /// One action-bar chip for a spell. <paramref name="variant"/> null = the spell's fixed cost
    /// (<paramref name="variantIndex"/> -1); otherwise this is one cost-variant of a variable-cost
    /// spell and the label carries its <c>Label</c>.
    /// </summary>
    private static SpellEntryView BuildSpellEntry(
        ICharacter c, SpellCastAction spell, bool isCantrip, int actions, bool baseCan,
        SpellCostVariant? variant, int variantIndex, string slotsText, TargetResolver targets)
    {
        int cost = variant?.ActionCost ?? spell.ActionCostCount;
        bool hasTargets = HasTargets(targets(spell.SpellId, variantIndex));
        bool castable = baseCan && actions >= cost && hasTargets;

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
            UnavailableReason = castable ? "" : SpellUnavailableReason(c, spell, isCantrip, actions, cost, hasTargets),
        };
    }

    /// <summary>
    /// Player-facing reason a spell chip is greyed out, mirroring the exact gates that computed
    /// Castable=false: action economy first, then the checks inside SpellAction.CanPerform
    /// (condition restrictions, focus points, spell slots incl. the divine-font pool), then the
    /// board (no legal target in range). Empty when the cause isn't determinable — the tooltip then
    /// adds nothing. Derived from the actor's own state only; never from bestiary-masked knowledge.
    /// </summary>
    private static string SpellUnavailableReason(
        ICharacter c, SpellCastAction spell, bool isCantrip, int actions, int cost, bool hasTargets)
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
        return hasTargets ? "" : NoTargetReason;
    }
}
