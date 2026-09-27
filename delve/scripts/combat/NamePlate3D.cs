using Godot;

namespace Delve.Combat;

/// <summary>
/// A token's board label: the name plate (actor, target, reactor) or, for an enemy with no plate
/// showing, its encounter letter badge (hovered, active, targeted). Both are fixed-size billboards,
/// scaled each frame so one font pixel covers one logical HUD pixel at any distance or zoom.
/// </summary>
public partial class NamePlate3D : Node3D
{
    private Label3D _name = null!;
    private Label3D _badge = null!;
    private bool _retired;

    public bool PlateVisible => _name.Visible;
    public bool BadgeVisible => _badge.Visible;

    public override void _Ready()
    {
        _name = GetNode<Label3D>("%Name");
        _badge = GetNode<Label3D>("%Badge");
        SetMode(false, false);
    }

    public void Configure(string plateText, string letter, Color badgeColor)
    {
        _name.Text = plateText;
        _badge.Text = letter;
        _badge.Modulate = badgeColor;
    }

    public void SetMode(bool plate, bool badge)
    {
        _name.Visible = plate && !_retired;
        _badge.Visible = badge && !plate && !_retired && _badge.Text.Length > 0;
        SetProcess(_name.Visible || _badge.Visible);
        if (IsProcessing()) FitToScreen();
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
    }
}
