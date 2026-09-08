using System;
using System.Collections.Generic;
using Delve.Run;
using Delve.Data;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>Seeded miniature combat scenery, with clearings for the route and its destinations.</summary>
public partial class MapScenery : Control
{
    [Export] public MapSceneryTheme[] Biomes { get; set; } = Array.Empty<MapSceneryTheme>();
    [Export] public float RouteClearance { get; set; } = 24f;
    [Export] public float TrailWidth { get; set; } = 7f;
    [Export] public float TrailPatchLength { get; set; } = 14f;
    [Export] public Color TrailColor { get; set; }
    [Export] public Color ShadowColor { get; set; }
    private RunState? _state;
    private IReadOnlyDictionary<int, Vector2> _centers = new Dictionary<int, Vector2>();
    private Control? _mapArea;
    private ColorRect _fog = null!;
    private MapSceneryTheme? _biome;
    internal Transform2D DrawnMapTransform { get; private set; }

    private Transform2D MapTransform => GetGlobalTransform().AffineInverse() * _mapArea!.GetGlobalTransform();

    public override void _Process(double delta)
    {
        // Containers can reposition the map after scrollbar signals and deferred setup ran.
        // Redraw only when its transform relative to this scenery has actually changed.
        if (_mapArea != null && IsVisibleInTree() && !DrawnMapTransform.IsEqualApprox(MapTransform))
            QueueRedraw();
    }

    public override void _Ready()
    {
        _fog = GetNode<ColorRect>("%SceneryFog");
        Resized += QueueRedraw;
    }

    public void Configure(RunState state, IReadOnlyDictionary<int, Vector2> centers, Control mapArea)
    {
        _state = state;
        _centers = centers;
        _mapArea = mapArea;
        string id = FloorThemes.ForStratum(state.Stratum).Id;
        _biome = Array.Find(Biomes, biome => biome.Id == id);
        if (_biome == null) return;
        if (_fog.Material is ShaderMaterial fog)
        {
            fog.SetShaderParameter("density", _biome.FogDensity);
            fog.SetShaderParameter("fog_color", _biome.FogColor);
        }
        QueueRedraw();
        Callable.From(QueueRedraw).CallDeferred();
    }

    public override void _Draw()
    {
        if (_state == null || _mapArea == null || _biome == null || Size.X <= 0 || Size.Y <= 0) return;
        DrawTextureRect(_biome.Ground, new Rect2(Vector2.Zero, Size), true, _biome.GroundTint);
        var poolRng = new Random(RunRng.StableSeed(_state.Seed, _state.Stratum, "map-pools"));
        for (int i = 0; i < _biome.Pools; i++)
        {
            var center = new Vector2((float)poolRng.NextDouble() * Size.X, (float)poolRng.NextDouble() * Size.Y);
            var radius = new Vector2(35 + poolRng.Next(65), 12 + poolRng.Next(25));
            var shore = new Vector2[24];
            for (int j = 0; j < shore.Length; j++)
            {
                float angle = j * Mathf.Tau / shore.Length;
                shore[j] = center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius
                    * (0.85f + (float)poolRng.NextDouble() * 0.15f);
            }
            DrawColoredPolygon(shore, _biome.WaterColor);
        }
        DrawnMapTransform = MapTransform;
        var routes = new List<(Vector2 From, Vector2 To)>();
        foreach (var node in _state.Map.Nodes)
            foreach (int next in node.Next)
            {
                var a = DrawnMapTransform * _centers[node.Id];
                var b = DrawnMapTransform * _centers[next];
                routes.Add((a, b));
                DrawWornTrail(a, b, RunRng.StableSeed(_state.Seed, node.Id, $"trail-{next}"));
            }

        var textures = _biome.Trees;
        if (textures.Length == 0) return;
        var rng = new Random(RunRng.StableSeed(_state.Seed, _state.Stratum, "map-scenery"));
        float spacing = _biome.Spacing;
        // Draw back to front, so lower canopies naturally overlap the trees behind them.
        for (float y = -spacing; y < Size.Y + _biome.TreeHeight; y += spacing)
            for (float x = -spacing; x < Size.X + spacing; x += spacing)
            {
                var foot = new Vector2(x + (float)rng.NextDouble() * spacing,
                    y + (float)rng.NextDouble() * spacing * 0.45f);
                var texture = textures[rng.Next(textures.Length)];
                float height = _biome.TreeHeight * (0.65f + (float)rng.NextDouble() * 0.65f);
                float skip = (float)rng.NextDouble();
                var size = texture.GetSize() * (height / texture.GetHeight());
                var rect = new Rect2(foot - new Vector2(size.X / 2, size.Y), size);
                var canopy = rect.GetCenter();
                bool blocked = false;
                foreach (var center in _centers.Values)
                    if (rect.Grow(16f).HasPoint(DrawnMapTransform * center)) { blocked = true; break; }
                if (blocked) continue;
                foreach (var (a, b) in routes)
                    if (Geometry2D.GetClosestPointToSegment(canopy, a, b).DistanceTo(canopy)
                        < RouteClearance + size.X * 0.35f) { blocked = true; break; }
                if (blocked || skip < _biome.ClearingChance) continue;
                DrawCircle(foot - new Vector2(0, 3), size.X * 0.3f, ShadowColor);
                float depth = Mathf.Clamp(foot.Y / Size.Y, 0f, 1f);
                DrawTextureRect(texture, rect, false, _biome.TreeTint * (0.75f + depth * 0.25f));
            }
    }

    private void DrawWornTrail(Vector2 from, Vector2 to, int seed)
    {
        var rng = new Random(seed);
        var direction = (to - from).Normalized();
        var side = direction.Orthogonal();
        float length = from.DistanceTo(to);
        for (float distance = 0; distance < length; distance += TrailPatchLength)
        {
            float width = TrailWidth * (0.45f + (float)rng.NextDouble() * 0.55f);
            float offset = ((float)rng.NextDouble() - 0.5f) * TrailWidth;
            float opacity = 0.4f + (float)rng.NextDouble() * 0.6f;
            if (rng.NextDouble() < 0.22) continue;
            var a = from + direction * distance + side * offset;
            var b = from + direction * Mathf.Min(length, distance + TrailPatchLength * 0.8f) + side * offset;
            DrawLine(a, b, TrailColor with { A = TrailColor.A * opacity }, width, true);
        }
    }
}
