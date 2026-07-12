using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e;
using PF2e.Core;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Combat;

/// <summary>
/// Plain-C# state machine translating player intents (from input / action bar) into validated
/// executor commands, and raising view-model events the presentation layer renders. Owns no Godot
/// types. Engine types (ICharacter, positions) are internal; everything crossing to UI is a Bulwark
/// view model (<see cref="ActionBarState"/>, <see cref="AttackPreviewView"/>).
///
/// After every executed action it re-checks actions remaining and auto-requests end-of-turn at 0.
/// </summary>
public sealed class PlayerTurnController
{
    private readonly PlayerActionExecutor _exec;

    private ICharacter? _current;
    private PlayerTurnMode _mode = PlayerTurnMode.Idle;
    private bool _busy;

    private HashSet<PF2eVec> _moveTiles = new();
    private HashSet<PF2eVec> _stepTiles = new();
    private readonly Dictionary<PF2eVec, ICharacter> _strikeTargets = new();

    // Pending spell/skill selection state.
    private string _pendingSpellId = "";
    private int _pendingVariant = -1;
    private string _pendingSkillId = "";
    private bool _shieldedStride;
    private HashSet<PF2eVec> _spellTiles = new();
    private HashSet<PF2eVec> _skillTiles = new();

    public PlayerTurnController(PlayerActionExecutor exec) => _exec = exec;

    // ---------------------------------------------------------------- View events
    public event Action<IReadOnlyCollection<PF2eVec>, HighlightKind>? HighlightsChanged;
    public event Action<IReadOnlyList<PF2eVec>?>? PathPreviewChanged;
    public event Action<AttackPreviewView?>? AttackPreviewChanged;
    /// <summary>Tiles an area template currently covers (hover preview during SelectingAreaOrigin).</summary>
    public event Action<IReadOnlyCollection<PF2eVec>>? AreaPreviewChanged;
    public event Action<ActionBarState>? ButtonStateChanged;
    public event Action<PlayerTurnMode>? ModeChanged;
    public event Action? EndTurnRequested;

    public ICharacter? Current => _current;
    public bool IsBusy => _busy;

    // ---------------------------------------------------------------- Turn lifecycle

    public void BeginTurn(ICharacter character)
    {
        _current = character;
        _busy = false;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();
    }

    public void EndControl()
    {
        _current = null;
        _busy = false;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
    }

    // ---------------------------------------------------------------- Intents

    public void BeginMove()
    {
        if (!Ready()) return;
        _moveTiles = _exec.GetReachableTiles(_current!);
        if (_moveTiles.Count == 0) return;
        SetMode(PlayerTurnMode.SelectingMove);
        HighlightsChanged?.Invoke(_moveTiles, HighlightKind.Move);
        PathPreviewChanged?.Invoke(null);
    }

    public void BeginStep()
    {
        if (!Ready()) return;
        _stepTiles = _exec.GetStepTiles(_current!);
        if (_stepTiles.Count == 0) return;
        SetMode(PlayerTurnMode.SelectingStep);
        HighlightsChanged?.Invoke(_stepTiles, HighlightKind.Step);
    }

    public void BeginStrike()
    {
        if (!Ready()) return;
        _strikeTargets.Clear();
        foreach (var t in _exec.GetStrikeTargets(_current!))
            _strikeTargets[t.GridPosition] = t;
        if (_strikeTargets.Count == 0) return;
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
                HighlightsChanged?.Invoke(_spellTiles,
                    plan.Kind == TargetingKind.SingleAlly ? HighlightKind.AllyTarget : HighlightKind.SpellEnemyTarget);
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
            _shieldedStride = true;
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
        HighlightsChanged?.Invoke(_skillTiles,
            plan.Kind == TargetingKind.SingleAlly ? HighlightKind.AllyTarget : HighlightKind.SpellEnemyTarget);
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

    public void TileHovered(PF2eVec? pos)
    {
        if (_current == null) return;

        switch (_mode)
        {
            case PlayerTurnMode.SelectingMove:
                if (pos.HasValue && _moveTiles.Contains(pos.Value))
                    PathPreviewChanged?.Invoke(_exec.GetPathTo(_current, pos.Value));
                else
                    PathPreviewChanged?.Invoke(null);
                break;

            case PlayerTurnMode.SelectingStrike:
                if (pos.HasValue && _strikeTargets.TryGetValue(pos.Value, out var target))
                    AttackPreviewChanged?.Invoke(BuildPreview(_current, target));
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
            case PlayerTurnMode.SelectingMove:
                if (_moveTiles.Contains(pos))
                {
                    if (_shieldedStride)
                        RunAction(() => _exec.ExecuteShieldedStride(_current!, pos));
                    else
                        RunAction(() => _exec.ExecuteStride(_current!, pos));
                }
                break;

            case PlayerTurnMode.SelectingStep:
                if (_stepTiles.Contains(pos))
                    RunAction(() => _exec.ExecuteStep(_current!, pos));
                break;

            case PlayerTurnMode.SelectingStrike:
                if (_strikeTargets.TryGetValue(pos, out var target))
                    RunAction(() => _exec.ExecuteStrike(_current!, target));
                break;

            case PlayerTurnMode.SelectingSpellTarget:
                if (_spellTiles.Contains(pos))
                {
                    string sid = _pendingSpellId;
                    int vi = _pendingVariant;
                    RunAction(() => _exec.ExecuteCast(_current!, sid, vi, pos));
                }
                break;

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
                    if (aid == "sudden-charge")
                        RunAction(() => _exec.ExecuteSuddenChargeTile(_current!, pos));
                    else
                        RunAction(() => _exec.ExecuteSkillAction(_current!, aid, pos));
                }
                break;
        }
    }

    // ---------------------------------------------------------------- Execution

    private async void RunAction(Func<Task<bool>> action)
    {
        if (_busy || _current == null) return;
        _busy = true;
        SetMode(PlayerTurnMode.Idle);
        ClearTransient();
        PublishState();

        try
        {
            await action();
        }
        catch (Exception e)
        {
            Log.Error($"[PlayerTurnController] action failed: {e.Message}");
        }

        _busy = false;

        int remaining = _current?.Actions?.TotalActionsRemaining ?? 0;
        PublishState();

        if (remaining <= 0)
            EndTurnRequested?.Invoke();
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

    private void ClearTransient()
    {
        _moveTiles = new();
        _stepTiles = new();
        _strikeTargets.Clear();
        _spellTiles = new();
        _skillTiles = new();
        _pendingSpellId = "";
        _pendingVariant = -1;
        _pendingSkillId = "";
        _shieldedStride = false;
        HighlightsChanged?.Invoke(Array.Empty<PF2eVec>(), HighlightKind.None);
        PathPreviewChanged?.Invoke(null);
        AttackPreviewChanged?.Invoke(null);
        AreaPreviewChanged?.Invoke(Array.Empty<PF2eVec>());
    }

    private void PublishState()
    {
        if (_current == null) return;
        int actions = _current.Actions?.TotalActionsRemaining ?? 0;

        ButtonStateChanged?.Invoke(new ActionBarState
        {
            ActorName = _current.Name,
            ActionsRemaining = actions,
            MaxActions = _current.Actions?.MaxBaseActions ?? 3,
            CanMove = actions > 0 && _exec.GetReachableTiles(_current).Count > 0,
            CanStep = actions > 0 && _exec.GetStepTiles(_current).Count > 0,
            CanStrike = actions > 0 && _exec.GetStrikeTargets(_current).Count > 0,
            CanRaiseShield = actions > 0 && _current.Equipment?.CanRaiseShield() == true,
            Map = _exec.GetCurrentMap(_current),
            Mode = _mode,
            SpellEntries = _current.Spellcasting != null
                ? _exec.GetSpellEntries(_current)
                : System.Array.Empty<SpellEntryView>(),
            SkillEntries = _exec.GetSkillEntries(_current),
        });
    }

    private AttackPreviewView? BuildPreview(ICharacter attacker, ICharacter target)
    {
        AttackPreviewData? data = _exec.GetAttackPreview(attacker, target);
        if (data == null) return null;

        return new AttackPreviewView
        {
            AttackerName = data.AttackerName,
            TargetName = data.TargetName,
            WeaponName = data.WeaponName,
            Map = data.MAP,
            TotalAttackBonus = data.TotalAttackBonus,
            TargetAc = data.TargetAC,
            HitChancePercent = (int)Math.Round(data.HitChance),
            CritChancePercent = (int)Math.Round(data.CritChance),
            DamageFormula = data.DamageFormula ?? "",
            TargetOffGuard = data.TargetIsOffGuard
        };
    }
}
