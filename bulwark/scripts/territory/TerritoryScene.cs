using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Thin Node3D adapter for the greybox territory scenes (<c>scenes/territory/forest.tscn</c>,
/// <c>elderwood.tscn</c>, <c>sunken_reach.tscn</c>), mirroring OutpostScene: it exposes the
/// blockout's functional nodes (entry spawn, exit/deeper/exploration triggers, node/roamer markers)
/// and translates world contact into GameState commands (HarvestResourceNode,
/// BeginTerritoryEncounter, TravelToOutpost). No game rules live here. Player/HUD/squad-panel
/// hosting is inherited from <see cref="CozyWorldScene"/>; no farm world is injected — the player
/// moves and raises interact intents only. The user authors the 3D blockout in the editor (every
/// tree, node prefab and sign is its own scene, swappable one at a time); marker ids are the
/// contract with <see cref="Territories"/> data (%Node_&lt;id&gt; / %Roamer_&lt;id&gt;).
///
/// Resource nodes come in three placement flavors (design/forage.md):
///  - marker-spawned (the original %Node_&lt;id&gt; contract, instanced from the definition's prefab),
///  - PLACED prefabs authored directly in the .tscn (trees etc.) — discovered at ready, registered
///    with the territory system under territory id + node name (names must be scene-unique),
///  - forage spawns — the ForageSystem's daily pass, synced here through the cell provider and
///    instanced at runtime (the sanctioned dynamic-children path).
///
/// WALKABLE BOUNDS: the scene AUTHORS its own collision — a <c>%Ground</c> StaticBody3D (physics
/// layer 1 "Terrain") carrying the floor box and the perimeter wall boxes. There is no runtime
/// baking. Depth sorting is the 3D depth buffer's job; the old y-sort/z-index contract is gone.
///
/// GRID: one cell is ONE METRE. Cell (x, y) covers world X ∈ [x, x+1), Z ∈ [y, y+1); its centre is
/// (x + 0.5, 0, y + 0.5).
/// </summary>
public partial class TerritoryScene : CozyWorldScene
{
    /// <summary>The <see cref="TerritoryDefinition.Id"/> this scene renders.</summary>
    [Export] public string TerritoryId { get; set; } = "verdant_fringe";

    /// <summary>Max distance (m) from the player at which an interact press harvests a node
    /// (≈1.5 cells — the 3D reading of the old 64 px reach).</summary>
    [Export] public float InteractRange { get; set; } = 1.5f;

    /// <summary>Quest whose active window governs the wolf-lair boss site (design/tutorial_quests.md
    /// quest 9). Tunable so the boss-site convention is not hard-coded in logic.</summary>
    [Export] public string WolfQuestId { get; set; } = "wolf_of_the_fringe";

    /// <summary>Where the %ExitTrigger leads. Empty = back to the outpost (the Verdant Fringe
    /// default); a territory id = march to that LINKED territory instead without an outpost round-trip
    /// (the Elderwood's exit points back to the Verdant Fringe). Set per scene.</summary>
    [Export] public string ExitTerritoryId { get; set; } = "";

    /// <summary>Signpost text for the %ExitTrigger affordance.</summary>
    [Export] public string ExitLabel { get; set; } = "To Outpost";

    /// <summary>Optional deeper-forest transition (the Verdant Fringe → Elderwood seam,
    /// design/tutorial_quests.md quest 11): the territory id the %DeeperTrigger leads to. Empty = this
    /// scene has no deeper sign. GATED on the biome unlock — impassable until the outpost's Command
    /// Post opens the biome (GameState.IsBiomeUnlocked).</summary>
    [Export] public string DeeperTerritoryId { get; set; } = "";

    /// <summary>Quest event raised once on arrival in this territory (design/tutorial_quests.md quest
    /// 11's optional "Travel to the Elderwood" objective, key <c>elderwood_entered</c>). Empty = raise
    /// nothing.</summary>
    [Export] public string TerritoryEnteredEvent { get; set; } = "";

    private StaticBody3D? _ground;
    private Marker3D? _playerSpawn;
    private Area3D? _exitTrigger;
    private TransitionSign? _exitSign;
    private Area3D? _deeperTrigger;
    private TransitionSign? _deeperSign;

    private readonly Dictionary<string, ResourceNodeView> _nodeViews = new();
    private readonly Dictionary<string, ResourceNodeDefinition> _nodeDefs = new();
    private readonly HashSet<string> _forageNodeIds = new();
    private readonly List<RoamingEnemy> _roamers = new();
    private WolfLair? _wolfLair;
    private RegionForageCellProvider? _forageCells;

    public override void _Ready()
    {
        _ground = GetNodeOrNull<StaticBody3D>("%Ground");
        _playerSpawn = GetNodeOrNull<Marker3D>("%PlayerSpawn");
        _exitTrigger = GetNodeOrNull<Area3D>("%ExitTrigger");

        SpawnPlayer();
        SpawnHud();
        SpawnSquadPanel();
        SpawnDaySummaryPanel();
        SpawnPauseMenu();
        SpawnCalendarPanel();
        DiscoverPlacedNodes();
        SpawnResourceNodes();
        SpawnRoamers();
        RefreshWolfLair();
        SpawnExitSign();
        WireExit();
        SpawnDeeperSign();
        WireStateEvents();
        SyncForage();
        RefreshHudAll();
        ShowArrivalToast();
        RaiseTerritoryEnteredEvent();
    }

    // ------------------------------------------------------------------ Instancing

    /// <summary>Victorious return drops the player back where the fight started; otherwise the entry.
    /// The stored return context is planar (X, Z) — the ground plane the whole territory lives on.</summary>
    protected override Vector3 GetPlayerSpawnPosition()
    {
        Vector2? stored = GameState.Instance?.ConsumeTerritoryReturn(TerritoryId);
        if (stored is { } p)
            return new Vector3(p.X, 0f, p.Y);
        return _playerSpawn?.GlobalPosition ?? Vector3.Zero;
    }

    /// <summary>
    /// Discover the resource-node prefabs placed directly in this .tscn (authored in the editor).
    /// Node NAME is the save identity (territory id + name), so duplicate names are rejected loudly.
    /// Registers all placements with the territory system FIRST (the depleted query resolves
    /// definitions through that registry), then binds the views.
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
                    GD.PushError($"[TerritoryScene] duplicate placed node name '{nodeId}' — skipped " +
                                 "(placed-node names must be unique per scene, they are the save identity)");
                    continue;
                }
                if (!ResourceNodes.TryGet(view.DefinitionId, out var def))
                {
                    GD.PushError($"[TerritoryScene] placed node '{nodeId}' has unknown definition id " +
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
            var marker = GetNodeOrNull<Marker3D>($"%Node_{placement.NodeId}");
            if (marker == null || !ResourceNodes.TryGet(placement.ResourceId, out var def))
                continue;

            var view = SpawnNodeView(placement.NodeId, def, marker.GlobalPosition);
            if (view != null)
                view.SetDepleted(gs?.Territory.IsNodeDepleted(TerritoryId, placement.NodeId) ?? false);
        }
    }

    /// <summary>Instance one node view (marker or forage flow) from the definition's prefab.</summary>
    private ResourceNodeView? SpawnNodeView(string nodeId, ResourceNodeDefinition def, Vector3 position)
    {
        var scene = GD.Load<PackedScene>(def.ScenePath ?? "res://scenes/territory/resource_node.tscn");
        if (scene == null)
            return null;

        var view = scene.Instantiate<ResourceNodeView>();
        view.Name = $"ResourceNode_{nodeId}";
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
        if (gs == null)
            return;

        _forageCells ??= new RegionForageCellProvider(
            GroundRectCells(), BuildOccupiedCells(), BuildReservedCells(), BuildTrailCells());
        gs.SyncTerritoryForage(TerritoryId, _forageCells);
        RefreshForageViews();
    }

    /// <summary>
    /// The walkable ground rectangle in CELLS, read off the AUTHORED %Ground body: the floor is the
    /// largest box collider it carries (the perimeter walls are the thin ones). Without a %Ground
    /// body — an F6 run of a stub scene — the region degenerates to nothing and forage simply never
    /// finds a cell.
    /// </summary>
    public Rect2I GroundRectCells()
    {
        if (_ground == null)
            return new Rect2I(0, 0, 0, 0);

        Rect2I best = new(0, 0, 0, 0);
        long bestArea = 0;
        foreach (Node child in _ground.GetChildren())
        {
            if (child is not CollisionShape3D { Disabled: false } shape || shape.Shape is not BoxShape3D box)
                continue;

            Vector3 centre = shape.GlobalPosition;
            Vector3 half = box.Size * 0.5f;
            int x0 = Mathf.FloorToInt(centre.X - half.X);
            int y0 = Mathf.FloorToInt(centre.Z - half.Z);
            int x1 = Mathf.CeilToInt(centre.X + half.X);
            int y1 = Mathf.CeilToInt(centre.Z + half.Z);
            long area = (long)(x1 - x0) * (y1 - y0);
            if (area > bestArea)
            {
                bestArea = area;
                best = new Rect2I(x0, y0, x1 - x0, y1 - y0);
            }
        }
        return best;
    }

    /// <summary>
    /// Cells claimed by world objects the forage pass must stay off: every trigger footprint
    /// (exit / deeper / exploration sensors) and every authored obstacle body that is not a resource
    /// node (those are handled as reserved cells) or the %Ground body itself. The provider adds its
    /// own one-cell ring around each.
    /// </summary>
    private IEnumerable<(int X, int Y)> BuildOccupiedCells()
    {
        var occupied = new List<(int, int)>();
        CollectOccupiedCells(this, occupied);
        return occupied;
    }

    private void CollectOccupiedCells(Node parent, List<(int, int)> result)
    {
        foreach (Node child in parent.GetChildren())
        {
            // Resource nodes are reserved cells (full spacing), the ground body IS the walkable
            // region, and the player/roamer bodies move — none of them are static occupancy.
            if (child is ResourceNodeView || child == _ground
                || child is PlayerController || child is RoamingEnemy)
            {
                continue;
            }

            if (child is CollisionShape3D { Disabled: false } shape)
            {
                AddShapeCells(shape, result);
                continue;
            }
            CollectOccupiedCells(child, result);
        }
    }

    /// <summary>Rasterise a collider's XZ footprint into cells (box / sphere / cylinder / capsule
    /// extents; anything else claims just the cell it stands on).</summary>
    private static void AddShapeCells(CollisionShape3D shape, List<(int, int)> result)
    {
        Vector3 centre = shape.GlobalPosition;
        float halfX = 0.5f, halfZ = 0.5f;
        switch (shape.Shape)
        {
            case BoxShape3D box:
                halfX = box.Size.X * 0.5f;
                halfZ = box.Size.Z * 0.5f;
                break;
            case SphereShape3D sphere:
                halfX = halfZ = sphere.Radius;
                break;
            case CylinderShape3D cylinder:
                halfX = halfZ = cylinder.Radius;
                break;
            case CapsuleShape3D capsule:
                halfX = halfZ = capsule.Radius;
                break;
        }

        for (int x = Mathf.FloorToInt(centre.X - halfX); x <= Mathf.FloorToInt(centre.X + halfX); x++)
            for (int y = Mathf.FloorToInt(centre.Z - halfZ); y <= Mathf.FloorToInt(centre.Z + halfZ); y++)
                result.Add((x, y));
    }

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
                var marker = GetNodeOrNull<Marker3D>($"%Roamer_{roamer.RoamerId}");
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
            Vector3 pos = CellCentre(spawn.CellX, spawn.CellY);
            if (SpawnNodeView(spawn.NodeId, def, pos) != null)
                _forageNodeIds.Add(spawn.NodeId);
        }
    }

    /// <summary>Grid cell containing a world-space point (one cell = one metre on the XZ plane).</summary>
    private static (int, int) ToCell(Vector3 world)
        => (Mathf.FloorToInt(world.X), Mathf.FloorToInt(world.Z));

    /// <summary>Centre world-space point (on the ground plane) of a grid cell.</summary>
    private static Vector3 CellCentre(int x, int y) => new(x + 0.5f, 0f, y + 0.5f);

    /// <summary>Planar (X, Z) reading of a world point — the shape the territory system stores as a
    /// return position.</summary>
    private static Vector2 Planar(Vector3 world) => new(world.X, world.Z);

    // ------------------------------------------------------------------ Roamers

    private void SpawnRoamers()
    {
        if (!Territories.TryGet(TerritoryId, out var territory))
            return;
        foreach (var roamer in territory.Roamers)
        {
            if (roamer.IsBoss)
                continue; // boss sites are placed by the wolf-lair path, not the wandering pass
            TrySpawnRoamer(roamer.RoamerId);
        }
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
            if (roamer.IsBoss)
                continue; // boss sites do not respawn with the daily roamer pass (see RefreshWolfLair)
            if (_roamers.Exists(r => IsInstanceValid(r) && r.RoamerId == roamer.RoamerId))
                continue;
            TrySpawnRoamer(roamer.RoamerId);
        }
    }

    /// <summary>
    /// Place or clear the one-shot wolf-lair boss site (design/tutorial_quests.md quest 9) to match
    /// its lifecycle: present exactly while <see cref="WolfQuestId"/> is active AND the wolf is not yet
    /// slain (<see cref="WolfLair.ShouldAppear"/>). Null-safe — a missing boss roamer or marker logs
    /// and skips (BuildingLoader's pattern). Re-run at ready and on day change; the flag persists, so
    /// a slain wolf never reappears across save/load.
    /// </summary>
    private void RefreshWolfLair()
    {
        var gs = GameState.Instance;
        if (gs == null || Player == null || !Territories.TryGet(TerritoryId, out var territory))
            return;

        string? bossId = null;
        foreach (var roamer in territory.Roamers)
            if (roamer.IsBoss)
            {
                bossId = roamer.RoamerId;
                break;
            }
        if (bossId == null)
            return; // this territory has no boss site

        bool shouldAppear = WolfLair.ShouldAppear(gs.IsQuestActive(WolfQuestId), gs.HasStoryFlag("dire_wolf_slain"));
        bool present = _wolfLair != null && IsInstanceValid(_wolfLair);

        if (shouldAppear && !present)
            SpawnWolfLair(bossId);
        else if (!shouldAppear && present)
        {
            _wolfLair!.QueueFree();
            _wolfLair = null;
        }
    }

    /// <summary>Instance the wolf-lair scene at its %Roamer_&lt;id&gt; marker and wire its contact to
    /// the same encounter hand-off a roamer uses. Missing marker/scene logs and skips.</summary>
    private void SpawnWolfLair(string bossId)
    {
        var marker = GetNodeOrNull<Marker3D>($"%Roamer_{bossId}");
        var scene = GD.Load<PackedScene>("res://scenes/territory/wolf_lair.tscn");
        if (marker == null || scene == null)
        {
            GD.PushWarning($"[TerritoryScene] wolf-lair marker '%Roamer_{bossId}' or scene missing — boss site skipped");
            return;
        }

        var lair = scene.Instantiate<WolfLair>();
        lair.Name = $"WolfLair_{bossId}";
        AddChild(lair);
        lair.GlobalPosition = marker.GlobalPosition;
        lair.Setup(bossId, Player!);
        lair.PlayerContacted += OnRoamerContact;
        _wolfLair = lair;
    }

    /// <summary>Spawn one roamer body at its %Roamer_&lt;id&gt; marker — unless it was already
    /// beaten today (it stays despawned for the rest of the day).</summary>
    private void TrySpawnRoamer(string roamerId)
    {
        if (Player == null)
            return;
        if (GameState.Instance?.Territory.IsRoamerDefeated(TerritoryId, roamerId) == true)
            return;

        var marker = GetNodeOrNull<Marker3D>($"%Roamer_{roamerId}");
        var scene = GD.Load<PackedScene>("res://scenes/territory/roaming_enemy.tscn");
        if (marker == null || scene == null)
            return;

        var enemy = scene.Instantiate<RoamingEnemy>();
        enemy.Name = $"Roamer_{roamerId}_Body";
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
        _exitSign = SpawnTransitionSign("ExitSign", ExitLabel, _exitTrigger, trackPlayer: true);
        if (_exitSign != null)
            _exitSign.PlayerApproached += OnExitApproached;
    }

    /// <summary>Human-readable name of wherever the %ExitTrigger leads (the outpost by default).</summary>
    private string ExitDestinationName()
        => string.IsNullOrEmpty(ExitTerritoryId)
            ? "the outpost"
            : (Territories.TryGet(ExitTerritoryId, out var d) ? d.DisplayName : ExitTerritoryId);

    private void OnExitApproached()
    {
        if (!IsTransitioning)
            Hud?.ShowToast($"Walk here to return to {ExitDestinationName()}", 2f);
    }

    /// <summary>Optional gated deep-forest affordance (the Verdant Fringe → Elderwood seam,
    /// design/tutorial_quests.md quest 11): a signpost at %DeeperTrigger that only lets the party press
    /// on once the outpost has opened the biome (GameState.IsBiomeUnlocked). Locked, it reads as
    /// impassable and travels nowhere. No deeper trigger / empty id = skipped (the Elderwood itself has
    /// no deeper sign until the Sunken Reach lands).</summary>
    private void SpawnDeeperSign()
    {
        if (string.IsNullOrEmpty(DeeperTerritoryId))
            return;

        _deeperTrigger = GetNodeOrNull<Area3D>("%DeeperTrigger");
        if (_deeperTrigger == null)
            return;

        bool unlocked = GameState.Instance?.IsBiomeUnlocked(DeeperTerritoryId) ?? false;
        _deeperSign = SpawnTransitionSign(
            "DeeperSign",
            unlocked ? $"To {DeeperDestinationName()}" : "The deep forest — impassable",
            _deeperTrigger,
            trackPlayer: true);
        if (_deeperSign != null)
            _deeperSign.PlayerApproached += OnDeeperApproached;
        _deeperTrigger.Connect(Area3D.SignalName.BodyEntered, Callable.From<Node3D>(OnDeeperBodyEntered));
    }

    /// <summary>Human-readable name of the deeper territory the %DeeperTrigger leads to.</summary>
    private string DeeperDestinationName()
        => Territories.TryGet(DeeperTerritoryId, out var d) ? d.DisplayName : DeeperTerritoryId;

    private void OnDeeperApproached()
    {
        if (IsTransitioning)
            return;
        bool unlocked = GameState.Instance?.IsBiomeUnlocked(DeeperTerritoryId) ?? false;
        Hud?.ShowToast(
            unlocked
                ? $"Walk here to press on into {DeeperDestinationName()}"
                : "The deep forest is impassable. The outpost must grow before the way opens.",
            2.5f);
    }

    private void WireExit()
    {
        _exitTrigger?.Connect(Area3D.SignalName.BodyEntered, Callable.From<Node3D>(OnExitBodyEntered));
    }

    protected override void WireExtraStateEvents(GameState gs, EventSubscriptions subs)
    {
        subs.Add(() => gs.DayStarted += OnDayStarted, () => gs.DayStarted -= OnDayStarted);
        subs.Add(() => gs.TerritoryNodeChanged += OnNodeChanged, () => gs.TerritoryNodeChanged -= OnNodeChanged);
        subs.Add(() => gs.ResourceHarvested += OnResourceHarvested, () => gs.ResourceHarvested -= OnResourceHarvested);
        subs.Add(() => gs.ForageChanged += OnForageChanged, () => gs.ForageChanged -= OnForageChanged);
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

    /// <summary>Nearest visible (non-depleted) node view within <see cref="InteractRange"/>, measured
    /// on the ground plane so a tall prefab's height never affects reach.</summary>
    private ResourceNodeView? FindNearestNode()
    {
        if (Player == null)
            return null;

        ResourceNodeView? nearest = null;
        float best = InteractRange;
        Vector2 player = Planar(Player.GlobalPosition);
        foreach (var view in _nodeViews.Values)
        {
            if (!IsInstanceValid(view) || !view.Visible)
                continue;
            float d = Planar(view.GlobalPosition).DistanceTo(player);
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

        // The deeper sign only prompts once the biome is unlocked; locked, the approach toast explains.
        if (_deeperSign?.PlayerInRange == true)
            return (GameState.Instance?.IsBiomeUnlocked(DeeperTerritoryId) ?? false) ? "Travel" : null;

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
        if (!gs.BeginTerritoryEncounter(roamerId, Planar(Player.GlobalPosition)))
            return;

        // Freeze the world, flash the encounter line, then hand off to the combat mode
        // (SceneRouter pauses the day clock on GoToCombat).
        foreach (var roamer in _roamers)
            if (IsInstanceValid(roamer))
                roamer.Freeze();

        string name = gs.Territory.PendingEncounter?.EncounterName ?? "An enemy";
        BeginHandOff($"{name} attacks!", () => SceneRouter.Instance?.GoToCombat());
    }

    private void OnExitBodyEntered(Node3D body)
    {
        if (body is not PlayerController || IsTransitioning)
            return;

        var gs = GameState.Instance;
        if (gs == null)
            return;

        // Default (empty ExitTerritoryId): march back to the outpost. Otherwise march directly to the
        // linked territory (the Elderwood's exit returns to the Verdant Fringe) — no outpost round-trip.
        if (string.IsNullOrEmpty(ExitTerritoryId))
        {
            if (!gs.TravelToOutpost())
                return;
            IsTransitioning = true;
            Callable.From(() => SceneRouter.Instance?.GoToOutpost()).CallDeferred();
        }
        else
        {
            if (!gs.TravelToLinkedTerritory(ExitTerritoryId))
                return;
            IsTransitioning = true;
            string dest = ExitTerritoryId;
            Callable.From(() => SceneRouter.Instance?.GoToTerritory(dest)).CallDeferred();
        }
    }

    private void OnDeeperBodyEntered(Node3D body)
    {
        if (body is not PlayerController || IsTransitioning)
            return;

        var gs = GameState.Instance;
        if (gs == null)
            return;

        if (!gs.IsBiomeUnlocked(DeeperTerritoryId))
        {
            Hud?.ShowToast("The deep forest is impassable. The outpost must grow before the way opens.", 2.5f);
            return;
        }
        if (!gs.TravelToLinkedTerritory(DeeperTerritoryId))
            return;

        IsTransitioning = true;
        string dest = DeeperTerritoryId;
        Callable.From(() => SceneRouter.Instance?.GoToTerritory(dest)).CallDeferred();
    }

    /// <summary>Fire the one-shot territory-entry quest event (design/tutorial_quests.md quest 11's
    /// optional <c>elderwood_entered</c> objective). Runs on every scene entry; RecordQuestEvent is
    /// idempotent once the OnceEvent objective is satisfied, so re-firing after a combat return is
    /// harmless.</summary>
    private void RaiseTerritoryEnteredEvent()
    {
        if (!string.IsNullOrEmpty(TerritoryEnteredEvent))
            GameState.Instance?.RecordQuestEvent(TerritoryEnteredEvent);
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
        RefreshWolfLair();
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

    // --- Blockout accessors (spike/host queries — mirrors OutpostScene) ---

    /// <summary>The authored floor + perimeter body (physics layer 1 "Terrain").</summary>
    public StaticBody3D? Ground => _ground;

    public Marker3D? PlayerSpawn => _playerSpawn;

    public Area3D? ExitTrigger => _exitTrigger;

    /// <summary>The forage spawn region this scene built from its authored ground + occupancy
    /// (null before <see cref="SyncForage"/> runs, or without a GameState autoload).</summary>
    public IForageCellProvider? ForageCells => _forageCells;
}
