using Ungilded.UI;
using Godot;
using PF2e.Core;

namespace Ungilded.Combat;

/// <summary>The enemy-turn band on the centre axis: the attacker card bottom left, the target card
/// bottom right, and the roll row between them, above a docked reaction prompt. On turns that show
/// the action bar the roll row sits above the bar's stack instead.</summary>
public partial class CombatScene
{
    [Export] public float BandGap { get; set; } = 8;
    private UnitInspectPanel _actorCard = null!;
    private UnitInspectPanel _targetCard = null!;
    private float _rollRestBottom;
    private int? _reactionSourceId;

    private void BuildBand()
    {
        _actorCard = GetNode<UnitInspectPanel>("%ActorCard");
        _targetCard = GetNode<UnitInspectPanel>("%TargetCard");
        _rollRestBottom = _dice.OffsetBottom;
    }

    private bool EnemyTurnShowing => _session?.CurrentActor is { TeamId: not 1 } && !_tacticalFinished && !_introPlaying;

    /// <summary>FFT forecast: the attacker card bottom left and the defender card bottom right. On
    /// an enemy turn they show the acting enemy and its target; on a player turn the defender card
    /// shows the unit the player is aiming at, else the hovered unit.</summary>
    private void RefreshBand()
    {
        var actor = _session?.CurrentActor;
        // During a reaction prompt, on any turn, the reactor is the one acting: it takes the left
        // card and the creature that set it off the right.
        ICharacter? reactor = _promptOpen && !_tacticalFinished && _reactorId is { } rid
            && _tacticalUnits.TryGetValue(rid, out var r) ? r.Character : null;
        bool band = reactor != null || EnemyTurnShowing && actor?.Health?.IsAlive == true;
        var left = reactor ?? actor;
        // A pinned hero card takes the left corner from the band's attacker card.
        _actorCardUnit = band && _pinnedHero == null ? left : null;
        _actorCard.Render(_actorCardUnit != null ? InspectFor(_actorCardUnit) : null);
        int? targetId = _pinnedCreature?.UniqueId ?? (reactor != null ? _reactionSourceId ?? actor?.UniqueId
            : band ? _actionTargetId ?? _reactorId : _playerTargetId ?? _hoveredId);
        ICharacter? target = targetId is { } id && _tacticalUnits.TryGetValue(id, out var unit) ? unit.Character : null;
        _targetCardUnit = target != null && target != left && !_tacticalFinished ? target : null;
        _targetCard.Render(_targetCardUnit != null ? InspectFor(_targetCardUnit) : null);
    }

    /// <summary>The units the band's two cards show now, or null.</summary>
    private ICharacter? _actorCardUnit, _targetCardUnit;

    private void LayoutBand()
    {
        float height = _tacticalHud.Size.Y;
        float bottom = height + _rollRestBottom;
        if (_actionBar.Visible) bottom = _actionBar.DecisionTop - BandGap;
        // A prompt beside its trigger is up on the board; only a docked one takes the bottom centre.
        else if (_reactionPrompt.Visible && !_reactionPrompt.Pointing) bottom = _reactionPrompt.BoxRect.Position.Y - BandGap;
        float offset = bottom - height;
        if (Mathf.IsEqualApprox(offset, _dice.OffsetBottom)) return;
        _dice.OffsetBottom = offset;
        _dice.OffsetTop = offset;
    }

    /// <summary>Metres above a unit's feet the command menu centres on: about chest height.</summary>
    [Export] public float MenuAnchorLift { get; set; } = 0.9f;

    /// <summary>Keep the FFT command menu beside the unit whose turn it is, following the camera.
    /// It takes its size step from that unit's HP plate (<see cref="ZoomScale"/>), so the two
    /// shrink to two thirds on the same frame when the view zooms out.</summary>
    private void AnchorCommandMenu()
    {
        if (!_actionBar.Visible || !_actionBar.MenuShown || _session?.CurrentActor is not { } actor
            || !_tacticalUnits.TryGetValue(actor.UniqueId, out var visual)) return;
        var camera = _cameraRig.Camera;
        var point = visual.GlobalPosition + Vector3.Up * MenuAnchorLift;
        if (camera.IsPositionBehind(point)) return;
        // Under canvas_items stretch, UnprojectPosition already returns HUD (canvas) coordinates.
        // An open journal is read during play, so the menu steps aside rather than under it.
        float limit = _journalPanel.Visible ? _journalPanel.GetGlobalRect().Position.X : float.PositiveInfinity;
        _actionBar.AnchorMenu(camera.UnprojectPosition(point), visual.PlateZoom, limit);
    }

    private void ClearBand()
    {
        _actorCardUnit = null;
        _targetCardUnit = null;
        _actorCard.Render(null);
        _targetCard.Render(null);
    }
}
