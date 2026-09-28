using Godot;

namespace Delve.Dungeon;

/// <summary>Named colours for the blockout props, doors and passages, authored in
/// <c>scenes/dungeon/palettes/prop_tints.tres</c> and shared by every room palette.</summary>
[GlobalClass]
public partial class PropTints : Resource
{
    [Export] public Godot.Collections.Dictionary<string, Color> Colors { get; set; } = new();

    /// <summary>The named tint. A missing name shows magenta, so a typo is visible in the room.</summary>
    public Color Get(string key) => Colors.TryGetValue(key, out var color) ? color : Godot.Colors.Magenta;
}
