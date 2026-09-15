using System.Collections.Generic;
using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Token picking adapter. Screen picking follows opaque pixels in the current sprite frame,
/// with the same fixed-Y billboard and offsets as the renderer. The retained footprint collider
/// supports physics consumers. Inactive tokens disable both through SetPickable.
/// </summary>
public partial class UnitPickArea : Area3D
{
    private static readonly Dictionary<Vector3, BoxShape3D> Shapes = new();

    [Export] public bool PickThroughTerrain { get; set; }
    public const string PickGroup = "unit_sprite_picking";
    public System.Func<PF2eVec>? GridTile { get; set; }
    public Sprite3D? Sprite { get; set; }
    private readonly Dictionary<Texture2D, Bitmap> _images = new();
    private CollisionShape3D _shape = null!;

    public override void _Ready()
    {
        _shape = GetNode<CollisionShape3D>("%PickShape");
        AddToGroup(PickGroup);
    }

    public override void _ExitTree()
    {
        foreach (var image in _images.Values) image.Dispose();
        _images.Clear();
    }

    /// <summary>Intersect the actual full billboard, including authored anchoring and UV flips.</summary>
    public bool HitSprite(Camera3D camera, Vector3 origin, Vector3 direction, out float distance)
    {
        distance = 0;
        var sprite = Sprite;
        if (_shape.Disabled || !IsVisibleInTree() || sprite?.Texture == null || !sprite.IsVisibleInTree()) return false;
        var right = camera.GlobalBasis.X;
        var up = camera.GlobalBasis.Y;
        if (sprite.Billboard == BaseMaterial3D.BillboardModeEnum.FixedY)
        {
            right = Vector3.Up.Cross(camera.GlobalBasis.Z).Normalized();
            up = Vector3.Up;
        }
        var normal = right.Cross(up);
        float denominator = direction.Dot(normal);
        if (Mathf.Abs(denominator) < 0.00001f) return false;
        distance = (sprite.GlobalPosition - origin).Dot(normal) / denominator;
        if (distance < 0) return false;
        var delta = origin + direction * distance - sprite.GlobalPosition;
        float x = delta.Dot(right) / (sprite.PixelSize * sprite.GlobalBasis.X.Length()) - sprite.Offset.X;
        float y = -delta.Dot(up) / (sprite.PixelSize * sprite.GlobalBasis.Y.Length()) + sprite.Offset.Y;
        int width = sprite.Texture.GetWidth() / sprite.Hframes;
        int height = sprite.Texture.GetHeight() / sprite.Vframes;
        if (sprite.Centered) { x += width * 0.5f; y += height * 0.5f; }
        int px = Mathf.FloorToInt(x), py = Mathf.FloorToInt(y);
        if (px < 0 || py < 0 || px >= width || py >= height) return false;
        if (sprite.FlipH) px = width - 1 - px;
        if (sprite.FlipV) py = height - 1 - py;
        px += sprite.FrameCoords.X * width;
        py += sprite.FrameCoords.Y * height;
        if (!_images.TryGetValue(sprite.Texture, out var image))
        {
            var source = sprite.Texture.GetImage();
            if (source == null) return false;
            using var pixels = (Image)source.Duplicate();
            if (pixels.IsCompressed()) pixels.Decompress();
            image = new Bitmap();
            image.CreateFromImageAlpha(pixels, PixelSprite.ScissorThreshold);
            _images.Add(sprite.Texture, image);
        }
        return image.GetBitv(new Vector2I(px, py));
    }

    /// <summary>Size the column: one footprint wide and deep, <paramref name="height"/> tall, standing
    /// on the token's feet.</summary>
    public void Configure(int tileWidth, float height)
    {
        var size = new Vector3(tileWidth, height, tileWidth);
        if (!Shapes.TryGetValue(size, out var box))
        {
            box = new BoxShape3D { Size = size };
            Shapes[size] = box;
        }
        _shape.Shape = box;
        _shape.Position = new Vector3(0f, height * 0.5f, 0f);
    }

    /// <summary>A corpse is scenery: rays pass through it to the ground.</summary>
    public void SetPickable(bool pickable) => _shape.Disabled = !pickable;

    /// <summary>The logical grid anchor, independent of presentation offsets and animation.</summary>
    public PF2eVec Tile => GridTile?.Invoke() ?? GridSpace.WorldToGrid(GlobalPosition);
}
