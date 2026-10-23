using System.Linq;
using Godot;
using Ungilded.Props;

namespace Ungilded.Combat;

/// <summary>
/// A hand lantern pinned to a hero body (scenes/combat/hand_lantern.tscn): a lit pixel sprite hung
/// from a pixel of the body's frame, its flame glow and its light. It sits on the body's billboard
/// in the body's own pixel grid, so the body's frames stay untouched, and follows the body's flip.
/// It sways while its carrier moves and hangs still at rest. The owner binds it to the body and
/// names the carrier; it shows only for the ids in <see cref="Carriers"/>.
/// </summary>
public partial class HandLantern : Sprite3D
{
    /// <summary>Hero ids that carry the lantern.</summary>
    [Export] public string[] Carriers { get; set; } = { "friend" };

    /// <summary>Body frame pixel (from the top left, facing right) the lantern's ring hangs from. The
    /// hand does not move in the rest clip, so one point serves every frame.</summary>
    [Export] public Vector2I HookPixel { get; set; } = new(29, 45);

    /// <summary>Largest sideways swing, body pixels.</summary>
    [Export] public float SwayPixels { get; set; } = 2f;

    /// <summary>Swings per second while the carrier walks.</summary>
    [Export] public float SwayRate { get; set; } = 1.6f;

    /// <summary>Carrier speed, metres per second, at which the sway is full.</summary>
    [Export] public float FullSwaySpeed { get; set; } = 1.5f;

    /// <summary>How fast the sway follows the carrier's speed, per second.</summary>
    [Export] public float SwayEase { get; set; } = 6f;

    /// <summary>The light's place from the lantern: x up, y toward the camera, metres.</summary>
    [Export] public Vector2 LightLead { get; set; } = new(0.15f, 0.3f);

    /// <summary>The glow's distance toward the camera from the flame, metres.</summary>
    [Export] public float GlowLead { get; set; } = 0.05f;

    /// <summary>Lantern pixel rows from its top edge to the flame's middle.</summary>
    [Export] public int FlameRow { get; set; } = 6;

    /// <summary>Seconds the light and glow take to go out, or to light again.</summary>
    [Export] public float FadeSeconds { get; set; } = 1f;

    [Export] public FlickerLight Light { get; set; } = null!;
    [Export] public Node3D Glow { get; set; } = null!;

    private Sprite3D? _body;
    private System.Func<bool>? _burning;
    private Vector3 _lastPosition;
    private float _sway;
    private float _phase;
    private float _level = 1f;

    /// <summary>Hang the lantern on <paramref name="body"/> if <paramref name="carrierId"/> carries one.
    /// While <paramref name="burning"/> returns false (the carrier is dying or dead) the light and
    /// glow fade out; the lantern sprite stays.</summary>
    public void Bind(Sprite3D body, string carrierId, System.Func<bool>? burning = null)
    {
        _body = body;
        _burning = burning;
        Visible = Carriers.Contains(carrierId);
        _lastPosition = GlobalPosition;
    }

    public override void _Process(double delta)
    {
        if (!Visible || _body == null) return;
        float dt = Mathf.Max((float)delta, 0.0001f);
        float target = _burning?.Invoke() ?? true ? 1f : 0f;
        _level = Mathf.MoveToward(_level, target, dt / Mathf.Max(FadeSeconds, 0.01f));
        Light.Level = _level;
        var position = GlobalPosition;
        float speed = new Vector2(position.X - _lastPosition.X, position.Z - _lastPosition.Z).Length() / dt;
        _lastPosition = position;
        _sway = Mathf.Lerp(_sway, Mathf.Clamp(speed / FullSwaySpeed, 0f, 1f), 1f - Mathf.Exp(-SwayEase * dt));
        _phase += dt * SwayRate * Mathf.Tau * _sway;

        if (_body.Texture is not { } sheet || Texture == null) return;
        PixelSize = _body.PixelSize;
        FlipH = _body.FlipH;
        int bodyWidth = sheet.GetWidth() / _body.Hframes, bodyHeight = sheet.GetHeight() / _body.Vframes;
        int column = _body.FlipH ? bodyWidth - 1 - HookPixel.X : HookPixel.X;
        float swing = Mathf.Round(SwayPixels * _sway * Mathf.Sin(_phase));
        Offset = new Vector2(
            column + 0.5f - bodyWidth * 0.5f + _body.Offset.X + swing,
            bodyHeight * 0.5f - HookPixel.Y - Texture.GetHeight() * 0.5f + _body.Offset.Y);
        PlaceLights();
    }

    /// <summary>The sprite is a billboard, so its offset lies in the camera's plane; the light and
    /// glow follow it there.</summary>
    private void PlaceLights()
    {
        var camera = GetViewport()?.GetCamera3D();
        if (camera == null || Texture == null) return;
        var basis = camera.GlobalBasis;
        float hookToFlame = Texture.GetHeight() * 0.5f - FlameRow;
        var flame = GlobalPosition + (basis.X * Offset.X + basis.Y * (Offset.Y + hookToFlame)) * PixelSize;
        Glow.GlobalPosition = flame + basis.Z * GlowLead;
        Light.GlobalPosition = flame + Vector3.Up * LightLead.X + basis.Z * LightLead.Y;
    }
}
