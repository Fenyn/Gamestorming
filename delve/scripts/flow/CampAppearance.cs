using Godot;

namespace Delve.Flow;

/// <summary>Authored rest poses and runtime appearance; original paper-doll layers stay editable.</summary>
[GlobalClass]
public partial class CampAppearance : Resource
{
    [Export] public Texture2D? StandSheet { get; set; }
    [Export] public Texture2D[] RestLayers { get; set; } = System.Array.Empty<Texture2D>();
    [Export] public Vector2I RestCell { get; set; } = new(5, 4);
    [Export] public Godot.Collections.Array<Vector2I> RiseCells { get; set; } = new();
    private Texture2D[]? _poses;

    public Texture2D[] Poses()
    {
        if (_poses != null) return _poses;
        var image = Image.CreateEmpty(512, 512, false, Image.Format.Rgba8);
        foreach (var layer in RestLayers)
        {
            var source = layer.GetImage();
            if (source.IsCompressed()) source.Decompress();
            source.Convert(Image.Format.Rgba8);
            image.BlendRect(source, new Rect2I(0, 0, 512, 512), Vector2I.Zero);
        }
        _poses = new Texture2D[RiseCells.Count + 2];
        _poses[0] = Cell(image, RestCell);
        var standing = StandSheet!.GetImage();
        if (standing.IsCompressed()) standing.Decompress();
        for (int i = 0; i < RiseCells.Count; i++) _poses[i + 1] = Cell(standing, RiseCells[i]);
        _poses[^1] = Cell(standing, Vector2I.Zero);
        return _poses;
    }

    private static Texture2D Cell(Image page, Vector2I cell)
        => ImageTexture.CreateFromImage(page.GetRegion(new Rect2I(cell * 64, new Vector2I(64, 64))));
}
