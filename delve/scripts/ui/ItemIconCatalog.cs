using Godot;

namespace Delve.UI;

/// <summary>Shared artwork keyed by equipment pack ID or slug. Assigned as a resource by each UI.</summary>
public partial class ItemIconCatalog : Resource
{
    [Export] public Godot.Collections.Dictionary<string, Texture2D> Icons { get; set; } = new();
    [Export] public Texture2D? Fallback { get; set; }

    public Texture2D? For(string itemId)
        => Icons.TryGetValue(itemId, out var icon) ? icon : Fallback;
}
