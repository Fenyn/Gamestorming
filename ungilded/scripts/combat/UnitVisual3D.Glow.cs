using Godot;
using Ungilded.Story;
using Ungilded.Story.Cutscene;

namespace Ungilded.Combat;

/// <summary>The glow of an accessory the unit carries or wears (the Prologue's spectacles): the
/// %Glow child at satchel height, or at eye height and toward the face side. A move between the two
/// tweens; on and off fade.</summary>
public partial class UnitVisual3D
{
    /// <summary>Metres above the feet of a carried accessory's glow: satchel height.</summary>
    [Export] public float CarriedGlowHeight { get; set; } = 0.5f;

    /// <summary>Eye height as a share of the sprite's body height, for a worn accessory's glow.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float EyeShareOfBody { get; set; } = 0.85f;

    /// <summary>How far the eyes sit from the sprite's centre line toward the face, as a share of the
    /// body height.</summary>
    [Export(PropertyHint.Range, "0,0.5,0.01")] public float EyeSideShareOfBody { get; set; } = 0.13f;

    /// <summary>Seconds the glow takes to move between satchel and eyes.</summary>
    [Export] public float GlowMoveSeconds { get; set; } = 0.6f;

    private CutsceneGlow? _glow;
    private Tween? _glowMove;
    private float _glowSide;
    private bool _glowFollows;

    public bool GlowLit => _glow?.On == true;

    /// <summary>Metres above the feet the glow sits at, or moves to.</summary>
    public float GlowHeight { get; private set; }

    /// <summary>Metres above the feet the glow is at this frame.</summary>
    public float GlowShownHeight => _glow?.Position.Y ?? 0f;

    /// <summary>World height (m) of the body the worn glow's eye height is a share of.</summary>
    public float GlowBodyHeight => _sprite.BodyHeight > 0f ? _sprite.BodyHeight : _hpBarY;

    public void ShowAccessory(AccessoryState state)
    {
        _glow ??= GetNode<CutsceneGlow>("%Glow");
        if (!_glowFollows)
        {
            _glowFollows = true;
            GetTree().ProcessFrame += PlaceGlowSide;
            TreeExiting += () => GetTree().ProcessFrame -= PlaceGlowSide;
        }
        float height = AccessoryGlow.Height(state, GlowBodyHeight, CarriedGlowHeight, EyeShareOfBody, _glow.Position.Y);
        float side = AccessoryGlow.Side(state, GlowBodyHeight, EyeSideShareOfBody);
        bool on = state != AccessoryState.Hidden;
        _glowMove?.Kill();
        if (on && _glow.On)
        {
            _glowMove = CreateTween().SetParallel().SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
            _glowMove.TweenProperty(_glow, "position:y", height, GlowMoveSeconds);
            _glowMove.TweenMethod(Callable.From<float>(s => _glowSide = s), _glowSide, side, GlowMoveSeconds);
        }
        else if (on != _glow.On)
        {
            _glow.Set(on, height);
            if (on) _glowSide = side;
        }
        GlowHeight = height;
    }

    /// <summary>Keep the glow toward the face side as the camera turns and the sprite flips.</summary>
    private void PlaceGlowSide()
    {
        if (_glow == null || !_glow.On) return;
        var beside = AccessoryGlow.Beside(this, _sprite.FlipH, _glowSide);
        _glow.Position = new Vector3(beside.X, _glow.Position.Y, beside.Z);
    }
}
