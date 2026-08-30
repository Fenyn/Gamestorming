using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// The single BattleEvent seam for the player action executors. It owns the
/// <see cref="BattleRunner"/> and holds the emission patterns that more than one executor needs
/// (damage + death, HP deltas, position syncs), so player turns animate exactly like
/// <c>AITurnExecutor</c>'s turns.
/// </summary>
internal sealed class BattleEventEmitter
{
    private readonly BattleRunner _runner;

    internal BattleEventEmitter(BattleRunner runner) => _runner = runner;

    /// <summary>Emit one prepared event to the presenter.</summary>
    internal Task Emit(BattleEvent evt) => _runner.Emit(evt);

    /// <summary>Emit a simple event that carries only a type, actors and a log line.</summary>
    internal Task Emit(BattleEventType type, ICharacter? source = null,
        ICharacter? target = null, string? description = null)
        => _runner.Emit(type, source, target, description);

    /// <summary>
    /// Emit the shared DamageDealt → CreatureDied pair every damage source funnels through (strikes,
    /// spell outcomes, HP-delta skills). The optional <paramref name="description"/> preserves each
    /// caller's exact log text; the default is the plain HP-delta line. <paramref name="targetKilled"/>
    /// lets the strike path honor its StrikeContext.TargetKilled latch in addition to Health.IsDead.
    /// </summary>
    internal async Task EmitDamageAndDeath(ICharacter source, ICharacter target, int damage,
        DamageType? type = null, DegreeOfSuccess? degree = null, string? description = null,
        bool targetKilled = false)
    {
        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.DamageDealt,
            Source = source,
            Target = target,
            IntValue = damage,
            DamageType = type,
            Degree = degree,
            Description = description ?? $"{target.Name} takes {damage} damage"
        });

        if (targetKilled || target.Health?.IsDead == true)
        {
            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.CreatureDied,
                Source = target,
                Description = $"{target.Name} is slain!"
            });
        }
    }

    /// <summary>
    /// Emit Damage/Died or Healed events from a target's HP delta since <paramref name="preHp"/> —
    /// the animation seam for engine actions that apply their own damage/healing internally
    /// (skill actions, Sudden Charge). No delta, no events.
    /// </summary>
    internal async Task EmitHpDelta(ICharacter actor, ICharacter target, int preHp)
    {
        if (target.Health == null)
            return;

        int delta = preHp - target.Health.CurrentHP;
        if (delta > 0)
        {
            await EmitDamageAndDeath(actor, target, delta);
        }
        else if (delta < 0)
        {
            await _runner.Emit(new BattleEvent
            {
                Type = BattleEventType.Healed,
                Source = actor,
                Target = target,
                IntValue = -delta,
                Description = $"{target.Name} heals {-delta} HP"
            });
        }
    }

    /// <summary>
    /// Emit the presenter's move pair for a completed position change (Step, forced movement, tumble,
    /// charge). Emits a MovementStarted (2-point path for a slide) + MovementCompleted only when the
    /// tile actually changed, so UnitVisual3D lands on the new GridPosition.
    /// </summary>
    internal async Task EmitPositionSync(ICharacter character, PF2eVec from, string? description = null)
    {
        if (character.GridPosition == from) return;

        await _runner.Emit(new BattleEvent
        {
            Type = BattleEventType.MovementStarted,
            Source = character,
            Path = new List<PF2eVec> { from, character.GridPosition },
            Description = description ?? $"{character.Name} moves"
        });
        await _runner.Emit(BattleEventType.MovementCompleted, source: character);
    }
}
