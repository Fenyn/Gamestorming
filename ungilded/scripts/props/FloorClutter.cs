using Godot;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>
/// Floor sprites: flat decals laid on the floor and standing sprites turned to the camera. They draw
/// lit (the torches light them) under the same pixel rules as the tile decor.
/// <see cref="SewerDressing"/> decides where they go.
/// </summary>
public static class FloorClutter
{
    /// <summary>Flat decals hover this far over the floor, against z-fighting.</summary>
    private const float FlatLift = 0.015f;

    /// <summary>Standing sprites sink this far so their base pixels meet the floor.</summary>
    private const float BillboardSink = 0.03f;

    /// <summary>A flat decal on the floor, turned in quarter steps so its pixels stay on the
    /// board's grid.</summary>
    public static void AddDecal(Node3D parent, DecorSprite def, Vector3 centre, int quarterTurns, float shade)
    {
        if (def.Texture == null) return;
        var sprite = NewSprite(def, def.Size / Mathf.Max(def.Texture.GetWidth(), def.Texture.GetHeight()), shade);
        sprite.Axis = Vector3.Axis.Y;
        sprite.RotateY(quarterTurns * Mathf.Pi * 0.5f);
        sprite.Position = centre + Vector3.Up * FlatLift;
        parent.AddChild(sprite);
    }

    /// <summary>A sprite standing on the floor at <paramref name="foot"/>, turned about Y to the camera.</summary>
    public static void AddStanding(Node3D parent, DecorSprite def, Vector3 foot, bool flip, float shade)
    {
        if (def.Texture == null) return;
        var sprite = NewSprite(def, def.Size / def.Texture.GetHeight(), shade);
        sprite.Billboard = BaseMaterial3D.BillboardModeEnum.FixedY;
        sprite.FlipH = flip;
        sprite.Position = foot + Vector3.Up * (def.Size * 0.5f - BillboardSink);
        parent.AddChild(sprite);
    }

    private static Sprite3D NewSprite(DecorSprite def, float pixelSize, float shade)
    {
        var sprite = new Sprite3D
        {
            Texture = def.Texture,
            PixelSize = pixelSize,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            Modulate = new Color(shade, shade, shade),
        };
        PixelSprite.Configure(sprite);
        sprite.Shaded = true;
        return sprite;
    }
}
