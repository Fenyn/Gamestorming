using Delve.UI;
using Godot;

namespace Delve.Combat;

/// <summary>
/// A world-space health bar that floats over an entity: a dark background quad and a coloured fill
/// quad that scales across it. It takes a plain 0..1 ratio, so it works for any entity that has a
/// quantity to show. It knows nothing about characters, damage or rules.
///
/// The fill travels to a new value rather than snapping, so a drop reads as a drop. Its colour steps
/// through the palette's HP tiers (<see cref="UiColors.HpFillColor"/>) unless a team colour is set
/// (<see cref="SetTeam"/>), which combat tokens do, FFT style.
/// One stored tween owns scale, position and colour together, so a second hit cannot leave the fill
/// and its colour out of step.
///
/// The bar billboards itself on the CPU. A material billboard cannot replace this: the two quads
/// would each face the camera around their own origin, so the fill would slide off the background at
/// any camera yaw, and the fill would lose its non-uniform scale.
///
/// The quads are authored in screen pixels. Each frame the node scales by the metres one pixel
/// spans at its depth, so the bar keeps one screen size at any zoom, like the name plates.
/// </summary>
public partial class WorldHpBar : Node3D
{
    /// <summary>Metres per quad unit while no camera is known, near the default camera's scale.</summary>
    [Export] public float FallbackMetresPerPixel { get; set; } = 0.0175f;

    /// <summary>Colour of the quad behind the fill.</summary>
    [Export] public Color BackgroundColor { get; set; } = new(0.08f, 0.08f, 0.1f, 0.9f);

    /// <summary>How long the bar takes to travel to a new value. Short enough to finish inside the
    /// hit own beat, long enough that the drop reads as a drop rather than a jump cut.</summary>
    [Export] public float TweenDuration { get; set; } = 0.2f;

    /// <summary>How far the timeline number is lightened from the team colour, so it reads on the
    /// dark outline above the bar.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float NumberLighten { get; set; } = 0.25f;

    /// <summary>Camera depth, metres, around which the bar steps down to two thirds of its screen
    /// size (<see cref="ZoomScale"/>).</summary>
    [Export] public float ZoomFullSizeDistance { get; set; } = 24f;

    /// <summary>The plate's current size step: 1 or <see cref="ZoomScale.Small"/>.</summary>
    public float Zoom { get; private set; } = 1f;

    /// <summary>Plate-pixel extent of the number and bar around the node's centre: the number sits
    /// right-aligned at <see cref="NumberRight"/> left of centre, the bar spans the background quad.</summary>
    [Export] public float NumberRight { get; set; } = 36f;

    private Vector3 _rest;

    /// <summary>Where the plate rests in its token, before any <see cref="Nudge"/>.</summary>
    public Vector3 RestPosition
    {
        get => _rest;
        set { _rest = value; Position = value; }
    }

    /// <summary>Screen pixels the plate is lifted to clear another unit's plate, set each frame by
    /// the scene's plate layout (<see cref="SetNudge"/>). In a pack, labels otherwise land on each
    /// other's bars.</summary>
    public float Nudge { get; private set; }

    /// <summary>Screen rectangle of the number and bar if lifted by <paramref name="nudge"/> pixels,
    /// measured from the rest position without moving the plate.</summary>
    public Rect2 ScreenRect(Camera3D camera, float nudge)
    {
        var centre = camera.UnprojectPosition(GlobalPosition - _lift) - new Vector2(0, nudge);
        var font = _number.Font ?? ThemeDB.FallbackFont;
        float numberWidth = _number.Text.Length == 0 ? 0
            : font.GetStringSize(_number.Text, HorizontalAlignment.Left, -1, _number.FontSize).X + _number.OutlineSize;
        float left = (NumberRight + numberWidth) * Zoom, right = ScreenWidth / 2 * Zoom;
        float half = Mathf.Max(ScreenHeight, _number.FontSize + _number.OutlineSize) / 2 * Zoom;
        return new Rect2(centre.X - left, centre.Y - half, left + right, half * 2);
    }

    private MeshInstance3D _bg = null!;
    private MeshInstance3D _fill = null!;
    private Label3D _number = null!;
    private Color? _teamFill;
    private StandardMaterial3D _fillMat = null!;
    private Tween? _tween;
    private Camera3D? _camera;

    /// <summary>Bar width in metres, read from the fill quad authored in the scene. It is the span the
    /// fill scales across, so an art pass that resizes the quad needs no code change.</summary>
    private float _width = 0.8f;

    /// <summary>Read-only handle on the fill mesh, for callers that must examine it.</summary>
    public MeshInstance3D Fill => _fill;

    /// <summary>Screen width in pixels of the background quad, the bar's outer edge.</summary>
    public float ScreenWidth => _bg.Mesh is QuadMesh background ? background.Size.X : _width;

    /// <summary>Screen height in pixels of the background quad.</summary>
    public float ScreenHeight => _bg.Mesh is QuadMesh background ? background.Size.Y : 0;

    public override void _Ready()
    {
        _bg = GetNode<MeshInstance3D>("HpBarBg");
        _fill = GetNode<MeshInstance3D>("HpFill");
        _number = GetNode<Label3D>("%Number");

        // Per-instance materials stay in code (the fill colour is tweened), assigned as overrides on
        // the scene meshes so the shared scene sub-resources never diverge across bars.
        _bg.MaterialOverride = BarMaterial(BackgroundColor);
        _fillMat = BarMaterial(UiColors.HpHigh);
        _fillMat.RenderPriority = 1;
        _fill.MaterialOverride = _fillMat;

        if (_fill.Mesh is QuadMesh fill) _width = fill.Size.X;
        Scale = Vector3.One * FallbackMetresPerPixel;
    }

    public override void _Process(double delta)
    {
        var camera = ResolveCamera();
        float height = GetViewport()?.GetVisibleRect().Size.Y ?? 0;
        if (camera == null || height <= 0) return;
        Position = _rest;
        float depth = ZoomScale.Depth(camera, GlobalPosition);
        Zoom = ZoomScale.For(depth, ZoomFullSizeDistance, Zoom);
        _pixel = camera.Projection == Camera3D.ProjectionType.Orthogonal
            ? camera.Size / height
            : 2f * Mathf.Tan(Mathf.DegToRad(camera.Fov) / 2f) / height * depth;
        GlobalBasis = camera.GlobalBasis.Scaled(Vector3.One * _pixel * Zoom);
        Lift(camera);
    }

    /// <summary>Metres one screen pixel spans at the plate's depth, as of this frame.</summary>
    private float _pixel;

    /// <summary>The world offset the current <see cref="Nudge"/> adds, so a rest rectangle can be
    /// measured without undoing it.</summary>
    private Vector3 _lift;

    /// <summary>Lift the plate by <paramref name="pixels"/> at once. The scene's plate layout runs
    /// after the plates update, so waiting for the next frame would leave them a frame behind.</summary>
    public void SetNudge(float pixels, Camera3D camera)
    {
        Nudge = pixels;
        Position = _rest;
        Lift(camera);
    }

    private void Lift(Camera3D camera)
    {
        _lift = Nudge != 0 ? camera.GlobalBasis.Y * Nudge * _pixel : Vector3.Zero;
        if (Nudge != 0) GlobalPosition += _lift;
    }

    private Camera3D? ResolveCamera()
    {
        if (_camera != null && IsInstanceValid(_camera)) return _camera;
        _camera = GetViewport()?.GetCamera3D();
        return _camera;
    }

    /// <summary>FFT style: the fill takes one team colour at every HP level and the bar's length
    /// carries the health, and the number beside it is the unit's place on the timeline.</summary>
    public void SetTeam(Color color)
    {
        _teamFill = color;
        _fillMat.AlbedoColor = color;
        _number.Modulate = color.Lightened(NumberLighten);
    }

    /// <summary>Timeline number shown left of the bar; 0 hides it.</summary>
    /// <param name="suffix">An enemy's letter, printed right after the number ("3C").</param>
    public void SetNumber(int number, string suffix = "") => _number.Text = number > 0 ? $"{number}{suffix}" : "";

    public string NumberText => _number.Text;

    /// <param name="ratio">Fill fraction, 0..1. Values outside the range are clamped.</param>
    /// <param name="instant">Snap instead of travelling. Used at spawn, where there is no previous
    /// value to animate from.</param>
    public void SetRatio(float ratio, bool instant = false)
    {
        ratio = Mathf.Clamp(ratio, 0f, 1f);

        // Never scale a mesh through a literal zero axis (renderer det==0 on a singular transform).
        // An emptied bar rests one thousandth wide, which is invisible at any gameplay distance.
        var scale = new Vector3(Mathf.Max(ratio, 0.001f), 1f, 1f);
        var position = new Vector3(-_width * 0.5f + _width * ratio * 0.5f, 0f, _fill.Position.Z);
        Color color = _teamFill ?? UiColors.HpFillColor(ratio);

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
