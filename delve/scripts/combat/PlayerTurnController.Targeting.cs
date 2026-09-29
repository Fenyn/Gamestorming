namespace Delve.Combat;

/// <summary>Spell and skill intents: each enters its target-selection mode or runs at once.</summary>
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
}
