using Godot;

namespace Delve.Village;

/// <summary>Plays every frame of its sheet in a loop, from the frame it was placed on, so stacked copies stay out of step (chimney smoke).</summary>
public partial class SpriteLoop : Sprite3D
{
    [Export] public float FrameSeconds { get; set; } = 0.18f;

    private float _clock;
    private int _start;

    public override void _Ready() => _start = Frame;

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        _clock += (float)delta;
        int count = Mathf.Max(1, Hframes * Vframes);
        Frame = (_start + (int)(_clock / FrameSeconds)) % count;
        SunShadows.Follow(this);
    }
}
