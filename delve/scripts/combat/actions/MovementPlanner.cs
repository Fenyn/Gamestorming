using System.Collections.Generic;
using PF2e.Core;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Builds the <see cref="MovePlan"/> the board shows while no action is selected: one band per
/// remaining action, each a single-Stride reachability pass seeded from the previous band's
/// standable tiles, plus the adjacent Step tiles laid over band 1. Queries only; the legs it
/// yields execute through <see cref="MovementActions"/>' Stride and Step primitives.
/// </summary>
internal sealed class MovementPlanner
{
    private readonly BattleGrid _grid;
    private readonly MovementActions _movement;

    internal MovementPlanner(BattleGrid grid, MovementActions movement)
    {
        _grid = grid;
        _movement = movement;
    }

    internal MovePlan Plan(ICharacter character)
    {
        int actions = character.Actions?.TotalActionsRemaining ?? 0;
        int speed = MovementActions.SpeedInTiles(character);
        if (actions <= 0 || speed <= 0) return MovePlan.Empty;

        var options = new Dictionary<PF2eVec, MoveOption>();
        var bands = new List<Dictionary<PF2eVec, PathEntry>>();
        var banded = new HashSet<PF2eVec> { character.GridPosition };
        var seeds = new List<PF2eVec> { character.GridPosition };

        for (int band = 1; band <= actions && seeds.Count > 0; band++)
        {
            var request = MovementActions.BuildRequest(character, speed);
            request.Origin = seeds[0];
            request.Origins = seeds;
            var map = Pathfinder.FindReachableTiles(_grid, request);

            var next = new List<PF2eVec>();
            foreach (var kvp in map)
            {
                var tile = kvp.Key;
                if (kvp.Value.Cost <= 0 || banded.Contains(tile)) continue;
                // Pass-through tiles (an ally's square) stay in the map for the next band's walk but
                // are not a place to stop, so they neither band nor seed.
                if (!_grid.CanCreatureFit(tile, character.TileWidth, ignore: character)) continue;
                banded.Add(tile);
                options[tile] = new MoveOption(band, MoveKind.Stride);
                next.Add(tile);
            }
            bands.Add(map);
            seeds = next;
        }

        // A careful Step wins on any adjacent tile it is legal for: same cost, no reactions.
        foreach (var tile in _movement.GetStepTiles(character))
            options[tile] = new MoveOption(1, MoveKind.Step);

        return new MovePlan(character.GridPosition, bands, options);
    }
}
