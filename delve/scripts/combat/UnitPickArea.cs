using System.Collections.Generic;
using Delve.Terrain;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Click column of a unit token: an inert Area3D over the footprint, as tall as the body, so a
/// picking ray that strikes the drawn sprite resolves to the unit's tile instead of the ground the
/// sprite hides behind it (a billboard has no depth; a click on its head lands a tile or more back).
/// Knows nothing about characters. The token sizes it at spawn and switches it off on death, and
/// <see cref="GridInput3D"/> reads <see cref="Tile"/> when its ray hits one. Box shapes are shared
/// per size, so a party of equal-sized tokens holds one shape.
/// </summary>
public partial class UnitPickArea : Area3D
{
    private static readonly Dictionary<Vector3, BoxShape3D> Shapes = new();

    private CollisionShape3D _shape = null!;

    public override void _Ready() => _shape = GetNode<CollisionShape3D>("%PickShape");

    /// <summary>Size the column: one footprint wide and deep, <paramref name="height"/> tall, standing
    /// on the token's feet.</summary>
    public void Configure(int tileWidth, float height)
    {
        var size = new Vector3(tileWidth, height, tileWidth);
        if (!Shapes.TryGetValue(size, out var box))
        {
            box = new BoxShape3D { Size = size };
            Shapes[size] = box;
        }
        _shape.Shape = box;
        _shape.Position = new Vector3(0f, height * 0.5f, 0f);
    }

    /// <summary>A corpse is scenery: rays pass through it to the ground.</summary>
    public void SetPickable(bool pickable) => _shape.Disabled = !pickable;

    /// <summary>The board tile under the column's centre — the token's own tile for a 1-square
    /// creature, a footprint tile for a larger one.</summary>
    public PF2eVec Tile => GridSpace.WorldToGrid(GlobalPosition);
}
