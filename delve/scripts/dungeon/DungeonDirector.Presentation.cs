using System.Threading.Tasks;
using Delve.Flow;
using Delve.Run;
using Godot;

namespace Delve.Dungeon;

public partial class DungeonDirector
{
    [Export] public double CombatReturnSeconds { get; set; } = 0.65;
    [Export] public double HudRevealSeconds { get; set; } = 0.25;
    private SceneTransition _transition = null!;
    private Tween? _returnTween;

    private void CancelPresentation()
    {
        _transition.Cancel();
        _returnTween?.Kill();
        _hud.Modulate = Colors.White;
    }

    public async Task ReturnFromHostedCombat(Transform3D pose, float fov)
    {
        if (!Hosted || Phase != DungeonPhase.Combat) return;
        if (AutoPlayCombat || DisplayServer.GetName() == "headless") { CompleteHostedCombat(); return; }
        int epoch = _epoch;
        Current.Resolved = true;
        Current.Completed = true;
        CurrentView.SetResolved();
        SpawnTravelParty(true);
        Frame();
        var target = _camera.Camera.GlobalTransform;
        float targetFov = _camera.Camera.Fov;
        Phase = DungeonPhase.Transition;
        _camera.ProcessMode = ProcessModeEnum.Disabled;
        RefreshHud();
        _camera.Camera.GlobalTransform = pose;
        _camera.Camera.Fov = fov;
        _returnTween = CreateTween();
        _returnTween.TweenMethod(Callable.From<float>(t =>
        {
            _camera.Camera.GlobalTransform = pose.InterpolateWith(target, t);
            _camera.Camera.Fov = Mathf.Lerp(fov, targetFov, t);
        }), 0f, 1f, CombatReturnSeconds).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        while (epoch == _epoch && IsInsideTree() && _returnTween.IsRunning())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (epoch != _epoch || !IsInsideTree()) return;
        ShowDoors();
        _hud.Modulate = Colors.Transparent;
        _returnTween = CreateTween();
        _returnTween.TweenProperty(_hud, "modulate:a", 1.0, HudRevealSeconds);
    }

    public void ShowPartyNotice(string message) => _hud.ShowNotice(message);
}
