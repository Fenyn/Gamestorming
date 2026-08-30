using Godot;

namespace Delve.Terrain;

/// <summary>
/// Pixel-art setup for a world-space <see cref="Sprite3D"/>. Every pixel sprite in the board — unit
/// tokens and tile decor — must draw with the same rules: no lighting, no filtering, and a hard alpha
/// cut. The rules live here once, so a change applies to all of them.
///
/// The billboard mode and the shadow setting stay with the caller. Those are placement choices, not
/// pixel-art rules: a token faces the camera on both axes, a grass tuft turns on Y only, and a flower
/// patch lies flat.
/// </summary>
public static class PixelSprite
{
    /// <summary>Alpha below this value is discarded, which keeps the pixel edges hard.</summary>
    public const float ScissorThreshold = 0.5f;

    /// <summary>Apply the pixel-art draw rules to one sprite.</summary>
    public static void Configure(Sprite3D sprite)
    {
        sprite.Shaded = false;
        sprite.TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest;
        sprite.AlphaCut = SpriteBase3D.AlphaCutMode.Discard;
        sprite.AlphaScissorThreshold = ScissorThreshold;
    }
}
