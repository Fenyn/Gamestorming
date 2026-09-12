using System;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Combat;

/// <summary>
/// Assembles the action bar's view models from the rules layer: the per-turn
/// <see cref="ActionBarState"/> snapshot and the hover <see cref="AttackPreviewView"/>. Plain C#,
/// split from <see cref="PlayerTurnController"/> so the controller keeps to intents and modes.
/// </summary>
internal static class ActionBarStateBuilder
{
    internal static ActionBarState Build(PlayerActionExecutor exec, ICharacter current)
    {
        int actions = current.Actions?.TotalActionsRemaining ?? 0;

        bool canStrike = actions > 0 && exec.GetStrikeTargets(current).Count > 0;
        bool canRaiseShield = actions > 0 && current.Equipment?.CanRaiseShield() == true;

        var inspect = exec.GetUnitInspect(current.GridPosition);

        return new ActionBarState
        {
            ActorName = current.Name,
            ActionsRemaining = actions,
            MaxActions = current.Actions?.MaxBaseActions ?? 3,
            CanStrike = canStrike,
            CanRaiseShield = canRaiseShield,
            Hp = inspect?.Hp ?? 0,
            MaxHp = inspect?.MaxHp ?? 0,
            Ac = inspect?.Ac ?? 0,
            StrikeDisabledReason = DisabledReason(canStrike, actions, "No targets in reach"),
            ShieldDisabledReason = canRaiseShield ? null : exec.GetRaiseShieldDisabledReason(current),
            Map = exec.GetCurrentMap(current),
            SpellEntries = current.Spellcasting != null
                ? exec.GetSpellEntries(current)
                : Array.Empty<SpellEntryView>(),
            SkillEntries = exec.GetSkillEntries(current),
        };
    }

    /// <summary>Common "no actions left" reason wins over the button-specific one; null when enabled.</summary>
    private static string? DisabledReason(bool can, int actionsRemaining, string specificReason)
        => can ? null : actionsRemaining <= 0 ? "No actions remaining" : specificReason;

    /// <summary>
    /// Build the hover attack preview, masked for what the bestiary knows about the target. Until
    /// Recall Knowledge reveals that species' AC, the DEFENDER-derived numbers (its AC, and the hit
    /// and crit odds computed against it) render "?"; everything the attacker brings — weapon,
    /// attack bonus, damage formula, off-guard — stays visible, because the player already knows
    /// their own character sheet. Gating lives here, in plain C#; the action bar just draws text.
    /// </summary>
    internal static AttackPreviewView? BuildPreview(PlayerActionExecutor exec, ICharacter attacker, ICharacter target)
    {
        AttackPreviewData? data = exec.GetAttackPreview(attacker, target);
        if (data == null) return null;

        bool acKnown = PlayerActionExecutor.IsCreatureFieldKnown(
            data.TargetCreatureId, CreatureKnowledgeField.AC);
        int hit = (int)Math.Round(data.HitChance);
        int crit = (int)Math.Round(data.CritChance);

        return new AttackPreviewView
        {
            AttackerName = data.AttackerName,
            TargetName = data.TargetName,
            WeaponName = data.WeaponName,
            TotalAttackBonus = data.TotalAttackBonus,
            DamageFormula = data.DamageFormula ?? "",
            TargetOffGuard = data.TargetIsOffGuard,
            TargetAcText = acKnown ? data.TargetAC.ToString() : "?",
            HitChanceText = acKnown ? $"{hit}%" : "?%",
            CritChanceText = acKnown ? $"{crit}%" : "?%",
        };
    }
}
