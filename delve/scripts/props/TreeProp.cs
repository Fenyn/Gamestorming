using Delve.Terrain;
using Godot;

namespace Delve.Props;

/// <summary>
/// One HD-2D tree: a Y-billboarded pixel sprite standing on its own origin, ready to drop into any
/// scene. Each tree KIND is a scene (scenes/props/tree_*.tscn) carrying this script plus that
/// kind's texture pool; which variant a given instance shows is hashed from its world position, so
/// a hand-placed tree keeps its look between runs and a procedural scatter needs no extra state.
/// Set <see cref="Variant"/> in the inspector to pin a specific texture instead.
///
/// The node's origin is the trunk's foot: place it on the ground and the tree stands on it. All
/// pixel-art draw rules come from <see cref="PixelSprite"/>, the same as unit tokens and tile decor.
/// </summary>
public partial class TreeProp : Node3D
{
    /// <summary>This kind's texture pool, wired in the scene file.</summary>
    [Export] public Texture2D[] Variants { get; set; } = System.Array.Empty<Texture2D>();

    /// <summary>Index into <see cref="Variants"/>, or -1 to hash one from the world position.</summary>
    [Export] public int Variant { get; set; } = -1;

    /// <summary>Source-art pixels per world tile. The Winlu sheets draw 48 px to a tile, so the
    /// default keeps a tree the size its pixel art implies; a scene may lower it to grow a landmark
    /// (the giant uses 64 to stay imposing without towering absurdly).</summary>
    [Export] public float PixelsPerTile { get; set; } = 48f;

    /// <summary>How far the sprite sinks into the ground, so baked root pixels nestle into the
    /// surface instead of hovering (same idea as the decor scatter's sink).</summary>
    [Export] public float Sink { get; set; } = 0.05f;

    /// <summary>Mirror half of the instances (hashed from position) so a repeated variant reads as
    /// two different trees. Off for art with readable asymmetry a designer wants kept.</summary>
    [Export] public bool HashedFlip { get; set; } = true;

    /// <summary>The partial-fade shader (assets/shaders/tree_occluder.gdshader), wired in the
    /// scene. Applied as a material override only WHILE the tree occludes the battlefield, so the
    /// rest of the forest stays on the stock opaque billboard material and never enters the
    /// transparent pipeline. Null disables fading entirely.</summary>
    [Export] public Shader? OccluderShader { get; set; }

    private Sprite3D _sprite = null!;
    private ShaderMaterial? _occluderMaterial;
    private Aabb _battlefield;

    /// <summary>World height of the chosen sprite, for occlusion tests. Set in <see cref="_Ready"/>.</summary>
    public float Height { get; private set; }

    public override void _Ready()
    {
        var sprite = _sprite = GetNode<Sprite3D>("%Sprite");
        if (Variants.Length == 0)
        {
            GD.PushError($"[TreeProp] {Name} has no variant textures; nothing to show.");
            return;
        }

        // Position-derived rolls: stable for a placed tree, free for a scatter. World position is
        // quantised to centimetres so a float wobble cannot flip the hash.
        var p = GlobalPosition;
        int hx = Mathf.RoundToInt(p.X * 100f);
        int hz = Mathf.RoundToInt(p.Z * 100f);

        int index = Variant >= 0 && Variant < Variants.Length
            ? Variant
            : (int)(MapHash.Hash01(hx, hz, 0x7E3A) * Variants.Length) % Variants.Length;
        var tex = Variants[index];

        sprite.Texture = tex;
        sprite.PixelSize = 1f / PixelsPerTile;
        sprite.Billboard = BaseMaterial3D.BillboardModeEnum.FixedY;
        sprite.CastShadow = GeometryInstance3D.ShadowCastingSetting.Off;
        sprite.FlipH = HashedFlip && MapHash.Hash01(hx, hz, 0x51C7) < 0.5f;
        PixelSprite.Configure(sprite);

        float worldHeight = tex.GetHeight() / PixelsPerTile;
        sprite.Position = new Vector3(0f, worldHeight * 0.5f - Sink, 0f);
        Height = worldHeight;
    }

    // ─────────────────────────── occluder fading ───────────────────────────

    /// <summary>The battlefield box (world space) the partial-fade shader protects. Set once per
    /// build by the scatter; a hand-dropped tree that never gets one simply never fades.</summary>
    public void SetBattlefield(Aabb box)
    {
        _battlefield = box;
        if (_occluderMaterial == null) return;
        _occluderMaterial.SetShaderParameter("battlefield_min", box.Position);
        _occluderMaterial.SetShaderParameter("battlefield_size", box.Size);
    }

    /// <summary>Tell the tree it stands between the camera and the battlefield (or no longer does).
    /// While occluding, the partial-fade shader takes over and ghosts ONLY the pixels whose
    /// sightline continues into the battlefield; the rest of the tree stays solid. Off the hook, the
    /// sprite returns to its stock opaque billboard material.</summary>
    public void SetOccluding(bool occluding)
    {
        if (!occluding)
        {
            _sprite.MaterialOverride = null;
            return;
        }
        if (OccluderShader == null || _sprite.Texture == null) return;

        if (_occluderMaterial == null)
        {
            _occluderMaterial = new ShaderMaterial { Shader = OccluderShader };
            _occluderMaterial.SetShaderParameter("sprite_tex", _sprite.Texture);
            SetBattlefield(_battlefield);
        }
        _sprite.MaterialOverride = _occluderMaterial;
    }
}
