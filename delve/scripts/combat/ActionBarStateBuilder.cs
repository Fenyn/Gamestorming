using System;
using System.Collections.Generic;
using System.Linq;
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
    /// <param name="delayBlockedReason">Why Delay is closed (the controller's acted-this-turn rule
    /// or the session's turn-order reason), null when it is open.</param>
    internal static ActionBarState Build(PlayerActionExecutor exec, ICharacter current, string? delayBlockedReason = null)
    {
        int actions = current.Actions?.TotalActionsRemaining ?? 0;

        bool canStrike = !Delve.Rules.WayfarerFeature.State(current).FinisherUsed && actions > 0 && exec.GetStrikeTargets(current).Count > 0;
        bool canRaiseShield = actions > 0 && current.Equipment?.CanRaiseShield() == true;
        bool canDelay = actions > 0 && delayBlockedReason == null;
        bool canMove = actions > 0 && exec.GetMovePlan(current).Options.Count > 0;

        var inspect = exec.GetUnitInspect(current.GridPosition);

        return new ActionBarState
        {
            ActorName = current.Name,
            ActorId = current.CreatureStats == null ? current.Id : "",
            Resources = Delve.Rules.ClassStatus.Resources(current),
            ResourcePips = Delve.Rules.ClassStatus.ResourcePips(current)
                .Select(r => new ResourcePipView(r.Name, r.Current, r.Max)).ToArray(),
            ActionsRemaining = actions,
            MaxActions = current.Actions?.MaxBaseActions ?? 3,
            CanStrike = canStrike,
            CanRaiseShield = canRaiseShield,
            HasShield = current.Equipment?.EquippedShield != null,
            CanDelay = canDelay,
            Hp = inspect?.Hp ?? 0,
            MaxHp = inspect?.MaxHp ?? 0,
            Ac = inspect?.Ac ?? 0,
            StrikeDisabledReason = DisabledReason(canStrike, actions, "No targets in reach"),
            ShieldDisabledReason = canRaiseShield ? null : exec.GetRaiseShieldDisabledReason(current),
            DelayDisabledReason = DisabledReason(canDelay, actions, delayBlockedReason ?? ""),
            MoveRestriction = actions > 0 ? exec.MoveRestriction(current) : null,
            CanMove = canMove,
            MoveDisabledReason = DisabledReason(canMove, actions, exec.MoveRestriction(current) ?? "No reachable tiles"),
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
        var preview = BuildPreview(data, ForecastModifiers.Strike(attacker, target, data.MAP));
        return HpPair(target, data.DamageMin, data.DamageMax) is { } hp
            ? preview with { Figures = preview.Figures.Append(new FigureView(HpPairCaption, hp)).ToList() }
            : preview;
    }

    /// <summary>The caption says which outcome the pair assumes: a plain hit, so a critical hit or a
    /// weakness can go lower and a resistance can stop short.</summary>
    internal const string HpPairCaption = "HP on hit";

    /// <summary>The target's HP before and after a hit, as FFT's forecast shows it: "14 → 2–9", the
    /// range from the least to the most damage of a plain hit before resistances and weaknesses.
    /// Null while its HP is masked or the attack deals none.</summary>
    internal static string? HpPair(ICharacter target, int damageMin, int damageMax)
    {
        if (target.Health == null || damageMax <= 0) return null;
        bool known = target.TeamId == 1 || PlayerActionExecutor.IsCreatureFieldKnown(
            target.CreatureStats?.CreatureId, CreatureKnowledgeField.MaxHP);
        if (!known) return null;
        int hp = target.Health.CurrentHP;
        int low = Math.Max(0, hp - damageMax), high = Math.Max(0, hp - damageMin);
        return low == high ? $"{hp} → {low}" : $"{hp} → {low}–{high}";
    }

    /// <param name="modifiers">The labelled modifier line; without it only the MAP shows.</param>
    internal static AttackPreviewView BuildPreview(AttackPreviewData data, IReadOnlyList<ModifierChip>? modifiers = null)
    {
        bool acKnown = PlayerActionExecutor.IsCreatureFieldKnown(
            data.TargetCreatureId, CreatureKnowledgeField.AC);
        int hit = (int)Math.Round(data.HitChance);
        int crit = (int)Math.Round(data.CritChance);
        string hitText = acKnown ? $"{hit}%" : "?%";
        string critText = acKnown ? $"{crit}%" : "?%";
        // Unknown AC: lead with what the attacker knows, their own attack total, instead of "?%" odds.
        var figures = acKnown
            ? new List<FigureView> { new("Hit", hitText), new("Crit", critText) }
            : new List<FigureView> { new("Attack", data.TotalAttackBonus.ToString("+0;-0;0")), new("AC", "?") };
        if (!string.IsNullOrEmpty(data.DamageFormula)) figures.Add(new("Damage", data.DamageFormula));
        modifiers ??= data.MAP < 0 ? new[] { new ModifierChip("MAP", data.MAP) } : System.Array.Empty<ModifierChip>();

        return new AttackPreviewView
        {
            Figures = figures,
            Modifiers = modifiers,
            AttackerName = data.AttackerName,
            TargetName = data.TargetName,
            WeaponName = data.WeaponName,
            TotalAttackBonus = data.TotalAttackBonus,
            DamageFormula = data.DamageFormula ?? "",
            TargetAcText = acKnown ? data.TargetAC.ToString() : "?",
            HitChanceText = hitText,
            CritChanceText = critText,
        };
    }
}
