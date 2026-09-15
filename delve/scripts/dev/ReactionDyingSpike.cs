using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Combat;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the WP4 reaction / dying / forced-movement integration. Each scenario
/// builds a fresh <see cref="CombatSession"/> (real wiring: grid, registry, spatial delegates, and a
/// live <see cref="ReactionManager"/> — NO pass-through damage handler), exercises one behaviour, and
/// tears the session down so statics never leak. Prints per-check PASS/FAIL and a SPIKE RESULT line.
///
/// Checks: (1) Shield Block reduces delivered damage by the shield's hardness and consumes the
/// reaction (vs an unraised control); (2) a foe striding out of the Veteran's reach provokes a
/// Reactive Strike; (3) a PC dropped to 0 HP becomes Dying + Unconscious (not dead) while an ally
/// stays up; (4) with every PC down the session reports defeat and ends; (5) Shove displaces a goblin
/// and grid occupancy updates; (6) ForcedMovementExecutor is installed against the session grid.
/// </summary>
public partial class ReactionDyingSpike : SpikeBase
{
    protected override string Banner => "==================== REACTION / DYING SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        await Check1_ShieldBlock(data);
        await Check2_ReactiveStrike(data);
        await Check3_DyingNotDead(data);
        await Check4_DefeatWhenAllDown(data);
        await Check5_ShoveDisplaces(data);
        Check6_ForcedMovementInstalled(data);
        await Check7_ReactionPresentationAndInterruption(data, playerMover: false);
        await Check7_ReactionPresentationAndInterruption(data, playerMover: true);
        await Check8_AiStopsQueuedActions(data);
    }

    // ── (1) Shield Block reduces damage by hardness + consumes the reaction ──

    private async Task Check1_ShieldBlock(DataManager data)
    {
        GD.Print("-------------------- (1) Shield Block --------------------");
        var raised = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var control = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        var (session, _) = StartSession(data,
            party: new() { (raised, new PF2eVec(5, 5)), (control, new PF2eVec(5, 7)) },
            enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: 42);
        try
        {
            raised.Equipment.RaiseShield(raised);
            Check("(1) test shield is raised", raised.Equipment.IsShieldRaised);
            Check("(1) control shield is NOT raised", control.Equipment?.IsShieldRaised != true);

            int hardness = raised.Equipment.EquippedShield?.Hardness ?? 0;
            Check("(1) shield has non-zero hardness", hardness > 0);

            int raisedHpBefore = raised.Health.CurrentHP;
            int controlHpBefore = control.Health.CurrentHP;

            // Identical fixed physical hit to each. With no prompt handler wired, the session's
            // policy auto-uses Shield Block for the raised veteran; the control cannot block.
            await ReactionEvents.DeliverDamage(goblin, raised, Physical(10));
            await ReactionEvents.DeliverDamage(goblin, control, Physical(10));

            int raisedTaken = raisedHpBefore - raised.Health.CurrentHP;
            int controlTaken = controlHpBefore - control.Health.CurrentHP;

            Check("(1) control takes full 10 damage (no block)", controlTaken == 10);
            Check($"(1) raised takes 10-hardness={10 - hardness} (blocked {hardness})",
                raisedTaken == 10 - hardness);
            Check("(1) Shield Block consumed the reaction", raised.Actions.ReactionAvailable == false);

            // Second hit same round: reaction spent → no block, full damage.
            int mid = raised.Health.CurrentHP;
            await ReactionEvents.DeliverDamage(goblin, raised, Physical(10));
            Check("(1) second hit unblocked (reaction spent)", mid - raised.Health.CurrentHP == 10);
        }
        finally { session.Teardown(); }
    }

    // ── (2) Reactive Strike provokes when a foe strides out of reach ──

    private async Task Check2_ReactiveStrike(DataManager data)
    {
        GD.Print("-------------------- (2) Reactive Strike --------------------");
        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        var (session, _) = StartSession(data,
            party: new() { (veteran, new PF2eVec(5, 5)) },
            enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: 7);
        try
        {
            bool hasReactiveStrike = veteran.Features?.GetFeatureById("reactive-strike") != null;
            Check("(2) Veteran has Reactive Strike (core fighter feature)", hasReactiveStrike);

            int strikesAtGoblin = 0;
            Action<StrikeStatEvent> obs = e => { if (e.Target == goblin) strikesAtGoblin++; };
            StrikeResolver.OnStrikeResolved += obs;
            try
            {
                bool reactionBefore = veteran.Actions.ReactionAvailable;

                // Goblin Strides out of the square the Veteran threatens: publish the movement-reaction
                // check exactly as PlayerActionExecutor.ExecuteStride / AITurnExecutor.ExecuteMove do.
                var from = goblin.GridPosition;              // (6,5) — threatened by the Veteran at (5,5)
                var to = new PF2eVec(7, 5);                   // striding away
                var args = new BeforeMoveEventArgs(goblin, from, to, 2, 10);
                MovementEvents.FireBeforeMove(args);
                if (ReactionEvents.HasMovementReactionSubscriber)
                    await ReactionEvents.CheckMovementReactions(args);

                Check("(2) reaction was available before the stride", reactionBefore);
                Check("(2) striding out of reach provoked a Reactive Strike", strikesAtGoblin >= 1);
                Check("(2) the Reactive Strike consumed the reaction",
                    veteran.Actions.ReactionAvailable == false);
            }
            finally { StrikeResolver.OnStrikeResolved -= obs; }
        }
        finally { session.Teardown(); }
    }

    // ── (3) A PC dropped to 0 HP is Dying + Unconscious, not dead; the ally stays up ──

    private async Task Check3_DyingNotDead(DataManager data)
    {
        GD.Print("-------------------- (3) Dying, not dead --------------------");
        var down = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var ally = PresetCharacters.BuildRecruit(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);

        var (session, _) = StartSession(data,
            party: new() { (down, new PF2eVec(5, 5)), (ally, new PF2eVec(5, 7)) },
            enemies: new() { (goblin, new PF2eVec(9, 9)) }, seed: 3);
        try
        {
            // Non-critical hit that drops the veteran straight to 0 HP (shield down → full damage).
            await ReactionEvents.DeliverDamage(goblin, down,
                new DamageResult { TotalDamage = down.Health.MaxHP, DamageType = DamageType.Slashing });

            Check("(3) downed PC is at 0 HP", down.Health.CurrentHP == 0);
            Check("(3) downed PC has Dying", down.Conditions.HasCondition(Condition.Dying));
            Check("(3) downed PC is Unconscious", down.Conditions.HasCondition(Condition.Unconscious));
            Check("(3) downed PC is NOT dead", !down.Health.IsDead);
            // Encounter must NOT be lost: the ally is still conscious and able (proxy for
            // EvaluateEncounter == InProgress, which gates defeat on ALL PCs being down).
            Check("(3) ally stays conscious and alive → encounter continues",
                ally.Health.IsAlive && ally.Conditions.HasCondition(Condition.Unconscious) != true);
        }
        finally { session.Teardown(); }
    }

    // ── (4) With every PC down, the session reports defeat and ends ──

    private async Task Check4_DefeatWhenAllDown(DataManager data)
    {
        GD.Print("-------------------- (4) Defeat when all down --------------------");
        // A lone, badly wounded PC that just stands there (auto-ends its turns) versus three goblins.
        // The goblins down it; the session's per-turn gate must then report Team2Wins (defeat), even
        // though the PC is dying/unconscious rather than slain.
        var pc = PresetCharacters.BuildRecruit(level: 1, teamId: 1);
        var g1 = MakeGoblin(data);
        var g2 = MakeGoblin(data);
        var g3 = MakeGoblin(data);

        var (session, _) = StartSession(data,
            party: new() { (pc, new PF2eVec(4, 4)) },
            enemies: new()
            {
                (g1, new PF2eVec(5, 4)), (g2, new PF2eVec(4, 5)), (g3, new PF2eVec(5, 5)),
            },
            seed: 1234, registerNow: false);
        try
        {
            // Wound the PC to a sliver so the goblins finish it quickly and deterministically.
            pc.Health.TakeDamage(new DamageResult
            {
                TotalDamage = pc.Health.MaxHP - 1, DamageType = DamageType.Slashing
            });

            BattleResult result = BattleResult.InProgress;
            session.EncounterFinished += r => result = r;
            // The PC is player-controlled; auto-end its turns so the loop advances to the AI goblins.
            session.PlayerTurnStarted += _ => session.RequestEndPlayerTurn();

            await session.RunAsync();

            bool down = pc.Health.IsDead || pc.Conditions.HasCondition(Condition.Unconscious);
            Check("(4) the lone PC ends the fight down (dying/unconscious/dead)", down);
            Check("(4) session reports DEFEAT (Team2Wins)", result == BattleResult.Team2Wins);
        }
        finally { session.Teardown(); }
    }

    // ── (5) Shove displaces a goblin one tile and grid occupancy updates ──

    private async Task Check5_ShoveDisplaces(DataManager data)
    {
        GD.Print("-------------------- (5) Shove displaces --------------------");
        // The Recruit has a free hand (no shield) so it can Shove; loop seeds until a push lands
        // (Athletics vs Fortitude is a check, like the Trip scenario in the spell spike).
        bool pushed = false;
        foreach (int seed in new[] { 1, 2, 3, 7, 11, 42, 100, 5, 9, 13 })
        {
            var recruit = PresetCharacters.BuildRecruit(level: 2, teamId: 1);
            var goblin = MakeGoblin(data);
            var (session, exec) = StartSession(data,
                party: new() { (recruit, new PF2eVec(5, 5)) },
                enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: seed);
            try
            {
                recruit.Actions.RefillActions();
                var before = goblin.GridPosition;
                await exec.ExecuteSkillAction(recruit, "shove", goblin.GridPosition);
                if (goblin.GridPosition != before)
                {
                    // The goblin is registered at its new tile; it no longer occupies the old tile.
                    // (The old tile may now hold the Recruit, who follows into the vacated space — the
                    // Shove free-follow — so we assert the goblin left it, not that it is empty.)
                    bool occupancyOk = session.Grid.GetGroundOccupant(goblin.GridPosition) == goblin
                                       && session.Grid.GetGroundOccupant(before) != goblin;
                    Check("(5) Shove pushed the goblin at least one tile", true);
                    Check("(5) grid occupancy updated (goblin at new tile, left the old tile)", occupancyOk);
                    pushed = true;
                    break;
                }
            }
            finally { session.Teardown(); }
        }
        Check("(5) a Shove eventually landed across the seed sweep", pushed);
    }

    // ── (6) ForcedMovementExecutor is installed against the session grid ──

    private void Check6_ForcedMovementInstalled(DataManager data)
    {
        GD.Print("-------------------- (6) Forced-movement install --------------------");
        // No preset ships a push-strike rider, so we assert the executor is wired to THIS session's
        // grid via a direct displacement call (a rider's OnPushRequested routes through the same path).
        var recruit = PresetCharacters.BuildRecruit(level: 2, teamId: 1);
        var goblin = MakeGoblin(data);
        var (session, _) = StartSession(data,
            party: new() { (recruit, new PF2eVec(5, 5)) },
            enemies: new() { (goblin, new PF2eVec(6, 5)) }, seed: 8);
        try
        {
            Check("(6) ForcedMovementExecutor.Grid is the session grid",
                ReferenceEquals(ForcedMovementExecutor.Grid, session.Grid));

            var before = goblin.GridPosition;
            int moved = ForcedMovementExecutor.Execute(recruit, goblin, 1);
            Check("(6) direct forced-movement displaces on the installed grid",
                moved == 1 && goblin.GridPosition != before
                && session.Grid.GetGroundOccupant(goblin.GridPosition) == goblin);
        }
        finally { session.Teardown(); }

        // After teardown the executor is uninstalled/cleared (no leak into the next scene).
        Check("(6) teardown clears ForcedMovementExecutor.Grid", ForcedMovementExecutor.Grid == null);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private (CombatSession session, PlayerActionExecutor exec) StartSession(
        DataManager data,
        List<(ICharacter, PF2eVec)> party,
        List<(ICharacter, PF2eVec)> enemies,
        int seed,
        bool registerNow = true)
    {
        var setup = new CombatSetup { GridWidth = 16, GridHeight = 14, RngSeed = seed };
        setup.Party.AddRange(party);
        setup.Enemies.AddRange(enemies);

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        // Scenarios that don't run the turn loop must register combatants themselves (the registry
        // otherwise fills during TurnManager.StartEncounter). RunAsync scenarios pass registerNow:false.
        if (registerNow)
        {
            foreach (var (c, _) in party) CombatantRegistry.Instance.Register(c);
            foreach (var (c, _) in enemies) CombatantRegistry.Instance.Register(c);
        }

        return (session, session.PlayerActions);
    }

    private ICharacter MakeGoblin(DataManager data)
    {
        var def = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        return CreatureFactory.Create(def, teamId: 2);
    }

    private async Task Check7_ReactionPresentationAndInterruption(DataManager data, bool playerMover)
    {
        string label = playerMover ? "downed player" : "slain enemy";
        ICharacter mover = playerMover ? PresetCharacters.BuildElara(5) : MakeGoblin(data);
        var reactor = PresetCharacters.BuildPlayer(2, teamId: playerMover ? 2 : 1);
        var ally = PresetCharacters.BuildTharr(2);
        var from = new PF2eVec(6, 5);
        var party = new List<(ICharacter, PF2eVec)> { (ally, new PF2eVec(2, 2)) };
        var enemies = new List<(ICharacter, PF2eVec)>();
        (playerMover ? party : enemies).Add((mover, from));
        (playerMover ? enemies : party).Add((reactor, new PF2eVec(5, 5)));
        var (session, exec) = StartSession(data, party, enemies, seed: 27);
        var releaseAttack = new TaskCompletionSource();
        var turnEnded = new TaskCompletionSource();
        var seen = new List<BattleEvent>();
        try
        {
            await ReactionEvents.DeliverDamage(reactor, mover, Physical(mover.Health.CurrentHP - 1));
            mover.Actions.RefillActions();
            session.SetPresenter(async evt =>
            {
                seen.Add(evt);
                if (evt.Type == BattleEventType.AttackRolled) await releaseAttack.Task;
            });
            DiceRoller.EnqueueD20(20);
            Task action;
            PlayerTurnController? controller = null;
            if (playerMover)
            {
                controller = new PlayerTurnController(exec);
                controller.EndTurnRequested += () => turnEnded.TrySetResult();
                controller.BeginTurn(mover);
                controller.TileClicked(new PF2eVec(10, 5));
                action = turnEnded.Task;
            }
            else action = exec.ExecuteStride(mover, new PF2eVec(10, 5));

            Check($"(7 {label}) reactor receives attack animation event",
                seen.Exists(e => e.Type == BattleEventType.AttackRolled && e.Source == reactor && e.Target == mover));
            Check($"(7 {label}) action waits for reaction animation", !action.IsCompleted && mover.GridPosition == from);
            releaseAttack.TrySetResult();
            await action.WaitAsync(TimeSpan.FromSeconds(3));
            Check($"(7 {label}) no movement segment after incapacitation",
                mover.GridPosition == from && !seen.Exists(e => e.Type == BattleEventType.MovementStep));
            Check($"(7 {label}) reaction damage is presented once",
                seen.FindAll(e => e.Type == BattleEventType.DamageDealt && e.Source == reactor).Count == 1);
            int attackIndex = seen.FindIndex(e => e.Type == BattleEventType.AttackRolled);
            int damageIndex = seen.FindIndex(e => e.Type == BattleEventType.DamageDealt);
            Check($"(7 {label}) damage follows attack animation", attackIndex >= 0 && damageIndex > attackIndex);
            if (playerMover)
            {
                Check("(7) unconscious player ends turn with actions remaining",
                    mover.Conditions.HasCondition(Condition.Unconscious) && !mover.Health.IsDead
                    && mover.Actions.TotalActionsRemaining > 0 && turnEnded.Task.IsCompleted);
                int count = seen.Count;
                controller!.BeginStrike();
                controller.TileClicked(reactor.GridPosition);
                Check("(7) unconscious player cannot start another attack", seen.Count == count);
                controller.EndControl();
            }
            else
            {
                Check("(7) slain enemy gets one death event", mover.Health.IsDead
                    && seen.FindAll(e => e.Type == BattleEventType.CreatureDied && e.Source == mover).Count == 1);
                Check("(7) interrupted movement does not restore corpse occupancy",
                    session.Grid.GetGroundOccupant(from) != mover);
            }
        }
        finally
        {
            releaseAttack.TrySetResult();
            DiceRoller.ClearAllOverrides();
            session.Teardown();
        }
    }

    private async Task Check8_AiStopsQueuedActions(DataManager data)
    {
        var actor = MakeGoblin(data);
        var reactor = PresetCharacters.BuildPlayer(5);
        var (session, _) = StartSession(data,
            new() { (reactor, new PF2eVec(5, 5)) }, new() { (actor, new PF2eVec(6, 5)) }, 7);
        bool reacted = false;
        int actionsAfterDeath = 0;
        try
        {
            var runner = new BattleRunner();
            runner.SetPresenter(async evt =>
            {
                if (evt.Source != actor) return;
                if (reacted && evt.Type is BattleEventType.AttackRolled or BattleEventType.MovementStarted)
                    actionsAfterDeath++;
                if (!reacted && evt.Type == BattleEventType.AttackRolled)
                {
                    reacted = true;
                    DiceRoller.EnqueueD20(20);
                    ReactionStrikeBridge.Execute(reactor, actor, isReactiveStrike: true);
                    await ReactionSuspension.Drain();
                }
            });
            await new PF2e.AI.AITurnExecutor(runner, session.Grid).ExecuteTurn(actor);
            Check("(8) reaction kills AI actor during its plan", reacted && actor.Health.IsDead);
            Check("(8) AI does not execute queued actions after death", actionsAfterDeath == 0);
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            session.Teardown();
        }
    }

    private static DamageResult Physical(int amount) =>
        new DamageResult { TotalDamage = amount, DamageType = DamageType.Slashing };
}
