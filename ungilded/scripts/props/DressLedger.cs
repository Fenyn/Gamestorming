using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Ungilded.Props;

/// <summary>What a sewer prop is, for spacing and for the checks.</summary>
public enum DressKind
{
    Torch,
    WallGrate,
    FloorGrate,
    Puddle,
    Slime,
    Bones,
    Rubble,
}

/// <summary>One placed prop. <see cref="Tile"/> is the floor tile it lies on or looks onto and
/// <see cref="Wall"/> the wall tile it hangs on (the same tile for a floor prop), both in BOARD
/// coordinates; <see cref="At"/> is its point on the floor plane in board metres.
/// <see cref="Reason"/> names the rule that placed it.</summary>
public readonly record struct DressPlacement(DressKind Kind, Vector2I Tile, Vector2I Wall, Vector2 At, string Reason);

/// <summary>
/// The props one board's dressing has placed so far, by tile, so each rule can ask whether a tile
/// is free and whether the same kind already lies next to it.
/// </summary>
public sealed class DressLedger
{
    private readonly List<DressPlacement> _placed = new();
    private readonly Dictionary<Vector2I, DressKind> _floor = new();

    public IReadOnlyList<DressPlacement> Placed => _placed;

    public void Add(DressPlacement placement)
    {
        _placed.Add(placement);
        if (placement.Kind is not (DressKind.Torch or DressKind.WallGrate)) _floor[placement.Tile] = placement.Kind;
    }

    public void Clear()
    {
        _placed.Clear();
        _floor.Clear();
    }

    /// <summary>No floor prop lies on <paramref name="tile"/> (board coordinates).</summary>
    public bool IsFree(Vector2I tile) => !_floor.ContainsKey(tile);

    /// <summary>A floor prop of <paramref name="kind"/> lies within <paramref name="rings"/> tiles of
    /// <paramref name="tile"/>, the tile itself included.</summary>
    public bool Near(DressKind kind, Vector2I tile, int rings)
    {
        for (int dy = -rings; dy <= rings; dy++)
            for (int dx = -rings; dx <= rings; dx++)
                if (_floor.TryGetValue(tile + new Vector2I(dx, dy), out var k) && k == kind) return true;
        return false;
    }

    public IEnumerable<DressPlacement> OfKind(params DressKind[] kinds) => _placed.Where(p => kinds.Contains(p.Kind));
}
