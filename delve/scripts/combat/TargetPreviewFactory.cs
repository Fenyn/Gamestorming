using System;
using System.Linq;
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
            var data = CombatPreviewCalculator.CalculateSpellAttackPreview(actor, target, spell);
            var attack = ActionBarStateBuilder.BuildPreview(data, ForecastModifiers.SpellAttack(actor, target, data.MAP));
            return attack with { DetailText = $"Attack {attack.TotalAttackBonus:+0;-0;0} vs AC {attack.TargetAcText}"
                + (attack.DamageFormula.Length > 0 ? $" · {attack.DamageFormula} damage" : ""),
                OutcomeText = $"{attack.HitChanceText} hit · {attack.CritChanceText} critical hit" };
        }
        if (spell.Spell.DefenseType is SpellDefenseType.BasicSave or SpellDefenseType.Save)
        {
            var save = CombatPreviewCalculator.CalculateSavePreview(actor, target, spell);
            bool known = Known(target, SaveField(spell.Spell.SaveType));
            bool basic = spell.Spell.DefenseType == SpellDefenseType.BasicSave;
            string fails = Percent(save.TargetFailChance, known);
            string critFails = Percent(save.TargetCritFailChance, known);
            var view = View(actor, target, spell.ActionName,
                $"{fails} target fails · {critFails} critical failure",
                $"{save.SaveName} {(known ? save.SaveBonus.ToString("+0;-0;0") : "?")} vs spell DC {save.SpellDC}"
                + (string.IsNullOrEmpty(save.DamageFormula) ? "" : $" · {save.DamageFormula} damage")
                + (basic ? " · Basic save" : ""));
            return view with
            {
                Figures = string.IsNullOrEmpty(save.DamageFormula)
                    ? new FigureView[] { new("Fails", fails), new("Crit fail", critFails) }
                    : new FigureView[] { new("Fails", fails), new("Crit fail", critFails), new("Damage", save.DamageFormula) },
                Tags = basic ? new[] { $"{save.SaveName} DC {save.SpellDC}", "Basic save" } : new[] { $"{save.SaveName} DC {save.SpellDC}" },
                Modifiers = ForecastModifiers.Save(actor, target, spell.Spell.SaveType),
            };
        }
        bool healing = spell.Spell.IsHealing;
        string amount = healing ? $"{variant?.GetEffectiveHealing(spell.Spell, spell.GetCastLevel(actor)) ?? spell.Spell.GetEffectiveHealing(spell.GetCastLevel(actor))}"
            : spell.Spell.IsDamaging ? $"{spell.Spell.GetEffectiveDamage(spell.GetCastLevel(actor))}" : "";
        string effect = healing ? $"{amount} healing" : amount.Length > 0 ? $"{amount} damage" : "Applies to a valid target";
        var noRoll = View(actor, target, spell.ActionName, "No roll required", effect);
        return amount.Length == 0 ? noRoll
            : noRoll with { Figures = new[] { new FigureView(healing ? "Healing" : "Damage", amount) }, Tags = new[] { "No roll" } };
    }

    public static AttackPreviewView? Ability(ICharacter actor, ICharacter target, BaseAction action)
    {
        if (action is SkillActionBase skill)
        {
            var check = CombatPreviewCalculator.CalculateSkillCheckPreview(actor, target, skill);
            if (check == null) return null;
            bool known = !skill.PreviewTargetSave.HasValue || Known(target, SaveField(skill.PreviewTargetSave.Value));
            string success = Percent(check.SuccessChance, known);
            string crit = Percent(check.CritSuccessChance, known);
            string dc = known ? check.DC.ToString() : "?";
            return View(actor, target, action.ActionName,
                $"{success} success · {crit} critical success",
                $"{check.SkillName} {check.TotalBonus:+0;-0;0} vs {check.DefenseLabel} DC {dc}") with
            {
                Figures = new FigureView[] { new("Success", success), new("Crit", crit) },
                Tags = new[] { $"{check.SkillName} {check.TotalBonus:+0;-0;0}", $"{check.DefenseLabel} DC {dc}" },
                Modifiers = ForecastModifiers.Check(actor, target, skill.GetPreviewSkill(actor, target),
                    skill.PreviewUsesFlatDC ? null : skill.PreviewTargetSave, check.MAP),
            };
        }
        // These actions begin with a weapon Strike. Label its forecast explicitly; subsequent
        // strikes, bonus damage and conditional riders are not folded into a made-up combined chance.
        if (action.ActionName is "Lunge" or "Double Slice" or "Sudden Charge" or "Flurry of Blows"
            or "Spellstrike" or "Dimensional Assault" or "Confident Finisher" or "Power Attack" or "Vicious Swing")
        {
            var data = CombatPreviewCalculator.CalculateAttackPreview(actor, target);
            var attack = ActionBarStateBuilder.BuildPreview(data, ForecastModifiers.Strike(actor, target, data.MAP));
            return attack with { WeaponName = action.ActionName,
                OutcomeText = $"{attack.HitChanceText} hit · {attack.CritChanceText} critical hit",
                DetailText = $"Opening Strike · Attack {attack.TotalAttackBonus:+0;-0;0} vs AC {attack.TargetAcText} · {attack.DamageFormula} weapon damage",
                Tags = new[] { "Opening Strike" }.Concat(attack.Tags).ToArray() };
        }
        return View(actor, target, action.ActionName, "Effect preview", action.Description ?? "");
    }

    private static AttackPreviewView View(ICharacter actor, ICharacter target, string name, string outcome, string detail)
        => new() { AttackerName = actor.Name, TargetName = target.Name, WeaponName = name,
            OutcomeText = outcome, DetailText = detail };
}
