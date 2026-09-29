using Godot;

namespace Delve.Combat;

/// <summary>Where a token's name plate sits: above the HP bar (actor), below the ring (target), or
/// one line above the actor's lane (reactor).</summary>
public enum PlateLane { Head, Foot, Crown }

/// <summary>
/// A token's board label: the name plate (actor, target, reactor) or, for an enemy with no plate
/// showing, its encounter letter badge (hovered, active, targeted). Both are fixed-size billboards,
/// scaled each frame so one font pixel covers one logical HUD pixel at any distance or zoom. Lane
/// offsets are in those pixels, measured from the HP bar (Head, Crown) or the ring's near edge (Foot).
/// </summary>
public partial class NamePlate3D : Node3D
{
    [Export] public float HeadLift { get; set; } = 24f;
    [Export] public float CrownLift { get; set; } = 52f;
    [Export] public float FootDrop { get; set; } = 16f;

    private Label3D _name = null!;
    private Label3D _badge = null!;
    private bool _retired;
    private PlateLane _lane;
    private float _ringRadius;
    private float _nudge;

    public bool PlateVisible => _name.Visible;
    public bool BadgeVisible => _badge.Visible;
    public PlateLane Lane => _lane;

    public override void _Ready()
    {
        _name = GetNode<Label3D>("%Name");
        _badge = GetNode<Label3D>("%Badge");
        SetMode(false, false);
    }

    public void Configure(string plateText, string letter, Color badgeColor, float ringRadius)
    {
        _name.Text = plateText;
        _badge.Text = letter;
        _badge.Modulate = badgeColor;
        _ringRadius = ringRadius;
    }

    public void SetMode(bool plate, bool badge, PlateLane lane = PlateLane.Head)
    {
        _lane = lane;
        _nudge = 0;
        _name.Visible = plate && !_retired;
        _badge.Visible = badge && !plate && !_retired && _badge.Text.Length > 0;
        _badge.Offset = new Vector2(0, HeadLift);
        SetProcess(_name.Visible || _badge.Visible);
        if (IsProcessing()) FitToScreen();
    }

    /// <summary>Extra pixels along the lane's direction, set by the scene's plate layout to clear
    /// another plate or a Dying badge.</summary>
    public void SetNudge(float pixels)
    {
        _nudge = pixels;
        PlaceName();
    }

    /// <summary>Screen rectangle of the name plate at its current lane and nudge.</summary>
    public Rect2 PlateRect(Camera3D camera)
    {
        var font = _name.Font;
        var size = font.GetStringSize(_name.Text, HorizontalAlignment.Left, -1, _name.FontSize)
            + Vector2.One * _name.OutlineSize;
        var centre = camera.UnprojectPosition(_name.GlobalPosition) + new Vector2(_name.Offset.X, -_name.Offset.Y);
        return new Rect2(centre - size / 2, size);
    }

    public float Nudge => _nudge;

    /// <summary>Screen rectangle the plate would take at <paramref name="nudge"/>, without moving
    /// it: the nudge only shifts the label along its lane (up for Head and Crown, down for Foot).</summary>
    public Rect2 PlateRect(Camera3D camera, float nudge)
    {
        var rect = PlateRect(camera);
        float down = _lane == PlateLane.Foot ? 1f : -1f;
        return rect with { Position = rect.Position + new Vector2(0, down * (nudge - _nudge)) };
    }

    /// <summary>A dead unit's labels never return.</summary>
    public void Retire()
    {
        _retired = true;
        SetMode(false, false);
    }

    public override void _Process(double delta) => FitToScreen();

    private void FitToScreen()
    {
        var camera = GetViewport()?.GetCamera3D();
        float height = GetViewport()?.GetVisibleRect().Size.Y ?? 0;
        if (camera == null || height <= 0) return;
        float pixel = 2f * Mathf.Tan(Mathf.DegToRad(camera.Fov) / 2f) / height;
        _name.PixelSize = pixel;
        _badge.PixelSize = pixel;
        PlaceName();
    }

    private void PlaceName()
    {
        if (_lane != PlateLane.Foot)
        {
            _name.Position = Vector3.Zero;
            _name.Offset = new Vector2(0, (_lane == PlateLane.Crown ? CrownLift : HeadLift) + _nudge);
            return;
        }
        var camera = GetViewport()?.GetCamera3D();
        var toward = camera == null ? Vector3.Zero : camera.GlobalPosition - GlobalPosition;
        toward.Y = 0;
        toward = toward.LengthSquared() > 0.0001f ? toward.Normalized() * _ringRadius : Vector3.Zero;
        _name.Position = new Vector3(0, -Position.Y, 0) + GlobalBasis.Inverse() * toward;
        _name.Offset = new Vector2(0, -FootDrop - _nudge);
    }
}
