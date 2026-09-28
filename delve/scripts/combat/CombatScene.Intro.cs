using System.Threading;
using System.Threading.Tasks;
using Delve.UI;
using Godot;

namespace Delve.Combat;

/// <summary>The fight intro: title fade and camera reveal. A click, confirm or decline skips it.
/// Board input and the action bar wait until it ends.</summary>
public partial class CombatScene
{
    [Export] public double IntroFadeInSeconds { get; set; } = 0.2;
    [Export] public double IntroHoldSeconds { get; set; } = 1.05;
    [Export] public double IntroFadeOutSeconds { get; set; } = 0.3;
    private bool _introPlaying;

    public bool IntroPlaying => _introPlaying;

    private async Task RunIntroAndEncounter(CombatSession session, CombatSetup setup,
        Transform3D? outgoingPose, float outgoingFov, CancellationToken token)
    {
        try
        {
            // Headless simulations retain their immediate turn-start contract.
            if (EncounterIntroEnabled && DisplayServer.GetName() != "headless")
            {
                var intro = GetNode<Control>("%EncounterIntro");
                GetNode<Label>("%EncounterSubtitle").Text = $"{setup.Enemies.Count} {(setup.Enemies.Count == 1 ? "foe" : "foes")} ahead"
                    + (setup.Allies.Count > 0 ? $"\n{setup.Allies[0].Unit.Name} fights beside you as an ally." : "");
                intro.Modulate = Colors.Transparent;
                intro.Show();
                _input.ProcessMode = ProcessModeEnum.Disabled;
                SetIntroPlaying(true);
                _introFade = CreateTween();
                _introFade.TweenProperty(intro, "modulate", Colors.White, IntroFadeInSeconds);
                _introFade.TweenInterval(IntroHoldSeconds);
                _introFade.TweenProperty(intro, "modulate", Colors.Transparent, IntroFadeOutSeconds);
                await _cameraRig.PlayIntro(outgoingPose ?? _cameraRig.Camera.GlobalTransform, outgoingFov, token);
                token.ThrowIfCancellationRequested();
                EndIntro();
            }
            await session.RunAsync(token);
        }
        catch (System.OperationCanceledException) { }
    }

    /// <summary>Finish the title fade and the camera reveal at once.</summary>
    public void SkipIntro()
    {
        if (!_introPlaying) return;
        if (_introFade?.IsValid() == true)
            _introFade.CustomStep(2 * (IntroFadeInSeconds + IntroHoldSeconds + IntroFadeOutSeconds));
        _cameraRig.SkipIntro();
    }

    private void EndIntro()
    {
        _introFade?.Kill();
        _introFade = null;
        GetNodeOrNull<Control>("%EncounterIntro")?.Hide();
        if (_input != null) _input.ProcessMode = ProcessModeEnum.Inherit;
        if (!_introPlaying) return;
        SetIntroPlaying(false);
    }

    private void SetIntroPlaying(bool playing)
    {
        _introPlaying = playing;
        GetNode<HudRoot>("%HudRoot").IntroPlaying = playing;
        if (playing) _journalPanel.Visible = false;
        RefreshBarVisibility();
    }

    public override void _Input(InputEvent @event)
    {
        if (!_introPlaying) return;
        bool skip = @event is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true }
            || @event.IsActionPressed(InputNames.Confirm) || @event.IsActionPressed(InputNames.Decline);
        if (!skip) return;
        GetViewport().SetInputAsHandled();
        SkipIntro();
    }
}
