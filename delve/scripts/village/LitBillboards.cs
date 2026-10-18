using System.Collections.Generic;
using Godot;

namespace Delve.Village;

/// <summary>
/// HD-2D lighting for village billboards: lit by the sun, the lamps and the fire, but never shadowed
/// by their own sun-facing shadow twin, which crosses the sprite and would darken half of it.
/// Godot's sprite material cannot skip receiving shadows, so each lit billboard draws through an
/// override material that does, one per texture and billboard mode.
/// </summary>
public sealed class LitBillboards
{
    private readonly Dictionary<(Texture2D, BaseMaterial3D.BillboardModeEnum), StandardMaterial3D> _materials = new();

    /// <summary>Lights a shaded, alpha-cut sprite; unshaded ones (the fire) and soft ones (smoke) keep their own look.</summary>
    public void Apply(Sprite3D sprite)
    {
        if (!sprite.Shaded || sprite.AlphaCut != SpriteBase3D.AlphaCutMode.Discard || sprite.Texture == null)
        {
            sprite.MaterialOverride = null;
            return;
        }
        var key = (sprite.Texture, sprite.Billboard);
        if (!_materials.TryGetValue(key, out var material))
            _materials[key] = material = new StandardMaterial3D
            {
                AlbedoTexture = sprite.Texture,
                TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
                Transparency = BaseMaterial3D.TransparencyEnum.AlphaScissor,
                AlphaScissorThreshold = 0.5f,
                CullMode = BaseMaterial3D.CullModeEnum.Disabled,
                BillboardMode = sprite.Billboard,
                VertexColorUseAsAlbedo = true,
                DisableReceiveShadows = true,
                SpecularMode = BaseMaterial3D.SpecularModeEnum.Disabled,
                DiffuseMode = BaseMaterial3D.DiffuseModeEnum.LambertWrap,
                Roughness = 1f,
            };
        sprite.MaterialOverride = material;
    }
}
