using System.Linq;
using System.Threading.Tasks;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial.Encounters;

/// <summary>Encounter 3's rat turns and the board helpers they use. Past round 2 the rats pass.</summary>
internal sealed partial class Encounter3Script
{
    private Task EnemyTurn(TurnGate turn)
    {
        var rat = turn.Unit;
        var script = turn.Round switch
        {
            1 => RoundOneRat(rat),
            2 => RoundTwoRat(rat),
            _ => new ScriptedTurn().EndTurn(),
        };
        S.Hooks.ScriptEnemyTurn(rat, turn.Round, script);
        S.Release(turn);
        return Task.CompletedTask;
    }

    /// <summary>Rats 1 and 2 bite the Player and miss, Rat 3 steps forward (its persistent acid then
    /// ticks for 4), Rat 4 bites the Friend for 2 and bleeds him, Rat 5 creeps up.</summary>
    private ScriptedTurn RoundOneRat(ICharacter rat)
    {
        var script = new ScriptedTurn();
        if (ReferenceEquals(rat, _rat1) || ReferenceEquals(rat, _rat2))
        {
            if (!EncounterStage.Adjacent(rat, S.Player) && S.ApproachTile(rat, S.Player) is { } tile)
                script.StrideTo(tile, provokes: false);
            S.Force(TutorialRolls.Strike(rat, S.Player, EncounterStage.Miss));
            return script.Strike(S.Player).EndTurn();
        }
        if (ReferenceEquals(rat, _rat3))
        {
            S.Force(System.Array.Empty<int>(), 4);
            return script.StrideTo(Offset(_rat3Anchor, 0, 1), provokes: false).EndTurn();
        }
        if (ReferenceEquals(rat, _rat4))
        {
            if (S.ApproachTile(rat, S.Friend, prefer: Offset(_rat3Anchor, 1, 0)) is { } tile)
                script.StrideTo(tile, provokes: false);
            S.Force(TutorialRolls.Strike(rat, S.Friend, EncounterStage.Hit), 1);
            return script.Strike(S.Friend).EndTurn();
        }
        return script.StrideTo(Offset(_rat5Anchor, 1, 0), provokes: false).EndTurn();
    }

    /// <summary>Rat 4 moves between the heroes and misses the Friend; Rat 5 stops short of both.</summary>
    private ScriptedTurn RoundTwoRat(ICharacter rat)
    {
        var script = new ScriptedTurn();
        if (ReferenceEquals(rat, _rat4))
        {
            var between = BetweenHeroes();
            if (S.ApproachTile(rat, S.Player, prefer: between) is { } tile) script.StrideTo(tile, provokes: false);
            var target = between != null ? S.Friend : S.Player;
            S.Force(TutorialRolls.Strike(rat, target, EncounterStage.Miss));
            return script.Strike(target).EndTurn();
        }
        if (ReferenceEquals(rat, _rat5))
            return script.StrideTo(Offset(_rat5Anchor, 2, -1), provokes: false).EndTurn();
        return script.EndTurn();
    }

    /// <summary>The free tile next to both heroes, where Rat 4 stands flanked for round 3.</summary>
    private PF2eVec? BetweenHeroes()
    {
        var reachable = S.Session.PlayerActions.GetReachableTiles(_rat4);
        return reachable.Where(t => Touches(t, S.Player.GridPosition) && Touches(t, S.Friend.GridPosition))
            .Cast<PF2eVec?>().FirstOrDefault();
    }

    private static PF2eVec Offset(PF2eVec tile, int dx, int dy) => new(tile.x + dx, tile.y + dy);

    private static bool Touches(PF2eVec a, PF2eVec b)
        => System.Math.Max(System.Math.Abs(a.x - b.x), System.Math.Abs(a.y - b.y)) == 1;
}
