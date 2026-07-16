using System.Collections.Generic;
using System.Text;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.Data.Dialogues;
using Bulwark.Territory;
using Godot;
using CharacterRegistry = Bulwark.Data.Characters.Characters;

namespace Bulwark.Cozy;

/// <summary>
/// Thin Node2D adapter for the outpost world scene (<c>scenes/outpost/outpost.tscn</c>). Holds no
/// game logic: it only exposes typed accessors so the avatar / farming systems can query the
/// blockout — tile layers, spawn/farm markers, ruined-building placeholders, and the territory
/// gate trigger. The user hand-paints the actual tilemaps in the editor; this script never mutates
/// world state. Player/HUD/squad-panel hosting is inherited from <see cref="CozyWorldScene"/>.
///
/// Layer draw order (bottom to top): Ground, GroundDecor, Walls, Props, Overhead. Overhead is meant
/// to render above the player avatar (roofs / treetops); the player scene is expected to sit between
/// Props and Overhead.
/// </summary>
public partial class OutpostScene : CozyWorldScene
{
    /// <summary>The territory the gate leads to (M3: the single Tier-1 forest).</summary>
    [Export] public string GateTerritoryId { get; set; } = "verdant_fringe";

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

    // Farm renderer instanced by this scene (draw order: layers < FarmRenderer < Player < Overhead).
    private FarmRenderer? _farmRenderer;

    // Phase-2 build loop: instances commissioned buildings at their %Building_<id> markers and
    // refreshes their staged visual on BuildingChanged.
    private BuildingLoader? _buildingLoader;

    // Phase-3 static cast: spawns an NPC node for each ARRIVED villager at its %Villager_<id> marker
    // and refreshes on VillagerArrived. No-op in shipped play (empty villager catalog).
    private VillagerLoader? _villagerLoader;
    private TransitionSign? _gateSign;
    private bool _playerAtGate;  // player currently inside the gate trigger (interact travels)

    // Level-ups announced by the sleep command, held until the wake toast consumes them.
    private IReadOnlyList<SquadLevelUpView>? _pendingLevelUps;

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
        SpawnSquadPanel();
        SpawnBuildPanel();
        SpawnInventoryPanel();
        SpawnSmithyPanel();
        SpawnCraftingPanel();
        SpawnTradingPostPanel();
        SpawnFriendshipPanel();
        SpawnQuestPanel();
        SpawnCalendarPanel();
        SpawnDialogueBox();
        SpawnDaySummaryPanel();
        SpawnPauseMenu();
        SpawnGateSign();
        WireGate();
        BuildWorldCollision(_ground);
        SpawnBuildings();
        SpawnVillagers();
        WireStateEvents();
        RefreshHudAll();
        ShowArrivalToasts();
        TryPlayIntroScene2();
    }

    // ------------------------------------------------------------------ Instancing

    private void SpawnFarmRenderer()
    {
        _farmRenderer = new FarmRenderer { Name = "FarmRenderer", ZIndex = 1 };
        AddChild(_farmRenderer);
        _farmRenderer.Bind(this);
    }

    /// <summary>Instance every building (ruined Stage0 for not-yet-commissioned ones too) at its
    /// <c>%Building_&lt;id&gt;</c> marker with the correct stage/scaffold/overlays for its current
    /// tier, construction, season/day, and story flags (design/building_visuals.md). Null-safe:
    /// missing markers/scenes are skipped (the build state still works, art arrives later). Refreshed
    /// per building on BuildingChanged, and for every building on DayStarted/StoryFlagChanged
    /// (season/window/flag boundaries).</summary>
    private void SpawnBuildings()
    {
        _buildingLoader = new BuildingLoader(
            this,
            id => GameState.Instance?.GetBuildingTier(id) ?? 0,
            id => GameState.Instance?.Building.IsUnderConstruction(id) ?? false,
            () => GameState.Instance is { } gs ? (gs.Clock.Season, gs.Clock.Day) : (Season.Spring, 1),
            id => GameState.Instance?.HasStoryFlag(id) ?? false);
        _buildingLoader.PlaceAll();
    }

    /// <summary>Instance a placeholder NPC for every ARRIVED villager at its <c>%Villager_&lt;id&gt;</c>
    /// marker. Null-safe: missing markers are skipped. Refreshed per villager on VillagerArrived.
    /// Places nothing in shipped play (the villager catalog ships empty).</summary>
    private void SpawnVillagers()
    {
        _villagerLoader = new VillagerLoader(this, id => GameState.Instance?.IsVillagerArrived(id) ?? false);
        _villagerLoader.PlaceArrived();
    }

    protected override Vector2 GetPlayerSpawnPosition() => PlayerSpawnPosition;

    protected override void ConfigurePlayer(PlayerController player)
    {
        player.Setup(this, _bedroll);
        player.SleepRequested += OnSleepRequested;
        player.ActionRejected += ShowRejectionToast;
    }

    /// <summary>Signpost at the %GateTrigger position. Visual only: the proximity hint rides the
    /// gate trigger's own entered/exited signals.</summary>
    private void SpawnGateSign()
        => _gateSign = SpawnTransitionSign("GateSign", $"To {GateDestinationName}", _gateTrigger, trackPlayer: false);

    private void WireGate()
    {
        _gateTrigger?.Connect(Area2D.SignalName.BodyEntered, Callable.From<Node2D>(OnGateBodyEntered));
        _gateTrigger?.Connect(Area2D.SignalName.BodyExited, Callable.From<Node2D>(OnGateBodyExited));
    }

    protected override void WireExtraStateEvents(GameState gs)
    {
        gs.DayStarted += RefreshHudTime;
        gs.SquadLeveledUp += OnSquadLeveledUp;
        gs.BuildingChanged += OnBuildingPlaced;
        gs.VillagerArrived += OnVillagerArrived;
        gs.DayStarted += RefreshBuildingVisuals;
        gs.StoryFlagChanged += OnStoryFlagChangedForVisuals;

        // World-rules seam: farm commands validate through THIS scene's map truth while it hosts
        // the farm (cleared symmetrically below so a freed scene is never queried).
        gs.BindFarmWorld(IsTillable);
    }

    protected override void UnwireExtraStateEvents(GameState gs)
    {
        gs.DayStarted -= RefreshHudTime;
        gs.SquadLeveledUp -= OnSquadLeveledUp;
        gs.BuildingChanged -= OnBuildingPlaced;
        gs.VillagerArrived -= OnVillagerArrived;
        gs.DayStarted -= RefreshBuildingVisuals;
        gs.StoryFlagChanged -= OnStoryFlagChangedForVisuals;
        gs.BindFarmWorld(null);
    }

    /// <summary>A building was commissioned or upgraded: (re)place its world visual at its marker and
    /// select the stage for the new tier. The panel refresh is handled by the base class.</summary>
    private void OnBuildingPlaced(string buildingId) => _buildingLoader?.Refresh(buildingId);

    /// <summary>Calendar boundary (new day): re-evaluate every commissioned building's visual —
    /// season overlays and event windows can flip without any building's own tier/construction
    /// state changing.</summary>
    private void RefreshBuildingVisuals() => _buildingLoader?.RefreshAll();

    /// <summary>A story flag was set: re-evaluate every commissioned building's visual — flag-driven
    /// overlays and stage overrides can change independent of tier/construction.</summary>
    private void OnStoryFlagChangedForVisuals(string flagId) => _buildingLoader?.RefreshAll();

    /// <summary>A villager arrived: spawn its NPC node at its marker (idempotent).</summary>
    private void OnVillagerArrived(string villagerId) => _villagerLoader?.Refresh(villagerId);

    // ------------------------------------------------------------------ Interactions

    private void OnSquadLeveledUp(IReadOnlyList<SquadLevelUpView> levelUps)
        => _pendingLevelUps = levelUps;

    private void OnSleepRequested()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        if (Hud != null)
            Hud.PlaySleepTransition(gs.Sleep, () => BuildWakeText(gs));
        else
            gs.Sleep();
    }

    /// <summary>Wake toast: date line plus one line per overnight level-up (consumed here).</summary>
    private string BuildWakeText(GameState gs)
    {
        string text = $"You wake — {gs.Clock.DateString()}";
        if (_pendingLevelUps != null)
        {
            foreach (var lu in _pendingLevelUps)
                text += $"\n{lu.MemberName} reached level {lu.ToLevel}!";
            _pendingLevelUps = null;
        }
        return text;
    }

    /// <summary>Destination display name for gate affordance text ("the Verdant Fringe").</summary>
    private string GateDestinationName
        => Territories.TryGet(GateTerritoryId, out var def) ? def.DisplayName : GateTerritoryId;

    /// <summary>Gate trigger reached: flash the travel hint (once per approach — the trigger's own
    /// entered/exited boundary is the hysteresis) and arm the interact-to-travel flow.</summary>
    private void OnGateBodyEntered(Node2D body)
    {
        if (body is not PlayerController || IsTransitioning)
            return;

        _playerAtGate = true;
        Hud?.ShowToast(
            $"Press E / LMB — travel to {GateDestinationName} ({TerritorySystem.TravelMinutes} min)",
            2.5f);
    }

    private void OnGateBodyExited(Node2D body)
    {
        if (body is PlayerController)
            _playerAtGate = false;
    }

    /// <summary>Proximity radius (px) for the villager TALK/gift interactions (~1.5 tiles).</summary>
    private const float VillagerTalkRadius = 72f;

    /// <summary>
    /// Interact press: at the gate, march out with the FULL living squad — confirm-free travel
    /// (interact → toast → travel; no party-select panel in this flow — the panel and the
    /// capability-limited selection command remain in the repo for future flows). Away from the
    /// gate, an interact BESIDE a villager NPC talks to them (the friendship daily-talk bump).
    /// </summary>
    protected override void OnInteractRequested(ToolKind tool)
    {
        var gs = GameState.Instance;
        if (gs == null || IsTransitioning)
            return;

        if (_playerAtGate)
        {
            if (!gs.TravelToTerritory(GateTerritoryId))
            {
                Hud?.ShowToast("Cannot travel right now.", 1.5f);
                return;
            }

            string territoryId = GateTerritoryId;
            BeginHandOff(
                $"The squad marches for {GateDestinationName}.",
                () => SceneRouter.Instance?.GoToTerritory(territoryId));
            return;
        }

        TryTalkToVillager(gs);
    }

    /// <summary>The placed villager NPC beside the player, for the friendship panel's gift flow.</summary>
    protected override string? GetNearbyVillagerId()
        => Player == null ? null : _villagerLoader?.NearestVillagerId(Player.GlobalPosition, VillagerTalkRadius);

    /// <summary>Floating "E — …" HUD prompt: mirrors <see cref="OnInteractRequested"/>'s exact
    /// proximity checks (the gate-trigger flag, the bedroll cell math, the villager talk radius) so
    /// the hint never promises an action interact wouldn't actually take.</summary>
    protected override string? GetInteractionHint()
    {
        if (Player == null)
            return null;
        if (_playerAtGate)
            return "Travel";
        if (IsNearBedroll())
            return "Sleep";
        if (GetNearbyVillagerId() != null)
            return "Talk";
        return null;
    }

    /// <summary>Same cell math as <see cref="PlayerController.TrySleepAtBedroll"/> (standing on or
    /// facing the bedroll tile) — read-only mirror the hint needs, without duplicating the private
    /// bedroll cell cached on the controller.</summary>
    private bool IsNearBedroll()
    {
        if (_bedroll == null || Player == null)
            return false;
        Vector2I self = WorldToCell(Player.GlobalPosition);
        Vector2I bedrollCell = WorldToCell(_bedroll.GlobalPosition);
        return self == bedrollCell || self + Player.FacingDirection == bedrollCell;
    }

    /// <summary>
    /// TALK: interact beside a placed villager NPC. First tries the dialogue system's talk pool
    /// (if a talk pool exists for the character with a passing entry, play it in the dialogue box).
    /// Falls back to the old Personality toast if no talk pool is loaded.
    /// </summary>
    private void TryTalkToVillager(GameState gs)
    {
        string? charId = GetNearbyVillagerId();
        if (charId == null)
            return;

        bool bumped = gs.TalkTo(charId);

        // Try the dialogue system's talk pool first
        if (gs.DialogueDb != null && gs.DialogueDb.HasTalkPool(charId))
        {
            var lines = gs.DialogueDb.GetTalkLines(charId, gs.BuildConditionContext());
            if (lines != null && lines.Count > 0)
            {
                PlayTalkLines(lines);
                return;
            }
        }

        // Fallback: the old Personality toast
        string name = charId;
        string? line = null;
        if (CharacterRegistry.TryGet(charId, out var profile))
        {
            name = profile.DefaultName;
            line = profile.Personality;
        }
        else if (_villagerLoader != null)
        {
            foreach (var v in Villagers.All)
                if (v.Id == charId)
                {
                    name = v.DisplayName;
                    break;
                }
        }

        string text = line != null ? $"{name}: \"{line}\"" : $"You chat with {name} for a while.";
        if (bumped)
            text += "\n(+12 friendship)";
        Hud?.ShowToast(text, 3f);
    }

    /// <summary>If this is the first arrival at the outpost after the road intro (intro_scene_1 set
    /// but intro_complete not yet set), play the Scene 2 dialogue sequence.</summary>
    private void TryPlayIntroScene2()
    {
        var gs = GameState.Instance;
        if (gs == null || DialogueBox == null)
            return;
        if (!gs.HasStoryFlag("intro_scene_1") || gs.HasStoryFlag("intro_complete"))
            return;

        var db = gs.DialogueDb;
        if (db == null || !db.TryGetSequence("intro_scene_2", out var seq) || seq.Steps == null)
            return;

        PlayDialogueSteps(seq.Steps, "intro_scene_2", seq.Once);
    }

    /// <summary>One-shot arrival messages: return-travel notice and/or the defeat wake summary.</summary>
    private void ShowArrivalToasts()
    {
        var gs = GameState.Instance;
        if (gs == null || Hud == null)
            return;

        var defeat = gs.ConsumeDefeatSummary();
        if (defeat != null)
        {
            var sb = new StringBuilder("Defeated... you wake at the outpost — ");
            sb.Append(gs.Clock.DateString());
            if (defeat.Losses.Count == 0)
            {
                sb.Append("\nThe stores survived intact.");
            }
            else
            {
                sb.Append("\nLost: ");
                for (int i = 0; i < defeat.Losses.Count; i++)
                {
                    if (i > 0) sb.Append(", ");
                    sb.Append($"{defeat.Losses[i].ItemName} x{defeat.Losses[i].Lost}");
                }
            }
            Hud.ShowToast(sb.ToString(), 4.5f);
            return;
        }

        string? travel = gs.Territory.ConsumeTravelToast();
        if (travel != null)
            Hud.ShowToast(travel);
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

    /// <summary>
    /// Stardew rule: a cell can be tilled only when the map says so — farmable Ground, nothing
    /// painted over it on a blocking/prop layer, no world object standing on it, AND (Refinement 2)
    /// the tile is within the currently UNLOCKED tillable area (its farm zone ≤ the outpost's
    /// tillable-area level). This is the predicate the scene injects into the farm system
    /// (GameState.BindFarmWorld); the highlight and the command share it, so an actionable highlight
    /// always matches a command that succeeds.
    /// </summary>
    public bool IsTillable(Vector2I cell)
        => IsFarmable(cell) && !HasBlockingTile(cell) && !IsCellOccupied(cell) && IsWithinUnlockedZone(cell);

    /// <summary>Refinement 2: the cell's farm zone is within the outpost's current tillable-area level.
    /// Baseline-safe — an unauthored zone reads as base (0), so with no zone tiers authored every
    /// farmable tile passes at level 0 exactly as before.</summary>
    private bool IsWithinUnlockedZone(Vector2I cell)
    {
        int level = GameState.Instance?.FarmTillableAreaLevel ?? 0;
        return FarmZones.IsWithinTillableArea(FarmZoneOf(cell), level);
    }

    /// <summary>The authored <c>farm_zone</c> tier on a Ground tile (default <see cref="FarmZones.BaseZone"/>).
    /// BASELINE SAFETY: when the TileSet has no <c>farm_zone</c> custom-data layer (nothing authored),
    /// returns base zone with no engine error — behaviour stays byte-identical until the user authors tiers.</summary>
    private int FarmZoneOf(Vector2I cell)
    {
        var tileSet = _ground?.TileSet;
        if (tileSet == null)
            return FarmZones.BaseZone;
        int layer = tileSet.GetCustomDataLayerByName(FarmZones.CustomDataKey);
        if (layer < 0)
            return FarmZones.BaseZone; // layer not authored → base zone
        TileData? td = _ground!.GetCellTileData(cell);
        if (td == null)
            return FarmZones.BaseZone;
        Variant v = td.GetCustomDataByLayerId(layer);
        return v.VariantType == Variant.Type.Int ? (int)v : FarmZones.BaseZone;
    }

    /// <summary>A painted Walls/Props tile claims the cell (fences, ruins, decor) — no tilling under it.</summary>
    private bool HasBlockingTile(Vector2I cell)
        => (_walls != null && _walls.GetCellSourceId(cell) != -1)
           || (_props != null && _props.GetCellSourceId(cell) != -1);

    /// <summary>
    /// Occupancy is scene knowledge: functional world objects (triggers, signs, placeable props,
    /// nodes, roamers) claim their cell even when the soil under them is farmable-flagged. Scanned
    /// live — tilling happens on interact presses, and a live scan tracks runtime-spawned children.
    /// </summary>
    private bool IsCellOccupied(Vector2I cell)
    {
        if (_gateTrigger != null && WorldToCell(_gateTrigger.GlobalPosition) == cell)
            return true;
        if (_bedroll != null && WorldToCell(_bedroll.GlobalPosition) == cell)
            return true;

        foreach (Node child in GetChildren())
            if (IsCellOccupant(child) && child is Node2D node && WorldToCell(node.GlobalPosition) == cell)
                return true;
        return false;
    }

    /// <summary>World objects that make their cell untillable (depleted nodes are hidden and free).</summary>
    private static bool IsCellOccupant(Node node) => node switch
    {
        ResourceNodeView view => view.Visible,
        TransitionSign or RoamingEnemy => true,
        Bulwark.Props.Door or Bulwark.Props.Chest or Bulwark.Props.Lever or Bulwark.Props.AmbientProp => true,
        _ => false,
    };

    /// <summary>Every painted Ground cell flagged farmable (the tillable soil the player may work).</summary>
    public IEnumerable<Vector2I> FarmableCells()
    {
        if (_ground == null) yield break;
        foreach (Vector2I cell in _ground.GetUsedCells())
            if (IsFarmable(cell)) yield return cell;
    }
}
