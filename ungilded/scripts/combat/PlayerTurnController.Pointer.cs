using System;
using System.Collections.Generic;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>Board hover and click, routed by the current mode.</summary>
public sealed partial class PlayerTurnController
{
    public void TileHovered(PF2eVec? pos)
    {
        HoverTileChanged?.Invoke(pos);
        if (_current == null) return;

        switch (_mode)
        {
            case PlayerTurnMode.Moving:
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

            case PlayerTurnMode.SelectingBombTarget:
                if (pos.HasValue && _bombTargets.TryGetValue(pos.Value, out var primary))
                {
                    AttackPreviewChanged?.Invoke(_exec.GetBombPreview(_current, _pendingBombId, primary));
                    AreaPreviewChanged?.Invoke(_exec.GetSplashTiles(primary));
                }
                else
                {
                    AttackPreviewChanged?.Invoke(null);
                    AreaPreviewChanged?.Invoke(Array.Empty<PF2eVec>());
                }
                break;
        }
    }

    /// <summary>The Strike forecast against <paramref name="target"/> while Strike aims and it is a
    /// legal target, else null.</summary>
    public AttackPreviewView? StrikePreview(PF2e.Core.ICharacter target)
        => _mode == PlayerTurnMode.SelectingStrike && _current != null && _strikeTargets.ContainsValue(target)
            ? ActionBarStateBuilder.BuildPreview(_exec, _current, target) : null;

    public void TileClicked(PF2eVec pos)
    {
        if (!Ready()) return;

        if ((_mode is PlayerTurnMode.Moving or PlayerTurnMode.SelectingMove) && MoveFilter?.Invoke(pos) == false)
        {
            MoveRefused?.Invoke(pos);
            return;
        }

        switch (_mode)
        {
            case PlayerTurnMode.Moving:
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
                    RunAction(() => _exec.ExecuteStrike(_current!, target), new PlayerOrder(PlayerOrderKind.Strike, target));
                break;

            case PlayerTurnMode.SelectingBombTarget:
                if (_bombTargets.TryGetValue(pos, out var bombTarget))
                {
                    string bombId = _pendingBombId;
                    RunAction(() => _exec.ExecuteBombThrow(_current!, bombId, bombTarget),
                        new PlayerOrder(PlayerOrderKind.Bomb, bombTarget));
                }
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
}
