using System.Collections.Generic;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>Spell, skill and bomb intents: each enters its target-selection mode or runs at once.</summary>
public sealed partial class PlayerTurnController
{
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

        if (PlayerActionExecutor.IsBombAction(actionId))
        {
            BeginBomb(actionId);
            return;
        }

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
        if (TargetFilter != null)
            plan.Tiles.RemoveWhere(tile => _exec.GetSpellTargetAt(tile) is { } creature && !Targetable(creature));
        if (plan.Tiles.Count == 0) { Cancel(); return; }

        _pendingSkillId = actionId;
        _skillTiles = plan.Tiles;
        SetMode(PlayerTurnMode.SelectingSkillTarget);
        HighlightsChanged?.Invoke(_skillTiles, HighlightFor(plan.Kind));
    }

    /// <summary>Light the foes in range of the bomb; the hover shows its splash, a click throws.</summary>
    private void BeginBomb(string bombId)
    {
        foreach (var target in _exec.GetBombTargets(_current!, bombId))
        {
            if (!Targetable(target)) continue;
            foreach (var tile in CreatureTargetTiles.For(target))
                _bombTargets[tile] = target;
        }
        if (_bombTargets.Count == 0) { Cancel(); return; }
        _pendingBombId = bombId;
        SetMode(PlayerTurnMode.SelectingBombTarget);
        HighlightsChanged?.Invoke(new List<PF2eVec>(_bombTargets.Keys), HighlightKind.SpellEnemyTarget);
    }

    /// <summary>Highlight colour a target-selection mode paints its legal tiles with.</summary>
    private static HighlightKind HighlightFor(TargetingKind kind)
        => (kind == TargetingKind.SingleAlly || kind == TargetingKind.MultiAlly) ? HighlightKind.AllyTarget : HighlightKind.SpellEnemyTarget;
}
