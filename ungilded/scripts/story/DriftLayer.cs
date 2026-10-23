using Godot;

namespace Ungilded.Story;

/// <summary>
/// One parallax layer of a <see cref="CrawlScenery"/>. The texture is drawn at the integer scale that
/// covers the scenery's height. A tiling layer repeats across the width with a spare tile each side
/// so the drift never uncovers an edge. A landmark layer (<see cref="Tiles"/> off) is drawn once,
/// centred, and its outermost columns are stretched outward to fill the rest of the width. The
/// scenery sets position from <see cref="Rest"/> plus <see cref="Drift"/> as its page plays.
/// </summary>
[GlobalClass]
public partial class DriftLayer : TextureRect
{
    /// <summary>Screen pixels the layer travels over the scenery's drift time.</summary>
    [Export] public Vector2 Drift { get; set; }

    /// <summary>Repeat the texture across the width. Off for a single landmark such as a sun or a castle.</summary>
    [Export] public bool Tiles { get; set; } = true;

    /// <summary>Position before any drift, set by <see cref="Fit"/>.</summary>
    public Vector2 Rest { get; private set; }

    private TextureRect _leftEdge = null!;
    private TextureRect _rightEdge = null!;

    public override void _Ready()
    {
        _leftEdge = GetNode<TextureRect>("%LeftEdge");
        _rightEdge = GetNode<TextureRect>("%RightEdge");
    }

    /// <summary>Scale and place the layer to cover <paramref name="area"/> and its drift.</summary>
    public void Fit(Vector2 area)
    {
        if (Texture == null) return;
        var tex = Texture.GetSize();
        int scale = Mathf.Max(1, Mathf.CeilToInt(area.Y / tex.Y));
        Scale = Vector2.One * scale;
        float tileWidth = tex.X * scale;
        float y = Mathf.Floor((area.Y - tex.Y * scale) / 2f);
        float reach = area.X + Mathf.Abs(Drift.X);
        if (Tiles)
        {
            StretchMode = StretchModeEnum.Tile;
            int count = Mathf.CeilToInt(reach / tileWidth) + 1;
            Size = new Vector2(tex.X * count, tex.Y);
            Rest = new Vector2(Drift.X < 0f ? 0f : -tileWidth, y);
            _leftEdge.Visible = _rightEdge.Visible = false;
            return;
        }
        StretchMode = StretchModeEnum.Scale;
        Size = tex;
        Rest = new Vector2(Mathf.Floor((area.X - tileWidth) / 2f), y);
        float extent = Mathf.Ceil(reach / scale);
        FitEdge(_leftEdge, 0, -extent, extent, tex);
        FitEdge(_rightEdge, (int)tex.X - 1, tex.X, extent, tex);
    }

    /// <summary>Show one texture column of <paramref name="tex"/> stretched over <paramref name="width"/> texture pixels from <paramref name="x"/>.</summary>
    private void FitEdge(TextureRect edge, int column, float x, float width, Vector2 tex)
    {
        edge.Texture = new AtlasTexture { Atlas = Texture, Region = new Rect2(column, 0, 1, tex.Y) };
        edge.Position = new Vector2(x, 0);
        edge.Size = new Vector2(width, tex.Y);
        edge.Visible = true;
    }
}
