using Bulwark.Data;
using Godot;
using PF2e.MapGen;

namespace Bulwark.Combat.Map;

/// <summary>
/// Scene-side holder for one generated battle map: the terrain MeshInstance3D and the static body
/// carrying its trimesh collider.
///
///     MapView3D
///       ├─ Terrain      (MeshInstance3D, materials baked on the mesh)
///       └─ TerrainBody  (StaticBody3D, layer "Terrain") └─ TerrainShape (CollisionShape3D, trimesh)
///
/// Built in code rather than from a .tscn because the content is per-encounter (mirroring how
/// <c>GridOverlay3D</c> pools its highlights). Deliberately dumb: no rules, no per-tile nodes —
/// gameplay queries go to the BattleGrid and picking goes through the single trimesh.
/// Standalone-safe: with no layout it builds nothing.
/// </summary>
public partial class MapView3D : Node3D
{
    /// <summary>Physics layer bit for terrain — <c>3d_physics/layer_1="Terrain"</c> in project.godot.</summary>
    public const uint TerrainCollisionLayer = 1;

    private const string TerrainNodeName = "Terrain";
    private const string BodyNodeName = "TerrainBody";
    private const string ShapeNodeName = "TerrainShape";

    /// <summary>The layout currently rendered, or null when empty.</summary>
    public MapLayout? Layout { get; private set; }

    /// <summary>Surfaces on the built visual mesh. 0 when empty. Diagnostics only.</summary>
    public int SurfaceCount { get; private set; }

    /// <summary>
    /// Replace the terrain with a mesh built from <paramref name="layout"/> under
    /// <paramref name="theme"/>. A null layout or theme clears the view and returns. Each build gets a
    /// fresh collision shape — trimesh shapes are never shared between maps.
    /// </summary>
    public void Build(MapLayout? layout, MapThemeDefinition? theme)
    {
        Clear();
        if (layout == null || theme == null) return;

        var built = TerrainMeshBuilder.Build(layout, theme);

        var terrain = new MeshInstance3D
        {
            Name = TerrainNodeName,
            Mesh = built.Visual,
        };
        AddChild(terrain);

        var body = new StaticBody3D
        {
            Name = BodyNodeName,
            CollisionLayer = TerrainCollisionLayer,
            // Terrain is queried, never querying: it needs no mask of its own.
            CollisionMask = 0,
        };
        body.AddChild(new CollisionShape3D
        {
            Name = ShapeNodeName,
            Shape = built.Collision.CreateTrimeshShape(),
        });
        AddChild(body);

        Layout = layout;
        SurfaceCount = built.SurfaceCount;
    }

    /// <summary>Drop the current terrain and collider.</summary>
    public void Clear()
    {
        foreach (var child in GetChildren())
        {
            RemoveChild(child);
            child.QueueFree();
        }
        Layout = null;
        SurfaceCount = 0;
    }
}
