using System.Collections.Generic;
using System.Linq;
using Delve.Combat;

namespace Delve.UI;

public partial class ActionBar
{
    /// <summary>Which chip category the flyout currently shows (None = closed).</summary>
    private enum FlyoutCategory { None, Spells, Skills, Control }

    private FlyoutCategory _openCategory = FlyoutCategory.None;

    /// <summary>Open the flyout on one category (None = close). Opening a category closes the
    /// other; the toggle buttons' pressed states mirror it without re-firing Toggled.</summary>
    private void SetFlyout(FlyoutCategory category, string? spellFilter = null)
    {
        _openCategory = category;
        _spellFilter = spellFilter;
        RebuildSignatures();
        _spellsBtn.SetPressedNoSignal(category == FlyoutCategory.Spells);
        _skillsBtn.SetPressedNoSignal(category == FlyoutCategory.Skills);
        _controlButton.SetPressedNoSignal(category == FlyoutCategory.Control);
        _controlOptions.Visible = category == FlyoutCategory.Control;
        if (category is FlyoutCategory.None or FlyoutCategory.Control)
        {
            _flyout.Visible = false;
            _flyout.Clear();
            return;
        }
        RebuildFlyout();
        _flyout.Visible = true;
    }

    private void CloseFlyout() => SetFlyout(FlyoutCategory.None);

    /// <summary>Rebuild the open category from the last rendered state: Cantrips and Spells
    /// sections for spells, Character and General for abilities.</summary>
    private void RebuildFlyout()
    {
        _flyout.Clear();

        if (_openCategory == FlyoutCategory.Spells)
        {
            var cantrips = new List<SpellEntryView>();
            var slotted = new List<SpellEntryView>();
            foreach (var spell in _spells)
            {
                if (_spellFilter != null && SignatureAbilities.BaseId(spell.SpellId) != _spellFilter) continue;
                (spell.IsCantrip ? cantrips : slotted).Add(spell);
            }

            AddSpellSection("Cantrips", cantrips);
            AddSpellSection("Spells", slotted);
        }
        else if (_openCategory == FlyoutCategory.Skills)
        {
            AddAbilitySection("Character", _skills.Where(s => s.IsCharacterAbility));
            AddAbilitySection("General", _skills.Where(s => !s.IsCharacterAbility));
        }
    }

    private void AddSpellSection(string header, List<SpellEntryView> spells)
    {
        if (spells.Count == 0) return;

        _flyout.AddSection(header);
        var flow = _flyout.AddFlow();
        foreach (var spell in spells)
            _flyout.AddChip(flow, new ChipSpec
            {
                Id = spell.SpellId,
                Icon = SpellIcons?.ForSpell(spell.SpellId),
                Variant = spell.VariantIndex,
                Name = spell.Name,
                ActionCost = spell.ActionCost,
                CostText = SpellOutCost(spell.ActionCost, spell.CostText),
                BadgeText = spell.IsCantrip ? null : $"[{spell.SlotsText}]",
                Enabled = _interactable && spell.Castable,
                Detail = spell.IsCantrip ? "cantrip"
                    : string.IsNullOrEmpty(spell.SlotsText) ? "" : $"{spell.SlotsText.TrimStart('x')} remaining",
                Description = spell.Description,
                UnavailableReason = spell.UnavailableReason,
            });
    }

    /// <summary>A pressed chip fires the category's intent and folds the flyout away.</summary>
    private void OnChipPressed(ChipSpec spec)
    {
        if (_openCategory == FlyoutCategory.Spells)
            SpellChipPressed?.Invoke(spec.Id, spec.Variant);
        else if (_openCategory == FlyoutCategory.Skills)
            SkillChipPressed?.Invoke(spec.Id);
        CloseFlyout();
    }

    /// <summary>1 -> "1 action", 2 -> "2 actions"; the raw cost text when there is no action count.</summary>
    private static string SpellOutCost(int actionCost, string costText)
        => actionCost switch
        {
            1 => "1 action",
            > 1 => $"{actionCost} actions",
            _ => costText,
        };
}
