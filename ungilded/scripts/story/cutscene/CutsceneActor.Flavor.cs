using System;
using System.Collections.Generic;
using Godot;
using Ungilded.Look;

namespace Ungilded.Story.Cutscene;

/// <summary>What an emote bubble showed: the emote and the bubble's foot above the actor's feet.</summary>
public readonly record struct EmoteRecord(Emote Emote, float Height);

/// <summary>The actor's small reactions: the speaker hop, the emote bubble, the glow it carries and
/// its shade in the dark past the lit area.</summary>
public partial class CutsceneActor
{
    /// <summary>Bubble scene for <see cref="ShowEmote"/>.</summary>
    [Export] public PackedScene? EmoteScene { get; set; }

    /// <summary>Hop height in sprite pixels.</summary>
    [Export] public int HopPixels { get; set; } = 2;

    /// <summary>Seconds per one-pixel step of the hop.</summary>
    [Export] public float HopStepSeconds { get; set; } = 0.05f;

    /// <summary>Seconds the hop holds at its top, so a slow frame cannot skip it.</summary>
    [Export] public float HopTopSeconds { get; set; } = 0.12f;

    /// <summary>Sprite pixels between the top of the body and the foot of an emote bubble.</summary>
    [Export] public int EmoteGapPixels { get; set; } = 2;

    /// <summary>Fires as a hop starts.</summary>
    public event Action<CutsceneActor>? Hopped;

    /// <summary>Hops so far.</summary>
    public int Hops { get; private set; }

    /// <summary>Every emote shown, oldest first.</summary>
    public List<EmoteRecord> Emotes { get; } = new();

    /// <summary>True for a creature: it darkens with the terrain past the lit area.</summary>
    public bool ShadeInDark { get; set; }

    /// <summary>Brightness the actor is drawn at, 1 in the lit area.</summary>
    public float Shade { get; private set; } = 1f;

    public bool GlowOn => _glow.On;

    /// <summary>Metres the hop lifts the sprite right now.</summary>
    public float Lift => _body.Position.Y;

    /// <summary>One sprite pixel in metres.</summary>
    public float SpritePixel => Pixel;

    private Node3D _body = null!;
    private CutsceneGlow _glow = null!;
    private Tween? _hop;

    /// <summary>One sprite pixel in metres.</summary>
    private float Pixel => _sprite.PixelSize;

    /// <summary>A short hop of <see cref="HopPixels"/>, one pixel per step so the sprite stays on
    /// its pixel grid. The shadow stays on the floor.</summary>
    public void Hop()
    {
        _hop?.Kill();
        _body.Position = Vector3.Zero;
        var tween = CreateTween();
        _hop = tween;
        // Each step: wait, then set the lift. The step down from the top waits HopTopSeconds.
        var steps = new List<(int Pixels, float Wait)>();
        for (int px = 1; px <= HopPixels; px++) steps.Add((px, HopStepSeconds));
        for (int px = HopPixels - 1; px >= 0; px--) steps.Add((px, px == HopPixels - 1 ? HopTopSeconds : HopStepSeconds));
        foreach (var (px, wait) in steps)
        {
            tween.TweenInterval(wait);
            tween.TweenCallback(Callable.From(() => _body.Position = Vector3.Up * px * Pixel));
        }
        Hops++;
        Hopped?.Invoke(this);
    }

    /// <summary>Pop <paramref name="emote"/> above the head and hold it <paramref name="hold"/> seconds.</summary>
    public void ShowEmote(Emote emote, float hold)
    {
        if (EmoteScene?.Instantiate() is not EmoteBubble bubble) return;
        float height = _sprite.BodyHeight + EmoteGapPixels * Pixel;
        bubble.Position = Vector3.Up * height;
        _body.AddChild(bubble);
        bubble.Play(emote, Pixel, hold);
        Emotes.Add(new EmoteRecord(emote, height));
    }

    /// <summary>Light or put out the glow, <paramref name="height"/> metres above the feet.</summary>
    public void SetGlow(bool on, float height) => _glow.Set(on, height);

    /// <summary>Draw the actor at <paramref name="shade"/> of the look's sprite tint.</summary>
    public void SetShade(float shade)
    {
        Shade = shade;
        var tint = LookScene.ActiveSpriteTint;
        _sprite.Modulate = new Color(tint.R * shade, tint.G * shade, tint.B * shade, tint.A);
    }
}
