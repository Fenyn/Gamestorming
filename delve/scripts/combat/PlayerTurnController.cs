using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PF2e;
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

    /// <summary>The Idle-mode bands; null whenever they are hidden (busy, targeting, no turn).</summary>
    private MovePlan? _plan;
    private HashSet<PF2eVec> _moveTiles = new();
    private readonly Dictionary<PF2eVec, ICharacter> _strikeTargets = new();

    // Pending spell/skill selection state.
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

    // ---------------------------------------------------------------- Turn lifecycle

    public void BeginTurn(ICharacter character)
    {
        _current = character;
        _busy = false;
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

            default: // SingleEnemy / SingleAlly / MultiEnemy
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
        => kind == TargetingKind.SingleAlly ? HighlightKind.AllyTarget : HighlightKind.SpellEnemyTarget;

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
                if (pos.HasValue)
                    AreaPreviewChanged?.Invoke(_exec.GetAreaTemplateTiles(_current, _pendingSpellId, pos.Value));
                else
                    AreaPreviewChanged?.Invoke(Array.Empty<PF2eVec>());
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
                    if (_plan.Options[pos].Kind == MoveKind.Step)
                        RunAction(() => _exec.ExecuteStep(actor, pos));
                    else
                        RunAction(() => WalkLegs(actor, legs));
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

    // ---------------------------------------------------------------- Execution

    /// <summary>
    /// Stride one leg at a time to the plan's leg ends. The lifecycle checks sit BETWEEN legs, in
    /// the controller rather than the executor: a Reactive Strike can drop the mover on leg one, the
    /// turn can be handed to the AI, or the encounter can be torn down while a leg animates, and
    /// none of those may start the next Stride. A leg that ends short (a reaction stopped the walk)
    /// ends the chain too, since the next leg's route assumed the planned tile.
    /// </summary>
    private async Task<bool> WalkLegs(ICharacter actor, IReadOnlyList<PF2eVec> legs)
    {
        bool moved = false;
        foreach (var leg in legs)
        {
            if (CancellationToken.IsCancellationRequested || !ReferenceEquals(_current, actor)) break;
            if (actor.Health?.IsAlive != true || (actor.Actions?.TotalActionsRemaining ?? 0) <= 0) break;

            if (!await _exec.ExecuteStride(actor, leg)) break;
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
            await action();
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

        int remaining = _current?.Actions?.TotalActionsRemaining ?? 0;
        PublishState();

        if (remaining <= 0)
            EndTurnRequested?.Invoke();
        else
            ShowIdleBands();
    }

    // ---------------------------------------------------------------- Helpers

    private bool Ready() => !_busy && _current != null
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
        _skillTiles = new();
        _pendingSpellId = "";
        _pendingVariant = -1;
        _pendingSkillId = "";
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
        ButtonStateChanged?.Invoke(ActionBarStateBuilder.Build(_exec, _current));
    }
}
