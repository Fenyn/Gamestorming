using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.UI;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Thin Node2D adapter for the outpost world scene (<c>scenes/outpost/outpost.tscn</c>). Holds no
/// game logic: it only exposes typed accessors so the avatar / farming systems can query the
/// blockout — tile layers, spawn/farm markers, ruined-building placeholders, and the territory
/// gate trigger. The user hand-paints the actual tilemaps in the editor; this script never mutates
/// world state.
///
/// Layer draw order (bottom to top): Ground, GroundDecor, Walls, Props, Overhead. Overhead is meant
/// to render above the player avatar (roofs / treetops); the player scene is expected to sit between
/// Props and Overhead.
/// </summary>
public partial class OutpostScene : Node2D
{
    private TileMapLayer? _ground;
    private TileMapLayer? _groundDecor;
    private TileMapLayer? _walls;
    private TileMapLayer? _props;
    private TileMapLayer? _overhead;
    private Marker2D? _playerSpawn;
    private Marker2D? _farmArea;
    private Area2D? _gateTrigger;
    private Area2D? _bedroll;
    private readonly List<Marker2D> _ruinedBuildings = new();

    // Avatar / farming / HUD instanced by this scene (draw order: layers < FarmRenderer < Player < Overhead).
    private PlayerController? _player;
    private FarmRenderer? _farmRenderer;
    private CozyHud? _hud;

    public override void _Ready()
    {
        _ground = GetNodeOrNull<TileMapLayer>("%Ground");
        _groundDecor = GetNodeOrNull<TileMapLayer>("%GroundDecor");
        _walls = GetNodeOrNull<TileMapLayer>("%Walls");
        _props = GetNodeOrNull<TileMapLayer>("%Props");
        _overhead = GetNodeOrNull<TileMapLayer>("%Overhead");
        _playerSpawn = GetNodeOrNull<Marker2D>("%PlayerSpawn");
        _farmArea = GetNodeOrNull<Marker2D>("%FarmArea");
        _gateTrigger = GetNodeOrNull<Area2D>("%GateTrigger");
        _bedroll = GetNodeOrNull<Area2D>("%Bedroll");

        _ruinedBuildings.Clear();
        for (int i = 1; i <= 8; i++)
        {
            var m = GetNodeOrNull<Marker2D>($"%RuinedBuilding_{i}");
            if (m != null) _ruinedBuildings.Add(m);
        }

        SpawnFarmRenderer();
        SpawnPlayer();
        SpawnHud();
        WireGate();
        WireStateEvents();
        RefreshHudAll();
    }

    public override void _ExitTree()
    {
        // GameState is an autoload that outlives this scene, so drop our subscriptions on scene swap.
        var gs = GameState.Instance;
        if (gs != null)
        {
            gs.MinuteChanged -= RefreshHudTime;
            gs.DayStarted -= RefreshHudTime;
            gs.InventoryChanged -= OnInventoryChanged;
            gs.GameLoaded -= RefreshHudAll;
        }
    }

    // ------------------------------------------------------------------ Instancing

    private void SpawnFarmRenderer()
    {
        _farmRenderer = new FarmRenderer { Name = "FarmRenderer", ZIndex = 1 };
        AddChild(_farmRenderer);
        _farmRenderer.Bind(this);
    }

    private void SpawnPlayer()
    {
        var scene = GD.Load<PackedScene>("res://scenes/cozy/player.tscn");
        if (scene == null)
            return;

        _player = scene.Instantiate<PlayerController>();
        _player.Name = "Player";
        _player.ZIndex = 5; // between the z=0 world layers and the z=10 Overhead layer
        AddChild(_player);
        _player.GlobalPosition = PlayerSpawnPosition;
        _player.Setup(this, _bedroll);
        _player.SleepRequested += OnSleepRequested;
        _player.Tools.Changed += RefreshHudTool;
    }

    private void SpawnHud()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/cozy_hud.tscn");
        if (scene == null)
            return;

        _hud = scene.Instantiate<CozyHud>();
        AddChild(_hud);
    }

    private void WireGate()
    {
        _gateTrigger?.Connect(Area2D.SignalName.BodyEntered, Callable.From<Node2D>(OnGateBodyEntered));
    }

    private void WireStateEvents()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        gs.MinuteChanged += RefreshHudTime;
        gs.DayStarted += RefreshHudTime;
        gs.InventoryChanged += OnInventoryChanged;
        gs.GameLoaded += RefreshHudAll;
    }

    // ------------------------------------------------------------------ HUD wiring (passive push)

    private void OnInventoryChanged(string itemId) => RefreshHudInventory();

    private void RefreshHudAll()
    {
        RefreshHudTime();
        RefreshHudTool();
        RefreshHudInventory();
    }

    private void RefreshHudTime()
    {
        var gs = GameState.Instance;
        if (_hud == null || gs == null)
            return;
        _hud.SetTimeDate(gs.Clock.TimeString(), gs.Clock.DateString());
    }

    private void RefreshHudTool()
    {
        var gs = GameState.Instance;
        if (_hud == null || _player == null || gs == null)
            return;

        ItemDefinition? seed = _player.Tools.SelectedSeed;
        _hud.SetTool(
            _player.Tools.CurrentDisplayName,
            seed?.DisplayName,
            seed == null ? 0 : gs.Inventory.Count(seed.Id));
    }

    private void RefreshHudInventory()
    {
        var gs = GameState.Instance;
        if (_hud == null || gs == null)
            return;

        var list = new List<(string Name, int Count)>();
        foreach (var (id, qty) in gs.Inventory.Stacks)
            if (qty > 0 && Items.TryGet(id, out ItemDefinition def))
                list.Add((def.DisplayName, qty));
        list.Sort((a, b) => string.CompareOrdinal(a.Name, b.Name));

        _hud.SetInventory(list);
        RefreshHudTool(); // a spent/gained seed changes the tool-belt count too
    }

    // ------------------------------------------------------------------ Interactions

    private void OnSleepRequested()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        if (_hud != null)
            _hud.PlaySleepTransition(gs.Sleep, () => $"You wake — {gs.Clock.DateString()}");
        else
            gs.Sleep();
    }

    private void OnGateBodyEntered(Node2D body)
    {
        if (body is PlayerController)
            GD.Print("[Outpost] Gate reached — territory travel comes in M3.");
    }

    // --- Layer accessors ---
    public TileMapLayer? Ground => _ground;
    public TileMapLayer? GroundDecor => _groundDecor;
    public TileMapLayer? Walls => _walls;
    public TileMapLayer? Props => _props;
    public TileMapLayer? Overhead => _overhead;

    // --- Marker accessors ---
    public Marker2D? PlayerSpawn => _playerSpawn;
    public Marker2D? FarmArea => _farmArea;
    public Area2D? GateTrigger => _gateTrigger;
    public IReadOnlyList<Marker2D> RuinedBuildings => _ruinedBuildings;

    /// <summary>World-space player spawn point (falls back to origin if the marker is missing).</summary>
    public Vector2 PlayerSpawnPosition => _playerSpawn?.GlobalPosition ?? Vector2.Zero;

    // --- Farming query API (for the farm system) ---

    /// <summary>Ground cell containing a world-space point.</summary>
    public Vector2I WorldToCell(Vector2 world)
        => _ground?.LocalToMap(_ground.ToLocal(world)) ?? Vector2I.Zero;

    /// <summary>Center world-space point of a ground cell.</summary>
    public Vector2 CellToWorld(Vector2I cell)
        => _ground != null ? _ground.ToGlobal(_ground.MapToLocal(cell)) : Vector2.Zero;

    /// <summary>True if the Ground tile at <paramref name="cell"/> carries the "farmable" flag.</summary>
    public bool IsFarmable(Vector2I cell)
    {
        TileData? td = _ground?.GetCellTileData(cell);
        return td != null && (bool)td.GetCustomData("farmable");
    }

    /// <summary>Every painted Ground cell flagged farmable (the tillable soil the player may work).</summary>
    public IEnumerable<Vector2I> FarmableCells()
    {
        if (_ground == null) yield break;
        foreach (Vector2I cell in _ground.GetUsedCells())
            if (IsFarmable(cell)) yield return cell;
    }
}
