using Delve.UI;
using Godot;
using PF2e.Conditions;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>
/// The one condition mark on the board: a dying unit's Dying icon and value on an ink plate with an
/// accent top edge, left of its HP bar so it never covers the unit behind. Every part is drawn under
/// the name plates. The node sits at the HP bar's centre; each frame it faces the camera like the bar
/// and lays the parts out leftward from the bar's edge in screen pixels.
/// </summary>
public partial class DyingBadge : Node3D
{
    [Export] public ConditionIconSet Icons { get; set; } = null!;
    /// <summary>Screen pixels per art pixel; the pack's art is 22 px.</summary>
    [Export] public int IconScale { get; set; } = 1;
    [Export] public int NativeIconSize { get; set; } = 22;
    /// <summary>Screen pixels between the plate and the bar, and between the icon and the value.</summary>
    [Export] public float Gap { get; set; } = 4;
    [Export] public float Padding { get; set; } = 3;
    [Export] public float EdgeHeight { get; set; } = 2;

    private Sprite3D _icon = null!;
    private Label3D _value = null!;
    private MeshInstance3D _plate = null!;
    private MeshInstance3D _edge = null!;
    private ICharacter? _character;
    private float _barHalfPixels;

    /// <summary>The Dying value on show, 0 while hidden.</summary>
    public int Value { get; private set; }

    private float IconPixels => NativeIconSize * IconScale;

    public override void _Ready()
    {
        _icon = GetNode<Sprite3D>("%DyingIcon");
        _value = GetNode<Label3D>("%DyingValue");
        _plate = GetNode<MeshInstance3D>("%DyingPlate");
        _edge = GetNode<MeshInstance3D>("%DyingEdge");
        _icon.Texture = Icons.Find(nameof(Condition.Dying));
        _value.Modulate = UiColors.Text;
        _value.OutlineModulate = UiColors.Ink;
        _plate.MaterialOverride = Flat(UiColors.Ink, _icon.RenderPriority - 2);
        _edge.MaterialOverride = Flat(UiColors.Accent, _icon.RenderPriority - 1);
        Visible = false;
    }

    /// <param name="barScreenWidth">The HP bar's width in screen pixels; the badge sits left of it.</param>
    public void Configure(ICharacter character, float barScreenWidth)
    {
        _character = character;
        _barHalfPixels = barScreenWidth / 2;
    }

    /// <summary>Screen rectangle of the plate for this frame's camera, or null while hidden.</summary>
    public Rect2? ScreenRect(Camera3D camera)
    {
        if (!IsVisibleInTree() || camera.IsPositionBehind(_value.GlobalPosition)) return null;
        var size = PlateSize();
        var edge = camera.UnprojectPosition(GlobalPosition) - new Vector2(_barHalfPixels, 0);
        return new Rect2(edge.X - Gap - size.X, edge.Y - size.Y / 2, size.X, size.Y);
    }

    public override void _Process(double delta)
    {
        Value = _character?.Health?.IsDead == false ? _character.Conditions?.GetConditionValue(Condition.Dying) ?? 0 : 0;
        var camera = GetViewport()?.GetCamera3D();
        float height = GetViewport()?.GetVisibleRect().Size.Y ?? 0;
        Visible = Value > 0 && camera != null && height > 0;
        if (!Visible) return;
        GlobalBasis = camera!.GlobalBasis;
        float pixel = 2f * Mathf.Tan(Mathf.DegToRad(camera.Fov) / 2f) / height;
        float unit = pixel * (GlobalPosition - camera.GlobalPosition).Dot(-camera.GlobalBasis.Z);
        _value.Text = Value.ToString();
        _value.PixelSize = pixel;
        var anchor = new Vector3(-_barHalfPixels * unit, 0, 0);
        _value.Position = anchor;
        _icon.Position = anchor;
        float valueWidth = ValueWidth();
        _value.Offset = new Vector2(-Gap - Padding - valueWidth / 2, 0);
        int texture = _icon.Texture?.GetWidth() ?? 1;
        _icon.PixelSize = pixel * IconPixels / texture;
        _icon.Offset = new Vector2(-(2 * Gap + Padding + valueWidth + IconPixels / 2) * texture / IconPixels, 0);

        var size = PlateSize();
        float centre = -(Gap + size.X / 2);
        _plate.Position = anchor + new Vector3(centre * unit, 0, 0);
        _plate.Scale = new Vector3(size.X * unit, size.Y * unit, 1);
        _edge.Position = anchor + new Vector3(centre * unit, (size.Y - EdgeHeight) / 2 * unit, 0);
        _edge.Scale = new Vector3(size.X * unit, EdgeHeight * unit, 1);
    }

    private Vector2 PlateSize()
        => new(IconPixels + Gap + ValueWidth() + 2 * Padding, Mathf.Max(IconPixels, _value.FontSize + _value.OutlineSize) + 2 * Padding);

    private float ValueWidth()
        => _value.Font.GetStringSize(_value.Text, HorizontalAlignment.Left, -1, _value.FontSize).X + _value.OutlineSize;

    private static StandardMaterial3D Flat(Color color, int priority) => new()
    {
        RenderPriority = priority,
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
        Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
        AlbedoColor = color,
        CullMode = BaseMaterial3D.CullModeEnum.Disabled,
        NoDepthTest = true,
    };
}
