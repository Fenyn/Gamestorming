using System.Collections.Generic;
using Godot;

namespace Delve.Terrain;

/// <summary>The node <see cref="TileDecor"/> builds: its sprites, kept so a room can recolour them.</summary>
public partial class DecorScatter : Node3D
{
    public List<Sprite3D> Sprites { get; } = new();

    /// <summary>Every sprite takes <paramref name="tint"/> (white when unset) scaled by
    /// <paramref name="light"/>, at full alpha. Rooms that fade with the fog of war drive it with
    /// their brightness.</summary>
    public void Shade(float light, Color? tint = null)
    {
        var color = (tint ?? Colors.White) * light;
        color.A = 1f;
        foreach (var sprite in Sprites) sprite.Modulate = color;
    }
}
