using Godot;

namespace Delve.Combat;

/// <summary>
/// A world-space health bar that floats over an entity: a dark background quad and a coloured fill
/// quad that scales across it. It takes a plain 0..1 ratio, so it works for any entity that has a
/// quantity to show. It knows nothing about characters, damage or rules.
///
/// The fill travels to a new value rather than snapping, so a drop reads as a drop. Its colour steps
/// green, yellow, red across the two thresholds. One stored tween owns scale, position and colour
/// together, so a second hit cannot leave the fill and its colour out of step.
///
/// The bar billboards itself on the CPU. A material billboard cannot replace this: the two quads
/// would each face the camera around their own origin, so the fill would slide off the background at
/// any camera yaw, and the fill would lose its non-uniform scale.
/// </summary>
public partial class WorldHpBar : Node3D
{
    /// <summary>Fill colour above <see cref="HighRatio"/>.</summary>
    [Export] public Color HighColor { get; set; } = new(0.25f, 0.8f, 0.25f);

    /// <summary>Fill colour between the two ratios.</summary>
    [Export] public Color MidColor { get; set; } = new(0.9f, 0.8f, 0.15f);

    /// <summary>Fill colour below <see cref="MidRatio"/>.</summary>
    [Export] public Color LowColor { get; set; } = new(0.9f, 0.25f, 0.25f);

    /// <summary>Colour of the quad behind the fill.</summary>
    [Export] public Color BackgroundColor { get; set; } = new(0.08f, 0.08f, 0.1f, 0.9f);

    /// <summary>How long the bar takes to travel to a new value. Short enough to finish inside the
    /// hit own beat, long enough that the drop reads as a drop rather than a jump cut.</summary>
    [Export] public float TweenDuration { get; set; } = 0.2f;

    /// <summary>Ratio above which the fill is <see cref="HighColor"/>.</summary>
    [Export] public float HighRatio { get; set; } = 0.6f;

    /// <summary>Ratio above which the fill is <see cref="MidColor"/>.</summary>
    [Export] public float MidRatio { get; set; } = 0.3f;

    private MeshInstance3D _bg = null!;
    private MeshInstance3D _fill = null!;
    private StandardMaterial3D _fillMat = null!;
    private Tween? _tween;
    private Camera3D? _camera;

    /// <summary>Bar width in metres, read from the fill quad authored in the scene. It is the span the
    /// fill scales across, so an art pass that resizes the quad needs no code change.</summary>
    private float _width = 0.8f;

    /// <summary>Read-only handle on the fill mesh, for callers that must examine it.</summary>
    public MeshInstance3D Fill => _fill;

    public override void _Ready()
    {
        _bg = GetNode<MeshInstance3D>("HpBarBg");
        _fill = GetNode<MeshInstance3D>("HpFill");

        // Per-instance materials stay in code (the fill colour is tweened), assigned as overrides on
        // the scene meshes so the shared scene sub-resources never diverge across bars.
        _bg.MaterialOverride = BarMaterial(BackgroundColor);
        _fillMat = BarMaterial(HighColor);
        _fill.MaterialOverride = _fillMat;

        if (_fill.Mesh is QuadMesh fill) _width = fill.Size.X;
    }

    public override void _Process(double delta)
    {
        var camera = ResolveCamera();
        if (camera != null) GlobalBasis = camera.GlobalBasis;
    }

    private Camera3D? ResolveCamera()
    {
        if (_camera != null && IsInstanceValid(_camera)) return _camera;
        _camera = GetViewport()?.GetCamera3D();
        return _camera;
    }

    /// <param name="ratio">Fill fraction, 0..1. Values outside the range are clamped.</param>
    /// <param name="instant">Snap instead of travelling. Used at spawn, where there is no previous
    /// value to animate from.</param>
    public void SetRatio(float ratio, bool instant = false)
    {
        ratio = Mathf.Clamp(ratio, 0f, 1f);

        // Never scale a mesh through a literal zero axis (renderer det==0 on a singular transform).
        // An emptied bar rests one thousandth wide, which is invisible at any gameplay distance.
        var scale = new Vector3(Mathf.Max(ratio, 0.001f), 1f, 1f);
        var position = new Vector3(-_width * 0.5f + _width * ratio * 0.5f, 0f, 0.001f);
        Color color = ratio > HighRatio ? HighColor : ratio > MidRatio ? MidColor : LowColor;

        _tween?.Kill();
        _tween = null;

        if (instant)
        {
            _fill.Scale = scale;
            _fill.Position = position;
            _fillMat.AlbedoColor = color;
            return;
        }

        _tween = CreateTween();
        _tween.SetParallel(true);
        _tween.TweenProperty(_fill, "scale", scale, TweenDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _tween.TweenProperty(_fill, "position", position, TweenDuration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
        _tween.TweenProperty(_fillMat, "albedo_color", color, TweenDuration);
    }

    private static StandardMaterial3D BarMaterial(Color color) => new()
    {
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
        Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
        AlbedoColor = color,
        CullMode = BaseMaterial3D.CullModeEnum.Disabled,
        NoDepthTest = true,
    };
}
