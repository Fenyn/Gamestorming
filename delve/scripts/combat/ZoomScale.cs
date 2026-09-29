using Godot;

namespace Delve.Combat;

/// <summary>
/// How far the command menu and the HP plates shrink as the camera pulls back. Pixeloid is drawn
/// on a 9 px grid and the HUD uses 18, 27 and 36 px, so only whole steps of that grid stay crisp:
/// they snap between full size and two thirds (27 px → 18 px, the text floor) instead of scaling
/// smoothly. 18 px labels (name plates, letter badges, the Dying value) never shrink, since two
/// thirds of them would fall under the floor. Every caller measures view depth, so the menu and
/// the plates switch on the same frame.
/// </summary>
public static class ZoomScale
{
    /// <summary>The smaller crisp step: a 27 px row drawn at 18 px.</summary>
    public const float Small = 2f / 3f;

    /// <summary>Half-width of the band around the switch point, on the smooth scale. Inside it the
    /// current size holds, so a camera resting at the threshold never flickers.</summary>
    private const float Hysteresis = 0.04f;

    /// <summary>Next size for something currently drawn at <paramref name="current"/>: 1 near the
    /// planning distance, <see cref="Small"/> further out, switching halfway between the two on
    /// the smooth scale the units themselves follow.</summary>
    public static float For(float depth, float fullSizeDistance, float current = 1f)
    {
        float smooth = fullSizeDistance / Mathf.Max(0.01f, depth);
        float mid = (1f + Small) / 2f;
        return current >= 1f
            ? (smooth < mid - Hysteresis ? Small : 1f)
            : (smooth > mid + Hysteresis ? 1f : Small);
    }

    /// <summary>Distance from the camera plane to <paramref name="point"/>, along the view axis.</summary>
    public static float Depth(Camera3D camera, Vector3 point)
        => Mathf.Max(0.01f, (point - camera.GlobalPosition).Dot(-camera.GlobalBasis.Z));
}
