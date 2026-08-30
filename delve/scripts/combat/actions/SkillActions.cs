using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// The skill / maneuver / feat-action half of the player action surface. Every chip it offers comes
/// from <see cref="SkillActionCatalog"/>, so the bar, the targeting, the gating text and the
/// dispatch all read one table. Movement-shaped feats (Shielded Stride, Sudden Charge) borrow the
/// pathfinding from <see cref="MovementActions"/>.
/// </summary>
internal sealed class SkillActions
{
    private readonly BattleGrid _grid;
    private readonly BattleEventEmitter _events;
    private readonly MovementActions _movement;

    internal SkillActions(BattleGrid grid, BattleEventEmitter events, MovementActions movement)
    {
        _grid = grid;
        _events = events;
        _movement = movement;
    }

    /// <summary>
    /// Injected per-encounter gate: has (actor, creature slug) already spent its Recall Knowledge
    /// attempt this fight? Owned by <see cref="CombatSession"/> (whose instance state dies with the
    /// encounter, which is the rule's lifetime); null = unwired, nothing filtered.
    /// </summary>
    internal Func<int, string, bool>? HasRecallAttempted { get; set; }

    // ---------------------------------------------------------------- Queries

    /// <summary>
    /// Every basic + feat-granted action chip for the action bar, with UI text and gating. Basic
    /// actions are gated by CanPerform + a legal target/exit; feat actions (Lunge, Sudden Charge,
    /// Shielded Stride) appear only when a feature grants them (FeatureHolder.GetAllGrantedActions).
    /// </summary>
    internal List<SkillEntryView> GetSkillEntries(ICharacter character)
    {
        var list = new List<SkillEntryView>();
        int actions = character.Actions?.TotalActionsRemaining ?? 0;

        foreach (var def in SkillActionCatalog.Basic)
        {
            bool hasTargets = def.Mode == SkillExecutionMode.Self
                              || GetSkillTargets(character, def.Id).Tiles.Count > 0;
            list.Add(BuildSkillEntry(character, def.Factory(), def.Id, hasTargets, actions));
        }

        // Feat-granted actions (Lunge / Sudden Charge / Shielded Stride) surface only when a feature
        // grants them. GetAllGrantedActions returns non-reaction actions from the character's active
        // features; we map each by ActionName to its chip id + targeting.
        var granted = character.Features?.GetAllGrantedActions();
        if (granted != null)
        {
            foreach (var action in granted)
            {
                string? id = SkillActionCatalog.IdForGrantedAction(action.ActionName);
                if (id == null) continue;

                bool hasTargets = SkillActionCatalog.Get(id)?.Mode == SkillExecutionMode.MoveTile
                    ? GetShieldedStrideTiles(character).Count > 0
                    : GetSkillTargets(character, id).Tiles.Count > 0;
                list.Add(BuildSkillEntry(character, action, id, hasTargets, actions));
            }
        }

        return list;
    }

    /// <summary>One action-bar chip for a skill / maneuver / feat action, with its gating text.</summary>
    private SkillEntryView BuildSkillEntry(
        ICharacter character, BaseAction action, string id, bool hasTargets, int actions)
    {
        bool castable = action.CanPerform(character) && hasTargets
                        && actions >= action.ActionCostCount;

        return new SkillEntryView
        {
            ActionId = id,
            Name = action.ActionName,
            ActionCost = action.ActionCostCount,
            CostText = $"{action.ActionCostCount}a",
            Targeting = SkillActionCatalog.Get(id)?.Kind ?? TargetingKind.SingleEnemy,
            Castable = castable,
            Description = action.Description ?? "",
            UnavailableReason = castable ? ""
                : SkillUnavailableReason(character, action, id, hasTargets, actions),
        };
    }

    /// <summary>
    /// Player-facing reason a skill chip is greyed out, mirroring the exact gates that computed
    /// Castable=false: action economy, then the action's own CanPerform (per-encounter use limits,
    /// condition restrictions, requirements — via the engine's validation message), then an empty
    /// legal-target set. Empty when the cause isn't determinable. Derived from the actor's own
    /// state only; never from bestiary-masked knowledge.
    /// </summary>
    private static string SkillUnavailableReason(
        ICharacter c, BaseAction action, string id, bool hasTargets, int actions)
    {
        if (actions < action.ActionCostCount)
            return CombatantQuery.NeedsActionsReason(action.ActionCostCount, actions);

        if (!action.CanPerform(c))
        {
            // CanPerform's use-limit gate has no message in GetValidationErrorMessage — cover it.
            if (action.HasUseLimits && c.CooldownTracker?.HasUsesRemaining(
                    action.AbilityId, action.UsesPerEncounter, action.UsesPerDay) == false)
                return "No uses left this encounter";
            string msg = action.GetValidationErrorMessage(c);
            // The engine's generic fallback explains nothing — show no reason instead.
            return msg == "Action cannot be performed" ? "" : msg ?? "";
        }

        if (!hasTargets)
        {
            var def = SkillActionCatalog.Get(id);
            return def == null ? "No valid targets in range" : def.NoTargetReason(c);
        }

        return "";
    }

    /// <summary>Legal target tiles for a skill / maneuver / feat action.</summary>
    internal TargetingPlan GetSkillTargets(ICharacter actor, string actionId)
    {
        var def = SkillActionCatalog.Get(actionId);
        var plan = new TargetingPlan { Kind = def?.Kind ?? TargetingKind.SingleEnemy };
        if (def?.RangeTiles == null) return plan;

        foreach (var t in CombatantQuery.TargetsInRange(actor, def.RangeTiles(actor), def.TargetsEnemies))
        {
            if (def.TargetFilter == null || def.TargetFilter(this, actor, t))
                plan.Tiles.Add(t.GridPosition);
        }
        return plan;
    }

    /// <summary>Tiles a Shielded Stride may reach: a normal Stride capped at half Speed (min 1 tile).</summary>
    internal HashSet<PF2eVec> GetShieldedStrideTiles(ICharacter character)
    {
        if (character.Equipment?.IsShieldRaised != true)
            return new HashSet<PF2eVec>();
        return _movement.ReachableTiles(character, ShieldedStrideAction.GetMaxDistanceTiles(character));
    }

    /// <summary>
    /// Whether Tumble Through has a legal exit tile past <paramref name="target"/>: the tile that
    /// continues the actor-to-foe straight line, one full footprint beyond.
    /// </summary>
    internal bool HasValidTumbleExit(ICharacter actor, ICharacter target)
    {
        var dir = target.GridPosition - actor.GridPosition;
        var unit = new PF2eVec(System.Math.Sign(dir.x), System.Math.Sign(dir.y));
        if (unit == PF2eVec.zero) return false;
        var exit = target.GridPosition + unit * target.TileWidth;
        var tile = _grid.GetTile(exit);
        if (tile == null || tile.IsBlocked) return false;
        var occ = _grid.GetGroundOccupant(exit);
        return occ == null || (occ.Health != null && occ.Health.IsDead);
    }

    // ---------------------------------------------------------------- Commands

    /// <summary>
    /// Perform a skill action against the target on <paramref name="tile"/>. SkillActionBase resolves
    /// synchronously and applies its own damage/healing/conditions (Prone, Frightened flow to the log
    /// via CombatLog). We emit an ActionUsed event plus HP-delta-derived Damage/Heal/Died events so the
    /// board animates without re-implementing any rules.
    /// </summary>
    internal async Task<bool> ExecuteSkillAction(ICharacter actor, string actionId, PF2eVec tile)
    {
        var action = SkillActionCatalog.Get(actionId)?.Factory();
        if (action == null) return false;

        var target = _grid.GetGroundOccupant(tile);
        if (target == null || target.Health == null || target.Health.IsDead) return false;
        if (!action.CanPerform(actor, target)) return false;

        int preHp = target.Health.CurrentHP;
        // Capture positions so board-moving maneuvers (Shove pushes the target + follow; Tumble
        // Through moves the actor) re-sync the 3D presenter after the rules resolve.
        var actorFrom = actor.GridPosition;
        var targetFrom = target.GridPosition;

        // Awaited: manipulate-trait maneuvers can provoke a (promptable) Reactive Strike, and Trip
        // crit damage can offer the target a Shield Block.
        await action.ExecuteAsync(actor, target);

        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.ActionUsed,
            Source = actor,
            Target = target,
            Description = $"{actor.Name} uses {action.ActionName} on {target.Name}"
        });

        await _events.EmitPositionSync(target, targetFrom);
        await _events.EmitPositionSync(actor, actorFrom);

        await _events.EmitHpDelta(actor, target, preHp);
        return true;
    }

    /// <summary>
    /// Execute a self-targeted action that fires immediately (Parry, Reload). The engine action owns
    /// its cost + state (parry AC bonus, reload progress); we emit an ActionUsed event for the board.
    /// </summary>
    internal async Task<bool> ExecuteSelfSkill(ICharacter actor, string actionId)
    {
        var action = SkillActionCatalog.Get(actionId)?.Factory();
        if (action == null || !action.CanPerform(actor)) return false;

        await action.ExecuteAsync(actor);

        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.ActionUsed,
            Source = actor,
            Description = $"{actor.Name} uses {action.ActionName}"
        });
        return true;
    }

    /// <summary>
    /// Shielded Stride (feat move token, reaction-free, half-Speed cap). Movement is resolved by the
    /// movement executor exactly like a normal Stride — the engine action only carries the gate + cap
    /// — so we route through ExecuteStride with triggersReactions:false (its
    /// TriggersMovementReactions marker).
    /// </summary>
    internal Task<bool> ExecuteShieldedStride(ICharacter actor, PF2eVec dest)
    {
        if (actor.Equipment?.IsShieldRaised != true) return Task.FromResult(false);
        return _movement.ExecuteStride(actor, dest, triggersReactions: false);
    }

    /// <summary>Sudden Charge against the foe occupying <paramref name="tile"/>.</summary>
    internal Task<bool> ExecuteSuddenChargeTile(ICharacter actor, PF2eVec tile)
    {
        var target = _grid.GetGroundOccupant(tile);
        if (target == null || target.Health == null || target.Health.IsDead)
            return Task.FromResult(false);
        return ExecuteSuddenCharge(actor, target);
    }

    /// <summary>
    /// Sudden Charge (2 actions, Flourish): Stride twice, then Strike a foe in reach. The engine
    /// action handles the 2-action cost, Flourish marking and the Strike, but expects the actor to
    /// have already moved (it strikes only if already within reach). So we first reposition the actor
    /// adjacent to the target (via pathfind, no action cost — the cost belongs to SuddenChargeAction),
    /// emit a position-sync move, then run Execute which resolves the Strike.
    /// </summary>
    internal async Task<bool> ExecuteSuddenCharge(ICharacter actor, ICharacter target)
    {
        var action = new SuddenChargeAction();
        if (!action.CanPerform(actor, target)) return false;
        if (target.Health == null || target.Health.IsDead) return false;

        var weapon = WeaponAttackCalculator.ResolveWeapon(actor);
        int reach = weapon.IsMelee ? weapon.GetRangeInTiles() : 1;

        var from = actor.GridPosition;
        var dest = FindChargeTile(actor, target, reach);
        if (dest.HasValue && dest.Value != from)
        {
            _grid.MoveCreature(actor, dest.Value);
            await _events.EmitPositionSync(actor, from);
        }

        int preHp = target.Health.CurrentHP;
        // Consumes 2 actions, marks Flourish, strikes if in reach. Awaited: the strike may prompt.
        await action.ExecuteAsync(actor, target);

        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.ActionUsed,
            Source = actor,
            Target = target,
            Description = $"{actor.Name} charges {target.Name}"
        });

        await _events.EmitHpDelta(actor, target, preHp);
        return true;
    }

    /// <summary>A tile within melee <paramref name="reach"/> of the target, reachable within 2x Speed.</summary>
    private PF2eVec? FindChargeTile(ICharacter actor, ICharacter target, int reach)
    {
        int span = MovementActions.SpeedInTiles(actor) * 2;
        if (span <= 0) return null;

        var map = Pathfinder.FindReachableTiles(_grid, MovementActions.BuildRequest(actor, span));
        PF2eVec? best = null;
        int bestCost = int.MaxValue;
        foreach (var kvp in map)
        {
            var tile = kvp.Key;
            if (!_grid.CanCreatureFit(tile, actor.TileWidth, ignore: actor)) continue;
            if (!FlankingCalculator.IsWithinReach(tile, actor.TileWidth,
                    target.GridPosition, target.TileWidth, reach))
                continue;
            if (kvp.Value.Cost < bestCost)
            {
                bestCost = kvp.Value.Cost;
                best = tile;
            }
        }
        // Already in reach (or nothing better found): stay put.
        return best;
    }
}
