using System.Collections.Generic;
using Delve.Flow;
using Godot;

namespace Delve.Village;

/// <summary>
/// The ground residents walk on: a navigation mesh baked from the town as built at a tier, so a walk
/// goes round buildings, props, trees and the decor sprites in <see cref="ObstacleGroup"/>. A bake is
/// kept per tier. Pieces count by their <see cref="TierGate"/>, never by visibility, because the
/// camera hides pieces that stand in front of a view.
/// </summary>
public partial class VillageWalkable : NavigationRegion3D
{
    /// <summary>Billboard decor that blocks a walk (a basket, a bucket); other billboards are walked past.</summary>
    public const string ObstacleGroup = "village_obstacle";

    [Export] public CampTerrain Ground { get; set; } = null!;

    /// <summary>Category nodes whose pieces block a walk.</summary>
    [Export] public Node3D[] Obstacles { get; set; } = System.Array.Empty<Node3D>();

    /// <summary>How tall a billboard obstacle stands for the bake.</summary>
    [Export] public float SpriteObstacleHeight { get; set; } = 1f;

    /// <summary>Pieces whose origin lies this far outside the baked area still count; a tree's crown or a
    /// house's porch reaches past its origin.</summary>
    [Export] public float PieceMargin { get; set; } = 4f;

    /// <summary>The mesh follows a slope only to within a cell or so; a point this close counts as on it.</summary>
    [Export] public float KeepSlack { get; set; } = 0.1f;

    /// <summary>How finely <see cref="Clear"/> samples a line; finer than the thinnest piece that blocks a walk.</summary>
    [Export] public float ClearSpacing { get; set; } = 0.15f;

    /// <summary>The bake settings (agent size, cell size, baked area). The region itself holds no mesh until
    /// the first bake, so no background update of an empty mesh can land after a bake.</summary>
    [Export] public NavigationMesh Template { get; set; } = null!;

    private readonly Dictionary<int, NavigationMesh> _baked = new();

    /// <summary>False until the first bake; until then every walk goes straight and every point is kept.</summary>
    private bool _live;

    public override void _Ready()
    {
        // Residents are placed the moment the tier is applied, so the map must answer routes then, not at
        // the end of the physics frame. A forced update is safe once the map and region sync on the main thread.
        NavigationServer3D.MapSetUseAsyncIterations(GetNavigationMap(), false);
        NavigationServer3D.RegionSetUseAsyncIterations(GetRid(), false);
    }

    public void Bake(int tier)
    {
        if (!_baked.TryGetValue(tier, out var mesh))
        {
            mesh = (NavigationMesh)Template.Duplicate();
            var source = new NavigationMeshSourceGeometryData3D();
            source.AddFaces(Ground.Mesh.GetFaces(), Ground.GlobalTransform);
            var bounds = Template.FilterBakingAabb.Grow(PieceMargin);
            var area = new Rect2(bounds.Position.X, bounds.Position.Z, bounds.Size.X, bounds.Size.Z);
            foreach (var root in Obstacles) Collect(root, tier, area, source);
            NavigationServer3D.BakeFromSourceGeometryData(mesh, source);
            _baked[tier] = mesh;
        }
        var map = GetNavigationMap();
        NavigationServer3D.MapSetCellSize(map, mesh.CellSize);
        NavigationServer3D.MapSetCellHeight(map, mesh.CellHeight);
        NavigationMesh = mesh;
#pragma warning disable CS0618
        NavigationServer3D.MapForceUpdate(map);
#pragma warning restore CS0618
        _live = true;
    }

    /// <summary>
    /// The walk from one ground point to another, ending exactly at <paramref name="to"/>. A point off
    /// the mesh (a seat on a log) is left and reached by its nearest walkable point.
    /// </summary>
    public IReadOnlyList<Vector2> Route(Vector2 from, Vector2 to)
    {
        if (!_live) return new[] { to };
        var path = NavigationServer3D.MapGetPath(GetNavigationMap(), Lift(from), Lift(to), true);
        var route = new List<Vector2>(path.Length + 1);
        foreach (var point in path)
        {
            var flat = new Vector2(point.X, point.Z);
            if (route.Count == 0 ? flat.DistanceTo(from) > 0.01f : flat.DistanceTo(route[^1]) > 0.01f) route.Add(flat);
        }
        if (route.Count == 0 || route[^1].DistanceTo(to) > 0.01f) route.Add(to);
        return route;
    }

    /// <summary>How far a ground point is from the walkable mesh, along the ground.</summary>
    public float OffMesh(Vector2 at)
    {
        var closest = NavigationServer3D.MapGetClosestPoint(GetNavigationMap(), Lift(at));
        return new Vector2(closest.X, closest.Z).DistanceTo(at);
    }

    /// <summary>A ground point, or the nearest walkable point when it is off the mesh by more than <see cref="KeepSlack"/>.</summary>
    public Vector2 Keep(Vector2 at)
    {
        if (!_live) return at;
        var closest = NavigationServer3D.MapGetClosestPoint(GetNavigationMap(), Lift(at));
        var flat = new Vector2(closest.X, closest.Z);
        return flat.DistanceTo(at) > KeepSlack ? flat : at;
    }

    /// <summary>Whether the straight line between two ground points stays on the walkable mesh.</summary>
    public bool Clear(Vector2 from, Vector2 to)
    {
        if (!_live) return true;
        float length = from.DistanceTo(to);
        for (float d = 0; d <= length; d += ClearSpacing)
            if (OffMesh(from.Lerp(to, d / Mathf.Max(length, Mathf.Epsilon))) > KeepSlack) return false;
        return OffMesh(to) <= KeepSlack;
    }

    private Vector3 Lift(Vector2 at)
    {
        var point = new Vector3(at.X, 0, at.Y);
        return point with { Y = Ground.HeightAt(point) };
    }

    /// <summary>Every piece built at the tier whose origin lies in the baked area.</summary>
    private void Collect(Node node, int tier, Rect2 area, NavigationMeshSourceGeometryData3D source)
    {
        foreach (var child in node.GetChildren())
            switch (child)
            {
                case TierGate gate:
                    if (gate.Builds(tier)) Collect(gate, tier, area, source);
                    break;
                case Node3D piece when area.HasPoint(new Vector2(piece.GlobalPosition.X, piece.GlobalPosition.Z)):
                    Add(piece, source);
                    break;
            }
    }

    private void Add(Node3D node, NavigationMeshSourceGeometryData3D source)
    {
        if (node is MeshInstance3D { Mesh: { } mesh } instance) source.AddFaces(mesh.GetFaces(), instance.GlobalTransform);
        else if (node is Sprite3D sprite && sprite.IsInGroup(ObstacleGroup)) Obstruct(sprite, source);
        foreach (var child in node.GetChildren())
            if (child is Node3D inner) Add(inner, source);
    }

    /// <summary>A billboard blocks a square as wide as its drawn frame, standing on the ground.</summary>
    private void Obstruct(Sprite3D sprite, NavigationMeshSourceGeometryData3D source)
    {
        float width = sprite.RegionEnabled ? sprite.RegionRect.Size.X
            : (sprite.Texture?.GetWidth() ?? 0) / (float)Mathf.Max(1, sprite.Hframes);
        float half = width * sprite.PixelSize * sprite.GlobalBasis.Scale.X / 2f;
        var at = sprite.GlobalPosition;
        float ground = Ground.HeightAt(at);
        var corners = new[]
        {
            new Vector3(at.X - half, ground, at.Z - half), new Vector3(at.X + half, ground, at.Z - half),
            new Vector3(at.X + half, ground, at.Z + half), new Vector3(at.X - half, ground, at.Z + half),
        };
        // Starts a little under the ground so a slope under the square cannot slip beneath it.
        source.AddProjectedObstruction(corners, ground - SpriteObstacleHeight / 4f, SpriteObstacleHeight, false);
    }
}
