using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>The enemy-turn band on the centre axis: the attacker card left of the prompt, the target
/// card right of it, and the roll row above the prompt. On turns that show the action bar the roll
/// row sits above the bar's stack instead.</summary>
public partial class CombatScene
{
    [Export] public float BandGap { get; set; } = 8;
    private UnitInspectPanel _actorCard = null!;
    private UnitInspectPanel _targetCard = null!;
    private float _rollRestBottom;

    private void BuildBand()
    {
        _actorCard = GetNode<UnitInspectPanel>("%ActorCard");
        _targetCard = GetNode<UnitInspectPanel>("%TargetCard");
        _rollRestBottom = _dice.OffsetBottom;
    }

    private bool EnemyTurnShowing => _session?.CurrentActor is { TeamId: not 1 } && !_tacticalFinished && !_introPlaying;

    private void RefreshBand()
    {
        var actor = _session?.CurrentActor;
        bool band = EnemyTurnShowing && actor?.Health?.IsAlive == true;
        _actorCard.Render(band ? InspectFor(actor!) : null);
        int? targetId = _actionTargetId ?? _reactorId;
        ICharacter? target = targetId is { } id && _tacticalUnits.TryGetValue(id, out var unit) ? unit.Character : null;
        _targetCard.Render(band && target != null && target != actor ? InspectFor(target) : null);
    }

    private void LayoutBand()
    {
        float height = _tacticalHud.Size.Y;
        float bottom = height + _rollRestBottom;
        if (_actionBar.Visible) bottom = _actionBar.ContentTop - BandGap;
        else if (_reactionPrompt.Visible) bottom = _reactionPrompt.Dock.GetGlobalRect().Position.Y - BandGap;
        float offset = bottom - height;
        if (Mathf.IsEqualApprox(offset, _dice.OffsetBottom)) return;
        _dice.OffsetBottom = offset;
        _dice.OffsetTop = offset;
    }

    private void ClearBand()
    {
        _actorCard.Render(null);
        _targetCard.Render(null);
    }
}
