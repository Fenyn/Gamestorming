using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Autoload;
using Delve.Combat;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Delve.Run.Events;
using Delve.Terrain;
using Godot;
using PF2e.Core;

namespace Delve.Dungeon;
public enum DungeonPhase
{
    Event,
    Combat,
    Results,
    Doors,
    Rest,
    Travel,
    Transition,
    End
}

/// <summary>Room exploration, either standalone or hosted by the main run flow.</summary>
public partial class DungeonDirector : Node3D
{
    [Export]
    public PackedScene[] RoomPrefabs { get; set; } = Array.Empty<PackedScene>();


    [Export]
    public PackedScene CombatPrefab { get; set; } = null!;

    [Export]
    public PackedScene EventPrefab { get; set; } = null!;

    [Export]
    public PackedScene ShortRestPrefab { get; set; } = null!;

    [Export]
    public PackedScene UnitPrefab { get; set; } = null!;

    [Export]
    public int Seed { get; set; } = 4711;

    [Export]
    public int CrossingBurn { get; set; } = 5;

    [Export]
    public float TravelSecondsPerTile { get; set; } = 0.035f;

    [Export]
    public bool ComparisonMode { get; set; }

    [Export]
    public int ComparisonSize { get; set; } = 14;

    [Export]
    public bool ComparisonOpen { get; set; }

    [Export]
    public DoorSide ComparisonEntry { get; set; } = DoorSide.West;

    [Export]
    public float CombatAiDelay { get; set; } = 0.35f;

    [Export]
    public bool AutoPlayCombat { get; set; }
    public DungeonFloor Floor { get; private set; } = null!;
    public RunState State { get; private set; } = null!;
    public DungeonPhase Phase { get; private set; }
    public DungeonRoom Current => Floor.Rooms[State.CurrentNodeId ?? 0];
    public DungeonRoomPrefab CurrentView => _rooms[Current.Id];

    private Node3D _world = null!, _partyLayer = null!;
    private OrbitCameraRig _camera = null!;
    private CombatScene? _combat;
    private EventPanel _event = null!;
    private ShortRestPanel _rest = null!;
    private DungeonHud _hud = null!;
    private ExplorationFx _fx = null!;
    private readonly Dictionary<int, DungeonRoomPrefab> _rooms = new();
    private readonly List<UnitVisual3D> _tokens = new();
    private readonly Dictionary<int, CombatSetup> _encounters = new();
    private readonly List<(Node3D View, int A, int B)> _corridors = new();
    private EventDefinition? _openEvent;
    private int _epoch;
    private bool _won, _restUsed;
    private Tween? _travelTween;
    public override void _Ready()
    {
        if (DataManager.Instance is not { IsLoaded: true })
        {
            GD.PushError("Dungeon requires loaded data.");
            return;
        }

        _world = GetNode<Node3D>("%DungeonWorld");
        _partyLayer = GetNode<Node3D>("%TravelParty");
        _camera = GetNode<OrbitCameraRig>("%ExploreCamera");
        _hud = GetNode<DungeonHud>("%DungeonHud");
        _fx = GetNode<ExplorationFx>("%ExplorationFx");
        var ownTransition = GetNode<SceneTransition>("%SceneTransition");
        _transition = SharedTransition ?? ownTransition;
        if (SharedTransition != null) ownTransition.QueueFree();
        _details = GetNode<CharacterDetailsOverlay>("%CharacterDetails");
        _details.Closed += CloseCharacterDetails;
        // A hosted floor fights in the host's combat scene; only the standalone crawl owns one.
        if (!Hosted)
        {
            var combat = CombatPrefab.Instantiate<CombatScene>();
            AddChild(combat);
            combat.EndHostedEncounter();
            combat.AiActionDelaySeconds = CombatAiDelay;
            combat.SetVictoryRestartVisible(false);
            combat.DefeatBannerEnabled = false;
            combat.EncounterFinished += FinishCombat;
            combat.ResultsContinued += ContinueCombat;
            _combat = combat;
        }
        var screens = GetNode<CanvasLayer>("%Screens");
        _event = EventPrefab.Instantiate<EventPanel>();
        screens.AddChild(_event);
        _event.Visible = false;
        _rest = ShortRestPrefab.Instantiate<ShortRestPanel>();
        screens.AddChild(_rest);
        _rest.Visible = false;
        _event.OptionPicked += ResolveEvent;
        _event.Continued += CloseEvent;
        _rest.SchedulePicked += TakeRest;
        _rest.Back += () =>
        {
            _rest.Visible = false;
            ShowDoors();
        };
        WirePresentation();
        _hud.RestPressed += OpenRest;
        _hud.CampPressed += MakeCamp;
        _hud.PotionPressed += DrinkPotion;
        _hud.MemberPressed += OpenMemberDetails;
        _hud.StairsPressed += UseStairs;
        _hud.RestartPressed += seed => Restart(seed);
        _hud.SizePicked += size =>
        {
            ComparisonSize = size;
            Restart(Seed);
        };
        _hud.LayoutPicked += () =>
        {
            ComparisonOpen = !ComparisonOpen;
            Restart(Seed);
        };
        _hud.EntryPicked += () =>
        {
            ComparisonEntry = (DoorSide)(((int)ComparisonEntry + 1) % 4);
            Restart(Seed);
        };
        if (int.TryParse(OS.GetEnvironment("DELVE_RUN_SEED"), out int supplied))
            Seed = supplied;
        if (!Hosted) Restart(Seed);
        else SetHostedVisible(false);
    }

    public void Restart(int seed)
    {
        if (Hosted) return;
        var floor = DungeonFloor.Generate(seed);
        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
        var state = RunState.StartOnMap(seed, party, floor.Map, new WardstoneRules { NodeBurn = CrossingBurn });
        BeginFloor(state, floor, seed);
    }

    public void BeginFloor(RunState state, DungeonFloor floor, int seed)
    {
        _epoch++;
        CancelPresentation();
        _details.Close();
        _pendingDoorClick = null;
        _doorPress = null;
        _travelTween?.Kill();
        _travelTween = null;
        FinishWalkIn();
        _combat?.EndHostedEncounter();
        _event.Visible = false;
        _rest.Visible = false;
        _openEvent = null;
        _studied = false;
        ResetAnnouncements();
        _encounters.Clear();
        _rooms.Clear();
        _corridors.Clear();
        Clear(_world);
        Clear(_partyLayer);
        _tokens.Clear();
        Seed = seed;
        _world.Position = Vector3.Zero;
        _partyLayer.Position = Vector3.Zero;
        Floor = floor;
        State = state;
        ApplyScenery(state);
        WatchWard();
        SetHostedVisible(true);
        foreach (var room in Floor.Rooms)
        {
            var family = ComparisonMode && room.Id == 0 ? RoomFamily.GuardHall : StationPlan.Prefab(room.Purpose);
            var scene = !ComparisonMode && Scenery.PurposePrefabs.Length > (int)room.Purpose ? Scenery.PurposePrefabs[(int)room.Purpose] : RoomPrefabs[(int)family];
            var prefab = scene.Instantiate<DungeonRoomPrefab>();
            _world.AddChild(prefab);
            prefab.PurposeOverride = ComparisonMode && room.Id == 0 ? RoomPurpose.Checkpoint : room.Purpose;
            prefab.History = Floor.History;
            prefab.Combat = DungeonFloor.Kind(room.Family) is NodeKind.Combat or NodeKind.Elite or NodeKind.Boss;
            prefab.Arrival = ArrivalFor(room, prefab);
            prefab.Generate(room.Seed, room.Doors.Select(d => d.Side(room.Id)).ToArray(), ComparisonMode && room.Id == 0 ? ComparisonSize : 0, ComparisonMode && room.Id == 0 && ComparisonOpen);
            prefab.Visible = false;
            _rooms[room.Id] = prefab;
            _fx.Dress(prefab, prefab.PurposeOverride ?? room.Purpose, prefab.Generated.Props);
        }

        var placement = DungeonPlacement.Pack(Floor, _rooms.ToDictionary(p => p.Key, p => p.Value.Width + 2 * p.Value.Shell!.Margin));
        foreach (var (id, bounds) in placement)
            _rooms[id].Position = new Vector3(bounds.X + _rooms[id].Shell!.Margin, 0, bounds.Y + _rooms[id].Shell!.Margin);
        BuildCorridors();
        State.Advance(0);
        Current.Discovered = true;
        Rebase();
        Frame();
        SpawnTravelParty();
        if (ComparisonMode)
        {
            var room = new DungeonRoom
            {
                Id = 0,
                X = 0,
                Y = 0,
                Seed = Current.Seed,
                Family = RoomFamily.GuardHall
            };
            var setup = DungeonEncounters.Build(State, room, CurrentView, ComparisonEntry, DataManager.Instance!.ResolveCreature);
            if (setup == null)
            {
                End(false);
                return;
            }

            _encounters[0] = setup;
            StartCombat(setup);
        }
        else
        {
            Enter(Floor.ArrivalSide);
            _ = WalkIn();
        }
        GD.Print($"[Dungeon] seed={Seed}, rooms={Floor.Rooms.Count}, crossing={CrossingBurn}, comparison={ComparisonMode}/{ComparisonSize}");
    }

    private void End(bool victory)
    {
        Phase = DungeonPhase.End;
        State.Outcome = victory ? RunOutcome.Victory : RunOutcome.Defeat;
        _event.Visible = false;
        _rest.Visible = false;
        _combat?.EndHostedEncounter();
        Frame();
        RefreshHud();
        if (Hosted) RunEnded?.Invoke(State.Outcome);
    }

    public void UseStairs()
    {
        if (_details.Visible || Phase != DungeonPhase.Doors || Current.Family != RoomFamily.Guardian || !Current.Completed) return;
        FinishWalkIn();
        _fx.Descended();
        if (Instant) { LeaveFloor(); return; }
        Phase = DungeonPhase.Transition;
        RefreshHud();
        _ = WalkDownStairs(_epoch);
    }

    private void LeaveFloor()
    {
        if (Hosted)
        {
            Phase = DungeonPhase.End;
            FloorCompleted?.Invoke();
        }
        else End(true);
    }

    /// <summary>Re-render the HUD, the party strip and the token bars from the run state.</summary>
    public void RefreshHud()
    {
        if (Phase != DungeonPhase.Doors) SetHoveredPartyMember(null);
        if (Phase != DungeonPhase.Doors) _details.Close();
        _hud.Instant = _fx.Instant = Instant;        foreach (var token in _tokens) token.UpdateHealthBar();
        foreach (var (id, view) in _rooms)
            view.SetTraversalActive(id == Current.Id && Phase == DungeonPhase.Doors);
        _hud.Render(Floor, State, Phase, Seed, ComparisonMode, ComparisonSize, ComparisonOpen, ComparisonEntry);
    }
    private static void Clear(Node n)
    {
        foreach (var child in n.GetChildren())
        {
            n.RemoveChild(child);
            child.QueueFree();
        }
    }

    public override void _ExitTree()
    {
        UnwatchWard();
        _epoch++;
        CancelPresentation();
        _pendingDoorClick = null;
        _doorPress = null;
        _travelTween?.Kill();
    }
}
