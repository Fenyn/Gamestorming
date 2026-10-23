using System.Threading.Tasks;
using Ungilded.Combat;
using Ungilded.Story;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// One Prologue encounter as spec section 3 scripts it. <see cref="Configure"/> adjusts the setup,
/// <see cref="Arm"/> registers the hooks before the fight starts, and <see cref="Play"/> runs the
/// steps on the held turns until the result is known.
/// </summary>
internal abstract class EncounterScript
{
    protected EncounterStage S { get; private set; } = null!;

    /// <summary>Scripted fights run in setup order (party, then enemies).</summary>
    public virtual CombatSetup Configure(CombatSetup setup) => setup with { FixedInitiative = true };

    /// <summary>True ends a hero's turn at 0 actions. Encounter 1 keeps it open to teach End Turn.</summary>
    public virtual bool AutoEndTurn => true;

    public void Arm(EncounterStage stage)
    {
        S = stage;
        OnArm();
    }

    protected virtual void OnArm() { }

    public abstract Task<EncounterOutcome> Play();

    /// <summary>Wait for the result once the scripted steps are done.</summary>
    protected async Task<EncounterOutcome> Outcome()
    {
        S.Unlock();
        S.LetTurnsRun();
        await S.WaitResult();
        return S.Won ? EncounterOutcome.Victory : EncounterOutcome.Defeat;
    }

    /// <summary>Hand every turn left to <paramref name="turn"/> until the encounter ends. The handler
    /// releases the gate.</summary>
    protected async Task RunTurns(System.Func<TurnGate, Task> turn)
    {
        while (await S.NextTurn() is { } gate)
            await turn(gate);
    }
}
