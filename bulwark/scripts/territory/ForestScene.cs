using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Thin Node2D adapter for the Tier-1 forest territory (<c>scenes/territory/forest.tscn</c>),
/// mirroring OutpostScene: it exposes the blockout's functional nodes (entry spawn, exit trigger,
/// node/roamer markers) and translates world contact into GameState commands
/// (HarvestResourceNode, BeginTerritoryEncounter, TravelToOutpost). No game rules live here.
/// Player/HUD/squad-panel hosting is inherited from <see cref="CozyWorldScene"/>; no farm world is
/// injected — the player moves and raises interact intents only. The user hand-paints the
/// tilemaps; marker ids are the contract with <see cref="Territories"/> data
/// (%Node_&lt;id&gt; / %Roamer_&lt;id&gt;).
///
/// Resource nodes come in three placement flavors (design/forage.md):
///  - marker-spawned (the original %Node_&lt;id&gt; contract, instanced from the definition's prefab),
///  - PLACED prefabs authored directly in the .tscn (trees etc.) — discovered at ready, registered
///    with the territory system under territory id + node name (names must be scene-unique),
///  - forage spawns — the ForageSystem's daily pass, synced here through the cell adapter and
///    instanced at runtime (the sanctioned dynamic-children path).
///
/// Layer draw order matches the outpost: Ground, GroundDecor, Walls, Props, Overhead(z=10); the
/// player sits at z=5 between Props and Overhead. The scene root is Y-SORTED, so tree prefabs
/// (z=5, origin at the trunk base) draw over the player standing behind them and under the player
/// standing in front.
/// </summary>
public partial class ForestScene : CozyWorldScene
{
    /// <summary>The <see cref="TerritoryDefinition.Id"/> this scene renders.</summary>
    [Export] public string TerritoryId { get; set; } = "verdant_fringe";

    /// <summary>Max distance (px) from the player at which an interact press harvests a node.</summary>
    [Export] public float InteractRange { get; set; } = 64f;

    private TileMapLayer? _ground;
    private Marker2D? _playerSpawn;
    private Area2D? _exitTrigger;
    private TransitionSign? _exitSign;

    private readonly Dictionary<string, ResourceNodeView> _nodeViews = new();
    private readonly Dictionary<string, ResourceNodeDefinition> _nodeDefs = new();
    private readonly HashSet<string> _forageNodeIds = new();
    private readonly List<RoamingEnemy> _roamers = new();
    private ForestForageAdapter? _forageAdapter;

    public override void _Ready()
    {
        _ground = GetNodeOrNull<TileMapLayer>("%Ground");
        _playerSpawn = GetNodeOrNull<Marker2D>("%PlayerSpawn");
        _exitTrigger = GetNodeOrNull<Area2D>("%ExitTrigger");

        SpawnPlayer();
        SpawnHud();
        SpawnSquadPanel();
        SpawnDaySummaryPanel();
        SpawnPauseMenu();
        SpawnCalendarPanel();
        DiscoverPlacedNodes();
        SpawnResourceNodes();
        SpawnRoamers();
        SpawnExitSign();
        WireExit();
        BuildWorldCollision(_ground);
        WireStateEvents();
        SyncForage();
        RefreshHudAll();
        ShowArrivalToast();
    }

    // ------------------------------------------------------------------ Instancing

    /// <summary>Victorious return drops the player back where the fight started; otherwise the entry.</summary>
    protected override Vector2 GetPlayerSpawnPosition()
        => GameState.Instance?.ConsumeTerritoryReturn(TerritoryId)
           ?? _playerSpawn?.GlobalPosition
           ?? Vector2.Zero;

    /// <summary>
    /// Discover the resource-node prefabs placed directly in this .tscn (authored in the editor /
    /// baked by ForestPainter). Node NAME is the save identity (territory id + name), so duplicate
    /// names are rejected loudly. Registers all placements with the territory system FIRST (the
    /// depleted query resolves definitions through that registry), then binds the views.
    /// </summary>
    private void DiscoverPlacedNodes()
    {
        var gs = GameState.Instance;
        var placed = new List<(ResourceNodeView View, string NodeId, ResourceNodeDefinition Def)>();
        CollectPlacedNodes(this, placed);

        var placements = new List<(string, string)>(placed.Count);
        foreach (var (_, nodeId, def) in placed)
            placements.Add((nodeId, def.Id));
        gs?.RegisterTerritoryPlacements(TerritoryId, placements);

        foreach (var (view, nodeId, def) in placed)
        {
            view.Bind(nodeId, def);
            view.SetLabelVisible(false);
            view.SetDepleted(gs?.Territory.IsNodeDepleted(TerritoryId, nodeId) ?? false);
            _nodeViews[nodeId] = view;
            _nodeDefs[nodeId] = def;
        }
    }

    private void CollectPlacedNodes(
        Node parent, List<(ResourceNodeView, string, ResourceNodeDefinition)> result)
    {
        foreach (Node child in parent.GetChildren())
        {
            if (child is ResourceNodeView view)
            {
                string nodeId = view.Name;
                if (_nodeViews.ContainsKey(nodeId) || result.Exists(r => r.Item2 == nodeId))
                {
                    GD.PushError($"[ForestScene] duplicate placed node name '{nodeId}' — skipped " +
                                 "(placed-node names must be unique per scene, they are the save identity)");
                    continue;
                }
                if (!ResourceNodes.TryGet(view.DefinitionId, out var def))
                {
                    GD.PushError($"[ForestScene] placed node '{nodeId}' has unknown definition id " +
                                 $"'{view.DefinitionId}' — skipped");
                    continue;
                }
                result.Add((view, nodeId, def));
                continue; // prefab internals hold no further placed nodes
            }
            CollectPlacedNodes(child, result);
        }
    }

    /// <summary>Marker flow: one view per <see cref="Territories"/> placement at its
    /// %Node_&lt;id&gt; marker, instanced from the definition's prefab (placeholder token scene
    /// when the definition ships none).</summary>
    private void SpawnResourceNodes()
    {
        var gs = GameState.Instance;
        if (!Territories.TryGet(TerritoryId, out var territory))
            return;

        foreach (var placement in territory.Nodes)
        {
            var marker = GetNodeOrNull<Marker2D>($"%Node_{placement.NodeId}");
            if (marker == null || !ResourceNodes.TryGet(placement.ResourceId, out var def))
                continue;

            var view = SpawnNodeView(placement.NodeId, def, marker.GlobalPosition);
            if (view != null)
                view.SetDepleted(gs?.Territory.IsNodeDepleted(TerritoryId, placement.NodeId) ?? false);
        }
    }

    /// <summary>Instance one node view (marker or forage flow) from the definition's prefab.</summary>
    private ResourceNodeView? SpawnNodeView(string nodeId, ResourceNodeDefinition def, Vector2 position)
    {
        var scene = GD.Load<PackedScene>(def.ScenePath ?? "res://scenes/territory/resource_node.tscn");
        if (scene == null)
            return null;

        var view = scene.Instantiate<ResourceNodeView>();
        view.Name = $"ResourceNode_{nodeId}";
        view.ZIndex = 5; // y-sorts with the player under the y-sorted scene root
        AddChild(view);
        view.GlobalPosition = position;
        view.Bind(nodeId, def);
        view.SetLabelVisible(false);
        _nodeViews[nodeId] = view;
        _nodeDefs[nodeId] = def;
        return view;
    }

    // ------------------------------------------------------------------ Forage (design/forage.md)

    /// <summary>Run the owed forage passes (catch-up at entry, again on day change while here)
    /// and mirror the resulting spawn set as node views.</summary>
    private void SyncForage()
    {
        var gs = GameState.Instance;
        if (gs == null || _ground == null)
            return;

        _forageAdapter ??= new ForestForageAdapter(
            _ground, BuildBlockedLayers(), BuildReservedCells(), BuildTrailCells());
        gs.SyncTerritoryForage(TerritoryId, _forageAdapter);
        RefreshForageViews();
    }

    private IEnumerable<TileMapLayer?> BuildBlockedLayers() => new[]
    {
        GetNodeOrNull<TileMapLayer>("%Walls"),
        GetNodeOrNull<TileMapLayer>("%Props"),
        GetNodeOrNull<TileMapLayer>("%Overhead"),
        GetNodeOrNull<TileMapLayer>("%OverheadDecor"),
        GetNodeOrNull<TileMapLayer>("%OverheadAccent"),
    };

    /// <summary>Cells all spawns keep their full distance from: every current node view (markers,
    /// placed prefabs) and every roamer marker.</summary>
    private IEnumerable<(int X, int Y)> BuildReservedCells()
    {
        var reserved = new List<(int, int)>();
        foreach (var view in _nodeViews.Values)
            reserved.Add(ToCell(view.GlobalPosition));
        if (Territories.TryGet(TerritoryId, out var territory))
        {
            foreach (var roamer in territory.Roamers)
            {
                var marker = GetNodeOrNull<Marker2D>($"%Roamer_{roamer.RoamerId}");
                if (marker != null)
                    reserved.Add(ToCell(marker.GlobalPosition));
            }
        }
        return reserved;
    }

    /// <summary>Trail-anchored cells (exit trigger, entry spawn): forage keeps 2 cells away, debris
    /// only 1 (clutter belongs underfoot — design/forage.md).</summary>
    private IEnumerable<(int X, int Y)> BuildTrailCells()
    {
        var trail = new List<(int, int)>();
        if (_exitTrigger != null)
            trail.Add(ToCell(_exitTrigger.GlobalPosition));
        if (_playerSpawn != null)
            trail.Add(ToCell(_playerSpawn.GlobalPosition));
        return trail;
    }

    /// <summary>Mirror the live forage AND debris sets: instance views for new spawns, drop views
    /// for spawns that were harvested/cleared or swept.</summary>
    private void RefreshForageViews()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        var live = new List<ForageSpawn>(gs.GetLiveForage(TerritoryId));
        live.AddRange(gs.GetLiveDebris(TerritoryId));
        var liveIds = new HashSet<string>();
        foreach (var spawn in live)
            liveIds.Add(spawn.NodeId);

        // Remove stale forage views (collected or swept).
        var stale = new List<string>();
        foreach (string id in _forageNodeIds)
            if (!liveIds.Contains(id))
                stale.Add(id);
        foreach (string id in stale)
        {
            if (_nodeViews.TryGetValue(id, out var view) && IsInstanceValid(view))
                view.QueueFree();
            _nodeViews.Remove(id);
            _nodeDefs.Remove(id);
            _forageNodeIds.Remove(id);
        }

        // Spawn views for new forage.
        foreach (var spawn in live)
        {
            if (_forageNodeIds.Contains(spawn.NodeId)
                || !ResourceNodes.TryGet(spawn.ResourceId, out var def))
            {
                continue;
            }
            Vector2 pos = CellCenter(spawn.CellX, spawn.CellY);
            if (SpawnNodeView(spawn.NodeId, def, pos) != null)
                _forageNodeIds.Add(spawn.NodeId);
        }
    }

    private (int, int) ToCell(Vector2 globalPos)
    {
        if (_ground == null)
            return ((int)(globalPos.X / 48f), (int)(globalPos.Y / 48f));
        Vector2I cell = _ground.LocalToMap(_ground.ToLocal(globalPos));
        return (cell.X, cell.Y);
    }

    private Vector2 CellCenter(int x, int y)
        => _ground != null
            ? _ground.ToGlobal(_ground.MapToLocal(new Vector2I(x, y)))
            : new Vector2(x * 48 + 24, y * 48 + 24);

    // ------------------------------------------------------------------ Roamers

    private void SpawnRoamers()
    {
        if (!Territories.TryGet(TerritoryId, out var territory))
            return;
        foreach (var roamer in territory.Roamers)
            TrySpawnRoamer(roamer.RoamerId);
    }

    /// <summary>
    /// A new day cleared the roamer-defeated set (TerritorySystem day reset) — put the missing
    /// bodies back on the map. Ids already alive are skipped, so survivors keep their position.
    /// </summary>
    private void RespawnRoamers()
    {
        if (!Territories.TryGet(TerritoryId, out var territory))
            return;
        foreach (var roamer in territory.Roamers)
        {
            if (_roamers.Exists(r => IsInstanceValid(r) && r.RoamerId == roamer.RoamerId))
                continue;
            TrySpawnRoamer(roamer.RoamerId);
        }
    }

    /// <summary>Spawn one roamer body at its %Roamer_&lt;id&gt; marker — unless it was already
    /// beaten today (it stays despawned for the rest of the day).</summary>
    private void TrySpawnRoamer(string roamerId)
    {
        if (Player == null)
            return;
        if (GameState.Instance?.Territory.IsRoamerDefeated(TerritoryId, roamerId) == true)
            return;

        var marker = GetNodeOrNull<Marker2D>($"%Roamer_{roamerId}");
        var scene = GD.Load<PackedScene>("res://scenes/territory/roaming_enemy.tscn");
        if (marker == null || scene == null)
            return;

        var enemy = scene.Instantiate<RoamingEnemy>();
        enemy.Name = $"Roamer_{roamerId}_Body";
        enemy.ZIndex = 5;
        AddChild(enemy);
        enemy.GlobalPosition = marker.GlobalPosition;
        enemy.Setup(roamerId, Player);
        enemy.PlayerContacted += OnRoamerContact;
        _roamers.Add(enemy);
    }

    /// <summary>Blockout-grade exit affordance: a visible signpost at the %ExitTrigger position with
    /// a once-per-approach proximity hint (the sign's radius fires before the trigger itself, so the
    /// player learns what walking in does). One hint mechanism only: the HUD toast.</summary>
    private void SpawnExitSign()
    {
        _exitSign = SpawnTransitionSign("ExitSign", "To Outpost", _exitTrigger, trackPlayer: true);
        if (_exitSign != null)
            _exitSign.PlayerApproached += OnExitApproached;
    }

    private void OnExitApproached()
    {
        if (!IsTransitioning)
            Hud?.ShowToast("Walk here to return to the outpost", 2f);
    }

    private void WireExit()
    {
        _exitTrigger?.Connect(Area2D.SignalName.BodyEntered, Callable.From<Node2D>(OnExitBodyEntered));
    }

    protected override void WireExtraStateEvents(GameState gs)
    {
        gs.DayStarted += OnDayStarted;
        gs.TerritoryNodeChanged += OnNodeChanged;
        gs.ResourceHarvested += OnResourceHarvested;
        gs.ForageChanged += OnForageChanged;
    }

    protected override void UnwireExtraStateEvents(GameState gs)
    {
        gs.DayStarted -= OnDayStarted;
        gs.TerritoryNodeChanged -= OnNodeChanged;
        gs.ResourceHarvested -= OnResourceHarvested;
        gs.ForageChanged -= OnForageChanged;
    }

    // ------------------------------------------------------------------ Interactions

    /// <summary>Interact press: harvest the nearest live node in range with the active tool.</summary>
    protected override void OnInteractRequested(ToolKind tool)
    {
        var gs = GameState.Instance;
        if (gs == null || Player == null || IsTransitioning)
            return;

        var nearest = FindNearestNode();
        if (nearest == null)
            return;

        if (gs.HarvestResourceNode(nearest.NodeId, tool))
            return;

        // Presentational hint: the only in-range failure for a visible node is the tool gate.
        if (_nodeDefs.TryGetValue(nearest.NodeId, out var def) && def.Tool != tool)
            Hud?.ShowToast($"{def.DisplayName}: needs the {ToolBelt.DisplayName(def.Tool)}", 1.5f);
    }

    /// <summary>Nearest visible (non-depleted) node view within <see cref="InteractRange"/>.</summary>
    private ResourceNodeView? FindNearestNode()
    {
        if (Player == null)
            return null;

        ResourceNodeView? nearest = null;
        float best = InteractRange;
        foreach (var view in _nodeViews.Values)
        {
            if (!IsInstanceValid(view) || !view.Visible)
                continue;
            float d = view.GlobalPosition.DistanceTo(Player.GlobalPosition);
            if (d <= best)
            {
                best = d;
                nearest = view;
            }
        }
        return nearest;
    }

    /// <summary>Floating "E — …" HUD prompt: mirrors <see cref="OnInteractRequested"/>'s nearest-node
    /// search (same <see cref="InteractRange"/>) and the exit sign's own proximity flag. Doubles as
    /// the label-proximity driver (same poll): only the nearest-in-range node shows its name label,
    /// so the tree-filled forest stays label-free at a distance.</summary>
    protected override string? GetInteractionHint()
    {
        if (Player == null)
            return null;

        var nearest = FindNearestNode();
        foreach (var view in _nodeViews.Values)
        {
            if (IsInstanceValid(view))
                view.SetLabelVisible(view == nearest);
        }

        if (_exitSign?.PlayerInRange == true)
            return "Travel";

        if (nearest != null && _nodeDefs.TryGetValue(nearest.NodeId, out var def))
        {
            return def.Tool switch
            {
                ToolKind.Axe => "Chop",
                ToolKind.Pick => "Mine",
                _ => "Gather",
            };
        }

        return null;
    }

    private void OnRoamerContact(string roamerId)
    {
        var gs = GameState.Instance;
        if (gs == null || Player == null || IsTransitioning)
            return;
        if (!gs.BeginTerritoryEncounter(roamerId, Player.GlobalPosition))
            return;

        // Freeze the world, flash the encounter line, then hand off to the combat mode
        // (SceneRouter pauses the day clock on GoToCombat).
        foreach (var roamer in _roamers)
            roamer.Freeze();

        string name = gs.Territory.PendingEncounter?.EncounterName ?? "An enemy";
        BeginHandOff($"{name} attacks!", () => SceneRouter.Instance?.GoToCombat());
    }

    private void OnExitBodyEntered(Node2D body)
    {
        if (body is not PlayerController || IsTransitioning)
            return;

        var gs = GameState.Instance;
        if (gs == null || !gs.TravelToOutpost())
            return;

        IsTransitioning = true;
        Callable.From(() => SceneRouter.Instance?.GoToOutpost()).CallDeferred();
    }

    /// <summary>
    /// A new day starting here means the 30:00 all-nighter rollover caught the squad in the
    /// territory — the player stays put, so no routing (the defeat wake path swaps scenes through
    /// SceneRouter itself and never lands here). TerritorySystem's own day reset already ran
    /// (roamer-defeated set cleared; due nodes respawned via NodeChanged, which refreshed the node
    /// views), so the HUD clock, the missing roamer bodies, and the forage daily pass are owed.
    /// </summary>
    private void OnDayStarted()
    {
        RefreshHudTime();
        RespawnRoamers();
        SyncForage();
    }

    // ------------------------------------------------------------------ HUD wiring (passive push)

    private void ShowArrivalToast()
    {
        string? toast = GameState.Instance?.Territory.ConsumeTravelToast();
        if (toast != null)
            Hud?.ShowToast(toast);
    }

    private void OnResourceHarvested(HarvestResultView view)
        => Hud?.ShowToast($"+{view.Count} {view.ItemName} — {view.MinutesSpent} min", 2f);

    private void OnNodeChanged(string nodeId)
    {
        var gs = GameState.Instance;
        if (gs != null && _nodeViews.TryGetValue(nodeId, out var view) && IsInstanceValid(view))
            view.SetDepleted(gs.Territory.IsNodeDepleted(TerritoryId, nodeId));
    }

    private void OnForageChanged(string territoryId)
    {
        if (territoryId == TerritoryId)
            RefreshForageViews();
    }
}
