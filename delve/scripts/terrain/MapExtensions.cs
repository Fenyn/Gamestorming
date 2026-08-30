using Godot;
using PF2e.MapGen;

namespace Delve.Terrain;

/// <summary>Small shared helpers for the map view nodes and the builders that read a layout.</summary>
public static class MapExtensions
{
    /// <summary>Remove and free every child of <paramref name="node"/>. The rebuild-from-scratch reset.</summary>
    public static void ClearChildren(this Node node)
    {
        foreach (var child in node.GetChildren())
        {
            node.RemoveChild(child);
            child.QueueFree();
        }
    }

    /// <summary>Role of the tile at (x, y), or null when the position is off the map.</summary>
    public static TileRole? TileAt(this MapLayout layout, int x, int y) =>
        layout.IsInBounds(x, y) ? layout.GetTile(x, y) : null;

    /// <summary>Surface of the tile at (x, y), or null when the position is off the map.</summary>
    public static SurfaceType? SurfaceAt(this MapLayout layout, int x, int y) =>
        layout.IsInBounds(x, y) ? layout.GetSurface(x, y) : null;
}
