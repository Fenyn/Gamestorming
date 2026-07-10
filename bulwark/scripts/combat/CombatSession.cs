using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e;
using PF2e.Actions;
using PF2e.AI;
using PF2e.Core;
using PF2e.Events;
using PF2e.Grid;
using PF2e.TurnManagement;
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

    private BattleRunner _runner = null!;
    private TurnManager _turnManager = null!;
    private CombatantRegistry _registry = null!;
    private AITurnExecutor _ai = null!;

    private readonly List<ICharacter> _team1 = new();
    private readonly List<ICharacter> _team2 = new();
    private readonly HashSet<ICharacter> _aiControlled = new();

    private ReactionEvents.DamageReactionHandler _damageHandler = null!;
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

    // ---------------------------------------------------------------- Pass-throughs
    public ICharacter? CurrentActor => _turnManager?.CurrentTurn?.Character;
    public IReadOnlyList<TurnEntry>? TurnOrder => _turnManager?.TurnOrder;
    public int Round => _turnManager?.RoundNumber ?? 0;
    public IReadOnlyList<ICharacter> Team1 => _team1;
    public IReadOnlyList<ICharacter> Team2 => _team2;

    // ---------------------------------------------------------------- Setup / teardown

    public void Setup(CombatSetup setup)
    {
        if (setup.RngSeed.HasValue)
            Rng.Seed(setup.RngSeed.Value);

        Grid = BattleGrid.CreateFlat(setup.GridWidth, setup.GridHeight);
        _runner = new BattleRunner();

        // Own the engine singletons for this encounter (mirrors BattleSimulator's constructor).
        _turnManager = new TurnManager();
        TurnManager.Instance = _turnManager;
        _registry = new CombatantRegistry();
        CombatantRegistry.Instance = _registry;

        Grid.WireDelegates();
        SpatialDelegates.Wire(Grid);

        // Shield Block prompt is out of scope for M1 — apply incoming damage unconditionally.
        _damageHandler = (src, tgt, result, applyDamage) => applyDamage();
        ReactionEvents.OnDamageReactionCheck += _damageHandler;

        // Step destination legality (reject blocked/occupied tiles).
        StepAction.ValidateDestination = ValidateStepDestination;

        _ai = new AITurnExecutor(_runner, Grid);
        PlayerActions = new PlayerActionExecutor(_runner, Grid);

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

        if (evt.Type == BattleEventType.CreatureDied
            && !_finished
            && _pendingResult == BattleResult.InProgress)
        {
            var result = BattleSimulator.CheckVictory(_team1, _team2);
            if (result != BattleResult.InProgress)
            {
                _pendingResult = result;
                _playerTurnTcs?.TrySetResult(PlayerTurnResolution.EndTurn);
            }
        }
    }

    public void Teardown()
    {
        if (_turnManager != null)
        {
            _turnManager.OnTurnStart -= HandleTurnStart;
            foreach (var c in _team1) UnsubscribeCharacter(c);
            foreach (var c in _team2) UnsubscribeCharacter(c);
            if (_turnManager.IsEncounterActive)
                _turnManager.EndEncounter();
        }

        if (_damageHandler != null)
            ReactionEvents.OnDamageReactionCheck -= _damageHandler;
        StepAction.ValidateDestination = null;
        SpatialDelegates.Unwire();
    }

    // ---------------------------------------------------------------- Turn loop

    public async Task RunAsync()
    {
        var all = new List<ICharacter>(_team1.Count + _team2.Count);
        all.AddRange(_team1);
        all.AddRange(_team2);

        await _runner.Emit(BattleEventType.EncounterStarted);
        _turnManager.StartEncounter(all);

        while (_turnManager.IsEncounterActive && !_finished)
        {
            var current = _turnManager.CurrentTurn?.Character;
            if (current == null) break;

            await _runner.Emit(BattleEventType.TurnStarted, source: current);

            if (IsPlayerControlled(current))
            {
                var resolution = await RunPlayerTurn(current);
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
            Finish(BattleSimulator.CheckVictory(_team1, _team2));
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
            : BattleSimulator.CheckVictory(_team1, _team2);
        if (result == BattleResult.InProgress)
            return false;

        if (_turnManager.IsEncounterActive)
            _turnManager.EndEncounter();
        await _runner.Emit(BattleEventType.EncounterEnded, description: result.ToString());
        Finish(result);
        return true;
    }

    private async Task<PlayerTurnResolution> RunPlayerTurn(ICharacter current)
    {
        // Async continuations so a mid-turn CreatureDied (which completes this from inside an Emit
        // call) doesn't reentrantly unwind the turn loop within that Emit's call stack.
        _playerTurnTcs = new TaskCompletionSource<PlayerTurnResolution>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        PlayerTurnStarted?.Invoke(current);
        var resolution = await _playerTurnTcs.Task;
        _playerTurnTcs = null;
        PlayerTurnEnded?.Invoke();
        return resolution;
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
    }

    private void UnsubscribeCharacter(ICharacter c)
    {
        c.Health?.UnsubscribeFromTurnEvents(_turnManager);
        c.Equipment?.Shield?.UnsubscribeFromTurnEvents(_turnManager);
        c.Conditions?.UnsubscribeFromTurnEvents(_turnManager);
        c.CooldownTracker?.UnsubscribeFromTurnEvents();
    }
}
