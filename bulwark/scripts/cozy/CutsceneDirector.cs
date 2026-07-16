using Bulwark.Data.Dialogues;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Godot Node that executes staging commands emitted by <see cref="DialogueRunner.StageCommand"/>.
/// Framework-only: enter/exit/move/camera/emote are placeholder implementations that log and
/// immediately signal completion. Fade and wait use tweens/timers. Each command signals completion
/// back to the runner via <see cref="DialogueRunner.StagingComplete"/>.
/// </summary>
public partial class CutsceneDirector : Node
{
    private DialogueRunner? _runner;
    private ColorRect? _fadeOverlay;

    /// <summary>Bind the director to a runner so it can signal staging completion.</summary>
    public void Bind(DialogueRunner runner)
    {
        if (_runner != null)
            _runner.StageCommand -= OnStageCommand;

        _runner = runner;
        _runner.StageCommand += OnStageCommand;
    }

    /// <summary>Unbind from the current runner.</summary>
    public void Unbind()
    {
        if (_runner != null)
            _runner.StageCommand -= OnStageCommand;
        _runner = null;
    }

    private void OnStageCommand(DialogueStep step)
    {
        switch (step.Type)
        {
            case "fade":
                ExecuteFade(step);
                break;

            case "wait":
                ExecuteWait(step);
                break;

            case "enter":
                GD.Print($"[CutsceneDirector] Enter: actor={step.Actor}, marker={step.Marker}");
                _runner?.StagingComplete();
                break;

            case "exit":
                GD.Print($"[CutsceneDirector] Exit: actor={step.Actor}");
                _runner?.StagingComplete();
                break;

            case "move":
                GD.Print($"[CutsceneDirector] Move: actor={step.Actor}, marker={step.Marker}, speed={step.Speed}");
                _runner?.StagingComplete();
                break;

            case "camera":
                GD.Print($"[CutsceneDirector] Camera: marker={step.Marker}, duration={step.Duration}");
                _runner?.StagingComplete();
                break;

            case "emote":
                GD.Print($"[CutsceneDirector] Emote: actor={step.Actor}, emotion={step.Emotion}");
                _runner?.StagingComplete();
                break;

            default:
                GD.PushWarning($"[CutsceneDirector] Unknown staging command: {step.Type}");
                _runner?.StagingComplete();
                break;
        }
    }

    private void ExecuteFade(DialogueStep step)
    {
        float duration = step.Duration ?? 0.5f;
        bool fadeOut = step.Direction == "out";

        EnsureFadeOverlay();
        if (_fadeOverlay == null)
        {
            _runner?.StagingComplete();
            return;
        }

        float fromAlpha = fadeOut ? 0f : 1f;
        float toAlpha = fadeOut ? 1f : 0f;
        _fadeOverlay.Modulate = new Color(0, 0, 0, fromAlpha);
        _fadeOverlay.Visible = true;

        var tween = CreateTween();
        tween.TweenProperty(_fadeOverlay, "modulate:a", toAlpha, duration);
        tween.Finished += () =>
        {
            if (!fadeOut)
                _fadeOverlay.Visible = false;
            _runner?.StagingComplete();
        };
    }

    private void ExecuteWait(DialogueStep step)
    {
        float seconds = step.Seconds ?? 0.5f;
        GetTree().CreateTimer(seconds).Timeout += () => _runner?.StagingComplete();
    }

    private void EnsureFadeOverlay()
    {
        if (_fadeOverlay != null)
            return;

        _fadeOverlay = new ColorRect
        {
            Name = "FadeOverlay",
            Color = Colors.Black,
            Visible = false,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        _fadeOverlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);

        // Add to the scene tree at the highest z level
        var canvas = new CanvasLayer { Name = "FadeCanvas", Layer = 100 };
        AddChild(canvas);
        canvas.AddChild(_fadeOverlay);
    }
}
