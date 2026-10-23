using Godot;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>
/// Hangs props on wall faces under one parent: scenes and flat pixel sprites turned out of the
/// face, shaded for the halo, and handed to the cutaway so they hide while their wall is cut.
/// </summary>
public sealed class WallProps
{
    private readonly Node3D _parent;
    private readonly TerrainCutaway? _cutaway;

    public WallProps(Node3D parent, TerrainCutaway? cutaway, float inset)
    {
        _parent = parent;
        _cutaway = cutaway;
        Inset = inset;
    }

    /// <summary>Gap between a prop and its wall, metres, so it never z-fights the bricks.</summary>
    public float Inset { get; }

    /// <summary>Unit vector out of the face, on the floor plane.</summary>
    public static Vector3 Out(WallFace face) => new(face.Normal.X, 0f, face.Normal.Y);

    /// <summary>With <paramref name="keepLights"/> the prop's lights stay on while its wall is cut
    /// and only its visuals hide.</summary>
    public Node3D? AddScene(PackedScene scene, WallFace face, Vector3 at, float shade, bool keepLights = false)
    {
        if (scene.Instantiate() is not Node3D prop) return null;
        prop.Name = $"{prop.Name}_{face.Wall.x}_{face.Wall.y}";
        prop.Transform = new Transform3D(face.Facing, at);
        _parent.AddChild(prop);
        if (shade < 1f) Shade(prop, shade);
        _cutaway?.Track(prop, face.Wall.x, face.Wall.y, keepLights);
        return prop;
    }

    /// <summary>A stain on the wall behind a pipe: it sits between the bricks and the pipe, so the
    /// pipe draws over it.</summary>
    public void AddStain(DecorSprite? stain, WallFace face, int margin, float shade)
    {
        if (stain != null) AddSprite("PipeStain", stain, face, margin, 0f, Inset * StainDepth, shade, onWall: true);
    }

    /// <summary>A stain's gap from the wall as a share of <see cref="Inset"/>.</summary>
    private const float StainDepth = 0.5f;

    /// <summary>A pixel sprite parallel to the face, its foot <paramref name="lift"/> metres above
    /// the floor and <paramref name="standOff"/> metres out from the wall (0 for the usual inset).
    /// <see cref="DecorSprite.Size"/> is its width. Only a sprite on the wall itself
    /// (<paramref name="onWall"/>) hides with the wall.</summary>
    public void AddSprite(string name, DecorSprite def, WallFace face, int margin, float lift, float standOff, float shade, bool onWall)
    {
        if (def.Texture == null) return;
        var sprite = new Sprite3D
        {
            Name = $"{name}_{face.Wall.x}_{face.Wall.y}",
            Texture = def.Texture,
            PixelSize = def.Size / def.Texture.GetWidth(),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            Modulate = new Color(shade, shade, shade),
        };
        PixelSprite.Configure(sprite);
        sprite.Shaded = true;
        float half = def.Size * def.Texture.GetHeight() / def.Texture.GetWidth() * 0.5f;
        sprite.Transform = new Transform3D(face.Facing,
            face.Foot(margin) + Vector3.Up * (lift + half) + Out(face) * (standOff > 0f ? standOff : Inset));
        _parent.AddChild(sprite);
        if (onWall) _cutaway?.Track(sprite, face.Wall.x, face.Wall.y);
    }

    /// <summary>Darken every sprite under <paramref name="node"/> by <paramref name="shade"/>.</summary>
    public static void Shade(Node node, float shade)
    {
        foreach (var child in node.GetChildren())
        {
            if (child is SpriteBase3D sprite)
                sprite.Modulate = new Color(sprite.Modulate.R * shade, sprite.Modulate.G * shade, sprite.Modulate.B * shade, sprite.Modulate.A);
            Shade(child, shade);
        }
    }
}
