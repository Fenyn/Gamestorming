using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.MapGen;

namespace Delve.Dungeon;

/// <summary>Prefab-authored textures and reusable materials for one room atmosphere.</summary>
[GlobalClass]
public partial class DungeonPalette : Resource
{
    [Export] public Texture2D[] FloorTextures { get; set; } = System.Array.Empty<Texture2D>();
    [Export] public Texture2D? MasonryTexture { get; set; }
    [Export] public Texture2D? TimberTexture { get; set; }
    [Export] public Color StoneTint { get; set; } = Colors.White;
    [Export] public Color ClothTint { get; set; } = new("795457");

    /// <summary>Colours of the blockout props, doors and passages.</summary>
    [Export] public PropTints? Tints { get; set; }

    public Color Tint(string key) => Tints?.Get(key) ?? Colors.Magenta;
    private readonly Dictionary<(Color, string), StandardMaterial3D> _materials = new();

    public MapThemeDefinition Theme()
    {
        var surfaces = new Dictionary<SurfaceType, MapSurfaceStyle>(MapThemes.Forest.Surfaces);
        var paths = System.Array.ConvertAll(FloorTextures, t => t.ResourcePath);
        surfaces[SurfaceType.Stone] = surfaces[SurfaceType.Stone] with
        {
            TopTextures = paths, WallTexture = MasonryTexture?.ResourcePath,
            WallTint = new(StoneTint.R, StoneTint.G, StoneTint.B)
        };
        surfaces[SurfaceType.Water] = MapThemes.Sewer.Surfaces[SurfaceType.Water];
        // The terrain material cache keys walls by biome. Keep palette entries
        // separate from each other and from the normal sewer theme.
        return MapThemes.Sewer with { BiomeId = $"dungeon/{ResourcePath}", Surfaces = surfaces, TopGridLineWidth = 0.012f };
    }

    public StandardMaterial3D Material(Color color, string surface)
    {
        if (_materials.TryGetValue((color, surface), out var material)) return material;
        var texture = surface == "wood" ? TimberTexture : surface == "stone" ? MasonryTexture : null;
        material = new StandardMaterial3D
        {
            AlbedoTexture = texture,
            AlbedoColor = surface == "cloth" ? ClothTint : surface == "stone" ? color.Lightened(0.35f) * StoneTint : color,
            Roughness = surface == "iron" ? 0.6f : 0.95f,
            Metallic = surface == "iron" ? 0.5f : 0,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.NearestWithMipmaps,
            Uv1Triplanar = texture != null, Uv1WorldTriplanar = texture != null
        };
        _materials[(color, surface)] = material;
        return material;
    }
}
