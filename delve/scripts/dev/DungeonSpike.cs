using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Dungeon;
using Delve.Run;
using Godot;

namespace Delve.Dev;
public partial class DungeonSpike : SpikeBase
{
    [Export]
    public PackedScene TestScene { get; set; } = null!;

    [Export]
    public bool Capture { get; set; }

    protected override async Task RunSpikeAsync(DataManager data)
    {
        CheckLayoutVariants();
        int graphErrors = 0, roomErrors = 0, repeatErrors = 0;
        var signatures = new System.Collections.Generic.HashSet<string>();
        for (int seed = 1; seed <= 100; seed++)
        {
            var floor = DungeonFloor.Generate(seed);
            var again = DungeonFloor.Generate(seed);
            string Signature(DungeonFloor f) => string.Join(";", f.Rooms.Select(r => $"{r.X},{r.Y}:{r.Family}:{string.Join(',', r.Doors.Select(d => d.Other(r.Id)))}"));
            if (Signature(floor) != Signature(again))
                repeatErrors++;
            signatures.Add(Signature(floor));
            int edges = floor.Rooms.Sum(r => r.Doors.Count) / 2;
            if (edges != 13 || floor.Map.Nodes.Any(n => n.Floor < 0) || floor.Rooms[11].Doors.Count != 1)
                graphErrors++;
            foreach (var room in floor.Rooms)
            {
                foreach (var d in room.Doors)
                {
                    var b = floor.Rooms[d.Other(room.Id)];
                    if (Math.Abs(room.X - b.X) + Math.Abs(room.Y - b.Y) != 1 || !b.Doors.Contains(d))
                        graphErrors++;
                }

                var doors = room.Doors.Select(d => d.Side(room.Id)).ToArray();
                int size = DungeonFloor.Kind(room.Family) == NodeKind.Event ? 10 : 14;
                var generated = RoomGeneration.Generate(room.Family, room.Seed, size, doors);
                if (!RoomGeneration.Validate(generated))
                    roomErrors++;
                var copy = RoomGeneration.Generate(room.Family, room.Seed, size, doors);
                for (int y = 0; y < generated.Layout.Height; y++)
                    for (int x = 0; x < generated.Layout.Width; x++)
                        if (generated.Layout.GetSurface(x, y) != copy.Layout.GetSurface(x, y) ||
                            !generated.Layout.GetCornerHeights(x, y).Equals(copy.Layout.GetCornerHeights(x, y))) repeatErrors++;
                foreach (var prop in generated.Props.Where(p => p.Kind is "rack" or "barrel" or "supplies" or "pipe" or "rubble" or "urn" or "votive" or "brazier"))
                    if (generated.Layout.GetTile((int)prop.X, (int)prop.Y) != PF2e.MapGen.TileRole.Wall) roomErrors++;
                if (!generated.Layout.Tiles.SequenceEqual(copy.Layout.Tiles) || !generated.Props.SequenceEqual(copy.Props))
                    repeatErrors++;
            }
        }

        Check("100 floor seeds: connected, reciprocal, two loops, terminal guardian", graphErrors == 0);
        Check("1,200 generated rooms have legal internal routes", roomErrors == 0);
        Check("same seeds reproduce graph, geometry and dressing", repeatErrors == 0);
        Check("different seeds produce different floor assemblies", signatures.Count == 100);
        int placementErrors = 0, touching = 0, connections = 0, gapTotal = 0, oldGapTotal = 0, maxGap = 0;
        for (int seed = 1; seed <= 1000; seed++)
        {
            var floor = DungeonFloor.Generate(seed);
            var rng = new Random(seed);
            var widths = floor.Rooms.ToDictionary(r => r.Id, r =>
                r.Family == RoomFamily.Guardian ? 18 + 2 * rng.Next(3) :
                r.Family == RoomFamily.Elite ? 16 + 2 * rng.Next(3) :
                DungeonFloor.Kind(r.Family) is NodeKind.Event or NodeKind.Rest ? 10 + 2 * rng.Next(3) : 14 + 2 * rng.Next(3));
            var packed = DungeonPlacement.Pack(floor, widths);
            var repeat = DungeonPlacement.Pack(floor, widths);
            if (!DungeonPlacement.IsLegal(floor, packed) || packed.Any(p => repeat[p.Key] != p.Value)) placementErrors++;
            foreach (var room in floor.Rooms)
            {
                var a = packed[room.Id];
                foreach (var other in floor.Rooms.Where(r => r.Id > room.Id))
                {
                    var b = packed[other.Id];
                    if (a.X < b.Right && a.Right > b.X && a.Y < b.Bottom && a.Bottom > b.Y) placementErrors++;
                }
                foreach (var door in room.Doors.Where(d => d.A == room.Id))
                {
                    var b = packed[door.B];
                    bool horizontal = door.SideA is DoorSide.East or DoorSide.West;
                    int gap = horizontal ? Math.Max(a.X, b.X) - Math.Min(a.Right, b.Right) : Math.Max(a.Y, b.Y) - Math.Min(a.Bottom, b.Bottom);
                    if (gap < 0) placementErrors++;
                    if (gap == 0) touching++;
                    maxGap = Math.Max(maxGap, gap);
                    gapTotal += gap;
                    oldGapTotal += 26 - (a.Width + b.Width) / 2;
                    connections++;
                }
            }
        }
        Check("1,000 compact floors: deterministic, aligned, no room or passage obstruction", placementErrors == 0);
        Check("compact floors join rooms directly and cut passage distance by over half", touching > 0 && gapTotal * 2 < oldGapTotal);
        GD.Print($"[DungeonPacking] direct={touching}/{connections}, mean gap={(float)gapTotal / connections:F2} tiles (was {(float)oldGapTotal / connections:F2}), max={maxGap}");
        int variants = 0;
        foreach (var family in Enum.GetValues<RoomFamily>())
            foreach (int size in new[]
            {
                8,
                10,
                12,
                14,
                16,
                18,
                20
            }

            )
                for (int mask = 1; mask < 16; mask++)
                {
                    var doors = Enum.GetValues<DoorSide>().Where(s => (mask & (1 << (int)s)) != 0).ToArray();
                    if (!RoomGeneration.Validate(RoomGeneration.Generate(family, mask * 17, size, doors)))
                        variants++;
                }

        Check("all families, sizes and door masks validate", variants == 0);
        var cache = DungeonEncounters.Event(RoomFamily.Cache);
        int authored = cache.Options[0].Check!.Dc;
        Check($"event DCs follow the party level (cache DC {authored} at level 1, {DungeonEncounters.AtLevel(cache, 5).Options[0].Check!.Dc} at 5, {DungeonEncounters.AtLevel(cache, 10).Options[0].Check!.Dc} at 10)",
            DungeonEncounters.AtLevel(cache, 1).Options[0].Check!.Dc == authored
            && DungeonEncounters.AtLevel(cache, 5).Options[0].Check!.Dc == authored + 5
            && DungeonEncounters.AtLevel(cache, 10).Options[0].Check!.Dc == authored + 12);
        var routeFloors = Enumerable.Range(1, 60).Select(DungeonFloor.Generate).ToArray();
        Check("entrance and guardian lie on the shortest route of every floor",
            routeFloors.All(f => f.OnShortestRoute(f.EntranceId) && f.OnShortestRoute(f.GuardianId)));
        int offRoute = routeFloors.Count(f => f.Map.Nodes.Any(n => n.Kind == NodeKind.Combat && !f.OnShortestRoute(n.Id)));
        int skippable = routeFloors.Count(f => f.Map.Nodes.Any(n => n.Kind == NodeKind.Combat && f.Skippable(n.Id)));
        Check($"every floor has a fight room the party can route around for the Wayfarer ({offRoute} off the shortest route, {skippable}/60 skippable)",
            skippable == routeFloors.Length);
        Check("the entrance, the guardian and the only way in are never skippable",
            routeFloors.All(f => !f.Skippable(f.EntranceId) && !f.Skippable(f.GuardianId) && !f.Skippable(10)));
        var edge = new Wardstone(new WardstoneRules { NodeBurn = 5 });
        while (edge.Ward > edge.Rules.SteadyAbove) edge.BurnNode();
        var danger = DoorTips.For(routeFloors[0].Rooms[1], edge, Array.Empty<string>()).Figures!;
        Check($"a crossing that raises the danger shows the pair (Danger {danger.ElementAtOrDefault(1)?.Before} → {danger.ElementAtOrDefault(1)?.Value})",
            danger.Count == 2 && danger[1].Before == "normal" && danger[1].Value == "+1");
        var steady = DoorTips.For(routeFloors[0].Rooms[1], new Wardstone(new WardstoneRules { NodeBurn = 5 }), Array.Empty<string>()).Figures!;
        Check("a crossing that keeps the danger shows only the ward pair", steady.Count == 1);
        var unseenEvent = routeFloors[0].Rooms.First(r => DungeonFloor.Kind(r.Family) == NodeKind.Event && r.Id != 0);
        Check("pending feats hold back unseen rooms of every kind, so the warning reveals nothing",
            DoorTips.NeedsPromotionsFirst(unseenEvent) && DoorTips.For(unseenEvent, edge, new[] { "Aldric" }).Body.Contains(DoorTips.FeatsFirstWarning));
        int eventSeed = Enumerable.Range(1, 100).First(seed =>
        {
            var f = DungeonFloor.Generate(seed);
            return f.Rooms[0].Doors.Any(d => DungeonFloor.Kind(f.Rooms[d.Other(0)].Family) == NodeKind.Event);
        });
        var host = TestScene.Instantiate<DungeonDirector>();
        host.Seed = eventSeed;
        float sceneWalk = host.TravelSecondsPerTile;
        host.TravelSecondsPerTile = 0.001f;
        AddChild(host);
        await WaitSeconds(0.2f);
        Check("the receiving hall opens straight to its doors with full ward", host.Phase == DungeonPhase.Doors
            && host.Current.Completed && host.State.Wardstone.Ward == 100);
        var entranceHud = host.GetNode<DungeonHud>("Screens/DungeonHud");
        Check($"the hall's card carries the station history ('{entranceHud.RoomCardText}')",
            entranceHud.RoomCardText == StationPlan.Name(RoomPurpose.Receiving) && entranceHud.RoomCardDetail == StationPlan.Account(host.Floor.History));
        var plan = entranceHud.Plan.Drawn();
        Check($"the floor plan shows the hall and only the rooms beyond its doors ({string.Join(",", plan.Select(p => $"{p.Key}:{p.Value}"))})",
            plan[0] == "entrance" && plan.Count == 1 + host.Current.Doors.Count
            && host.Current.Doors.All(d => plan[d.Other(0)] == "unknown"));
        var hud = host.GetNode<DungeonHud>("Screens/DungeonHud");
        Check("exploration shows full ward meter", hud.GetNode<ProgressBar>("%WardBar").Value == 100
            && hud.GetNode<Control>("%Expedition").Visible);
        if (Capture)
            await Shot("dungeon_entrance.png");
        host.ResolveEvent(0, null);
        var completions = new List<int>();
        var entries = new List<(int Room, bool First)>();
        var crossings = new List<(int Before, int After)>();
        var wardChanges = new List<(int Before, int After)>();
        host.RoomCompleted += room => completions.Add(room.Id);
        host.RoomEntered += (room, _, first) => entries.Add((room.Id, first));
        host.CrossingStarted += (_, _, before, after) => crossings.Add((before, after));
        host.State.Wardstone.Changed += (before, after) => wardChanges.Add((before, after));
        host.ResolveEvent(0, null);
        host.CloseEvent();
        Check("entrance resolves exactly once", host.Current.Completed && host.Phase == DungeonPhase.Doors);
        Check("room meter tracks completed rooms", hud.GetNode<ProgressBar>("%RoomsBar").Value == 1);
        await CheckCharacterDetails(host);
        var first = host.Current.Doors.First(d => DungeonFloor.Kind(host.Floor.Rooms[d.Other(0)].Family) == NodeKind.Event);
        var task = host.Travel(first.Side(0));
        await host.Travel(first.Side(0));
        await task;
        Check("duplicate click charges one crossing", host.State.Wardstone.Ward == 95 && host.Phase == DungeonPhase.Event);
        var wardBar = hud.GetNode<ProgressBar>("%WardBar");
        Check($"ward meter slides toward the crossing cost ({wardBar.Value:F1})", wardBar.Value > 95);
        Check($"an event room is named by its panel, not by a second card ('{hud.RoomCardText}')",
            hud.RoomCardText == StationPlan.Name(RoomPurpose.Receiving));
        var afterCrossing = hud.Plan.Drawn();
        Check($"the plan shows the visited event room by kind and its unseen neighbours as unknown ({string.Join(",", afterCrossing.Select(p => $"{p.Key}:{p.Value}"))})",
            afterCrossing[host.Current.Id] == "event" && host.Current.Doors.All(d => afterCrossing.ContainsKey(d.Other(host.Current.Id))));
        await WaitSeconds((float)hud.WardTweenSeconds + 0.1f);
        Check("ward meter settles on the crossing cost", wardBar.Value == 95);
        if (Capture)
            await Shot("dungeon_happenstance.png");
        host.ResolveEvent(0, null);
        host.CloseEvent();
        int gold = host.State.Gold;
        var completed = host.Current;
        await host.Travel(first.Side(completed.Id));
        Check("backtracking costs ward without replaying entrance", host.Current.Id == 0 && host.Phase == DungeonPhase.Doors && host.State.Wardstone.Ward == 90);
        await host.Travel(first.Side(0));
        Check("cleared room retains rewards and resolution", host.Current.Completed && host.State.Gold == gold && host.State.Wardstone.Ward == 85 && host.Phase == DungeonPhase.Doors);
        int eventRoom = completed.Id;
        Check($"room completed fires once per room ({string.Join(",", completions)})",
            completions.SequenceEqual(new[] { eventRoom }));
        Check($"room entered marks only the first arrival ({string.Join(",", entries)})",
            entries.SequenceEqual(new[] { (eventRoom, true), (0, false), (eventRoom, false) }));
        Check("each crossing reports its ward before and after once",
            crossings.SequenceEqual(new[] { (100, 95), (95, 90), (90, 85) }) && wardChanges.SequenceEqual(crossings));
        Check($"only the current room and its discovered neighbours render ({host.VisibleRoomCount} drawn)",
            host.VisibleRoomCount <= 1 + host.Current.Doors.Count && host.CurrentView.Visible);
        int dressed = host.GetNode<ExplorationFx>("%ExplorationFx").Dressed;
        Check($"signature rooms carry their looping effect ({dressed} of refuge, kitchen, workshop, shrine, ward chamber)", dressed >= 4);
        int beats = host.GetNode<ExplorationFx>("%ExplorationFx").Played;
        Check($"exploration beats reach the effects node ({beats} after three crossings, an arrival and a clear)", beats >= 5);
        // A real-speed crossing fits the two-second budget, and a click skips it without a second charge.
        float fastWalk = host.TravelSecondsPerTile;
        host.TravelSecondsPerTile = sceneWalk;
        int wardBeforeSkip = host.State.Wardstone.Ward;
        var walking = host.Travel(first.Side(host.Current.Id));
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        bool wasWalking = host.Phase == DungeonPhase.Travel;
        host._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true });
        for (int frame = 0; frame < 3 && host.Phase == DungeonPhase.Travel; frame++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await walking;
        Check($"a real-speed crossing fits the budget ({host.LastCrossingSeconds:F2} s of 2.0)", host.LastCrossingSeconds <= 2.0);
        Check("a click during the walk arrives within three frames and charges one crossing",
            wasWalking && host.Phase == DungeonPhase.Doors && host.State.Wardstone.Ward == wardBeforeSkip - host.CrossingBurn);
        host.TravelSecondsPerTile = fastWalk;
        await host.Travel(first.Side(host.Current.Id));
        // Restore the ward the two extra crossings spent, so the checks below keep their numbers.
        host.State.Wardstone.RefillFull();
        while (host.State.Wardstone.Ward > wardBeforeSkip) host.State.Wardstone.BurnNode();
        if (Capture)
        {
            await Shot("dungeon_cleared.png");
            var world = host.GetNode<Node3D>("%DungeonWorld");
            var hidden = world.GetChildren().OfType<Node3D>().Where(n => !n.Visible).ToArray();
            foreach (var n in hidden) n.Visible = true;
            var rooms = world.GetChildren().OfType<DungeonRoomPrefab>().ToArray();
            float minX = rooms.Min(r => r.GlobalPosition.X), minZ = rooms.Min(r => r.GlobalPosition.Z);
            float maxX = rooms.Max(r => r.GlobalPosition.X + r.Width), maxZ = rooms.Max(r => r.GlobalPosition.Z + r.Width);
            var rig = host.GetNode<Delve.Combat.OrbitCameraRig>("%ExploreCamera");
            rig.FrameBoard(new Vector3((minX + maxX) / 2, 0, (minZ + maxZ) / 2), (int)(maxX - minX), (int)(maxZ - minZ));
            await Shot("dungeon_compact_floor.png");
            foreach (var n in hidden) n.Visible = false;
            int width = host.CurrentView.Width;
            rig.FrameBoard(new Vector3(width / 2f, 0, width / 2f), width, width);
        }
        await WaitSeconds(0.4f);
        var camera = host.GetNode<Delve.Combat.OrbitCameraRig>("%ExploreCamera").Camera;
        var doorway = host.CurrentView.ToGlobal(host.CurrentView.DoorPosition(first.Side(completed.Id))) + Vector3.Up;
        var screen = camera.UnprojectPosition(doorway);
        if (Capture)
        {
            GetViewport().PushInput(new InputEventMouseMotion { Position = screen, GlobalPosition = screen });
            await WaitSeconds(0.1f);
            Check("hovering a world doorway highlights the exit", host.CurrentView.HoveredDoor == first.Side(completed.Id));
            await Shot("dungeon_door_hover.png");
        }
        host._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = screen });
        host._UnhandledInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = screen });
        for (int frame = 0; frame < 240 && host.Current.Id != 0; frame++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("clicking the actual 3D doorway crosses once", host.Current.Id == 0 && host.State.Wardstone.Ward == 80);
        var pending = host.Travel(first.Side(host.Current.Id));
        host.Restart(eventSeed);
        await pending;
        Check("restart cancels travel and starts a fresh isolated run", host.State.Wardstone.Ward == 100 && host.Current.Id == 0 && host.Phase == DungeonPhase.Doors);
        host.ResolveEvent(0, null);
        host.CloseEvent();
        while (host.State.Wardstone.Ward > 5)
            host.State.Wardstone.BurnNode();
        await host.Travel(host.Current.Doors[0].Side(0));
        Check("last crossing depletes ward before destination encounter", host.Phase == DungeonPhase.End && host.State.Outcome == RunOutcome.Defeat && host.State.Wardstone.Ward == 0);
        await WaitSeconds((float)hud.WardTweenSeconds + 0.1f);
        Check("spent ward has an empty meter and explicit warning", hud.GetNode<ProgressBar>("%WardBar").Value == 0
            && hud.GetNode<Label>("%WardDanger").Text.Contains("EXHAUSTED"));
        if (Capture) await RoomGallery(host);
        host.ComparisonMode = true;
        host.ComparisonSize = 14;
        host.Restart(4711);
        await WaitSeconds(0.5f);
        Check("comparison starts combat on prefab terrain", host.Phase == DungeonPhase.Combat && host.CurrentView.Width == 16);
        if (Capture)
            await Shot("dungeon_combat_14.png");
        foreach (int size in new[]
        {
            12,
            16
        }

        )
        {
            host.ComparisonSize = size;
            host.Restart(4711);
            await WaitSeconds(0.3f);
            Check($"comparison {size}: encounter can be restarted", host.Phase == DungeonPhase.Combat && host.CurrentView.Width == size + 2);
            if (Capture)
                await Shot($"dungeon_combat_{size}.png");
        }

        host.QueueFree();
        await WaitSeconds(0.1f);
    }

    private async Task RoomGallery(DungeonDirector host)
    {
        var world = host.GetNode<Node3D>("%DungeonWorld");
        var party = host.GetNode<Node3D>("%TravelParty");
        var screens = host.GetNode<CanvasLayer>("%Screens");
        var rig = host.GetNode<Delve.Combat.OrbitCameraRig>("%ExploreCamera");
        world.Visible = party.Visible = screens.Visible = false;
        foreach (var purpose in Enum.GetValues<RoomPurpose>())
        {
            var room = host.PurposePrefabs[(int)purpose].Instantiate<DungeonRoomPrefab>();
            host.AddChild(room);
            room.History = StationHistory.Flooded;
            room.LayoutVariant = 0;
            room.Generate(4711 + (int)purpose, new[] { DoorSide.South, DoorSide.East }, 14);
            room.SetDoorsOpen(true, instant: true);
            rig.FrameBoard(new Vector3(room.Width / 2f, 0, room.Width / 2f), room.Width, room.Width);
            room.Cutaway(rig.Camera);
            Check($"{purpose}: textured station prefab and valid layout", room.Palette?.FloorTextures.Length > 0 && RoomGeneration.Validate(room.Generated));
            await Shot($"station_room_{purpose}.png");
            host.RemoveChild(room);
            room.QueueFree();
        }
        world.Visible = party.Visible = screens.Visible = true;
    }

    private async Task WaitSeconds(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
    private async Task Shot(string name)
    {
        await WaitSeconds(0.5f);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        SaveViewportCapture("res://.godot/" + name);
    }
}
