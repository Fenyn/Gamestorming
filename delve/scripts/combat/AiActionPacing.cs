using System.Threading;
using System.Threading.Tasks;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>One pause per AI action cue, never per movement tile or damage target.</summary>
internal static class AiActionPacing
{
    internal static bool IsActionCue(BattleEventType type) => type is
        BattleEventType.MovementStarted or BattleEventType.AttackRolled or
        BattleEventType.SpellCast or BattleEventType.ActionUsed or BattleEventType.ShieldRaised;

    internal static Task Wait(BattleEvent evt, bool playerControlled, float seconds, CancellationToken token)
        => !playerControlled && IsActionCue(evt.Type) && seconds > 0
            ? Task.Delay(System.TimeSpan.FromSeconds(seconds), token) : Task.CompletedTask;
}
