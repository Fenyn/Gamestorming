using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Godot;

namespace Delve.UI;

public partial class ActionBar
{
    [Export] public ItemIconCatalog? AbilityIcons { get; set; }
    [Export(PropertyHint.Range, "1,3,1")] public int SignatureLimit { get; set; } = 3;
    private ChipFlyout _signatures = null!;
    private string? _spellFilter;

    private ChipSpec SkillChip(SkillEntryView skill) => new()
    {
        Id = skill.ActionId, Name = skill.Name, Icon = AbilityIcons?.For(skill.ActionId),
        ActionCost = skill.ActionCost, CostText = SpellOutCost(skill.ActionCost, skill.CostText),
        BadgeText = skill.BadgeText, Enabled = _interactable && skill.Castable,
        Description = skill.Description, UnavailableReason = skill.UnavailableReason,
    };

    private void RebuildSignatures()
    {
        _signatures.Clear();
        var entries = new List<(int Priority, ChipSpec Chip)>();
        foreach (var skill in _skills.Where(s => s.SignaturePriority > 0))
            entries.Add((skill.SignaturePriority, SkillChip(skill)));
        foreach (var group in _spells.Where(s => s.SignaturePriority > 0)
                     .GroupBy(s => SignatureAbilities.BaseId(s.SpellId)))
        {
            var spell = group.First();
            bool choices = group.Count() > 1;
            entries.Add((spell.SignaturePriority, new ChipSpec
            {
                Id = choices ? group.Key : spell.SpellId, Variant = choices ? -2 : spell.VariantIndex,
                Name = spell.SignatureName.Length > 0 ? spell.SignatureName : spell.Name,
                Icon = SpellIcons?.ForSpell(spell.SpellId),
                ActionCost = choices ? 0 : spell.ActionCost,
                CostText = choices ? "Choose" : SpellOutCost(spell.ActionCost, spell.CostText),
                Enabled = _interactable && group.Any(s => s.Castable),
                Description = spell.Description,
                UnavailableReason = group.Any(s => s.Castable) ? "" : spell.UnavailableReason,
                BadgeText = choices ? null : spell.IsCantrip ? null : $"[{spell.SlotsText}]",
            }));
        }
        var chosen = entries.OrderBy(e => e.Priority).ThenBy(e => e.Chip.Id, System.StringComparer.Ordinal)
            .Take(SignatureLimit).ToArray();
        if (chosen.Length > 0)
        {
            var flow = _signatures.AddFlow();
            foreach (var entry in chosen) _signatures.AddChip(flow, entry.Chip);
        }
        // The quick slots are rows of the menu itself, so they stay while a sub-menu is open: hiding
        // them would change the menu's height under the cursor.
        _signatures.Visible = _interactable && !_compact && chosen.Length > 0;
    }

    private void OnSignaturePressed(ChipSpec spec)
    {
        if (!_interactable || _hud?.ModalActive == true) return;
        if (_skills.Any(s => s.ActionId == spec.Id)) SkillChipPressed?.Invoke(spec.Id);
        else if (spec.Variant == -2) SetFlyout(FlyoutCategory.Spells, spec.Id);
        else SpellChipPressed?.Invoke(spec.Id, spec.Variant);
    }

    private void AddAbilitySection(string title, IEnumerable<SkillEntryView> entries)
    {
        var skills = entries.ToArray();
        if (skills.Length == 0) return;
        _flyout.AddSection(title);
        var flow = _flyout.AddFlow();
        foreach (var skill in skills) _flyout.AddChip(flow, SkillChip(skill));
    }
}
