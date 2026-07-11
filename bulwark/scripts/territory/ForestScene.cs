using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.UI;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Thin Node2D adapter for the Tier-1 forest territory (<c>scenes/territory/forest.tscn</c>),
/// mirroring OutpostScene: it exposes the blockout's functional nodes (tile layers, entry spawn,
/// exit trigger, node/roamer markers), spawns the player + HUD + squad panel, and translates world
/// contact into GameState commands (HarvestResourceNode, BeginTerritoryEncounter, TravelToOutpost).
/// No game rules live here. The user hand-paints the tilemaps; marker ids are the contract with
/// <see cref="Territories"/> data (%Node_&lt;id&gt; / %Roamer_&lt;id&gt;).
///
/// Layer draw order matches the outpost: Ground, GroundDecor, Walls, Props, Overhead(z=10); the
/// player sits at z=5 between Props and Overhead.
/// </summary>
public partial class ForestScene : Node2D
{
    /// <summary>The <see cref="TerritoryDefinition.Id"/> this scene renders.</summary>
    [Export] public string TerritoryId { get; set; } = "verdant_fringe";

    /// <summary>Max distance (px) from the player at which an interact press harvests a node.</summary>
    [Export] public float InteractRange { get; set; } = 64f;

    private Marker2D? _playerSpawn;
    private Area2D? _exitTrigger;

    private PlayerController? _player;
    private CozyHud? _hud;
    private SquadPanel? _squadPanel;

    private readonly Dictionary<string, ResourceNodeView> _nodeViews = new();
    private readonly List<RoamingEnemy> _roamers = new();

    private bool _transitioning; // encounter hand-off or travel out — ignore further world input

    public override void _Ready()
    {
        _playerSpawn = GetNodeOrNull<Marker2D>("%PlayerSpawn");
        _exitTrigger = GetNodeOrNull<Area2D>("%ExitTrigger");

        SpawnPlayer();
        SpawnHud();
        SpawnSquadPanel();
        SpawnResourceNodes();
        SpawnRoamers();
        WireExit();
        WireStateEvents();
        RefreshHudAll();
        ShowArrivalToast();
    }

    public override void _ExitTree()
    {
        var gs = GameState.Instance;
        if (gs != null)
        {
            gs.MinuteChanged -= RefreshHudTime;
            gs.DayStarted -= OnDayStarted;
            gs.InventoryChanged -= OnInventoryChanged;
            gs.SquadChanged -= RefreshSquadPanel;
            gs.TreatWoundsResolved -= OnTreatWoundsResolved;
            gs.TerritoryNodeChanged -= OnNodeChanged;
            gs.ResourceHarvested -= OnResourceHarvested;
        }
    }

    // ------------------------------------------------------------------ Instancing

    private void SpawnPlayer()
    {
        var scene = GD.Load<PackedScene>("res://scenes/cozy/player.tscn");
        if (scene == null)
            return;

        _player = scene.Instantiate<PlayerController>();
        _player.Name = "Player";
        _player.ZIndex = 5;
        AddChild(_player);

        // Victorious return drops the player back where the fight started; otherwise the entry.
        Vector2? returnPos = GameState.Instance?.ConsumeTerritoryReturn(TerritoryId);
        _player.GlobalPosition = returnPos ?? _playerSpawn?.GlobalPosition ?? Vector2.Zero;

        // No farm world injected here — the player moves and raises interact intents only.
        _player.InteractRequested += OnInteractRequested;
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

    private void SpawnSquadPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/squad_panel.tscn");
        if (scene == null)
            return;

        _squadPanel = scene.Instantiate<SquadPanel>();
        AddChild(_squadPanel);
        _squadPanel.TreatWoundsRequested += OnTreatWoundsRequested;
        _squadPanel.Toggled += OnSquadPanelToggled;
    }

    private void SpawnResourceNodes()
    {
        var gs = GameState.Instance;
        if (!Territories.TryGet(TerritoryId, out var territory))
            return;

        var scene = GD.Load<PackedScene>("res://scenes/territory/resource_node.tscn");
        if (scene == null)
            return;

        foreach (var placement in territory.Nodes)
        {
            var marker = GetNodeOrNull<Marker2D>($"%Node_{placement.NodeId}");
            if (marker == null || !ResourceNodes.TryGet(placement.ResourceId, out var def))
                continue;

            var view = scene.Instantiate<ResourceNodeView>();
            view.Name = $"ResourceNode_{placement.NodeId}";
            view.ZIndex = 1;
            AddChild(view);
            view.GlobalPosition = marker.GlobalPosition;
            view.Bind(placement.NodeId, def);
            view.SetDepleted(gs?.Territory.IsNodeDepleted(TerritoryId, placement.NodeId) ?? false);
            _nodeViews[placement.NodeId] = view;
        }
    }

    private void SpawnRoamers()
    {
        var gs = GameState.Instance;
        if (_player == null || !Territories.TryGet(TerritoryId, out var territory))
            return;

        var scene = GD.Load<PackedScene>("res://scenes/territory/roaming_enemy.tscn");
        if (scene == null)
            return;

        foreach (var roamer in territory.Roamers)
        {
            // A beaten roamer stays despawned for the rest of the day.
            if (gs?.Territory.IsRoamerDefeated(TerritoryId, roamer.RoamerId) == true)
                continue;

            var marker = GetNodeOrNull<Marker2D>($"%Roamer_{roamer.RoamerId}");
            if (marker == null)
                continue;

            var enemy = scene.Instantiate<RoamingEnemy>();
            enemy.Name = $"Roamer_{roamer.RoamerId}_Body";
            enemy.ZIndex = 5;
            AddChild(enemy);
            enemy.GlobalPosition = marker.GlobalPosition;
            enemy.Setup(roamer.RoamerId, _player);
            enemy.PlayerContacted += OnRoamerContact;
            _roamers.Add(enemy);
        }
    }

    private void WireExit()
    {
        _exitTrigger?.Connect(Area2D.SignalName.BodyEntered, Callable.From<Node2D>(OnExitBodyEntered));
    }

    private void WireStateEvents()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        gs.MinuteChanged += RefreshHudTime;
        gs.DayStarted += OnDayStarted;
        gs.InventoryChanged += OnInventoryChanged;
        gs.SquadChanged += RefreshSquadPanel;
        gs.TreatWoundsResolved += OnTreatWoundsResolved;
        gs.TerritoryNodeChanged += OnNodeChanged;
        gs.ResourceHarvested += OnResourceHarvested;
    }

    // ------------------------------------------------------------------ Interactions

    /// <summary>Interact press: harvest the nearest live node in range with the active tool.</summary>
    private void OnInteractRequested(ToolKind tool)
    {
        var gs = GameState.Instance;
        if (gs == null || _player == null || _transitioning)
            return;

        ResourceNodeView? nearest = null;
        float best = InteractRange;
        foreach (var view in _nodeViews.Values)
        {
            if (!view.Visible)
                continue;
            float d = view.GlobalPosition.DistanceTo(_player.GlobalPosition);
            if (d <= best)
            {
                best = d;
                nearest = view;
            }
        }
        if (nearest == null)
            return;

        if (gs.HarvestResourceNode(nearest.NodeId, tool))
            return;

        // Presentational hint: the only in-range failure for a visible node is the tool gate.
        if (TryGetNodeDef(nearest.NodeId, out var def) && def.Tool != tool)
            _hud?.ShowToast($"{def.DisplayName}: needs the {ToolName(def.Tool)}", 1.5f);
    }

    private void OnRoamerContact(string roamerId)
    {
        var gs = GameState.Instance;
        if (gs == null || _player == null || _transitioning)
            return;
        if (!gs.BeginTerritoryEncounter(roamerId, _player.GlobalPosition))
            return;

        // Freeze the world, flash the encounter line, then hand off to the combat mode
        // (SceneRouter pauses the day clock on GoToCombat).
        _transitioning = true;
        _player.ProcessMode = ProcessModeEnum.Disabled;
        foreach (var roamer in _roamers)
            roamer.Freeze();

        string name = gs.Territory.PendingEncounter?.EncounterName ?? "An enemy";
        _hud?.ShowToast($"{name} attacks!", 1.2f);

        GetTree().CreateTimer(0.9).Timeout += () => SceneRouter.Instance?.GoToCombat();
    }

    private void OnExitBodyEntered(Node2D body)
    {
        if (body is not PlayerController || _transitioning)
            return;

        var gs = GameState.Instance;
        if (gs == null || !gs.TravelToOutpost())
            return;

        _transitioning = true;
        Callable.From(() => SceneRouter.Instance?.GoToOutpost()).CallDeferred();
    }

    /// <summary>A new day only starts here via the 2 AM collapse — the forced sleep already moved
    /// the player home, so follow it to the outpost scene.</summary>
    private void OnDayStarted()
    {
        RefreshHudTime();
        if (_transitioning)
            return;
        _transitioning = true;
        Callable.From(() => SceneRouter.Instance?.GoToOutpost()).CallDeferred();
    }

    // ------------------------------------------------------------------ HUD wiring (passive push)

    private void ShowArrivalToast()
    {
        string? toast = GameState.Instance?.Territory.ConsumeTravelToast();
        if (toast != null)
            _hud?.ShowToast(toast);
    }

    private void OnResourceHarvested(HarvestResultView view)
        => _hud?.ShowToast($"+{view.Count} {view.ItemName} — {view.MinutesSpent} min", 2f);

    private void OnNodeChanged(string nodeId)
    {
        var gs = GameState.Instance;
        if (gs != null && _nodeViews.TryGetValue(nodeId, out var view))
            view.SetDepleted(gs.Territory.IsNodeDepleted(TerritoryId, nodeId));
    }

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
        RefreshHudTool();
    }

    // ------------------------------------------------------------------ Squad panel (passive push)

    private void OnSquadPanelToggled(bool open)
    {
        if (_player != null && !_transitioning)
            _player.ProcessMode = open ? ProcessModeEnum.Disabled : ProcessModeEnum.Inherit;

        var clock = GameState.Instance?.Clock;
        if (clock != null)
            clock.IsPaused = open;

        if (open)
            RefreshSquadPanel();
    }

    private void OnTreatWoundsRequested(string healerId, string targetId, int dc)
        => GameState.Instance?.TreatWounds(healerId, targetId, dc);

    private void OnTreatWoundsResolved(TreatWoundsResultView view)
        => _squadPanel?.ShowResult(view);

    private void RefreshSquadPanel()
    {
        if (_squadPanel == null || !_squadPanel.Visible)
            return;

        var view = GameState.Instance?.GetSquadPanelView();
        if (view != null)
            _squadPanel.Render(view);
    }

    // ------------------------------------------------------------------ Helpers

    private bool TryGetNodeDef(string nodeId, out ResourceNodeDefinition def)
    {
        def = null!;
        if (!Territories.TryGet(TerritoryId, out var territory))
            return false;
        foreach (var placement in territory.Nodes)
            if (placement.NodeId == nodeId)
                return ResourceNodes.TryGet(placement.ResourceId, out def);
        return false;
    }

    private static string ToolName(ToolKind tool) => tool switch
    {
        ToolKind.Hand => "Hand",
        ToolKind.Axe => "Axe",
        ToolKind.Pick => "Pick",
        ToolKind.Hoe => "Hoe",
        ToolKind.WateringCan => "Watering Can",
        ToolKind.Seeds => "Seeds",
        _ => tool.ToString(),
    };
}
