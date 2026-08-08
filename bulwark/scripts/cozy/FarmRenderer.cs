using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Passive 3D renderer of the farm plots. Subscribes to <see cref="GameState.PlotChanged"/> and
/// hydrates from <see cref="FarmSystem.AllPlots"/>, then shows the plot state three ways with flat
/// greybox geometry (one cell = one metre):
///  - <b>tilled soil</b> — a dark quad laid on the ground at the cell;
///  - <b>watered</b> — the same quad in a darker, wetter tint;
///  - <b>crop</b> — a thin stem box that grows with the plot's stage, topped by a coloured berry
///    once the crop is mature and harvestable.
/// Holds no rules; every value comes from the authoritative <see cref="FarmSystem"/> state. Each
/// plot owns one pooled Node3D, created on first use and reused for the rest of the session, so a
/// day of tilling/watering never churns the scene tree.
/// </summary>
public partial class FarmRenderer : Node3D
{
    /// <summary>Side length (m) of the soil quad — slightly under a full cell so the grid reads.</summary>
    private const float SoilSize = 0.92f;

    /// <summary>Height (m) the soil quad floats above the ground plane (z-fighting guard).</summary>
    private const float SoilY = 0.02f;

    /// <summary>Stem height (m) at full growth.</summary>
    private const float MaxStemHeight = 0.55f;

    private OutpostScene? _outpost;

    private readonly Dictionary<Vector2I, PlotVisual> _plots = new();

    // Shared greybox resources (built once — meshes/materials are safe to share; collision shapes
    // are the thing that must never be, and the farm has none).
    private PlaneMesh _soilMesh = null!;
    private BoxMesh _stemMesh = null!;
    private SphereMesh _fruitMesh = null!;
    private StandardMaterial3D _soilDry = null!;
    private StandardMaterial3D _soilWet = null!;
    private StandardMaterial3D _stemGreen = null!;
    private StandardMaterial3D _fruitRipe = null!;

    /// <summary>One pooled visual per farm cell.</summary>
    private sealed class PlotVisual
    {
        public required Node3D Root { get; init; }
        public required MeshInstance3D Soil { get; init; }
        public required MeshInstance3D Stem { get; init; }
        public required MeshInstance3D Fruit { get; init; }
    }

    public override void _Ready() => BuildSharedResources();

    /// <summary>Injected by <see cref="OutpostScene"/> once the blockout accessors are ready.</summary>
    public void Bind(OutpostScene outpost)
    {
        _outpost = outpost;
        BuildSharedResources();

        var gs = GameState.Instance;
        if (gs != null)
        {
            gs.PlotChanged += OnPlotChanged;
            gs.GameLoaded += HydrateAll;
        }
        HydrateAll();
    }

    public override void _ExitTree()
    {
        var gs = GameState.Instance;
        if (gs != null)
        {
            gs.PlotChanged -= OnPlotChanged;
            gs.GameLoaded -= HydrateAll;
        }
    }

    private void BuildSharedResources()
    {
        if (_soilMesh != null)
            return;

        _soilDry = Flat(new Color(0.30f, 0.20f, 0.13f));
        _soilWet = Flat(new Color(0.17f, 0.12f, 0.09f));
        _stemGreen = Flat(new Color(0.32f, 0.60f, 0.26f));
        _fruitRipe = Flat(new Color(0.90f, 0.55f, 0.18f));

        _soilMesh = new PlaneMesh { Size = new Vector2(SoilSize, SoilSize) };
        _stemMesh = new BoxMesh { Size = new Vector3(0.07f, 1f, 0.07f) };
        _fruitMesh = new SphereMesh { Radius = 0.11f, Height = 0.22f, RadialSegments = 8, Rings = 4 };
    }

    private static StandardMaterial3D Flat(Color color) => new()
    {
        AlbedoColor = color,
        Roughness = 1f,
        SpecularMode = BaseMaterial3D.SpecularModeEnum.Disabled,
    };

    private void OnPlotChanged(Vector2I tile) => UpdatePlot(tile);

    private void HydrateAll()
    {
        foreach (var visual in _plots.Values)
            visual.Root.Visible = false;

        var gs = GameState.Instance;
        if (gs != null)
            foreach (Plot plot in gs.Farm.AllPlots)
                UpdatePlot(plot.Tile);
    }

    private void UpdatePlot(Vector2I tile)
    {
        if (_outpost == null)
            return;

        Plot? plot = GameState.Instance?.Farm.GetPlot(tile);
        bool tilled = plot != null && plot.Stage != PlotStage.Untilled;

        if (!tilled)
        {
            if (_plots.TryGetValue(tile, out var hidden))
                hidden.Root.Visible = false;
            return;
        }

        PlotVisual visual = GetOrCreate(tile);
        visual.Root.Visible = true;
        visual.Soil.MaterialOverride = plot!.WateredToday ? _soilWet : _soilDry;

        if (plot.CropId == null)
        {
            visual.Stem.Visible = false;
            visual.Fruit.Visible = false;
            return;
        }

        bool mature = plot.Stage == PlotStage.Mature;
        float t = 0.15f;
        if (Crops.TryGet(plot.CropId, out CropDefinition crop) && crop.GrowthDays > 0)
            t = Mathf.Clamp((float)plot.DaysGrown / crop.GrowthDays, 0f, 1f);
        if (mature)
            t = 1f;
        t = Mathf.Max(t, 0.15f);

        float height = MaxStemHeight * t;
        visual.Stem.Visible = true;
        visual.Stem.Scale = new Vector3(1f, height, 1f);
        visual.Stem.Position = new Vector3(0f, height * 0.5f, 0f);

        visual.Fruit.Visible = mature;
        visual.Fruit.Position = new Vector3(0f, height + 0.08f, 0f);
    }

    private PlotVisual GetOrCreate(Vector2I tile)
    {
        if (_plots.TryGetValue(tile, out var existing))
            return existing;

        var root = new Node3D { Name = $"Plot_{tile.X}_{tile.Y}" };
        AddChild(root);
        root.GlobalPosition = _outpost!.CellToWorld(tile);

        var soil = new MeshInstance3D { Name = "Soil", Mesh = _soilMesh, Position = new Vector3(0f, SoilY, 0f) };
        soil.MaterialOverride = _soilDry;
        root.AddChild(soil);

        var stem = new MeshInstance3D { Name = "Stem", Mesh = _stemMesh, Visible = false };
        stem.MaterialOverride = _stemGreen;
        root.AddChild(stem);

        var fruit = new MeshInstance3D { Name = "Fruit", Mesh = _fruitMesh, Visible = false };
        fruit.MaterialOverride = _fruitRipe;
        root.AddChild(fruit);

        var visual = new PlotVisual { Root = root, Soil = soil, Stem = stem, Fruit = fruit };
        _plots[tile] = visual;
        return visual;
    }
}
