using System.Collections.Generic;
using Godot;

namespace Delve.Dungeon;

/// <summary>Stone infill between socket thresholds, with the same wall cutaway as rooms.</summary>
public partial class DungeonPassage : Node3D
{
    public DungeonPalette? Palette { get; set; }
    private readonly List<(Node3D Wall, int Sign)> _walls = new();
    private bool _horizontal;

    public void Build(Vector3 a, Vector3 b)
    {
        Position = (a + b) / 2;
        var delta = (a - b).Abs();
        _horizontal = delta.X > delta.Z;
        float length = _horizontal ? delta.X : delta.Z;
        var stone = new DungeonProp { Palette = Palette };
        AddChild(stone);
        stone.Box(new(0, -0.12f, 0), _horizontal ? new(length, 0.24f, 3) : new(3, 0.24f, length), new Color("626975"));
        // Touching rooms already supply both jambs; only fill the threshold seam.
        if (length <= 1) return;
        foreach (int sign in new[] { -1, 1 })
        {
            var edge = _horizontal ? new Vector3(0, 0, sign * 1.75f) : new(sign * 1.75f, 0, 0);
            var size = _horizontal ? new Vector3(length, 0.5f, 0.5f) : new(0.5f, 0.5f, length);
            stone.Box(edge + Vector3.Up * 0.25f, size, new Color("59606d"));
            size.Y = 1.6f;
            var wall = stone.Box(edge + Vector3.Up * 1.3f, size, new Color("59606d"));
            _walls.Add((wall, sign));
        }
    }

    public void Cutaway(Camera3D camera)
    {
        var relative = camera.GlobalPosition - GlobalPosition;
        foreach (var (wall, sign) in _walls)
            wall.Visible = (_horizontal ? relative.Z : relative.X) * sign < 0;
    }
}
