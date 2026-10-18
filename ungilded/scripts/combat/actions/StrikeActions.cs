using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Utilities;

namespace Ungilded.Combat;

/// <summary>
/// The weapon half of the player action surface: Strike and Raise a Shield, plus the previews the
/// UI shows before the player commits (targets in reach, hit chance, current MAP, shield gating).
/// </summary>
internal sealed class StrikeActions
{
    private readonly BattleEventEmitter _events;
    private readonly RaiseShieldAction _raiseShield = new();

    internal StrikeActions(BattleEventEmitter events) => _events = events;

    // ---------------------------------------------------------------- Queries

    /// <summary>Living enemies within the character's weapon reach.</summary>
    internal List<ICharacter> GetStrikeTargets(ICharacter character)
    {
        if (Ungilded.Rules.WayfarerFeature.State(character).FinisherUsed) return new();
        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        int reach = weapon.GetRangeInTiles();
        return new List<ICharacter>(CombatantQuery.ScanCombatants(character, enemies: true, other =>
            FlankingCalculator.IsWithinReach(
                character.GridPosition, character.TileWidth,
                other.GridPosition, other.TileWidth, reach)));
    }

    internal AttackPreviewData? GetAttackPreview(ICharacter attacker, ICharacter target)
    {
        if (attacker == null || target == null) return null;
        return CombatPreviewCalculator.CalculateAttackPreview(attacker, target);
    }

    /// <summary>Current MAP the character would suffer on their next Strike (0 / -4/-5 / -8/-10).</summary>
    internal int GetCurrentMap(ICharacter character)
    {
        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        return character.Combat?.GetCurrentMAP(weapon.IsAgile) ?? 0;
    }

    /// <summary>Why Raise a Shield is disabled right now (engine-sourced: no shield / already raised /
    /// destroyed / not in hand), or null when it can be performed. Reuses the shared action instance
    /// so the UI never has to re-derive shield rules itself.</summary>
    internal string? GetRaiseShieldDisabledReason(ICharacter character)
        => _raiseShield.CanPerform(character) ? null : _raiseShield.GetValidationErrorMessage(character);

    // ---------------------------------------------------------------- Commands

    /// <summary>Strike a target (1 action). Mirrors AITurnExecutor's equipped-weapon branch.</summary>
    internal async Task<bool> ExecuteStrike(ICharacter character, ICharacter target)
    {
        if (target?.Health == null || target.Health.IsDead) return false;

        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        if (!FlankingCalculator.IsWithinReach(
            character.GridPosition, character.TileWidth,
            target.GridPosition, target.TileWidth, weapon.GetRangeInTiles()))
            return false;

        if (Ungilded.Rules.WayfarerFeature.State(character).FinisherUsed) return false;
        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        // Awaited: the strike Task completes when all reactions (possibly an interactive prompt,
        // e.g. the defender's Shield Block) have resolved, so strikeCtx is fully resolved after.
        StrikeContext? strikeCtx = null;
        await StrikeResolver.ExecuteStrike(character, target, sourceAction: null,
            onComplete: ctx => strikeCtx = ctx);

        if (strikeCtx != null) await EmitStrike(character, target, strikeCtx, strikeCtx.WeaponName);
        return true;
    }

    /// <summary>The index of the creature's first melee stat-block strike (0 when it has only
    /// ranged ones), or null for a character that strikes with equipment.</summary>
    internal static int? CreatureStrikeIndex(ICharacter character)
    {
        var stats = character.CreatureStats;
        if (stats == null || stats.StrikeCount == 0) return null;
        for (int i = 0; i < stats.StrikeCount; i++)
            if (stats.GetStrike(i) is { IsRanged: false }) return i;
        return 0;
    }

    /// <summary>
    /// Strike with a creature's first melee stat-block strike (1 action), as AITurnExecutor's
    /// creature branch does, for scripted enemy turns. Falls back to <see cref="ExecuteStrike"/> for
    /// a character with no stat-block strikes.
    /// </summary>
    internal async Task<bool> ExecuteCreatureStrike(ICharacter character, ICharacter target)
    {
        if (CreatureStrikeIndex(character) is not { } index || character.CreatureStats!.GetStrike(index) is not { } strike)
            return await ExecuteStrike(character, target);
        if (target?.Health == null || target.Health.IsDead) return false;
        int reach = strike.IsRanged ? strike.RangeFeet / MovementActions.FeetPerTile : strike.MeleeReachTiles;
        if (!FlankingCalculator.IsWithinReach(character.GridPosition, character.TileWidth,
                target.GridPosition, target.TileWidth, reach))
            return false;
        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        StrikeContext? strikeCtx = null;
        await StrikeResolver.ExecuteStrike(character, target, sourceAction: null,
            creatureStrikeIndex: index, onComplete: ctx => strikeCtx = ctx);
        if (strikeCtx != null) await EmitStrike(character, target, strikeCtx, strikeCtx.StrikeName ?? strikeCtx.WeaponName);
        return true;
    }

    /// <summary>The AttackRolled, DamageDealt and CreatureDied events of one resolved strike.</summary>
    private async Task EmitStrike(ICharacter character, ICharacter target, StrikeContext strikeCtx, string strikeName)
    {
        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.AttackRolled,
            Source = character,
            Target = target,
            Degree = strikeCtx.Degree,
            Description = $"{character.Name} Strikes {target.Name} with {strikeName}: " +
                $"d20({strikeCtx.D20Roll})+{strikeCtx.EffectiveBonus}={strikeCtx.Total} vs AC {strikeCtx.TargetAC} → {strikeCtx.Degree}"
        });

        if (strikeCtx.Hit && strikeCtx.DamageResult != null)
        {
            int damage = strikeCtx.DamageResult.TotalDamage;
            await _events.EmitDamageAndDeath(character, target, damage,
                type: strikeCtx.DamageResult.DamageType,
                // The strike's degree rides along so the view can style a crit (bigger red number,
                // crit spark ring, screen shake). Omitting it is what kept DamagePopup3D's crit path
                // dead for every weapon strike while spells — which always passed theirs — showed it.
                degree: strikeCtx.Degree,
                description: $"{target.Name} takes {damage} {strikeCtx.DamageResult.DamageType} damage",
                targetKilled: strikeCtx.TargetKilled);
        }
    }

    /// <summary>Raise a Shield (1 action). Emits a ShieldRaised battle event on success.</summary>
    internal async Task<bool> ExecuteRaiseShield(ICharacter character)
    {
        if (!_raiseShield.CanPerform(character))
            return false;

        _raiseShield.Execute(character);

        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.ShieldRaised,
            Source = character,
            Description = $"{character.Name} raises a shield"
        });
        return true;
    }
}
