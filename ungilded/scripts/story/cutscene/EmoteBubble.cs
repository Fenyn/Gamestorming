using Godot;

namespace Ungilded.Story.Cutscene;

/// <summary>
/// One emote bubble: the sheet's pop-in frames, then the emote's two frames in turn while it holds,
/// then a fade, then it frees itself. Its origin is the bubble's foot: the bottom of the trailing dots.
/// </summary>
public partial class EmoteBubble : Sprite3D
{
    [Export] public float PopFrameSeconds { get; set; } = 0.06f;

    [Export] public float IconFrameSeconds { get; set; } = 0.3f;

    [Export] public float FadeSeconds { get; set; } = 0.3f;

    /// <summary>Frames in the pop-in row; each emote row holds two frames.</summary>
    [Export] public int PopFrames { get; set; } = 4;

    /// <summary>Empty pixel rows at the bottom of a frame, under the trailing dots.</summary>
    [Export] public int FootPaddingPixels { get; set; } = 8;

    /// <summary>Plays one emote. <paramref name="pixel"/> is the carrier's sprite pixel in metres, so
    /// the bubble's pixels match the body's.</summary>
    public void Play(Emote emote, float pixel, float hold)
    {
        PixelSize = pixel;
        Centered = true;
        float frameHeight = Texture != null ? Texture.GetHeight() / (float)Vframes : 0f;
        Offset = new Vector2(0f, frameHeight * 0.5f - FootPaddingPixels);
        int row = 1 + (int)emote;
        var tween = CreateTween();
        for (int f = 0; f < PopFrames; f++)
        {
            int frame = f;
            tween.TweenCallback(Callable.From(() => Frame = frame));
            tween.TweenInterval(PopFrameSeconds);
        }
        int beats = Mathf.Max(1, Mathf.RoundToInt(hold / Mathf.Max(IconFrameSeconds, 0.01f)));
        for (int b = 0; b < beats; b++)
        {
            int frame = row * Hframes + b % 2;
            tween.TweenCallback(Callable.From(() => Frame = frame));
            tween.TweenInterval(IconFrameSeconds);
        }
        tween.TweenProperty(this, "modulate:a", 0f, FadeSeconds);
        tween.TweenCallback(Callable.From(QueueFree));
    }
}
