using System;
using System.Threading.Tasks;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>A short, input-blocking chapter fade. The covered callback owns the scene change.</summary>
public partial class SceneTransition : CanvasLayer
{
    [Export] public double FadeSeconds { get; set; } = 0.3;
    [Export] public double HoldSeconds { get; set; } = 0.65;
    private Control _veil = null!;
    private Label _caption = null!;
    private Control _continueHint = null!;
    private Tween? _tween;
    private int _epoch;
    private TaskCompletionSource? _dismissed;
    public bool Busy { get; private set; }

    /// <summary>Headless runs skip transitions unless a spike sets this to test the real fades and holds.</summary>
    public bool PlayWhenHeadless { get; set; }

    /// <summary>True while a held caption waits for a click, Enter or Esc.</summary>
    public bool WaitingForInput => _dismissed != null;

    public override void _Ready()
    {
        _veil = GetNode<Control>("%Veil");
        _caption = GetNode<Label>("%Caption");
        _continueHint = GetNode<Control>("%ContinueHint");
        Hide();
    }

    /// <summary>Fade out, run <paramref name="covered"/>, hold the caption, fade in. With
    /// <paramref name="holdForInput"/> the caption stays until the player dismisses it.</summary>
    public async Task Play(string caption, Action covered, bool instant = false, bool holdForInput = false)
    {
        if (Busy) return;
        if (instant || (DisplayServer.GetName() == "headless" && !PlayWhenHeadless)) { covered(); return; }
        int epoch = ++_epoch;
        Busy = true;
        _skipping = false;
        _caption.Text = caption;
        _continueHint.Visible = false;
        _veil.Modulate = Colors.Transparent;
        Show();
        try
        {
            await Fade(1, FadeSeconds, epoch);
            if (epoch != _epoch || !IsInsideTree()) return;
            covered();
            await Fade(1, HoldSeconds, epoch);
            if (epoch != _epoch || !IsInsideTree()) return;
            if (holdForInput)
            {
                _dismissed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
                _continueHint.Visible = true;
                await _dismissed.Task;
                _dismissed = null;
                _continueHint.Visible = false;
                if (epoch != _epoch || !IsInsideTree()) return;
            }
            await Fade(0, FadeSeconds, epoch);
        }
        finally
        {
            if (epoch == _epoch && IsInsideTree()) { Busy = false; Hide(); }
        }
    }

    /// <summary>Release a held caption, as a click would.</summary>
    public void Dismiss() => _dismissed?.TrySetResult();

    private async Task Fade(float alpha, double seconds, int epoch)
    {
        _tween = CreateTween();
        _tween.TweenProperty(_veil, "modulate:a", alpha, _skipping ? 0 : seconds);
        while (epoch == _epoch && IsInsideTree() && _tween.IsRunning())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    public void Cancel()
    {
        ++_epoch;
        _tween?.Kill();
        Dismiss();
        Busy = false;
        Hide();
    }

    public override void _Input(InputEvent e)
    {
        if (!Busy) return;
        bool press = e is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }
            || e.IsActionPressed(InputNames.Confirm) || e.IsActionPressed(InputNames.UiCancel);
        if (press && WaitingForInput) Dismiss();
        // Any other press rushes the fades: the covered step still runs, only the waiting goes.
        else if (press)
        {
            _skipping = true;
            if (_tween != null && GodotObject.IsInstanceValid(_tween) && _tween.IsRunning()) _tween.CustomStep(3600);
        }
        GetViewport().SetInputAsHandled();
    }

    private bool _skipping;

    /// <summary>True once a press has rushed the current transition.</summary>
    public bool Skipping => _skipping;

    public override void _ExitTree() => Cancel();
}
