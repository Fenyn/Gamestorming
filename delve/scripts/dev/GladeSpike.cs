using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Dungeon;
using Delve.Look;
using Delve.Run;
using Delve.Presets;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Forest glade rooms (scenes/dev/glade_spike.tscn). Headless it generates glades over 100 seeds
/// and checks the room contract: mouths at ground level, every mouth and the centre reachable
/// without climbing a cliff, deployment boxes open, and the same seed giving the same glade.
/// Rendered, it also builds three glades joined by trails under the forest look and saves an
/// exploration shot and an overview.
/// </summary>
public partial class GladeSpike : SpikeBase
{
    [Export] public PackedScene? GladeScene { get; set; }
    [Export] public PackedScene? LookScene { get; set; }
    [Export] public PackedScene? CameraScene { get; set; }
    [Export] public PackedScene? UnitPrefab { get; set; }
    [Export] public int Seeds { get; set; } = 100;

    /// <summary>Mean generation time per glade the crawl can afford: twelve glades per floor
    /// must build inside about a second and a half.</summary>
    [Export] public double MaxMillisecondsPerGlade { get; set; } = 120;

    [Export] public float SettleSeconds { get; set; } = 2.5f;

    protected override string Banner => "===================== GLADE SPIKE =====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        CheckGeneration();
        if (DisplayServer.GetName() != "headless") await RenderRow();
        FinishAndQuit("GladeSpike");
    }

    private void CheckGeneration()
    {
        var sides = Enum.GetValues<DoorSide>();
        int[] sizes = { 12, 14, 16 };
        int invalid = 0, rebuilt = 0, cliffs = 0;
        var clock = Stopwatch.StartNew();
        for (int seed = 1; seed <= Seeds; seed++)
        {
            var rng = new Random(seed);
            var doors = sides.Where(_ => rng.Next(2) == 0).DefaultIfEmpty(sides[rng.Next(4)]).ToArray();
            var room = GladeGeneration.Generate(seed, sizes[seed % sizes.Length], doors);
            if (!GladeGeneration.Valid(room)) invalid++;
            var again = GladeGeneration.Generate(seed, sizes[seed % sizes.Length], doors);
            if (!again.Layout.Tiles.SequenceEqual(room.Layout.Tiles) || !again.Layout.Elevations.SequenceEqual(room.Layout.Elevations)) rebuilt++;
            if (MaxRise(room.Layout) > 0) cliffs++;
        }
        double ms = clock.Elapsed.TotalMilliseconds / (Seeds * 2.0);
        Check($"{Seeds} glades keep the room contract (mouths at ground level, reachable, zones open): {invalid} invalid", invalid == 0);
        Check($"the same seed builds the same glade: {rebuilt} differ", rebuilt == 0);
        Check($"glades build fast enough for a 12-room floor ({ms:F0} ms each, limit {MaxMillisecondsPerGlade})", ms <= MaxMillisecondsPerGlade);
        GD.Print($"[GladeSpike] glades with some raised ground: {cliffs} of {Seeds}");
    }

    /// <summary>Highest elevation in the glade, to report how much relief survives the shaping.</summary>
    private static int MaxRise(MapLayout layout) => layout.Elevations.Max();

    private async Task RenderRow()
    {
        if (GladeScene == null || LookScene == null || CameraScene == null)
        {
            Check("glade, look and camera scenes are wired", false);
            return;
        }
        var look = LookScene.Instantiate<LookScene>();
        AddChild(look);
        var world = new Node3D { Name = "World" };
        AddChild(world);
        var rig = CameraScene.Instantiate<OrbitCameraRig>();
        AddChild(rig);

        var clock = Stopwatch.StartNew();
        var doors = new[] { new[] { DoorSide.East }, new[] { DoorSide.West, DoorSide.East, DoorSide.South }, new[] { DoorSide.West } };
        var glades = new List<DungeonRoomPrefab>();
        for (int i = 0; i < 3; i++)
        {
            var glade = GladeScene.Instantiate<DungeonRoomPrefab>();
            world.AddChild(glade);
            glade.Generate(RunRng.StableSeed(7, i, "glade-row"), doors[i]);
            glades.Add(glade);
        }
        GD.Print($"[GladeSpike] three glades built in {clock.Elapsed.TotalMilliseconds:F0} ms");
        int rim = glades[0].GetNode<GladeShell>("Shell").RimDepth;
        float x = 0;
        foreach (var glade in glades)
        {
            glade.Position = new Vector3(x, 0, -glade.Width / 2);
            x += glade.Width + 2 * rim;
        }
        var middle = glades[1];
        world.Position = -middle.Position;
        middle.SetDoorsOpen(true, instant: true);
        foreach (var glade in glades) glade.SetDoorsOpen(true, instant: true);
        RenderingServer.GlobalShaderParameterSet(Look.LookScene.BoardRectGlobal, new Vector4(0, 0, middle.Width, middle.Width));
        SpawnParty(middle);

        rig.Camera.Current = true;
        rig.FrameBoard(new Vector3(middle.Width / 2f, 0, middle.Width / 2f), middle.Width, middle.Width);
        await Wait(SettleSeconds);
        Check("glade exploration shot saved", SaveViewportCapture("user://dev_shots/glade_explore.png") == Error.Ok);

        float span = x - 2 * rim;
        var centre = new Vector3(span / 2f, 0, middle.Width / 2f) - middle.Position with { Z = 0 };
        rig.FrameBoard(centre, (int)span, middle.Width);
        await Wait(SettleSeconds);
        Check("glade overview shot saved", SaveViewportCapture("user://dev_shots/glade_overview.png") == Error.Ok);
    }

    private void SpawnParty(DungeonRoomPrefab room)
    {
        if (UnitPrefab == null) return;
        var party = Party.Build(new[] { PresetCharacters.PlayerId, PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId }, new UnlockState(), Party.DefaultLevel);
        int n = room.Width, i = 0;
        foreach (var member in party.Living())
        {
            var token = UnitVisual3D.Spawn(UnitPrefab, member);
            room.AddChild(token);
            token.UseExplorationMarkers();
            token.Position = GridSpace.GridToWorld(new PF2eVec(n / 2 + i % 2, n / 2 + i / 2), room.Heights);
            i++;
        }
    }

    private async Task Wait(float seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
}
