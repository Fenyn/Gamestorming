using Godot;

namespace Delve.Combat;

/// <summary>Plays SpriteFrames on the existing Sprite3D without changing its effects interface.</summary>
public sealed class EnemyAnimationPlayer
{
    private SpriteFrames? _frames;
    private double _elapsed;
    private double _cycleDuration;
    public StringName Animation { get; private set; } = "";
    public int FrameIndex { get; private set; }
    public bool Playing { get; private set; }
    public Texture2D? Texture => _frames?.GetFrameTexture(Animation, FrameIndex);

    public bool Play(SpriteFrames? frames, StringName name)
    {
        if (frames == null || !frames.HasAnimation(name) || frames.GetFrameCount(name) == 0)
            return false;
        _frames = frames;
        Animation = name;
        FrameIndex = 0;
        _elapsed = 0;
        _cycleDuration = 0;
        for (int i = 0; i < frames.GetFrameCount(name); i++)
            _cycleDuration += frames.GetFrameDuration(name, i);
        Playing = true;
        return true;
    }

    public void Clear()
    {
        _frames = null;
        Animation = "";
        Playing = false;
        FrameIndex = 0;
        _elapsed = 0;
    }

    public void Tick(double delta)
    {
        if (!Playing || _frames == null || delta <= 0) return;
        double speed = _frames.GetAnimationSpeed(Animation);
        if (speed <= 0 || _cycleDuration <= 0) return;
        _elapsed += delta * speed;
        bool loop = _frames.GetAnimationLoop(Animation);
        if (loop) _elapsed %= _cycleDuration;
        while (_elapsed >= _frames.GetFrameDuration(Animation, FrameIndex))
        {
            _elapsed -= _frames.GetFrameDuration(Animation, FrameIndex);
            if (FrameIndex + 1 < _frames.GetFrameCount(Animation)) FrameIndex++;
            else if (loop) FrameIndex = 0;
            else { Playing = false; _elapsed = 0; break; }
        }
    }
}
