using System;
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
        int eventSeed = Enumerable.Range(1, 100).First(seed =>
        {
            var f = DungeonFloor.Generate(seed);
            return f.Rooms[0].Doors.Any(d => DungeonFloor.Kind(f.Rooms[d.Other(0)].Family) == NodeKind.Event);
        });
        var host = TestScene.Instantiate<DungeonDirector>();
        host.Seed = eventSeed;
        host.TravelSecondsPerTile = 0.001f;
        AddChild(host);
        await WaitSeconds(0.2f);
        Check("starts with entrance event and full ward", host.Phase == DungeonPhase.Event && host.State.Wardstone.Ward == 100);
        var hud = host.GetNode<DungeonHud>("Screens/DungeonHud");
        Check("exploration shows full ward meter", hud.GetNode<ProgressBar>("%WardBar").Value == 100
            && hud.GetNode<Control>("%Expedition").Visible);
        if (Capture)
            await Shot("dungeon_entrance.png");
        host.ResolveEvent(0, null);
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
        Check("ward meter follows crossing cost", hud.GetNode<ProgressBar>("%WardBar").Value == 95);
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
        Check("restart cancels travel and starts a fresh isolated run", host.State.Wardstone.Ward == 100 && host.Current.Id == 0 && host.Phase == DungeonPhase.Event);
        host.ResolveEvent(0, null);
        host.CloseEvent();
        while (host.State.Wardstone.Ward > 5)
            host.State.Wardstone.BurnNode();
        await host.Travel(host.Current.Doors[0].Side(0));
        Check("last crossing depletes ward before destination encounter", host.Phase == DungeonPhase.End && host.State.Outcome == RunOutcome.Defeat && host.State.Wardstone.Ward == 0);
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
            room.SetDoorsOpen(true);
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
        string path = ProjectSettings.GlobalizePath("res://.godot/" + name);
        var image = GetViewport().GetTexture().GetImage();
        image.Convert(Image.Format.Rgba8);
        image.LinearToSrgb();
        image.SavePng(path);
        GD.Print($"[DungeonShot] {path}");
    }
}
