using Godot;

namespace Delve.UI;

[GlobalClass]
public partial class ConditionIconSet : Resource
{
    [Export] public string[] Names { get; set; } = System.Array.Empty<string>();
    [Export] public Godot.Collections.Array<Texture2D> Textures { get; set; } = new();
    [Export] public Texture2D? Fallback { get; set; }

    public Texture2D? Find(string name)
    {
        string key = name.Replace("-", "").Replace(" ", "").Replace("_", "").ToLowerInvariant();
        key = key switch { "stupefied" => "stupified", "concealed" => "obscured", "electricity" => "lightning", "feinted" => "offguard", _ => key };
        if (key.StartsWith("persistent")) key = key[10..].Replace("damage", "");
        for (int i = 0; i < Names.Length && i < Textures.Count; i++)
            if (Names[i] == key) return Textures[i];
        return Fallback;
    }
}
