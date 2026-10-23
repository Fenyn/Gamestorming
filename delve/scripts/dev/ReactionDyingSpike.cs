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
/// and grid occupancy updates; (6) ForcedMovementExecutor is installed against the session grid;
/// (10) a foe killed by a Reactive Strike during its own strike stays the current actor through the
/// beat, and its TurnEnded and end-of-turn effects come before the next initiative entry starts.
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
        await Check9_TurnAfterReactionKill(data);
        await Check10_MidTurnKillHoldsTheTurn(data);
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
                controller.BeginMove();
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

    // ── (9) A Reactive Strike that kills the acting foe does not cost the next combatant its turn ──

    private async Task Check9_TurnAfterReactionKill(DataManager data)
    {
        GD.Print("-------------------- (9) Turn after a reaction kill --------------------");
        // The actor dies as its turn starts. Ending that turn must start the next combatant once,
        // not skip or end the next turn.
        var reactor = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var ally = PresetCharacters.BuildTharr(2);
        var victim = MakeGoblin(data);
        var far = MakeGoblin(data);
        var (session, _) = StartSession(data,
            party: new() { (reactor, new PF2eVec(5, 5)), (ally, new PF2eVec(2, 2)) },
            enemies: new() { (victim, new PF2eVec(6, 5)), (far, new PF2eVec(14, 12)) },
            seed: 99, registerNow: false);
        var turns = new HashSet<(ICharacter Unit, int Round)>();
        using var stop = new System.Threading.CancellationTokenSource();
        bool killed = false;
        try
        {
            victim.Health.TakeDamage(new DamageResult { TotalDamage = victim.Health.MaxHP - 1, DamageType = DamageType.Slashing });
            session.PlayerTurnStarted += _ => session.RequestEndPlayerTurn();
            session.SetPresenter(async evt =>
            {
                if (evt.Type != BattleEventType.TurnStarted || evt.Source == null) return;
                if (session.RoundNumber >= 3) { stop.Cancel(); return; }
                turns.Add((evt.Source, session.RoundNumber));
                if (killed || evt.Source != victim) return;
                killed = true;
                DiceRoller.EnqueueD20(20);
                ReactionStrikeBridge.Execute(reactor, victim, isReactiveStrike: true);
                await ReactionSuspension.Drain();
            });

            await session.RunAsync(stop.Token);

            Check("(9) the Reactive Strike slew the acting foe during its turn", killed && victim.Health.IsDead);
            var missing = new List<string>();
            foreach (var unit in new[] { reactor, ally, far })
                for (int round = 1; round <= 2; round++)
                    if (unit.Health.IsAlive && !turns.Contains((unit, round))) missing.Add($"{unit.Name} r{round}");
            Check($"(9) every living hero and foe had a turn in rounds 1 and 2 (missing: {string.Join(", ", missing)})",
                missing.Count == 0);
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            session.Teardown();
        }
    }

    // ── (10) A foe killed during its own turn keeps that turn until it ends ──

    private async Task Check10_MidTurnKillHoldsTheTurn(DataManager data)
    {
        GD.Print("-------------------- (10) Mid-turn kill holds the turn --------------------");
        // The goblin strikes, and a Reactive Strike kills it while that strike resolves. Its turn
        // stays current through the scene's beat; TurnEnded and the engine's end of turn come
        // before the next initiative entry starts.
        var reactor = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var ally = PresetCharacters.BuildTharr(2);
        var victim = MakeGoblin(data);
        var far = MakeGoblin(data);
        var (session, _) = StartSession(data,
            party: new() { (reactor, new PF2eVec(5, 5)), (ally, new PF2eVec(2, 2)) },
            enemies: new() { (victim, new PF2eVec(6, 5)), (far, new PF2eVec(14, 12)) },
            seed: 77, registerNow: false);
        var timeline = new List<string>();
        var starts = new Dictionary<(ICharacter, int), int>();
        var beatIssues = new List<string>();
        string? expectedNext = null;
        int expectedRound = 0;
        using var stop = new System.Threading.CancellationTokenSource();
        bool killed = false;
        try
        {
            victim.Health.TakeDamage(new DamageResult { TotalDamage = victim.Health.MaxHP - 1, DamageType = DamageType.Slashing });
            var turns = PF2e.TurnManagement.TurnManager.Instance!;
            turns.OnTurnStart += c => timeline.Add($"start {c.Name}");
            turns.OnTurnEnd += c => timeline.Add($"end {c.Name}");
            session.PlayerTurnStarted += c => { timeline.Add($"player {c.Name}"); session.RequestEndPlayerTurn(); };
            session.RemovedTurnBeat = () =>
            {
                timeline.Add("beat");
                if (!ReferenceEquals(session.CurrentActor, victim) || !session.CurrentTurnRemoved || session.PlayerTurnActive)
                    beatIssues.Add($"actor {session.CurrentActor?.Name} removed {session.CurrentTurnRemoved} player {session.PlayerTurnActive}");
                return Task.CompletedTask;
            };
            session.SetPresenter(async evt =>
            {
                switch (evt.Type)
                {
                    case BattleEventType.TurnStarted when evt.Source != null:
                        if (session.RoundNumber >= 3) { stop.Cancel(); return; }
                        timeline.Add($"TurnStarted {evt.Source.Name} r{session.RoundNumber}");
                        var key = (evt.Source, session.RoundNumber);
                        starts[key] = starts.TryGetValue(key, out int n) ? n + 1 : 1;
                        if (evt.Source == victim && !killed)
                        {
                            var order = session.TurnOrder!;
                            int index = IndexOf(order, victim);
                            bool last = index == order.Count - 1;
                            expectedNext = order[last ? 0 : index + 1].Character.Name;
                            expectedRound = session.RoundNumber + (last ? 1 : 0);
                            PF2e.TurnManagement.TurnEndCountdown.Register(victim, untilNextTurn: false,
                                () => timeline.Add($"expired {victim.Name}"));
                        }
                        break;
                    case BattleEventType.TurnEnded when evt.Source != null:
                        timeline.Add($"TurnEnded {evt.Source.Name}");
                        break;
                    case BattleEventType.CreatureDied:
                        timeline.Add($"Died {(evt.Target ?? evt.Source)?.Name}");
                        break;
                    case BattleEventType.AttackRolled when evt.Source == victim && !killed:
                        killed = true;
                        DiceRoller.EnqueueD20(20);
                        ReactionStrikeBridge.Execute(reactor, victim, isReactiveStrike: true);
                        await ReactionSuspension.Drain();
                        break;
                }
            });

            await session.RunAsync(stop.Token);

            int died = timeline.IndexOf($"Died {victim.Name}");
            int ownStart = died < 0 ? -1 : timeline.FindLastIndex(died, e => e.StartsWith("TurnStarted "));
            Check($"(10) a Reactive Strike slew the goblin during its own turn ({(killed ? "during its strike" : "as it moved")})",
                victim.Health.IsDead && ownStart >= 0 && timeline[ownStart].StartsWith($"TurnStarted {victim.Name} "));
            int ended = died < 0 ? -1 : timeline.FindIndex(died, e => e == $"TurnEnded {victim.Name}");
            int engineEnd = ended < 0 ? -1 : timeline.FindIndex(ended, e => e == $"end {victim.Name}");
            int expired = timeline.IndexOf($"expired {victim.Name}");
            int next = ended < 0 ? -1 : timeline.FindIndex(ended, e => e.StartsWith("TurnStarted "));
            int engineNext = ended < 0 ? -1 : timeline.FindIndex(ended, e => e.StartsWith("start "));
            bool quiet = died >= 0 && ended > died && !timeline.GetRange(died, ended - died)
                .Exists(e => e.StartsWith("start ") || e.StartsWith("TurnStarted ") || e.StartsWith("player "));
            Check($"(10) the dead goblin's turn held from its death to its TurnEnded, with one beat ({string.Join("; ", beatIssues)})",
                quiet && timeline.GetRange(died, ended - died).FindAll(e => e == "beat").Count == 1 && beatIssues.Count == 0);
            Check("(10) TurnEnded, then its end of turn and the 'until the end of its turn' expiry, then the next turn starts",
                ended >= 0 && ended < engineEnd && engineEnd < expired && expired < engineNext && engineNext < next);
            string nextLabel = next < 0 ? "none" : timeline[next];
            Check($"(10) the next initiative entry acts next (expected {expectedNext} r{expectedRound}, got {nextLabel})",
                nextLabel == $"TurnStarted {expectedNext} r{expectedRound}");
            var wrong = new List<string>();
            foreach (var unit in new[] { reactor, ally, far })
                for (int round = 1; round <= 2; round++)
                    if (unit.Health.IsAlive && (!starts.TryGetValue((unit, round), out int count) || count != 1))
                        wrong.Add($"{unit.Name} r{round}");
            Check($"(10) every living hero and foe started exactly one turn in rounds 1 and 2 (wrong: {string.Join(", ", wrong)})",
                wrong.Count == 0);
            GD.Print($"(10) timeline: {string.Join(" | ", timeline)}");
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            session.Teardown();
        }
    }

    private static int IndexOf(IReadOnlyList<PF2e.TurnManagement.TurnEntry> order, ICharacter character)
    {
        for (int i = 0; i < order.Count; i++)
            if (order[i].Character == character) return i;
        return -1;
    }

    private static DamageResult Physical(int amount) =>
        new DamageResult { TotalDamage = amount, DamageType = DamageType.Slashing };
}
