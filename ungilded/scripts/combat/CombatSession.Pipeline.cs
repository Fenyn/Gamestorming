using System.Threading;
using System.Threading.Tasks;
using PF2e.Core;

namespace Ungilded.Combat;

/// <summary>Turn ends and HP changes on the battle event stream. The runner watches every combatant's
/// HP (SubscribeCharacter), and plays what no executor presents at the next flush.</summary>
public sealed partial class CombatSession
{
    /// <summary>
    /// End the current turn. Its end-of-turn effects (a persistent damage tick) play and can decide
    /// the encounter before the next creature's start-of-turn effects run; a death at that turn start
    /// (a failed recovery check) can decide it too. True when the encounter ended.
    /// </summary>
    private async Task<bool> EndTurnAsync(CancellationToken cancellationToken)
    {
        _turnManager.FinishTurn();
        await _runner.FlushAsync();
        if (await EndIfDecided(cancellationToken))
            return true;
        _turnManager.AdvanceTurn();
        await _runner.FlushAsync();
        return await EndIfDecided(cancellationToken);
    }

    /// <summary>Mark the HP change an event shows as presented, for an event the scene plays outside
    /// the runner, so the next flush does not play it again.</summary>
    public void ClaimPresented(BattleEvent evt) => _runner?.Claim(evt);
}
