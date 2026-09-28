using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>The condition icons. <see cref="Find"/> gives the art region of the source icon, one
/// texel per screen pixel at 1x, for the board badge. <see cref="Tile"/> gives the baked HUD tile:
/// bone art on a dark tile (tools/art/bake_condition_tiles.py), for chips, rows, cards and the forecast.</summary>
[GlobalClass]
public partial class ConditionIconSet : Resource
{
    [Export] public string[] Names { get; set; } = System.Array.Empty<string>();
    [Export] public Godot.Collections.Array<Texture2D> Textures { get; set; } = new();
    [Export] public Godot.Collections.Array<Texture2D> Tiles { get; set; } = new();
    [Export] public Texture2D? Fallback { get; set; }

    /// <summary>Empty texels around the art in each source icon.</summary>
    [Export] public int ArtMargin { get; set; } = 14;

    /// <summary>Side of the art region: 22 cells of 22 texels.</summary>
    [Export] public int ArtSize { get; set; } = 484;

    private readonly Dictionary<Texture2D, AtlasTexture> _regions = new();

    /// <summary>The source icon cut to its art region.</summary>
    public Texture2D? Find(string name)
    {
        int index = IndexOf(name);
        var source = index >= 0 && index < Textures.Count ? Textures[index] : Fallback;
        if (source == null) return null;
        if (!_regions.TryGetValue(source, out var region))
        {
            region = new AtlasTexture { Atlas = source, Region = new Rect2(ArtMargin, ArtMargin, ArtSize, ArtSize) };
            _regions[source] = region;
        }
        return region;
    }

    /// <summary>The baked HUD tile, or the art region when no tile exists.</summary>
    public Texture2D? Tile(string name)
    {
        int index = IndexOf(name);
        if (index < 0) index = Fallback == null ? -1 : Textures.IndexOf(Fallback);
        return index >= 0 && index < Tiles.Count ? Tiles[index] : Find(name);
    }

    /// <summary>True for any texture this set hands out: a source icon, its art region or a tile.</summary>
    public bool Owns(Texture2D texture)
        => Textures.Contains(texture) || Tiles.Contains(texture) || texture is AtlasTexture atlas && _regions.ContainsValue(atlas);

    private int IndexOf(string name)
    {
        string key = name.Replace("-", "").Replace(" ", "").Replace("_", "").ToLowerInvariant();
        key = key switch { "stupefied" => "stupified", "concealed" => "obscured", "electricity" => "lightning", "feinted" => "offguard", _ => key };
        if (key.StartsWith("persistent")) key = key[10..].Replace("damage", "");
        return System.Array.IndexOf(Names, key);
    }
}
