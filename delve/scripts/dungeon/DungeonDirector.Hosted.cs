using System;
using Delve.Combat;
using Delve.Flow;
using Delve.Look;
using Delve.Run;
using Godot;

namespace Delve.Dungeon;

public partial class DungeonDirector
{
    /// <summary>Set before adding to the tree. The host owns party, rewards and campaign state.</summary>
    public bool Hosted { get; set; }

    /// <summary>Set before adding to the tree. The host's transition, so camp and descent share one
    /// veil and one busy flag.</summary>
    public SceneTransition? SharedTransition { get; set; }
    public event Action<CombatSetup>? CombatRequested;
    public event Action? FloorCompleted;
    public event Action<RunOutcome>? RunEnded;

    public void SetHostedVisible(bool visible)
    {
        Visible = visible;
        if (!visible) SetHoveredPartyMember(null);
        if (!visible) _details.Close();
        if (Hosted) GetNode<LookScene>("%Look").SetActive(visible);
        GetNode<CanvasLayer>("%Screens").Visible = visible;
        _hud.SetDevelopmentControlsVisible(!Hosted);
        if (!visible) _camera.ProcessMode = ProcessModeEnum.Disabled;
        else if (Phase is not DungeonPhase.Combat and not DungeonPhase.Results)
        {
            _camera.ProcessMode = ProcessModeEnum.Inherit;
            _camera.Camera.Current = true;
        }
    }

    public void StopHosted()
    {
        _epoch++;
        CancelPresentation();
        UnwatchWard();
        _pendingDoorClick = null;
        _doorPress = null;
        _travelTween?.Kill();
        _combat?.EndHostedEncounter();
        _event.Visible = false;
        _rest.Visible = false;
        Phase = DungeonPhase.End;
        SetHostedVisible(false);
    }

    public void CompleteHostedCombat()
    {
        if (!Hosted || Phase != DungeonPhase.Combat) return;
        CompleteRoom();
        SpawnTravelParty(true);
        Frame();
        ShowDoors();
    }

    public void ResumeHosted()
    {
        if (Phase != DungeonPhase.Doors) return;
        SpawnTravelParty(true);
        Frame();
        ShowDoors();
    }
}
