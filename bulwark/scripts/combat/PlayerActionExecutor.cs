using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Executes and previews the four M1 player actions (Stride, Step, Strike, Raise a Shield).
/// The command side mirrors <c>AITurnExecutor</c>'s BattleEvent emission exactly so player and AI
/// turns animate identically through the shared <see cref="BattleRunner"/>. The query side feeds
/// the UI/controller (reachable tiles, targets, previews) with no side effects.
///
/// Plain C#: the only Godot-free dependency is the engine. Consumes actions from
/// <c>ICharacter.Actions</c> so the action bar stays in sync.
/// </summary>
public sealed class PlayerActionExecutor
{
    private const int FeetPerTile = 5;

    private readonly BattleRunner _runner;
    private readonly BattleGrid _grid;
    private readonly RaiseShieldAction _raiseShield = new();
    private readonly StepAction _step = new();

    public PlayerActionExecutor(BattleRunner runner, BattleGrid grid)
    {
        _runner = runner;
        _grid = grid;
    }

    // ---------------------------------------------------------------- Queries

    /// <summary>Tiles reachable with a single Stride (unoccupied, creature fits).</summary>
    public HashSet<PF2eVec> GetReachableTiles(ICharacter character)
    {
        var result = new HashSet<PF2eVec>();
        int speed = SpeedInTiles(character);
        if (speed <= 0 || character.Actions == null || character.Actions.TotalActionsRemaining <= 0)
            return result;

        var map = Pathfinder.FindReachableTiles(_grid, BuildRequest(character, speed));
        foreach (var kvp in map)
        {
            var tile = kvp.Key;
            if (tile == character.GridPosition) continue;
            if (kvp.Value.Cost <= 0) continue;
            if (!_grid.CanCreatureFit(tile, character.TileWidth, ignore: character)) continue;
            result.Add(tile);
        }
        return result;
    }

    /// <summary>Adjacent tiles a Step can legally land on (unoccupied, fits).</summary>
    public HashSet<PF2eVec> GetStepTiles(ICharacter character)
    {
        var result = new HashSet<PF2eVec>();
        if (character.Actions == null || character.Actions.TotalActionsRemaining <= 0)
            return result;

        foreach (var neighbor in _grid.GetNeighbors(character.GridPosition))
        {
            var tile = _grid.GetTile(neighbor);
            if (tile == null || tile.IsBlocked) continue;
            if (!_grid.CanCreatureFit(neighbor, character.TileWidth, ignore: character)) continue;
            result.Add(neighbor);
        }
        return result;
    }

    /// <summary>Living enemies within the character's weapon reach.</summary>
    public List<ICharacter> GetStrikeTargets(ICharacter character)
    {
        var targets = new List<ICharacter>();
        var registry = CombatantRegistry.Instance;
        if (registry == null) return targets;

        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        int reach = weapon.GetRangeInTiles();

        foreach (var other in registry.All)
        {
            if (other.TeamId == character.TeamId) continue;
            if (other.Health == null || other.Health.IsDead) continue;
            if (FlankingCalculator.IsWithinReach(
                character.GridPosition, character.TileWidth,
                other.GridPosition, other.TileWidth, reach))
                targets.Add(other);
        }
        return targets;
    }

    public List<PF2eVec>? GetPathTo(ICharacter character, PF2eVec dest)
    {
        int speed = SpeedInTiles(character);
        if (speed <= 0) return null;
        return Pathfinder.FindPath(_grid, character.GridPosition, dest, BuildRequest(character, speed));
    }

    public AttackPreviewData? GetAttackPreview(ICharacter attacker, ICharacter target)
    {
        if (attacker == null || target == null) return null;
        return CombatPreviewCalculator.CalculateAttackPreview(attacker, target);
    }

    /// <summary>Current MAP the character would suffer on their next Strike (0 / -4/-5 / -8/-10).</summary>
    public int GetCurrentMap(ICharacter character)
    {
        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        return character.Combat?.GetCurrentMAP(weapon.IsAgile) ?? 0;
    }

    // ---------------------------------------------------------------- Commands

    /// <summary>Stride to <paramref name="dest"/> (1 action). Mirrors AITurnExecutor.ExecuteMove.</summary>
    public async Task<bool> ExecuteStride(ICharacter character, PF2eVec dest)
    {
        int speed = SpeedInTiles(character);
        if (speed <= 0) return false;

        var path = Pathfinder.FindPath(_grid, character.GridPosition, dest, BuildRequest(character, speed));
        if (path == null || path.Count < 2) return false;

        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.MovementStarted,
            Source = character,
            Path = path,
            Description = $"{character.Name} Strides to ({dest.x}, {dest.y})"
        });

        for (int i = 1; i < path.Count; i++)
        {
            var from = path[i - 1];
            var to = path[i];

            var args = new BeforeMoveEventArgs(character, from, to, path.Count, path.Count * FeetPerTile);
            MovementEvents.FireBeforeMove(args);

            if (args.Cancelled)
            {
                _grid.MoveCreature(character, from);
                await _runner.Emit(BattleEventType.MovementCompleted, source: character,
                    description: $"{character.Name} movement interrupted!");
                return true;
            }

            _grid.MoveCreature(character, to);

            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.MovementStep,
                Source = character
            });
        }

        await _runner.Emit(BattleEventType.MovementCompleted, source: character);
        return true;
    }

    /// <summary>Step to an adjacent tile (1 action, no reactions).</summary>
    public async Task<bool> ExecuteStep(ICharacter character, PF2eVec dest)
    {
        var from = character.GridPosition;
        _step.Destination = dest;
        if (!_step.CanPerform(character))
            return false;

        // Execute consumes the action and sets GridPosition, but does NOT update grid occupancy.
        _step.Execute(character);

        // Rewind GridPosition so MoveCreature clears the *old* tile before occupying the new one.
        character.GridPosition = from;
        _grid.MoveCreature(character, dest);

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.MovementStarted,
            Source = character,
            Path = new List<PF2eVec> { from, dest },
            Description = $"{character.Name} Steps"
        });
        await _runner.Emit(BattleEventType.MovementCompleted, source: character);
        return true;
    }

    /// <summary>Strike a target (1 action). Mirrors AITurnExecutor's equipped-weapon branch.</summary>
    public async Task<bool> ExecuteStrike(ICharacter character, ICharacter target)
    {
        if (target?.Health == null || target.Health.IsDead) return false;

        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        if (!FlankingCalculator.IsWithinReach(
            character.GridPosition, character.TileWidth,
            target.GridPosition, target.TileWidth, weapon.GetRangeInTiles()))
            return false;

        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        // StrikeResolver runs its callbacks synchronously, so strikeCtx is fully resolved on return.
        StrikeContext? strikeCtx = null;
        StrikeResolver.ExecuteStrike(character, target, sourceAction: null,
            onComplete: ctx => strikeCtx = ctx);

        if (strikeCtx == null) return true;

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.AttackRolled,
            Source = character,
            Target = target,
            Degree = strikeCtx.Degree,
            Description = $"{character.Name} Strikes {target.Name} with {strikeCtx.WeaponName}: " +
                $"d20({strikeCtx.D20Roll})+{strikeCtx.EffectiveBonus}={strikeCtx.Total} vs AC {strikeCtx.TargetAC} → {strikeCtx.Degree}"
        });

        if (strikeCtx.Hit && strikeCtx.DamageResult != null)
        {
            int damage = strikeCtx.DamageResult.TotalDamage;

            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.DamageDealt,
                Source = character,
                Target = target,
                IntValue = damage,
                DamageType = strikeCtx.DamageResult.DamageType,
                Description = $"{target.Name} takes {damage} {strikeCtx.DamageResult.DamageType} damage"
            });

            if (strikeCtx.TargetKilled || target.Health.IsDead)
            {
                await _runner.Emit(new BattleEvent
                {
                    Type = BattleEventType.CreatureDied,
                    Source = target,
                    Description = $"{target.Name} is slain!"
                });
            }
        }

        return true;
    }

    /// <summary>Raise a Shield (1 action). Emits a ShieldRaised battle event on success.</summary>
    public async Task<bool> ExecuteRaiseShield(ICharacter character)
    {
        if (!_raiseShield.CanPerform(character))
            return false;

        _raiseShield.Execute(character);

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.ShieldRaised,
            Source = character,
            Description = $"{character.Name} raises a shield"
        });
        return true;
    }

    // ---------------------------------------------------------------- Helpers

    private PathfindingRequest BuildRequest(ICharacter character, int maxDistance) => new()
    {
        Origin = character.GridPosition,
        MaxDistance = maxDistance,
        TileWidth = character.TileWidth,
        MaxStepUpElevations = 1,
        OriginTeamId = character.TeamId
    };

    private static int SpeedInTiles(ICharacter character)
    {
        int feet = character.StatProvider?.BaseSpeedInFeet
                   ?? character.CreatureStats?.BaseSpeedInFeet
                   ?? 25;
        return feet / FeetPerTile;
    }
}
