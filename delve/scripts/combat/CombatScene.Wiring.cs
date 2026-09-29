using System.Collections.Generic;
using Delve.UI;
using Godot;

namespace Delve.Combat;

/// <summary>Controller, action bar and session wiring, the board input handlers and the result.</summary>
public partial class CombatScene
{
    private void WireControllerToView()
    {
        _session.CombatantRemoved += character =>
        {
            _tacticalUnits.Remove(character.UniqueId);
            if (_focusedMember == character.UniqueId) _focusedMember = null;
            _presenter.RetireUnit(character);
        };
        _controller.HighlightsChanged += (tiles, kind) => _overlay.SetHighlights(tiles, kind);
        _controller.MoveBandsChanged += bands =>
        {
            _lastBands = bands;
            _moveBands.SetBands(bands);
            _overlay.SetPathBands(bands);
        };
        _controller.HoverTileChanged += tile => _moveBands.SetHoverTile(tile);
        _controller.MoveHoverChanged += hover =>
        {
            _actionBar.SetMoveHint(hover);
            _inspectPanel.PreviewSpend(hover?.Actions ?? 0);
        };
        _controller.PathPreviewChanged += path => { _overlay.SetPathPreview(path); PreviewDestination(path); };
        _controller.AreaPreviewChanged += tiles => _overlay.SetAreaPreview(tiles);
        _controller.AttackPreviewChanged += preview =>
        {
            _actionBar.ShowAttackPreview(preview);
            NotePlayerTarget(preview != null);
            // A Strike costs one action; other aimed actions carry their cost on their own chip.
            if (_controller.Mode == PlayerTurnMode.SelectingStrike) _inspectPanel.PreviewSpend(preview != null ? 1 : 0);
        };
        _controller.ButtonStateChanged += state => _actionBar.Render(state);
        _controller.SpellTargetsChanged += _actionBar.SetSpellTargetSelection;
        _controller.ModeChanged += _ => { ClearStagedOrder(); ClearPartyFocus(); _inspectPanel.PreviewSpend(0); };
        _controller.ActionCompleted += () => _cameraRig.RestorePlanningView();
        _controller.ModeChanged += mode => _actionBar.SetTargetingHint(
            mode is not (PlayerTurnMode.Idle or PlayerTurnMode.Moving), mode == PlayerTurnMode.SelectingDelaySlot);
        _controller.ModeChanged += _ => RefreshCommandPrompt();
        _controller.ModeChanged += _ => RefreshMenuShown();
        _controller.BusyChanged += _ => { RefreshMenuShown(); RefreshCommandPrompt(); };
        _controller.EndTurnRequested += () => _session.RequestEndPlayerTurn();
        _controller.DelayBlockedReason = character => _session.DelayBlockedReason(character);
        _controller.DelayAnchors = _ => _session.GetDelayAnchors();
        _controller.DelayAnchorsChanged += ids =>
        {
            _delayPickIds = new HashSet<int>(ids);
            RefreshTurnOrder();
        };
        _controller.DelayRequested += (_, after) => _session.RequestDelay(after);
    }

    private void WireActionBar()
    {
        _actionBar.ConfirmTargetsPressed += () => _controller.ConfirmSpellTargets();
        _actionBar.SpendPreviewed += actions => _inspectPanel.PreviewSpend(actions);
        _actionBar.ConfirmOrderPressed += ConfirmStagedOrder;
        _actionBar.StagingChanged += () => ClearStagedOrder();
        _actionBar.OverviewPressed += () => { if (!_tacticalHud.ModalActive && !_tacticalFinished) _cameraRig.ToggleOverview(); };
        _actionBar.MovePressed += () => _controller.BeginMove();
        _actionBar.StrikePressed += () => _controller.BeginStrike();
        _actionBar.RaiseShieldPressed += () => _controller.RaiseShield();
        _actionBar.EndTurnPressed += () => _controller.EndTurn();
        _actionBar.DelayPressed += () => _controller.BeginDelay();
        _actionBar.SpellChipPressed += (spellId, variant) => _controller.BeginSpell(spellId, variant);
        _actionBar.SkillChipPressed += actionId => _controller.BeginSkill(actionId);
        _actionBar.AiToggled += on =>
        {
            var actor = _session.CurrentActor;
            if (actor != null) _session.SetAiToggle(actor, on);
        };
        _actionBar.AutoReactToggled += on =>
        {
            var actor = _session.CurrentActor;
            if (actor != null) _session.SetAutoReactions(actor, on);
        };
    }

    private void WireSession()
    {
        var session = _session;
        _session.PlayerTurnStarted += character =>
        {
            if (!ReferenceEquals(_session, session)) return;
            _controller.BeginTurn(character);
            _actionBar.SetInteractable(true);
            _actionBar.SetAiToggle(_session.IsAiToggled(character));
            _actionBar.SetAutoReactToggle(_session.IsAutoReactions(character));
        };
        _session.PlayerTurnEnded += () =>
        {
            if (!ReferenceEquals(_session, session)) return;
            // EndControl clears the overlay through the controller's own transient reset.
            _controller.EndControl();
            _actionBar.SetInteractable(false);
        };
        _session.TurnChanged += () => { if (ReferenceEquals(_session, session)) { ClearPartyFocus(); ClearBoardTargets(); RefreshTurnOrder(); } };
        _session.EncounterFinished += result => { if (ReferenceEquals(_session, session)) ShowResult(result); };
        _session.RecallKnowledgeLearned += (target, degree) =>
        {
            if (ReferenceEquals(_session, session)) OnKnowledgeLearned(target, degree);
        };
    }

    // ---------------------------------------------------------------- Input handlers

    private void OnTileClicked(PF2e.Vector2Int pos) => HandleTacticalClick(pos);

    /// <summary>Forwards hover to the targeting controller (path/attack preview) and, independently,
    /// to the card slot and the board badges. This Node3D reads engine occupancy and hands the UI a
    /// view model, nothing more.</summary>
    private void OnTileHovered(PF2e.Vector2Int? pos)
    {
        _hoveredId = pos.HasValue ? _session.Grid.GetGroundOccupant(pos.Value)?.UniqueId : null;
        if (_stagedTile == null) _controller.TileHovered(pos);
        RefreshCard();
        RefreshPlates();
        RefreshTileReadout(pos);
    }

    private void OnCancel() { ClearStagedOrder(); _controller.Cancel(); }

    private void ShowResult(PF2e.Core.BattleResult result)
    {
        // Only a Team1 win is a victory; everything else (loss OR draw) is scored as a defeat downstream
        // — penalty + day advance — so the banner reads "Defeat" for a draw too rather than lying "Draw".
        string text = result == PF2e.Core.BattleResult.Team1Wins ? "Victory!" : "Defeat";
        Color color = result == PF2e.Core.BattleResult.Team1Wins
            ? UiColors.Victory
            : UiColors.Defeat;
        _tacticalFinished = true;
        ClearStagedOrder();
        if (result == PF2e.Core.BattleResult.Team1Wins || DefeatBannerEnabled)
            _victoryBanner.ShowResult(text, color);
        _actionBar.SetInteractable(false);
        RefreshBarVisibility();
        RefreshPlates();

        EncounterFinished?.Invoke(result);
    }
}
