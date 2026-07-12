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
/// Layer draw order matches the outpost: Ground, GroundDecor, Walls, Props, Overhead(z=10); the
/// player sits at z=5 between Props and Overhead.
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
    private readonly List<RoamingEnemy> _roamers = new();

    public override void _Ready()
    {
        _ground = GetNodeOrNull<TileMapLayer>("%Ground");
        _playerSpawn = GetNodeOrNull<Marker2D>("%PlayerSpawn");
        _exitTrigger = GetNodeOrNull<Area2D>("%ExitTrigger");

        SpawnPlayer();
        SpawnHud();
        SpawnSquadPanel();
        SpawnDaySummaryPanel();
        SpawnResourceNodes();
        SpawnRoamers();
        SpawnExitSign();
        WireExit();
        BuildWorldCollision(_ground);
        WireStateEvents();
        RefreshHudAll();
        ShowArrivalToast();
    }

    // ------------------------------------------------------------------ Instancing

    /// <summary>Victorious return drops the player back where the fight started; otherwise the entry.</summary>
    protected override Vector2 GetPlayerSpawnPosition()
        => GameState.Instance?.ConsumeTerritoryReturn(TerritoryId)
           ?? _playerSpawn?.GlobalPosition
           ?? Vector2.Zero;

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
    }

    protected override void UnwireExtraStateEvents(GameState gs)
    {
        gs.DayStarted -= OnDayStarted;
        gs.TerritoryNodeChanged -= OnNodeChanged;
        gs.ResourceHarvested -= OnResourceHarvested;
    }

    // ------------------------------------------------------------------ Interactions

    /// <summary>Interact press: harvest the nearest live node in range with the active tool.</summary>
    protected override void OnInteractRequested(ToolKind tool)
    {
        var gs = GameState.Instance;
        if (gs == null || Player == null || IsTransitioning)
            return;

        ResourceNodeView? nearest = null;
        float best = InteractRange;
        foreach (var view in _nodeViews.Values)
        {
            if (!view.Visible)
                continue;
            float d = view.GlobalPosition.DistanceTo(Player.GlobalPosition);
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
            Hud?.ShowToast($"{def.DisplayName}: needs the {ToolBelt.DisplayName(def.Tool)}", 1.5f);
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
    /// (roamer-defeated set cleared; daily nodes respawned via NodeChanged, which refreshed the
    /// node views), so only the HUD clock and the missing roamer bodies are owed.
    /// </summary>
    private void OnDayStarted()
    {
        RefreshHudTime();
        RespawnRoamers();
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
        if (gs != null && _nodeViews.TryGetValue(nodeId, out var view))
            view.SetDepleted(gs.Territory.IsNodeDepleted(TerritoryId, nodeId));
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
}
