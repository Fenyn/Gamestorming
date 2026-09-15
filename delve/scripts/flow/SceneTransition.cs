using System;
using System.Threading.Tasks;
using Godot;

namespace Delve.Flow;

/// <summary>A short, input-blocking chapter fade. The covered callback owns the scene change.</summary>
public partial class SceneTransition : CanvasLayer
{
    [Export] public double FadeSeconds { get; set; } = 0.3;
    [Export] public double HoldSeconds { get; set; } = 0.65;
    private Control _veil = null!;
    private Label _caption = null!;
    private Tween? _tween;
    private int _epoch;
    public bool Busy { get; private set; }

    public override void _Ready()
    {
        _veil = GetNode<Control>("%Veil");
        _caption = GetNode<Label>("%Caption");
        Hide();
    }

    public async Task Play(string caption, Action covered, bool instant = false)
    {
        if (Busy) return;
        if (instant || DisplayServer.GetName() == "headless") { covered(); return; }
        int epoch = ++_epoch;
        Busy = true;
        _caption.Text = caption;
        _veil.Modulate = Colors.Transparent;
        Show();
        try
        {
            await Fade(1, FadeSeconds, epoch);
            if (epoch != _epoch || !IsInsideTree()) return;
            covered();
            await Fade(1, HoldSeconds, epoch);
            if (epoch != _epoch || !IsInsideTree()) return;
            await Fade(0, FadeSeconds, epoch);
        }
        finally
        {
            if (epoch == _epoch && IsInsideTree()) { Busy = false; Hide(); }
        }
    }

    private async Task Fade(float alpha, double seconds, int epoch)
    {
        _tween = CreateTween();
        _tween.TweenProperty(_veil, "modulate:a", alpha, seconds);
        while (epoch == _epoch && IsInsideTree() && _tween.IsRunning())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    public void Cancel()
    {
        ++_epoch;
        _tween?.Kill();
        Busy = false;
        Hide();
    }

    public override void _Input(InputEvent e)
    {
        if (Busy) GetViewport().SetInputAsHandled();
    }

    public override void _ExitTree() => Cancel();
}
