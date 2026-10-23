using Godot;

namespace Ungilded.Story;

/// <summary>
/// A TextureRect that plays one animation of a <see cref="SpriteFrames"/>, honouring its speed,
/// per-frame durations and loop flag. Playing the animation already on screen keeps its frame.
/// <see cref="Overlay"/> shows the same animation and frame from the accessory frames, mirrored
/// with the face, and hides when no accessory is set.
/// </summary>
public partial class PortraitView : TextureRect
{
    [Export] public TextureRect? Overlay { get; set; }

    public StringName CurrentAnimation { get; private set; } = "";

    public bool OverlayShown => Overlay?.Visible == true;

    private SpriteFrames? _frames;
    private SpriteFrames? _accessory;
    private int _frame;
    private double _elapsed;

    public override void _Ready()
    {
        SetProcess(false);
        ShowFrame();
    }

    public void Play(SpriteFrames? frames, StringName animation)
    {
        if (frames == _frames && animation == CurrentAnimation) return;
        _frames = frames;
        CurrentAnimation = animation;
        _frame = 0;
        _elapsed = 0;
        bool valid = HasFrame(frames);
        ShowFrame();
        SetProcess(valid && frames!.GetFrameCount(animation) > 1 && frames.GetAnimationSpeed(animation) > 0);
    }

    /// <summary>Overlay frames to draw over the face, or null for none.</summary>
    public void SetAccessory(SpriteFrames? frames)
    {
        _accessory = frames;
        ShowFrame();
    }

    public override void _Process(double delta)
    {
        if (_frames == null) return;
        _elapsed += delta;
        int count = _frames.GetFrameCount(CurrentAnimation);
        double speed = _frames.GetAnimationSpeed(CurrentAnimation);
        while (_elapsed >= FrameSeconds(speed))
        {
            _elapsed -= FrameSeconds(speed);
            if (_frame + 1 < count) _frame++;
            else if (_frames.GetAnimationLoop(CurrentAnimation)) _frame = 0;
            else { SetProcess(false); break; }
        }
        ShowFrame();
    }

    private void ShowFrame()
    {
        bool face = HasFrame(_frames);
        Texture = face ? _frames!.GetFrameTexture(CurrentAnimation, _frame) : null;
        if (Overlay == null) return;
        bool worn = face && HasFrame(_accessory);
        Overlay.Texture = worn ? _accessory!.GetFrameTexture(CurrentAnimation, _frame) : null;
        Overlay.FlipH = FlipH;
        Overlay.Visible = worn;
    }

    private bool HasFrame(SpriteFrames? frames) =>
        frames != null && frames.HasAnimation(CurrentAnimation) && frames.GetFrameCount(CurrentAnimation) > _frame;

    private double FrameSeconds(double speed) =>
        _frames!.GetFrameDuration(CurrentAnimation, _frame) / speed;
}
