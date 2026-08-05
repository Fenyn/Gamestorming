using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PF2e;
using PF2e.Actions;
using PF2e.AI;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Events;
using PF2e.Grid;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Owns a single tactical encounter: the grid, the shared BattleRunner, the TurnManager /
/// CombatantRegistry lifecycle, the AI and player executors, spatial-delegate + reaction wiring,
/// and the turn loop with victory checking. Plain C#; presentation subscribes via
/// <see cref="SetPresenter"/> and the turn events.
///
/// Turn loop: while the encounter is active, the current combatant either runs engine AI
/// (team 2, or an ally toggled to AI) or hands control to the player (awaiting an End-Turn / AI
/// hand-off signal). After each turn <c>BattleSimulator.CheckVictory</c> decides whether to end.
/// </summary>
public sealed class CombatSession
{
    private enum PlayerTurnResolution { EndTurn, HandOffToAi }

    // Engine surfaces (created in Setup).
    public BattleGrid Grid { get; private set; } = null!;
    public PlayerActionExecutor PlayerActions { get; private set; } = null!;

    /// <summary>
    /// The generated battle map this encounter runs on, or null for a flat board. Read by the scene to
    /// decide whether to build terrain geometry and an elevation-aware view; the rules themselves need
    /// nothing from it, because everything they ask about elevation is already baked into
    /// <see cref="Grid"/>'s per-tile corner heights.
    /// </summary>
    public PF2e.MapGen.MapLayout? MapLayout { get; private set; }

    private BattleRunner _runner = null!;
    private TurnManager _turnManager = null!;
    private CombatantRegistry _registry = null!;
    private AITurnExecutor _ai = null!;

    private readonly List<ICharacter> _team1 = new();
    private readonly List<ICharacter> _team2 = new();
    private readonly HashSet<ICharacter> _aiControlled = new();
    // Allies toggled to auto-use reactions (skip the prompt). Default is empty = everyone PROMPTS.
    private readonly HashSet<ICharacter> _autoReactions = new();

    private ReactionManager _reactions = null!;
    private TaskCompletionSource<PlayerTurnResolution>? _playerTurnTcs;
    private bool _finished;

    // External presentation sink, wrapped so we can watch the shared event stream for mid-turn
    // deaths. Decisive result latched here the instant it is detected; the turn loop's gate reads it.
    private Func<BattleEvent, Task>? _presenter;
    private BattleResult _pendingResult = BattleResult.InProgress;

    // ---------------------------------------------------------------- Events
    public event Action<ICharacter>? PlayerTurnStarted;
    public event Action? PlayerTurnEnded;
    public event Action<BattleResult>? EncounterFinished;
    /// <summary>Fires whenever a new combatant's turn begins (player or AI) — for turn-order UI.</summary>
    public event Action? TurnChanged;

    /// <summary>
    /// Interactive reaction prompt seam, set by the scene. Given a UI view model, resolve true
    /// (Use) or false (Skip) — typically by showing a modal panel and completing on click. While
    /// the returned Task is pending the entire combat pipeline is suspended (the engine awaits it
    /// through ReactionManager.PlayerReactionPolicy), including mid-enemy-turn prompts.
    /// Null (headless / no UI wired) → auto-use, preserving the old behaviour safely.
    /// </summary>
    public Func<ReactionPromptView, Task<bool>>? ReactionPromptHandler { get; set; }

    // ---------------------------------------------------------------- Pass-throughs
    public ICharacter? CurrentActor => _turnManager?.CurrentTurn?.Character;
    public IReadOnlyList<TurnEntry>? TurnOrder => _turnManager?.TurnOrder;
    public int Round => _turnManager?.RoundNumber ?? 0;
    public IReadOnlyList<ICharacter> Team1 => _team1;
    public IReadOnlyList<ICharacter> Team2 => _team2;

    // ---------------------------------------------------------------- Setup / teardown

    /// <summary>Deployment corrections from <see cref="CombatSetup.Normalize"/> (empty when legal).</summary>
    public IReadOnlyList<string> SetupCorrections { get; private set; } = Array.Empty<string>();

    public void Setup(CombatSetup setup)
    {
        // Ordering trap: SetupCore wires engine statics (TurnManager.Instance,
        // CombatantRegistry.Instance) and global delegates (reactions, forced movement, step
        // validation, spatial) incrementally. If it throws partway, those are left half-wired and
        // would poison the next encounter. Teardown is null-tolerant (every step guards on null /
        // identity), so it is safe to call on a partially-constructed session — unwind through it,
        // then surface the fault.
        try
        {
            SetupCore(setup);
        }
        catch
        {
            Teardown();
            throw;
        }
    }

    private void SetupCore(CombatSetup setup)
    {
        if (setup.RngSeed.HasValue)
            Rng.Seed(setup.RngSeed.Value);

        // Self-heal out-of-bounds/stacked anchors BEFORE placement; the scene surfaces these
        // loudly so data/board mismatches never silently render units off the visible board.
        SetupCorrections = setup.Normalize();

        // The single grid swap point. A generated layout brings per-tile roles, corner heights, cover
        // flags and climb DCs with it (MapLayoutGridBuilder), which is all the engine's movement,
        // forced-movement and fall handling needs to become terrain-aware — no rule code changes here.
        MapLayout = setup.Layout;
        Grid = setup.Layout != null
            ? PF2e.MapGen.MapLayoutGridBuilder.Build(setup.Layout)
            : BattleGrid.CreateFlat(setup.GridWidth, setup.GridHeight);
        _runner = new BattleRunner();

        // Own the engine singletons for this encounter (mirrors BattleSimulator's constructor).
        _turnManager = new TurnManager();
        TurnManager.Instance = _turnManager;
        _registry = new CombatantRegistry();
        CombatantRegistry.Instance = _registry;

        Grid.WireDelegates();
        SpatialDelegates.Wire(Grid);

        // Reactions: a subscribed ReactionManager OWNS damage delivery (its damage handler runs
        // reactions then calls the applyDamage continuation). It replaces the old pass-through — never
        // both, or the multicast event would deliver damage twice. It also owns movement/defense/etc.
        _reactions = new ReactionManager();
        _reactions.Subscribe();
        // Player-team members (not toggled to AI) are "player controlled" for reaction decisions.
        ReactionManager.IsPlayerControlled = IsPlayerControlled;
        // Interactive reaction policy: prompt through the scene-supplied handler unless the ally
        // is toggled to auto-reactions (or no UI handler is wired) — then auto-use.
        ReactionManager.PlayerReactionPolicy = DecidePlayerReaction;

        // Forced movement (Shove push/follow, Tumble Through exit-move, push-strike riders) resolves
        // through ForcedMovementExecutor against this encounter's grid. Install() routes push-rider
        // OnPushRequested events so rider displacement actually moves creatures.
        ForcedMovementExecutor.Grid = Grid;
        ForcedMovementExecutor.Install();

        // Step destination legality (reject blocked/occupied tiles).
        StepAction.ValidateDestination = ValidateStepDestination;

        _ai = new AITurnExecutor(_runner, Grid);
        PlayerActions = new PlayerActionExecutor(_runner, Grid);
        WireConsumables();

        foreach (var (unit, pos) in setup.Party)
        {
            Grid.PlaceCreature(unit, pos);
            _team1.Add(unit);
        }
        foreach (var (unit, pos) in setup.Enemies)
        {
            Grid.PlaceCreature(unit, pos);
            _team2.Add(unit);
        }

        // Ordering trap: components must be subscribed to the TurnManager (which now exists) so
        // shield auto-lower and condition/cooldown ticking fire on turn boundaries.
        foreach (var c in _team1) SubscribeCharacter(c);
        foreach (var c in _team2) SubscribeCharacter(c);

        _turnManager.OnTurnStart += HandleTurnStart;

        // Combat-scoped consumable buffs (elixirs) expire on their round duration — tick them at each
        // round's end. Encounter-end clearing is owned by GameState.CompleteEncounter.
        _turnManager.OnRoundEnd += _ => Bulwark.Autoload.GameState.Instance?.Consumables.AdvanceCombatRound();
    }

    /// <summary>
    /// Wire the "Use Item" action path: point the executor's consumable delegates at the live GameState's
    /// ConsumableSystem + Inventory. A player-controlled ally can drink a carried potion/elixir as their
    /// action (engine cost + manipulate, consumed from their carry). No-op when no GameState is active
    /// (standalone combat scenes) — the executor simply reports "no consumables".
    /// </summary>
    private void WireConsumables()
    {
        var gs = Bulwark.Autoload.GameState.Instance;
        if (gs?.Squad == null)
            return;

        PlayerActions.UseConsumable = (actor, itemId, target) =>
            gs.Consumables.UseInCombat(gs.Squad.FindMember(actor.Id), itemId, gs.Inventory, target);

        PlayerActions.ConsumableOptions = actor =>
        {
            var list = new List<ConsumableOptionView>();
            foreach (var kv in gs.Inventory.MemberStacks(actor.Id))
            {
                if (!Bulwark.Data.Consumables.TryGet(kv.Key, out var def))
                    continue;
                list.Add(new ConsumableOptionView
                {
                    ItemId = def.Id,
                    Name = def.DisplayName,
                    EffectText = def.EffectText,
                    CostText = def.ActionCost.ToString(),
                    Quantity = kv.Value,
                });
            }
            return list;
        };
    }

    public void SetPresenter(Func<BattleEvent, Task> presenter)
    {
        _presenter = presenter;
        _runner.SetPresenter(OnBattleEvent);
    }

    /// <summary>
    /// Presenter shim: forwards every event to the real presentation sink, then — for a
    /// <see cref="BattleEventType.CreatureDied"/> — evaluates victory immediately. If the encounter is
    /// decided mid-turn, latch the result and unblock any in-progress player turn so the turn loop
    /// reaches its single end-of-encounter gate at once (remaining player actions / AI plan stop).
    /// The victory flow itself still fires exactly once, from the loop's gate — never here.
    /// </summary>
    private async Task OnBattleEvent(BattleEvent evt)
    {
        if (_presenter != null)
            await _presenter(evt);

        // Watch both deaths (enemy slain → win) and damage (a PC dropped to Dying/Unconscious mid-turn
        // → potential defeat, since dying emits no CreatureDied). Latch a decisive result the instant
        // it appears so remaining player actions / AI plans stop; the victory flow still fires once,
        // from the loop's gate.
        if ((evt.Type == BattleEventType.CreatureDied || evt.Type == BattleEventType.DamageDealt)
            && !_finished
            && _pendingResult == BattleResult.InProgress)
        {
            var result = EvaluateEncounter();
            if (result != BattleResult.InProgress)
            {
                _pendingResult = result;
                _playerTurnTcs?.TrySetResult(PlayerTurnResolution.EndTurn);
            }
        }
    }

    /// <summary>
    /// Decide the encounter. Win when no enemy is alive (enemies die outright). Loss when NO
    /// player-team member can still act — dying, unconscious, and dead all count as "down" (a dying
    /// PC is Unconscious, not dead, so this can't rely on IsDead / CheckVictory alone).
    /// </summary>
    private BattleResult EvaluateEncounter()
    {
        bool anyEnemyAlive = false;
        foreach (var c in _team2)
            if (c.Health != null && c.Health.IsAlive) { anyEnemyAlive = true; break; }

        bool anyPlayerActive = false;
        foreach (var c in _team1)
            if (IsConsciousAndAble(c)) { anyPlayerActive = true; break; }

        if (!anyEnemyAlive && !anyPlayerActive) return BattleResult.Draw;
        if (!anyEnemyAlive) return BattleResult.Team1Wins;
        if (!anyPlayerActive) return BattleResult.Team2Wins;
        return BattleResult.InProgress;
    }

    /// <summary>A combatant still in the fight: alive and not Unconscious (dying/knocked-out PCs are
    /// Unconscious at 0 HP and cannot act).</summary>
    private static bool IsConsciousAndAble(ICharacter c)
        => c.Health != null && !c.Health.IsDead
           && c.Conditions?.HasCondition(Condition.Unconscious) != true;

    public void Teardown()
    {
        // A player turn parked on RunPlayerTurn's TCS would otherwise hang forever once the scene
        // exits (nothing left to press End Turn / hand off to AI). Complete it as an EndTurn so the
        // awaiting turn loop unwinds; after cancellation RunAsync's next boundary check bails out
        // before an AI plan can start. TrySetResult is idempotent — harmless if already resolved or
        // never created.
        _playerTurnTcs?.TrySetResult(PlayerTurnResolution.EndTurn);

        if (_turnManager != null)
        {
            _turnManager.OnTurnStart -= HandleTurnStart;
            foreach (var c in _team1) UnsubscribeCharacter(c);
            foreach (var c in _team2) UnsubscribeCharacter(c);
            if (_turnManager.IsEncounterActive)
                _turnManager.EndEncounter();
        }

        _reactions?.Unsubscribe();
        ReactionManager.IsPlayerControlled = null;
        ReactionManager.PlayerReactionPolicy = null;

        ForcedMovementExecutor.Uninstall();
        ForcedMovementExecutor.Grid = null;

        StepAction.ValidateDestination = null;
        SpatialDelegates.Unwire();

        // Release the engine singletons Setup claimed — but ONLY if they still point at THIS
        // encounter. Setup overwrites both unconditionally, so a newer CombatSession may already own
        // them (e.g. an old scene tearing down after the next encounter began); clobbering those to
        // null would break the live fight. Identity-guard the clear.
        if (ReferenceEquals(TurnManager.Instance, _turnManager))
            TurnManager.Instance = null!;
        if (ReferenceEquals(CombatantRegistry.Instance, _registry))
            CombatantRegistry.Instance = null!;
    }

    // ---------------------------------------------------------------- Turn loop

    /// <summary>
    /// Runs the encounter to completion (or abort). CANCELLATION CONTRACT: the owner passes a token
    /// whose source it cancels on scene exit (<c>CombatScene._ExitTree</c>, before/around Teardown).
    /// Cancellation is cooperative and surfaces two ways — a boundary check between turns, and, mid-turn,
    /// the presenter's paced <c>Task.Delay</c> / tween waits observing the SAME token and throwing
    /// <see cref="OperationCanceledException"/> up through the AI plan and Emit chain. Either path unwinds
    /// the loop WITHOUT running the victory flow: a torn-down scene must not raise EncounterFinished or
    /// touch freed nodes. A NON-cancel exception (AI-planning bug, Emit fault) is logged through the
    /// engine <see cref="Log"/> and routed to an abort finish (Team2Wins) so the encounter still ends and
    /// the owning scene can route out instead of soft-locking. The task therefore never faults for
    /// cancellation; the fire-and-forget caller attaches a faulted continuation only as a last backstop.
    /// </summary>
    public async Task RunAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var all = new List<ICharacter>(_team1.Count + _team2.Count);
            all.AddRange(_team1);
            all.AddRange(_team2);

            await _runner.Emit(BattleEventType.EncounterStarted);
            _turnManager.StartEncounter(all);

            while (_turnManager.IsEncounterActive && !_finished)
            {
                // Cooperative cancellation point between turns (scene exit). Throwing here unwinds to
                // the OperationCanceledException handler below — no victory flow, no freed-node touches.
                cancellationToken.ThrowIfCancellationRequested();

                var current = _turnManager.CurrentTurn?.Character;
                if (current == null) break;

                await _runner.Emit(BattleEventType.TurnStarted, source: current);

                // A dying character's recovery check ran at StartTurn (DyingSystem.OnTurnStart) and called
                // TurnManager.RequestEndTurn — dying creatures can't act. Skip the turn body (mirrors
                // BattleSimulator.RunEncounter). StartTurn clears the flag for the next character.
                if (_turnManager.EndTurnRequested)
                {
                    await _runner.Emit(BattleEventType.TurnEnded, source: current);
                    if (await EndIfDecided())
                        return;
                    _turnManager.EndTurn();
                    continue;
                }

                if (IsPlayerControlled(current))
                {
                    var resolution = await RunPlayerTurn(current, cancellationToken);
                    // A mid-turn death may have already decided the encounter; don't start an AI plan.
                    if (resolution == PlayerTurnResolution.HandOffToAi
                        && _pendingResult == BattleResult.InProgress)
                        await _ai.ExecuteTurn(current);
                }
                else
                {
                    await _ai.ExecuteTurn(current);
                }

                await _runner.Emit(BattleEventType.TurnEnded, source: current);

                if (await EndIfDecided())
                    return;

                _turnManager.EndTurn();
            }

            if (!_finished)
                Finish(EvaluateEncounter());
        }
        catch (OperationCanceledException)
        {
            // Scene torn down mid-encounter (Task.Delay / tween wait / boundary check observed the
            // token). Teardown — run from _ExitTree alongside the cancel — owns cleanup; the loop just
            // stops. Deliberately NO Finish: the scene is gone, EncounterFinished must not fire.
        }
        catch (Exception e)
        {
            // Without this, a bug in AI planning or an Emit chain vanishes into this unobserved Task and
            // combat soft-locks with no result / no EncounterFinished / no log. Log through the engine
            // sink (plain C# — no GD.* here) and route to a defeat/abort finish so the encounter still
            // ends and the owning scene routes out. Guarded by _finished so a fault raised during the
            // end-of-encounter flow itself is a harmless no-op.
            Log.Error($"[CombatSession] Encounter loop faulted, aborting encounter: {e}");
            if (!_finished)
                Finish(BattleResult.Team2Wins);
        }
    }

    /// <summary>
    /// The single victory gate: runs the end-of-encounter flow (EndEncounter, EncounterEnded event,
    /// <see cref="Finish"/>) exactly once. Prefers a result already latched by a mid-turn death,
    /// otherwise checks now. Returns true when the encounter ended.
    /// </summary>
    private async Task<bool> EndIfDecided()
    {
        var result = _pendingResult != BattleResult.InProgress
            ? _pendingResult
            : EvaluateEncounter();
        if (result == BattleResult.InProgress)
            return false;

        if (_turnManager.IsEncounterActive)
            _turnManager.EndEncounter();
        await _runner.Emit(BattleEventType.EncounterEnded, description: result.ToString());
        Finish(result);
        return true;
    }

    private async Task<PlayerTurnResolution> RunPlayerTurn(ICharacter current, CancellationToken cancellationToken)
    {
        // Async continuations so a mid-turn CreatureDied (which completes this from inside an Emit
        // call) doesn't reentrantly unwind the turn loop within that Emit's call stack.
        _playerTurnTcs = new TaskCompletionSource<PlayerTurnResolution>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        PlayerTurnStarted?.Invoke(current);
        // Scene exit while the turn is parked here would suspend this task forever (nothing left to
        // press End Turn / hand off to AI). Completing the TCS as an EndTurn on cancellation unblocks
        // it; the loop's next boundary check then throws before an AI plan starts. Teardown does the
        // same as a backstop for a session with no live token. Register is disposed when the turn ends.
        using (cancellationToken.Register(
            static tcs => ((TaskCompletionSource<PlayerTurnResolution>)tcs!)
                .TrySetResult(PlayerTurnResolution.EndTurn),
            _playerTurnTcs))
        {
            var resolution = await _playerTurnTcs.Task;
            _playerTurnTcs = null;
            PlayerTurnEnded?.Invoke();
            return resolution;
        }
    }

    // ---------------------------------------------------------------- Player intents

    public bool IsPlayerControlled(ICharacter character)
        => character.TeamId == 1 && !_aiControlled.Contains(character);

    public bool IsAiToggled(ICharacter character) => _aiControlled.Contains(character);

    public void SetAiToggle(ICharacter character, bool aiControlled)
    {
        if (aiControlled) _aiControlled.Add(character);
        else _aiControlled.Remove(character);

        // Hand off immediately if the toggled character's player turn is in progress.
        if (aiControlled && character == CurrentActor)
            _playerTurnTcs?.TrySetResult(PlayerTurnResolution.HandOffToAi);
    }

    public void RequestEndPlayerTurn()
        => _playerTurnTcs?.TrySetResult(PlayerTurnResolution.EndTurn);

    // ---------------------------------------------------------------- Reaction prompts

    /// <summary>True when this ally auto-uses reactions (no prompt). Default false = prompt.</summary>
    public bool IsAutoReactions(ICharacter character) => _autoReactions.Contains(character);

    public void SetAutoReactions(ICharacter character, bool autoUse)
    {
        if (autoUse) _autoReactions.Add(character);
        else _autoReactions.Remove(character);
    }

    /// <summary>
    /// The engine's PlayerReactionPolicy. Runs for player-controlled reactors only (AI-toggled
    /// allies and enemies use the feature's AI decision inside ReactionManager). Auto-toggled
    /// allies — or a session with no UI handler — auto-use, matching the pre-prompt behaviour.
    /// Otherwise the handler shows a modal prompt; combat stays suspended on this Task, even when
    /// the trigger is inside an ENEMY's turn (goblin strike → Shield Block offer).
    /// </summary>
    private Task<bool> DecidePlayerReaction(ReactionPromptContext ctx)
    {
        if (ReactionPromptHandler == null || _autoReactions.Contains(ctx.Reactor))
            return Task.FromResult(true);

        return ReactionPromptHandler(BuildPromptView(ctx));
    }

    /// <summary>Translate the engine context into a UI view model (no engine types cross to UI).</summary>
    private static ReactionPromptView BuildPromptView(ReactionPromptContext ctx)
    {
        string description = ctx.PromptInfo.Description ?? "";

        // Feature-supplied text is null for preview-style prompts (Shield Block, Reactive
        // Strike) — synthesize the consequence text the panel shows.
        if (string.IsNullOrEmpty(description))
        {
            switch (ctx.Trigger)
            {
                case ReactionTrigger.Damage:
                {
                    int incoming = ctx.Damage?.TotalDamage ?? 0;
                    int hardness = ctx.Reactor.Equipment?.EquippedShield?.Hardness ?? 0;
                    int absorbed = Math.Min(hardness, incoming);
                    string who = ctx.ProtectedAlly != null ? $" for {ctx.ProtectedAlly.Name}" : "";
                    description =
                        $"Absorb {absorbed} of {incoming} incoming damage{who} — your shield takes the rest.";
                    break;
                }
                case ReactionTrigger.Movement:
                    description = $"Strike {ctx.Source?.Name ?? "the enemy"} as they leave your reach.";
                    break;
                case ReactionTrigger.Action:
                    description = $"Strike {ctx.Source?.Name ?? "the enemy"} as they act within your reach.";
                    break;
                default:
                    description = $"Spend your reaction to use {ctx.ReactionName}.";
                    break;
            }
        }

        return new ReactionPromptView
        {
            ReactorName = ctx.Reactor.Name,
            PortraitKey = ctx.Reactor.Name,
            ReactionName = ctx.ReactionName,
            Description = description,
        };
    }

    // ---------------------------------------------------------------- Helpers

    private void HandleTurnStart(ICharacter _) => TurnChanged?.Invoke();

    private void Finish(BattleResult result)
    {
        if (_finished) return;
        _finished = true;
        EncounterFinished?.Invoke(result);
    }

    private string? ValidateStepDestination(ICharacter actor, PF2eVec dest)
    {
        var tile = Grid.GetTile(dest);
        if (tile == null || tile.IsBlocked) return "Blocked.";
        if (!Grid.CanCreatureFit(dest, actor.TileWidth, ignore: actor)) return "Occupied.";
        return null;
    }

    private void SubscribeCharacter(ICharacter c)
    {
        c.Health?.SubscribeToTurnEvents(_turnManager);
        c.Equipment?.Shield?.SubscribeToTurnEvents(_turnManager);
        c.Conditions?.SubscribeToTurnEvents(_turnManager);
        c.CooldownTracker?.SubscribeToTurnEvents(_turnManager);
        // Dying PCs make their recovery check at turn start via the DyingSystem's OnTurnStart hook;
        // it then calls TurnManager.RequestEndTurn (dying creatures can't act) — RunAsync honors that.
        c.Health?.DyingSystem?.SubscribeToTurnEvents(_turnManager);
    }

    private void UnsubscribeCharacter(ICharacter c)
    {
        c.Health?.UnsubscribeFromTurnEvents(_turnManager);
        c.Equipment?.Shield?.UnsubscribeFromTurnEvents(_turnManager);
        c.Conditions?.UnsubscribeFromTurnEvents(_turnManager);
        c.CooldownTracker?.UnsubscribeFromTurnEvents();
        // Detach the per-encounter turn wiring only. We deliberately do NOT Dispose() the DyingSystem:
        // Dispose severs its permanent ConditionTracker wiring (dying/wounded/doomed), which the
        // character keeps across encounters for future M3 attrition (carried damage/wounds).
        c.Health?.DyingSystem?.UnsubscribeFromTurnEvents(_turnManager);
    }
}
