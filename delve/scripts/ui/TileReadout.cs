using Godot;

namespace Delve.UI;

/// <summary>
/// The FFT tile readout at the top right: the hovered tile's height in feet as a large number,
/// and its surface under it. Hidden while no tile is hovered. Renders plain values only.
/// </summary>
public partial class TileReadout : Control
{
    private Label _height = null!;
    private Label _surface = null!;

    public string HeightText => _height.Text;

    public override void _Ready()
    {
        _height = GetNode<Label>("%HeightValue");
        _surface = GetNode<Label>("%Surface");
        Visible = false;
    }

    /// <summary>Show a tile, or hide the readout when <paramref name="heightFeet"/> is null.</summary>
    public void Render(int? heightFeet, string surface)
    {
        Visible = heightFeet != null;
        if (heightFeet is not { } feet) return;
        _height.Text = $"{feet} ft";
        _surface.Text = surface;
    }
}
