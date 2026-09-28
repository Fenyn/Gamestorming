using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Plain-C# state machine translating player intents (from input / action bar) into validated
/// executor commands, and raising view-model events the presentation layer renders. Owns no Godot
/// types. Engine types (ICharacter, positions) are internal; everything crossing to UI is a Delve
/// view model (<see cref="ActionBarState"/>, <see cref="AttackPreviewView"/>, <see cref="MoveHoverView"/>).
///
/// Idle owns movement: while no action is selected the board shows the <see cref="MovePlan"/>
/// bands, hovering a band tile previews the route and cost, and clicking one runs the plan's legs
/// (a Step, or one Stride per action). Selecting Strike / a spell / a skill hides the bands for
/// that mode's targets; Cancel or a finished action returns to Idle and shows them again.
///
/// After every executed action it re-checks actions remaining and auto-requests end-of-turn at 0.
/// </summary>
public sealed class PlayerTurnController
{
    private readonly PlayerActionExecutor _exec;

    private ICharacter? _current;
    private PlayerTurnMode _mode = PlayerTurnMode.Idle;
    private bool _busy;
    public PlayerTurnMode Mode => _mode;
    public bool CanAcceptOrders => Ready();
    public event Action? ActionCompleted;
    public bool CanStageOrder(PF2eVec tile) => Ready() && _mode switch
    {
        PlayerTurnMode.Idle => _plan?.Options.ContainsKey(tile) == true,
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

    /// <summary>The Idle-mode bands; null whenever they are hidden (busy, targeting, no turn).</summary>
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
    /// <summary>The Idle movement bands (empty when hidden).</summary>
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
        _busy = false;
        _actedThisTurn = false;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();
        ShowIdleBands();
    }

    public void EndControl()
    {
        _current = null;
        _busy = false;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
    }

    // ---------------------------------------------------------------- Intents

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

    /// <summary>Begin casting a spell (or a cost-variant). Enters the matching selection mode, or
    /// casts immediately for a self-centered emanation.</summary>
    public void BeginSpell(string spellId, int variantIndex)
    {
        if (!Ready()) return;
        ClearTransient();

        var plan = _exec.GetSpellTargets(_current!, spellId, variantIndex);
        _pendingSpellId = spellId;
        _pendingVariant = variantIndex;

        switch (plan.Kind)
        {
            case TargetingKind.SelfArea:
                RunAction(() => _exec.ExecuteCast(_current!, spellId, variantIndex, null));
                return;

            case TargetingKind.AreaAim:
                if (plan.Tiles.Count == 0) { Cancel(); return; }
                _spellTiles = plan.Tiles;
                SetMode(PlayerTurnMode.SelectingAreaOrigin);
                HighlightsChanged?.Invoke(_spellTiles, HighlightKind.AreaOrigin);
                break;

            case TargetingKind.MultiEnemy:
            case TargetingKind.MultiAlly:
                if (plan.Tiles.Count == 0) { Cancel(); return; }
                _spellTiles = plan.Tiles;
                _spellTargetLimit = plan.MaxTargets;
                SetMode(PlayerTurnMode.SelectingSpellTargets);
                HighlightsChanged?.Invoke(_spellTiles, HighlightFor(plan.Kind));
                SpellTargetsChanged?.Invoke(0, _spellTargetLimit);
                break;

            default: // SingleEnemy / SingleAlly
                if (plan.Tiles.Count == 0) { Cancel(); return; }
                _spellTiles = plan.Tiles;
                SetMode(PlayerTurnMode.SelectingSpellTarget);
                HighlightsChanged?.Invoke(_spellTiles, HighlightFor(plan.Kind));
                break;
        }
    }

    /// <summary>
    /// Begin a skill / maneuver / feat action. Self-actions (Parry, Reload) fire immediately;
    /// Shielded Stride enters a (reaction-free, half-Speed) move selection; everything else enters
    /// target-a-creature selection (Trip, Demoralize, Battle Medicine, Shove, Tumble Through, Seek,
    /// Lunge, Sudden Charge).
    /// </summary>
    public void BeginSkill(string actionId)
    {
        if (!Ready()) return;
        ClearTransient();

        if (PlayerActionExecutor.IsSelfSkill(actionId))
        {
            RunAction(() => _exec.ExecuteSelfSkill(_current!, actionId));
            return;
        }

        if (PlayerActionExecutor.IsMoveSkill(actionId)) // Shielded Stride
        {
            _moveTiles = _exec.GetShieldedStrideTiles(_current!);
            if (_moveTiles.Count == 0) { Cancel(); return; }
            SetMode(PlayerTurnMode.SelectingMove);
            HighlightsChanged?.Invoke(_moveTiles, HighlightKind.Move);
            PathPreviewChanged?.Invoke(null);
            return;
        }

        var plan = _exec.GetSkillTargets(_current!, actionId);
        if (plan.Tiles.Count == 0) { Cancel(); return; }

        _pendingSkillId = actionId;
        _skillTiles = plan.Tiles;
        SetMode(PlayerTurnMode.SelectingSkillTarget);
        HighlightsChanged?.Invoke(_skillTiles, HighlightFor(plan.Kind));
    }

    /// <summary>Highlight colour a target-selection mode paints its legal tiles with.</summary>
    private static HighlightKind HighlightFor(TargetingKind kind)
        => (kind == TargetingKind.SingleAlly || kind == TargetingKind.MultiAlly) ? HighlightKind.AllyTarget : HighlightKind.SpellEnemyTarget;

    public void EndTurn()
    {
        if (_busy) return;
        EndTurnRequested?.Invoke();
    }

    /// <summary>
    /// Delay this turn. Legal only before any action. The turn order bar offers every anchor the
    /// engine returns, next-round rows included; a click on one settles the return, and the choice
    /// is final.
    /// </summary>
    public void BeginDelay()
    {
        if (!Ready() || DelayReason() != null) return;
        var actor = _current!;

        ClearTransient();
        foreach (var anchor in DelayAnchors?.Invoke(actor) ?? Array.Empty<ICharacter>())
            _delayAnchors[anchor.UniqueId] = anchor;
        if (_delayAnchors.Count == 0) { Cancel(); return; }
        SetMode(PlayerTurnMode.SelectingDelaySlot);
        DelayAnchorsChanged?.Invoke(new List<int>(_delayAnchors.Keys));
    }

    /// <summary>A turn order chip was clicked while picking the Delay slot.</summary>
    public void DelayAnchorClicked(int combatantId)
    {
        if (_mode != PlayerTurnMode.SelectingDelaySlot || _current == null) return;
        if (!_delayAnchors.TryGetValue(combatantId, out var anchor)) return;
        RequestDelay(_current, anchor);
    }

    /// <summary>Hand the turn to the session as a Delay. The controller is done with it: the
    /// session's turn-ended event releases control, exactly as after End Turn.</summary>
    private void RequestDelay(ICharacter actor, ICharacter after)
    {
        _busy = true;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        DelayRequested?.Invoke(actor, after);
    }

    /// <summary>Why the actor cannot Delay now: acted already (the controller's rule), or the
    /// session's reason. Null when allowed.</summary>
    private string? DelayReason()
    {
        if (_current == null) return "No active turn";
        if (_actedThisTurn) return "Delay must be the first thing you do this turn";
        return DelayBlockedReason?.Invoke(_current);
    }

    public void Cancel()
    {
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();
        ShowIdleBands();
    }

    public void TileHovered(PF2eVec? pos)
    {
        HoverTileChanged?.Invoke(pos);
        if (_current == null) return;

        switch (_mode)
        {
            case PlayerTurnMode.Idle:
                // The plan is null while busy or off-turn, so a hover mid-walk previews nothing.
                if (pos.HasValue && _plan != null && _plan.Options.TryGetValue(pos.Value, out var option))
                {
                    PathPreviewChanged?.Invoke(_plan.PathTo(pos.Value, out _));
                    MoveHoverChanged?.Invoke(new MoveHoverView(option.Actions, option.Kind));
                }
                else
                {
                    PathPreviewChanged?.Invoke(null);
                    MoveHoverChanged?.Invoke(null);
                }
                break;

            case PlayerTurnMode.SelectingMove:
                if (pos.HasValue && _moveTiles.Contains(pos.Value))
                    PathPreviewChanged?.Invoke(_exec.GetPathTo(_current, pos.Value));
                else
                    PathPreviewChanged?.Invoke(null);
                break;

            case PlayerTurnMode.SelectingStrike:
                if (pos.HasValue && _strikeTargets.TryGetValue(pos.Value, out var target))
                    AttackPreviewChanged?.Invoke(ActionBarStateBuilder.BuildPreview(_exec, _current, target));
                else
                    AttackPreviewChanged?.Invoke(null);
                break;

            case PlayerTurnMode.SelectingAreaOrigin:
                AttackPreviewChanged?.Invoke(pos.HasValue
                    ? _exec.GetSpellTargetPreview(_current, _pendingSpellId, _pendingVariant, pos.Value) : null);
                if (pos.HasValue)
                    AreaPreviewChanged?.Invoke(_exec.GetAreaTemplateTiles(_current, _pendingSpellId, pos.Value));
                else
                    AreaPreviewChanged?.Invoke(Array.Empty<PF2eVec>());
                break;

            case PlayerTurnMode.SelectingSpellTarget:
            case PlayerTurnMode.SelectingSpellTargets:
                AttackPreviewChanged?.Invoke(pos.HasValue
                    ? _exec.GetSpellTargetPreview(_current, _pendingSpellId, _pendingVariant, pos.Value) : null);
                break;
            case PlayerTurnMode.SelectingSkillTarget:
                AttackPreviewChanged?.Invoke(pos.HasValue
                    ? _exec.GetAbilityTargetPreview(_current, _pendingSkillId, pos.Value) : null);
                break;
        }
    }

    public void TileClicked(PF2eVec pos)
    {
        if (!Ready()) return;

        switch (_mode)
        {
            case PlayerTurnMode.Idle:
                if (_plan != null && _plan.PathTo(pos, out var legs) != null)
                {
                    var actor = _current!;
                    var kind = _plan.Options[pos].Kind;
                    if (kind == MoveKind.Step)
                        RunAction(() => _exec.ExecuteStep(actor, pos));
                    else
                        RunAction(() => WalkLegs(actor, legs, kind));
                }
                break;

            case PlayerTurnMode.SelectingMove: // Shielded Stride
                if (_moveTiles.Contains(pos))
                    RunAction(() => _exec.ExecuteShieldedStride(_current!, pos));
                break;

            case PlayerTurnMode.SelectingStrike:
                if (_strikeTargets.TryGetValue(pos, out var target))
                    RunAction(() => _exec.ExecuteStrike(_current!, target));
                break;

            case PlayerTurnMode.SelectingSpellTargets:
                if (_spellTiles.Contains(pos) && _exec.GetSpellTargetAt(pos) is { } selected
                    && selected.Health?.IsAlive == true)
                {
                    if (!_selectedSpellTargets.Remove(selected) && _selectedSpellTargets.Count < _spellTargetLimit)
                        _selectedSpellTargets.Add(selected);
                    var tiles = new HashSet<PF2eVec>();
                    foreach (var creature in _selectedSpellTargets)
                        tiles.UnionWith(CreatureTargetTiles.For(creature));
                    AreaPreviewChanged?.Invoke(tiles);
                    SpellTargetsChanged?.Invoke(_selectedSpellTargets.Count, _spellTargetLimit);
                    if (_selectedSpellTargets.Count == _spellTargetLimit)
                        ConfirmSpellTargets();
                }
                break;

            // A spell target and an area origin are both just the aim tile ExecuteCast takes.
            case PlayerTurnMode.SelectingSpellTarget:
            case PlayerTurnMode.SelectingAreaOrigin:
                if (_spellTiles.Contains(pos))
                {
                    string sid = _pendingSpellId;
                    int vi = _pendingVariant;
                    RunAction(() => _exec.ExecuteCast(_current!, sid, vi, pos));
                }
                break;

            case PlayerTurnMode.SelectingSkillTarget:
                if (_skillTiles.Contains(pos))
                {
                    string aid = _pendingSkillId;
                    // Sudden Charge repositions the actor then Strikes (its own executor path);
                    // every other targeted maneuver resolves through the generic skill executor.
                    if (SkillActionCatalog.Get(aid)?.Mode == SkillExecutionMode.ChargeTile)
                        RunAction(() => _exec.ExecuteSuddenChargeTile(_current!, pos));
                    else
                        RunAction(() => _exec.ExecuteSkillAction(_current!, aid, pos));
                }
                break;
        }
    }

    public void ConfirmSpellTargets()
    {
        if (!Ready() || _mode != PlayerTurnMode.SelectingSpellTargets || _selectedSpellTargets.Count == 0) return;
        var targets = _selectedSpellTargets.ToArray();
        var actor = _current!;
        string id = _pendingSpellId;
        int variant = _pendingVariant;
        RunAction(() => _exec.ExecuteCastTargets(actor, id, variant, targets));
    }

    // ---------------------------------------------------------------- Execution

    /// <summary>
    /// Stride (or Crawl) one leg at a time to the plan's leg ends. The lifecycle checks sit BETWEEN
    /// legs, in the controller rather than the executor: a Reactive Strike can drop the mover on leg
    /// one, the turn can be handed to the AI, or the encounter can be torn down while a leg animates,
    /// and none of those may start the next leg. A condition gained mid-walk (tripped prone, grabbed)
    /// ends the chain before an illegal Stride; the executor refuses one as well. A leg that ends
    /// short ends the chain too, since the next leg's route assumed the planned tile.
    /// </summary>
    private async Task<bool> WalkLegs(ICharacter actor, IReadOnlyList<PF2eVec> legs, MoveKind kind)
    {
        bool moved = false;
        foreach (var leg in legs)
        {
            if (CancellationToken.IsCancellationRequested || !ReferenceEquals(_current, actor)) break;
            if (!CanAct(actor) || (actor.Actions?.TotalActionsRemaining ?? 0) <= 0) break;
            if (kind == MoveKind.Stride && _exec.MoveRestriction(actor) != null) break;

            bool walked = kind == MoveKind.Crawl
                ? await _exec.ExecuteCrawl(actor, leg)
                : await _exec.ExecuteStride(actor, leg);
            if (!walked) break;
            moved = true;
            if (actor.GridPosition != leg) break;
        }
        return moved;
    }

    /// <summary>
    /// Run one action to completion, then republish the bar. <c>async void</c> because it is called
    /// from UI event handlers, so the resumption after the await must prove the controller is still
    /// on the SAME turn: the encounter can end, the scene can reset, or the next turn can begin while
    /// the action animates. A changed <see cref="_current"/> or a cancelled encounter means the state
    /// this continuation would publish belongs to a turn that is over — drop it.
    /// </summary>
    private async void RunAction(Func<Task<bool>> action)
    {
        if (_busy || _current == null) return;
        var actor = _current;
        _busy = true;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();

        try
        {
            if (await action()) _actedThisTurn = true;
        }
        catch (OperationCanceledException)
        {
            // Encounter cancelled mid-action (scene exit / reset). Nothing left to publish.
            return;
        }
        catch (Exception e)
        {
            Log.Error($"[PlayerTurnController] action failed: {e.Message}");
        }

        if (CancellationToken.IsCancellationRequested || !ReferenceEquals(_current, actor))
            return;

        _busy = false;
        ActionCompleted?.Invoke();

        int remaining = _current?.Actions?.TotalActionsRemaining ?? 0;
        PublishState();

        if (remaining <= 0 || !CanAct(actor))
            EndTurnRequested?.Invoke();
        else
            ShowIdleBands();
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

    /// <summary>Publish the Idle bands when the actor can act, else an empty set.</summary>
    private void ShowIdleBands()
    {
        _plan = Ready() ? _exec.GetMovePlan(_current!) : null;
        MoveBandsChanged?.Invoke(_plan?.Options ?? EmptyOptions);
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
