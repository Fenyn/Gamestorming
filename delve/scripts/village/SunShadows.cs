using Godot;

namespace Delve.Village;

/// <summary>Where a billboard's feet meet the ground, in the sprite's own space, when the art does not end at the ground line.</summary>
public interface IShadowGround
{
    float GroundLocalY { get; }
}

/// <summary>The sun as the shadow twins need it: the yaw to turn square to, and how much to squash the twin.</summary>
public readonly record struct SunAngle(float Yaw, float Squash);

/// <summary>
/// HD-2D sprite shadows. A billboard's own quad tilts with the camera pitch and casts a skewed
/// shadow, so each billboard gets a shadow-only twin instead: same frame, upright, in the
/// billboard's plane (facing the camera's yaw), so the shadow and the sprite never cross. The
/// village sun sits behind the camera, so those shadows fall straight up-screen behind the feet.
/// A low sun would stretch a shadow into a long smear, so the twin is squashed toward its feet
/// until the shadow is no longer than the figure allows.
/// </summary>
public static class SunShadows
{
    /// <summary>Billboards in the village that need a twin; the bake and the figure scenes join it.</summary>
    public const string BillboardGroup = "village_billboard";

    private const string TwinName = "ShadowTwin";

    /// <param name="maxLength">Longest shadow a billboard may cast, as a share of its own height.</param>
    /// <param name="viewYaw">The camera's yaw: twins stand in the same plane as the billboards they shadow,
    /// so no two planes cross; the sun stays behind the camera to cast them up-screen.</param>
    public static SunAngle Angle(DirectionalLight3D sun, float maxLength, float viewYaw)
    {
        var light = -sun.GlobalBasis.Z;
        float elevation = Mathf.Asin(Mathf.Clamp(-light.Y, 0.01f, 1f));
        // A caster of height h throws h / tan(elevation); squashing it by s makes that s times shorter.
        float squash = Mathf.Min(1f, maxLength * Mathf.Tan(elevation));
        return new SunAngle(viewYaw, squash);
    }

    public static void Sync(Sprite3D sprite, SunAngle sun)
    {
        sprite.CastShadow = GeometryInstance3D.ShadowCastingSetting.Off;
        if (sprite.GetNodeOrNull<Sprite3D>(TwinName) is not { } twin)
        {
            twin = new Sprite3D { Name = TwinName, CastShadow = GeometryInstance3D.ShadowCastingSetting.ShadowsOnly };
            sprite.AddChild(twin);
        }
        twin.Texture = sprite.Texture;
        twin.Hframes = sprite.Hframes;
        twin.Vframes = sprite.Vframes;
        twin.Frame = sprite.Frame;
        twin.RegionEnabled = sprite.RegionEnabled;
        twin.RegionRect = sprite.RegionRect;
        twin.PixelSize = sprite.PixelSize;
        twin.Centered = sprite.Centered;
        twin.Offset = sprite.Offset;
        twin.FlipH = sprite.FlipH;
        twin.AlphaCut = SpriteBase3D.AlphaCutMode.Discard;
        twin.TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest;
        // Squash about the ground line, so the shadow still starts at the feet.
        float ground = sprite is IShadowGround grounded ? grounded.GroundLocalY : Bottom(sprite);
        twin.Position = new Vector3(0, ground * (1 - sun.Squash), 0);
        twin.GlobalRotation = new Vector3(0, sun.Yaw, 0);
        twin.Scale = new Vector3(1, sun.Squash, 1);
    }

    /// <summary>Keeps an animated sprite's shadow on the sheet and frame it shows.</summary>
    public static void Follow(Sprite3D sprite)
    {
        if (sprite.GetNodeOrNull<Sprite3D>(TwinName) is not { } twin) return;
        if (twin.Texture != sprite.Texture) twin.Texture = sprite.Texture;
        twin.Hframes = sprite.Hframes;
        twin.Vframes = sprite.Vframes;
        twin.Frame = sprite.Frame;
        twin.Offset = sprite.Offset;
        twin.FlipH = sprite.FlipH;
    }

    /// <summary>The bottom edge of the drawn frame, in the sprite's own space: decor stands its art on the ground.</summary>
    private static float Bottom(Sprite3D sprite)
    {
        float height = sprite.RegionEnabled ? sprite.RegionRect.Size.Y
            : (sprite.Texture?.GetHeight() ?? 0) / (float)Mathf.Max(1, sprite.Vframes);
        float offset = sprite.Offset.Y * sprite.PixelSize;
        return sprite.Centered ? offset - height * sprite.PixelSize / 2f : offset;
    }
}
