using Godot;

namespace Delve.Combat;

public partial class BillboardSpriteAnimator
{
    private ShaderMaterial? _silhouette;
    private Texture2D? _silhouetteTexture;
    private float _silhouetteAlpha = -1;
    private bool _silhouetteConnected;

    private void ConfigureSilhouette()
    {
        if (MaterialOverlay is not ShaderMaterial authored) return;
        _silhouette = (ShaderMaterial)authored.Duplicate();
        MaterialOverlay = _silhouette;
        // Pre-draw catches attack starts, facing flips, frozen poses and death tweens in the same
        // rendered frame. Geometry and sheet UVs come from Sprite3D itself, not a second animator.
        RenderingServer.FramePreDraw += RefreshSilhouette;
        _silhouetteConnected = true;
        RefreshSilhouette();
    }

    internal void RefreshSilhouette()
    {
        if (_silhouette == null) return;
        if (_silhouetteTexture != Texture)
        {
            _silhouetteTexture = Texture;
            _silhouette.SetShaderParameter("sprite_tex", Texture);
        }
        float alpha = Texture == null ? 0 : Modulate.A;
        if (Mathf.IsEqualApprox(alpha, _silhouetteAlpha)) return;
        _silhouetteAlpha = alpha;
        _silhouette.SetShaderParameter("body_alpha", alpha);
    }

    public override void _ExitTree()
    {
        if (!_silhouetteConnected) return;
        RenderingServer.FramePreDraw -= RefreshSilhouette;
        _silhouetteConnected = false;
    }
}
