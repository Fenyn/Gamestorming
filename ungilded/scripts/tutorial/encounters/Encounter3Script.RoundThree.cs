using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using PF2e.Core;
using Ungilded.Combat;
using Ungilded.Content;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial.Encounters;

/// <summary>Encounter 3's round 3 (spec section 8, tutorial pacing pass): each hero's turn opens with
/// the full menu, no target filter and no move lock. Gold tiles mark where the hero would flank a
/// living rat and refresh after every action. Every hero Strike is forced to hit, with dice chosen
/// by its target, so the PDF table's outcome holds whatever order the player picks.</summary>
internal sealed partial class Encounter3Script
{
    internal const string PlayerFreeTip = "Two rats are still up. The gold tiles flank them.";
    internal const string FriendFreeTip = "Finish the last rat. The gold tile flanks it.";

    /// <summary>The Player's Strike on Rat 5 leaves it low.</summary>
    private static readonly int[] PlayerRat5Dice = { 1 };

    /// <summary>The Friend's dagger on Rat 5, then Sneak Attack when it is off-guard to him.</summary>
    private static readonly int[] FriendRat5Dice = { 2, 3 };

    private Task PlayerRoundThree(TurnGate gate) => GuidedTurn(gate, S.Player, S.Friend, "e3_20_free", PlayerFreeTip);

    private Task FriendRoundThree(TurnGate gate)
        => GuidedTurn(gate, S.Friend, S.Player, "e3_24_free", LivingRats().Any() ? FriendFreeTip : null);

    /// <summary>Release the turn unrestricted with the order rule on, show the tip beside the
    /// command menu until a command is picked, and keep the gold flank tiles current until the turn ends.</summary>
    private async Task GuidedTurn(TurnGate gate, ICharacter hero, ICharacter partner, string id, string? text)
    {
        S.Unlock();
        S.ForceByOrder(RoundThreeRoll);
        S.Release(gate);
        var tip = text == null ? null : S.Step(id, TutorialFocus.CommandMenu.Undimmed(), text);
        try
        {
            S.HintMoveTo(FlankHints(hero, partner));
            // The menu closes as a command is picked, so the tip closes with it.
            if (tip != null && !await S.WaitUntil(hero, () => S.Scene.Controller is { Busy: true } or { Mode: not PlayerTurnMode.Idle }))
                return;
            tip?.Dispose();
            tip = null;
            while (true)
            {
                S.HintMoveTo(FlankHints(hero, partner));
                if (!await S.WaitUntil(hero, () => S.Scene.Controller is { Busy: true })) break;
                if (!await S.WaitUntil(hero, () => S.Scene.Controller is { Busy: false })) break;
            }
        }
        finally
        {
            tip?.Dispose();
            S.ForceByOrder(null);
            S.ClearMove();
        }
    }

    /// <summary>A hero Strike on a rat hits. On Rat 4 the dice kill it; on Rat 5 the Player's die
    /// leaves it low and the Friend's dagger and Sneak Attack finish it. Other orders roll live.</summary>
    private ForcedRoll? RoundThreeRoll(PlayerOrder order)
    {
        if (order.Kind != PlayerOrderKind.Strike || order.Target is not { } rat
            || S.Session.CurrentActor is not { } hero) return null;
        if (TutorialRolls.TryStrike(hero, rat, EncounterStage.Hit) is not { } d20) return null;
        bool friend = ReferenceEquals(hero, S.Friend);
        bool sneak = friend && TutorialRolls.OffGuardTo(hero, rat);
        if (ReferenceEquals(rat, _rat5))
            return new ForcedRoll(d20, friend ? FriendRat5Dice.Take(sneak ? 2 : 1).ToArray() : PlayerRat5Dice);
        return new ForcedRoll(d20, TutorialRolls.KillDice(hero, rat, sneak ? PrologueCast.FriendSneakAttackDie : 0));
    }

    private IEnumerable<ICharacter> LivingRats()
        => new[] { _rat1, _rat2, _rat3, _rat4, _rat5 }.Where(r => r.Health?.IsAlive == true);

    /// <summary>Tiles next to a living rat that the mover reaches with one Stride and that flank
    /// the rat with the partner where it stands. With none, the tiles next to a rat whose opposite
    /// is free floor, so the partner can complete the flank on its turn. (A unit's reachable tiles
    /// are empty while it has no actions, so the partner's reach cannot be asked between its turns.)</summary>
    private List<PF2eVec> FlankHints(ICharacter mover, ICharacter partner)
    {
        var reach = S.Session.PlayerActions.GetReachableTiles(mover);
        var flanks = FlankTiles(reach, far => far.Equals(partner.GridPosition));
        return flanks.Count > 0 ? flanks : FlankTiles(reach, FreeFloor);
    }

    private bool FreeFloor(PF2eVec tile)
    {
        var layout = S.Battle.Layout;
        if (tile.x < 0 || tile.y < 0 || tile.x >= layout.Width || tile.y >= layout.Height || !layout.IsWalkable(tile.x, tile.y))
            return false;
        var session = S.Session;
        return !session.Team1.Concat(session.Team2).Any(c => c.Health?.IsAlive == true && c.GridPosition.Equals(tile));
    }

    /// <summary>Reachable tiles next to a living rat whose tile on the rat's far side passes <paramref name="far"/>.</summary>
    private List<PF2eVec> FlankTiles(ICollection<PF2eVec> reach, System.Func<PF2eVec, bool> far)
    {
        var tiles = new List<PF2eVec>();
        foreach (var rat in LivingRats())
        {
            var p = rat.GridPosition;
            for (int dx = -1; dx <= 1; dx++)
                for (int dy = -1; dy <= 1; dy++)
                {
                    var tile = new PF2eVec(p.x + dx, p.y + dy);
                    if ((dx == 0 && dy == 0) || !reach.Contains(tile) || tiles.Contains(tile)) continue;
                    if (far(new PF2eVec(p.x - dx, p.y - dy))) tiles.Add(tile);
                }
        }
        return tiles;
    }
}
