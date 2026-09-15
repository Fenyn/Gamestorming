using System;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Spellcasting;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>Read-only, knowledge-masked forecasts shared by the targeting modes.</summary>
internal static class TargetPreviewFactory
{
    private static string Percent(float value, bool known) => known ? $"{Math.Round(value)}%" : "?%";
    private static CreatureKnowledgeField SaveField(SavingThrow save) => save switch
    {
        SavingThrow.Fortitude => CreatureKnowledgeField.FortSave,
        SavingThrow.Reflex => CreatureKnowledgeField.RefSave,
        _ => CreatureKnowledgeField.WillSave
    };
    private static bool Known(ICharacter target, CreatureKnowledgeField field) => target.TeamId == 1
        || PlayerActionExecutor.IsCreatureFieldKnown(target.CreatureStats?.CreatureId, field);

    public static AttackPreviewView Spell(ICharacter actor, ICharacter target, SpellCastAction spell, SpellCostVariant? variant = null)
    {
        if (spell.Spell.DefenseType == SpellDefenseType.SpellAttack)
        {
            var attack = ActionBarStateBuilder.BuildPreview(CombatPreviewCalculator.CalculateSpellAttackPreview(actor, target, spell));
            return attack with { DetailText = $"Attack {attack.TotalAttackBonus:+0;-0;0} vs AC {attack.TargetAcText}"
                + (attack.DamageFormula.Length > 0 ? $" · {attack.DamageFormula} damage" : ""),
                OutcomeText = $"{attack.HitChanceText} hit · {attack.CritChanceText} critical hit" };
        }
        if (spell.Spell.DefenseType is SpellDefenseType.BasicSave or SpellDefenseType.Save)
        {
            var save = CombatPreviewCalculator.CalculateSavePreview(actor, target, spell);
            bool known = Known(target, SaveField(spell.Spell.SaveType));
            return View(actor, target, spell.ActionName,
                $"{Percent(save.TargetFailChance, known)} target fails · {Percent(save.TargetCritFailChance, known)} critical failure",
                $"{save.SaveName} {(known ? save.SaveBonus.ToString("+0;-0;0") : "?")} vs spell DC {save.SpellDC}"
                + (string.IsNullOrEmpty(save.DamageFormula) ? "" : $" · {save.DamageFormula} damage")
                + (spell.Spell.DefenseType == SpellDefenseType.BasicSave ? " · Basic save" : ""));
        }
        string effect = spell.Spell.IsHealing ? $"{variant?.GetEffectiveHealing(spell.Spell, spell.GetCastLevel(actor)) ?? spell.Spell.GetEffectiveHealing(spell.GetCastLevel(actor))} healing"
            : spell.Spell.IsDamaging ? $"{spell.Spell.GetEffectiveDamage(spell.GetCastLevel(actor))} damage" : "Applies to a valid target";
        return View(actor, target, spell.ActionName, "No roll required", effect);
    }

    public static AttackPreviewView? Ability(ICharacter actor, ICharacter target, BaseAction action)
    {
        if (action is SkillActionBase skill)
        {
            var check = CombatPreviewCalculator.CalculateSkillCheckPreview(actor, target, skill);
            if (check == null) return null;
            bool known = !skill.PreviewTargetSave.HasValue || Known(target, SaveField(skill.PreviewTargetSave.Value));
            return View(actor, target, action.ActionName,
                $"{Percent(check.SuccessChance, known)} success · {Percent(check.CritSuccessChance, known)} critical success",
                $"{check.SkillName} {check.TotalBonus:+0;-0;0} vs {check.DefenseLabel} DC {(known ? check.DC.ToString() : "?")}");
        }
        // These actions begin with a weapon Strike. Label its forecast explicitly; subsequent
        // strikes, bonus damage and conditional riders are not folded into a made-up combined chance.
        if (action.ActionName is "Lunge" or "Double Slice" or "Sudden Charge" or "Flurry of Blows"
            or "Spellstrike" or "Dimensional Assault" or "Confident Finisher" or "Power Attack" or "Vicious Swing")
        {
            var attack = ActionBarStateBuilder.BuildPreview(CombatPreviewCalculator.CalculateAttackPreview(actor, target));
            return attack with { WeaponName = action.ActionName,
                OutcomeText = $"{attack.HitChanceText} hit · {attack.CritChanceText} critical hit",
                DetailText = $"Opening Strike · Attack {attack.TotalAttackBonus:+0;-0;0} vs AC {attack.TargetAcText} · {attack.DamageFormula} weapon damage" };
        }
        return View(actor, target, action.ActionName, "Effect preview", action.Description ?? "");
    }

    private static AttackPreviewView View(ICharacter actor, ICharacter target, string name, string outcome, string detail)
        => new() { AttackerName = actor.Name, TargetName = target.Name, WeaponName = name,
            OutcomeText = outcome, DetailText = detail };
}
