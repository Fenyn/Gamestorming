using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Events;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// The movement half of the player action surface: Stride and Step, plus the pathfinding queries
/// the UI highlights them with. Owns the tile/speed helpers (<see cref="ReachableTiles"/>,
/// <see cref="BuildRequest"/>, <see cref="SpeedInTiles"/>) that the skill executor reuses for
/// Shielded Stride and Sudden Charge.
/// </summary>
internal sealed class MovementActions
{
    internal const int FeetPerTile = 5;

    private readonly BattleGrid _grid;
    private readonly BattleEventEmitter _events;
    private readonly StepAction _step = new();

    internal MovementActions(BattleGrid grid, BattleEventEmitter events)
    {
        _grid = grid;
        _events = events;
    }

    // ---------------------------------------------------------------- Queries

    /// <summary>Tiles reachable with a single Stride (unoccupied, creature fits).</summary>
    internal HashSet<PF2eVec> GetReachableTiles(ICharacter character)
        => ReachableTiles(character, SpeedInTiles(character));

    /// <summary>Adjacent tiles a Step can legally land on (unoccupied, fits).</summary>
    internal HashSet<PF2eVec> GetStepTiles(ICharacter character)
    {
        var result = new HashSet<PF2eVec>();
        if (character.Actions == null || character.Actions.TotalActionsRemaining <= 0)
            return result;

        foreach (var neighbor in _grid.GetNeighbors(character.GridPosition))
        {
            if (StepBlockedReason(character, neighbor) == null)
                result.Add(neighbor);
        }
        return result;
    }

    /// <summary>
    /// Why a Step to <paramref name="dest"/> is illegal ("Blocked." / "Occupied." / "Too steep."), or
    /// null when it is legal. The single source of step legality: <see cref="GetStepTiles"/> filters
    /// neighbors with it, and CombatSession installs it as the engine's StepAction.ValidateDestination.
    /// The elevation clause mirrors the engine's own StepAction gate, so a highlighted tile and an
    /// accepted Step never disagree: a Step neither scrambles up a cliff (the one-elevation rise the
    /// Pathfinder allows a Stride) nor drops off one — falling is not careful movement.
    /// </summary>
    internal string? StepBlockedReason(ICharacter actor, PF2eVec dest)
    {
        var tile = _grid.GetTile(dest);
        if (tile == null || tile.IsBlocked) return "Blocked.";
        if (!_grid.CanCreatureFit(dest, actor.TileWidth, ignore: actor)) return "Occupied.";
        if (!_grid.CanTraverseEdge(actor.GridPosition, dest)) return "Too steep.";
        if (_grid.GetEdgeStepUp(dest, actor.GridPosition) >= TileCornerHeights.FallDamageThreshold)
            return "Too steep.";
        return null;
    }

    internal List<PF2eVec>? GetPathTo(ICharacter character, PF2eVec dest)
    {
        int speed = SpeedInTiles(character);
        if (speed <= 0) return null;
        return Pathfinder.FindPath(_grid, character.GridPosition, dest, BuildRequest(character, speed));
    }

    // ---------------------------------------------------------------- Commands

    /// <summary>
    /// Stride to <paramref name="dest"/> (1 action). Mirrors AITurnExecutor.ExecuteMove EXACTLY,
    /// including the per-tile-exit movement-reaction publish (Reactive Strike). Set
    /// <paramref name="triggersReactions"/> false for reaction-free strides (Shielded Stride).
    /// </summary>
    internal async Task<bool> ExecuteStride(ICharacter character, PF2eVec dest, bool triggersReactions = true)
    {
        int speed = SpeedInTiles(character);
        if (speed <= 0) return false;

        var path = Pathfinder.FindPath(_grid, character.GridPosition, dest, BuildRequest(character, speed));
        if (path == null || path.Count < 2) return false;

        if (character.Actions == null || !character.Actions.TryConsumeActions(1))
            return false;

        // Walk-animation CUE only — deliberately carries NO Path. The per-tile MovementStep events
        // in the loop below drive the actual segment-by-segment animation so movement reactions
        // (Reactive Strike) resolve BETWEEN tiles. Emitting the whole path here would animate the
        // token to the destination before the first tile-exit prompt could appear, and a
        // reaction-cancelled stride would then teleport it back on MovementCompleted. The presenter
        // reads a pathless MovementStarted as SetMoving(true) (lowered by MovementCompleted); a
        // 2-point Path (Step / EmitPositionSync) still animates immediately as a slide.
        await _events.Emit(new BattleEvent
        {
            Type = BattleEventType.MovementStarted,
            Source = character,
            Description = $"{character.Name} Strides to ({dest.x}, {dest.y})"
        });

        for (int i = 1; i < path.Count; i++)
        {
            var from = path[i - 1];
            var to = path[i];

            var args = new BeforeMoveEventArgs(character, from, to, path.Count, path.Count * FeetPerTile);
            MovementEvents.FireBeforeMove(args);

            // Publish the AoO/Reactive-Strike check at the tile-exit point (the FROM tile the reactor
            // threatens), mirroring AITurnExecutor.ExecuteMove. Gated on an active subscriber so a
            // stride with no ReactionManager present does not throw. Awaited: an interactive reaction
            // prompt may suspend the walk here; a reaction that drops the mover (setting
            // args.Cancelled) has fully resolved when the await completes.
            if (triggersReactions && !args.Cancelled
                && ReactionEvents.HasMovementReactionSubscriber)
            {
                await ReactionEvents.CheckMovementReactions(args);
            }

            if (args.Cancelled)
            {
                _grid.MoveCreature(character, from);
                // Reconcile-only: no MovementStep ran for this tile, so the token still sits on the
                // FROM tile. MovementCompleted snaps to the authoritative GridPosition (== from) —
                // never a teleport back across the already-animated segments.
                await _events.Emit(BattleEventType.MovementCompleted, source: character,
                    description: $"{character.Name} movement interrupted!");
                return true;
            }

            _grid.MoveCreature(character, to);

            // Animate exactly this one segment now that the tile-exit reaction has resolved. The
            // 2-point Path is the animation payload; the presenter tweens from -> to without toggling
            // the walk state (raised by MovementStarted, lowered by MovementCompleted).
            await _events.Emit(new BattleEvent
            {
                Type = BattleEventType.MovementStep,
                Source = character,
                Path = new List<PF2eVec> { from, to }
            });
        }

        await _events.Emit(BattleEventType.MovementCompleted, source: character);
        return true;
    }

    /// <summary>Step to an adjacent tile (1 action, no reactions).</summary>
    internal async Task<bool> ExecuteStep(ICharacter character, PF2eVec dest)
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

        await _events.EmitPositionSync(character, from, $"{character.Name} Steps");
        return true;
    }

    // ---------------------------------------------------------------- Helpers

    /// <summary>
    /// Tiles reachable within <paramref name="maxDistance"/> where the creature can legally stand
    /// (excludes the origin and unreachable/zero-cost entries; requires an action remaining).
    /// SkillActions.FindChargeTile keeps its own map walk — it needs the per-tile costs to pick the
    /// cheapest in-reach tile and deliberately considers the origin ("already in reach: stay put").
    /// </summary>
    internal HashSet<PF2eVec> ReachableTiles(ICharacter character, int maxDistance)
    {
        var result = new HashSet<PF2eVec>();
        if (maxDistance <= 0 || character.Actions == null || character.Actions.TotalActionsRemaining <= 0)
            return result;

        var map = Pathfinder.FindReachableTiles(_grid, BuildRequest(character, maxDistance));
        foreach (var kvp in map)
        {
            var tile = kvp.Key;
            if (tile == character.GridPosition || kvp.Value.Cost <= 0) continue;
            if (!_grid.CanCreatureFit(tile, character.TileWidth, ignore: character)) continue;
            result.Add(tile);
        }
        return result;
    }

    internal static PathfindingRequest BuildRequest(ICharacter character, int maxDistance) => new()
    {
        Origin = character.GridPosition,
        MaxDistance = maxDistance,
        TileWidth = character.TileWidth,
        MaxStepUpElevations = 1,
        OriginTeamId = character.TeamId
    };

    internal static int SpeedInTiles(ICharacter character)
    {
        int feet = character.StatProvider?.BaseSpeedInFeet
                   ?? character.CreatureStats?.BaseSpeedInFeet
                   ?? 25;
        return feet / FeetPerTile;
    }
}
