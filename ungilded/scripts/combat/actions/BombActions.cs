using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>Keys a bomb's DamageDealt events carry in <see cref="BattleEvent.Extra"/>, for the log
/// line and the floater.</summary>
internal static class BombEventKeys
{
    /// <summary>Direct damage before splash and weakness (int). Primary target only.</summary>
    internal const string Direct = "bomb_direct";

    /// <summary>Splash damage before weakness (int).</summary>
    internal const string Splash = "bomb_splash";

    /// <summary>Weakness added on top (int).</summary>
    internal const string Weakness = "bomb_weakness";

    /// <summary>True on a creature the splash alone reached.</summary>
    internal const string SplashOnly = "bomb_splash_only";

    /// <summary>A word the floater shows before the number (string).</summary>
    internal const string PopupLabel = "popup_label";

    /// <summary>True on a bomb throw's AttackRolled. The presenter flies the flask before the damage.</summary>
    internal const string Thrown = "bomb_thrown";
}

/// <summary>
/// Alchemical bombs on the player action surface: one Abilities entry per carried bomb, the foes in
/// range, the splash preview and the throw. The throw itself is the engine's
/// <see cref="ThrowBombAction"/>; this turns its <see cref="BombThrowResult"/> into board events.
/// </summary>
internal sealed class BombActions
{
    internal const string IdPrefix = "bomb:";
    private const string SplashWord = "Splash";

    private readonly BattleEventEmitter _events;

    internal BombActions(BattleEventEmitter events) => _events = events;

    internal static bool IsBombId(string id) => id.StartsWith(IdPrefix, StringComparison.Ordinal);

    internal static string IdFor(BombDefinition bomb) => IdPrefix + bomb.Id;

    /// <summary>The throw action for the bomb this entry id names, when the actor carries it.</summary>
    internal static ThrowBombAction? Resolve(ICharacter actor, string id)
        => IsBombId(id) ? ThrowBombAction.CreateForCarriedBombs(actor).FirstOrDefault(a => IdFor(a.Bomb) == id) : null;

    /// <summary>One entry per bomb the actor carries, with the count left as its badge.</summary>
    internal List<SkillEntryView> GetEntries(ICharacter actor)
    {
        var list = new List<SkillEntryView>();
        int actions = actor.Actions?.TotalActionsRemaining ?? 0;
        foreach (var action in ThrowBombAction.CreateForCarriedBombs(actor))
        {
            string id = IdFor(action.Bomb);
            int left = action.GetBombsRemaining(actor);
            bool hasTargets = GetTargets(actor, action).Count > 0;
            bool castable = action.CanPerform(actor) && hasTargets;
            list.Add(new SkillEntryView
            {
                ActionId = id,
                IsCharacterAbility = true,
                Name = action.ActionName,
                ActionCost = action.ActionCostCount,
                CostText = $"{action.ActionCostCount}a",
                Targeting = TargetingKind.SingleEnemy,
                Castable = castable,
                BadgeText = $"[x{left}]",
                Description = Describe(action.Bomb),
                UnavailableReason = castable ? "" : UnavailableReason(actor, action, left, actions, hasTargets),
            });
        }
        return list;
    }

    private static string UnavailableReason(ICharacter actor, ThrowBombAction action, int left, int actions, bool hasTargets)
    {
        if (left <= 0) return action.GetValidationErrorMessage(actor);
        if (actions < action.ActionCostCount) return CombatantQuery.NeedsActionsReason(action.ActionCostCount, actions);
        return hasTargets ? "" : "No foes in range";
    }

    /// <summary>"1 acid, 1d6 persistent acid, 1 acid splash. Range 20 ft."</summary>
    internal static string Describe(BombDefinition bomb)
    {
        string type = bomb.DamageType.ToString().ToLowerInvariant();
        var parts = new List<string> { $"{bomb.Damage} {type}" };
        if (bomb.HasPersistentDamage)
            parts.Add($"{bomb.PersistentDamage} persistent {bomb.PersistentDamageType.ToString().ToLowerInvariant()}");
        if (bomb.HasSplash) parts.Add($"{bomb.SplashDamage} {type} splash");
        return $"{string.Join(", ", parts)}. Range {bomb.RangeFeet} ft.";
    }

    /// <summary>Living foes within the bomb's range.</summary>
    internal static List<ICharacter> GetTargets(ICharacter actor, ThrowBombAction action)
        => CombatantQuery.ScanCombatants(actor, enemies: true, t => action.IsInRange(actor, t)).ToList();

    /// <summary>The tiles of every creature a bomb landing on <paramref name="primary"/> would splash.</summary>
    internal static HashSet<PF2eVec> SplashTiles(ICharacter primary)
    {
        var tiles = new HashSet<PF2eVec>();
        foreach (var creature in ThrowBombAction.GetSplashArea(primary))
            tiles.UnionWith(CreatureTargetTiles.For(creature));
        return tiles;
    }

    /// <summary>The hover forecast: the bomb's attack against the target, as a Strike preview.</summary>
    internal static AttackPreviewView? GetPreview(ICharacter actor, ThrowBombAction action, ICharacter target)
    {
        var data = CombatPreviewCalculator.CalculateAttackPreview(actor, target, new WeaponInstance(action.Bomb.ToWeaponDefinition(null)));
        return data == null ? null : ActionBarStateBuilder.BuildPreview(data);
    }

    /// <summary>Throw the bomb (1 action), then play the roll, the direct hit and every splash.</summary>
    internal async Task<bool> ExecuteThrow(ICharacter actor, string id, ICharacter target)
    {
        var action = Resolve(actor, id);
        if (action == null || target.Health == null || target.Health.IsDead || !action.CanPerform(actor, target)) return false;

        var hpBefore = ThrowBombAction.GetSplashArea(target)
            .Where(c => c.Health != null).ToDictionary(c => c, c => c.Health.CurrentHP);
        var result = await action.ThrowAsync(actor, target);
        if (result == null) return false;
        if (result.Cancelled) return true;

        var thrown = new BattleEvent
        {
            Type = BattleEventType.AttackRolled,
            Source = actor,
            Target = target,
            Degree = result.Degree,
            Description = $"{actor.Name} throws {action.Bomb.Name} at {target.Name} → {result.Degree}",
        };
        thrown.Set(BombEventKeys.Thrown, true);
        await _events.Emit(thrown);

        await EmitDamage(actor, target, result, hpBefore, primary: true, direct: result.Hit ? result.DirectDamageAmount : 0);
        foreach (var splash in result.Splash)
            await EmitDamage(actor, splash.Creature, result, hpBefore, primary: false, direct: 0);
        return true;
    }

    private async Task EmitDamage(ICharacter actor, ICharacter creature, BombThrowResult result,
        IReadOnlyDictionary<ICharacter, int> hpBefore, bool primary, int direct)
    {
        if (creature.Health == null || !hpBefore.TryGetValue(creature, out int before)) return;
        int lost = before - creature.Health.CurrentHP;
        if (lost <= 0) return;
        int splash = primary ? result.PrimarySplashAmount : result.Bomb.SplashDamage;
        int weakness = creature.DefenseProfile?.GetWeakness(result.DamageType) ?? 0;
        bool splashOnly = direct == 0;
        var evt = new BattleEvent
        {
            Type = BattleEventType.DamageDealt,
            Source = actor,
            Target = creature,
            IntValue = lost,
            DamageType = result.DamageType,
            Degree = splashOnly ? null : result.Degree,
            Description = $"{creature.Name} takes {lost} {result.DamageType} damage",
        };
        evt.Set(BombEventKeys.Direct, direct);
        evt.Set(BombEventKeys.Splash, splash);
        evt.Set(BombEventKeys.Weakness, weakness);
        evt.Set(BombEventKeys.SplashOnly, splashOnly);
        if (splashOnly) evt.Set(BombEventKeys.PopupLabel, SplashWord);
        // No Damage reference: the event claims every HP loss the throw left on this creature, and
        // the runner follows a kill with its CreatureDied.
        await _events.Emit(evt);
    }
}
