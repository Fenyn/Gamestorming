using System;
using System.Collections.Generic;
using System.Threading;
using PF2e.Conditions;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Plain-C# state machine translating player intents (from input / action bar) into validated
/// executor commands, and raising view-model events the presentation layer renders. Owns no Godot
/// types. Engine types (ICharacter, positions) are internal; everything crossing to UI is a Delve
/// view model (<see cref="ActionBarState"/>, <see cref="AttackPreviewView"/>, <see cref="MoveHoverView"/>).
///
/// Movement is a command, as in FFT: Idle shows no bands. <see cref="BeginMove"/> enters Moving,
/// which shows the <see cref="MovePlan"/> bands; hovering a band tile previews the route and cost,
/// and clicking one runs the plan's legs (a Step, or one Stride per action). Cancel or a finished
/// action returns to Idle with the board clear.
///
/// After every executed action it re-checks actions remaining and auto-requests end-of-turn at 0.
/// </summary>
public sealed partial class PlayerTurnController
{
    private readonly PlayerActionExecutor _exec;

    private ICharacter? _current;
    private PlayerTurnMode _mode = PlayerTurnMode.Idle;
    private bool _busy;
    public PlayerTurnMode Mode => _mode;

    /// <summary>True while an action plays out; the command menu stays closed until it ends.</summary>
    public bool Busy => _busy;
    public event Action<bool>? BusyChanged;

    private void SetBusy(bool busy)
    {
        if (_busy == busy) return;
        _busy = busy;
        BusyChanged?.Invoke(busy);
    }
    public bool CanAcceptOrders => Ready();
    public event Action? ActionCompleted;
    public bool CanStageOrder(PF2eVec tile) => Ready() && _mode switch
    {
        PlayerTurnMode.Moving => _plan?.Options.ContainsKey(tile) == true,
        PlayerTurnMode.SelectingStrike => _strikeTargets.ContainsKey(tile),
        PlayerTurnMode.SelectingSpellTarget => _spellTiles.Contains(tile),
        PlayerTurnMode.SelectingSkillTarget => _skillTiles.Contains(tile),
        _ => false,
    };

    /// <summary>An action was executed this turn. Delay is a free action as the turn BEGINS, so
    /// this closes it.</summary>
    private bool _actedThisTurn;

    /// <summary>Chips offered while picking the Delay slot, by combatant id.</summary>
    private readonly Dictionary<int, ICharacter> _delayAnchors = new();

    /// <summary>The Moving-mode bands; null whenever they are hidden.</summary>
    private MovePlan? _plan;
    private HashSet<PF2eVec> _moveTiles = new();
    private readonly Dictionary<PF2eVec, ICharacter> _strikeTargets = new();

    // Pending spell/skill selection state.
    private readonly List<ICharacter> _selectedSpellTargets = new();
    private int _spellTargetLimit;
    public event Action<int, int>? SpellTargetsChanged;

    private string _pendingSpellId = "";
    private int _pendingVariant = -1;
    private string _pendingSkillId = "";
    private HashSet<PF2eVec> _spellTiles = new();
    private HashSet<PF2eVec> _skillTiles = new();

    public PlayerTurnController(PlayerActionExecutor exec) => _exec = exec;

    /// <summary>
    /// The encounter's cancellation token, set by <see cref="CombatScene"/> from the same source it
    /// cancels on scene exit or encounter reset. <see cref="RunAction"/> observes it after each await
    /// so a torn-down encounter never publishes state or asks for an end of turn. Defaults to None,
    /// which keeps a headless / standalone controller behaving exactly as before.
    /// </summary>
    public CancellationToken CancellationToken { get; set; } = CancellationToken.None;

    /// <summary>Session seam: why the actor cannot Delay now (null = allowed).</summary>
    public Func<ICharacter, string?>? DelayBlockedReason { get; set; }

    /// <summary>Session seam: the combatants the actor may Delay until after, in turn order.</summary>
    public Func<ICharacter, IReadOnlyList<ICharacter>>? DelayAnchors { get; set; }

    // ---------------------------------------------------------------- View events
    public event Action<IReadOnlyCollection<PF2eVec>, HighlightKind>? HighlightsChanged;
    /// <summary>The Moving-mode bands (empty when hidden).</summary>
    public event Action<IReadOnlyDictionary<PF2eVec, MoveOption>>? MoveBandsChanged;
    /// <summary>Cost readout of the hovered band tile (null when the cursor is off the bands).</summary>
    public event Action<MoveHoverView?>? MoveHoverChanged;
    /// <summary>The tile under the cursor in every mode (null off-board), for the board cursor.</summary>
    public event Action<PF2eVec?>? HoverTileChanged;
    public event Action<IReadOnlyList<PF2eVec>?>? PathPreviewChanged;
    public event Action<AttackPreviewView?>? AttackPreviewChanged;
    /// <summary>Tiles an area template currently covers (hover preview during SelectingAreaOrigin).</summary>
    public event Action<IReadOnlyCollection<PF2eVec>>? AreaPreviewChanged;
    public event Action<ActionBarState>? ButtonStateChanged;
    public event Action<PlayerTurnMode>? ModeChanged;
    public event Action? EndTurnRequested;
    /// <summary>Combatant ids the turn order bar should offer as Delay slots (empty when the pick ends).</summary>
    public event Action<IReadOnlyCollection<int>>? DelayAnchorsChanged;
    /// <summary>The actor Delays, returning after the given combatant.</summary>
    public event Action<ICharacter, ICharacter>? DelayRequested;

    // ---------------------------------------------------------------- Turn lifecycle

    public void BeginTurn(ICharacter character)
    {
        _current = character;
        SetBusy(false);
        _actedThisTurn = false;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();
    }

    public void EndControl()
    {
        _current = null;
        SetBusy(false);
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
    }

    // ---------------------------------------------------------------- Intents

    /// <summary>Show the smart-move bands: Step, Stride legs or Crawl, whichever the actor can take.
    /// A second Move while the bands are up puts them away.</summary>
    public void BeginMove()
    {
        if (!Ready()) return;
        if (_mode == PlayerTurnMode.Moving) { Cancel(); return; }
        ClearTransient();
        _plan = _exec.GetMovePlan(_current!);
        if (_plan.Options.Count == 0) { Cancel(); return; }
        SetMode(PlayerTurnMode.Moving);
        MoveBandsChanged?.Invoke(_plan.Options);
    }

    public void BeginStrike()
    {
        if (!Ready()) return;
        ClearTransient();
        foreach (var t in _exec.GetStrikeTargets(_current!))
            foreach (var tile in CreatureTargetTiles.For(t))
                _strikeTargets[tile] = t;
        if (_strikeTargets.Count == 0) { Cancel(); return; }
        SetMode(PlayerTurnMode.SelectingStrike);
        HighlightsChanged?.Invoke(new List<PF2eVec>(_strikeTargets.Keys), HighlightKind.StrikeTarget);
    }

    public void RaiseShield()
    {
        if (!Ready()) return;
        if (_current!.Equipment?.CanRaiseShield() != true) return;
        RunAction(() => _exec.ExecuteRaiseShield(_current!));
    }

    public void EndTurn()
    {
        if (_busy) return;
        EndTurnRequested?.Invoke();
    }

    public void Cancel()
    {
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();
    }

    // ---------------------------------------------------------------- Helpers

    private static bool CanAct(ICharacter actor) => actor.Health?.IsAlive == true
        && actor.Conditions?.HasCondition(Condition.Unconscious) != true;

    private bool Ready() => !_busy && _current != null && CanAct(_current)
        && (_current.Actions?.TotalActionsRemaining ?? 0) > 0;

    private void SetMode(PlayerTurnMode mode)
    {
        if (_mode == mode) return;
        _mode = mode;
        ModeChanged?.Invoke(mode);
    }

    private static readonly IReadOnlyDictionary<PF2eVec, MoveOption> EmptyOptions =
        new Dictionary<PF2eVec, MoveOption>();

    private void ClearTransient()
    {
        _plan = null;
        _moveTiles = new();
        _strikeTargets.Clear();
        _spellTiles = new();
        _selectedSpellTargets.Clear();
        _spellTargetLimit = 0;
        SpellTargetsChanged?.Invoke(0, 0);
        _skillTiles = new();
        _pendingSpellId = "";
        _pendingVariant = -1;
        _pendingSkillId = "";
        _delayAnchors.Clear();
        DelayAnchorsChanged?.Invoke(Array.Empty<int>());
        MoveBandsChanged?.Invoke(EmptyOptions);
        MoveHoverChanged?.Invoke(null);
        HighlightsChanged?.Invoke(Array.Empty<PF2eVec>(), HighlightKind.None);
        PathPreviewChanged?.Invoke(null);
        AttackPreviewChanged?.Invoke(null);
        AreaPreviewChanged?.Invoke(Array.Empty<PF2eVec>());
    }

    private void PublishState()
    {
        if (_current == null) return;
        ButtonStateChanged?.Invoke(ActionBarStateBuilder.Build(_exec, _current, DelayReason()));
    }
}
