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
    [Export] public PackedScene? ForestCrawl { get; set; }
    [Export] public PackedScene? DeepCrawl { get; set; }
    [Export] public int Seeds { get; set; } = 100;

    /// <summary>Mean generation time per glade the crawl can afford: twelve glades per floor
    /// must build inside about a second and a half.</summary>
    [Export] public double MaxMillisecondsPerGlade { get; set; } = 120;

    [Export] public float SettleSeconds { get; set; } = 2.5f;

    /// <summary>The rendered row: a lookout, the guardian glade with its landmarks, and a refuge.</summary>
    private static readonly RoomPurpose[] RowPurposes = { RoomPurpose.Checkpoint, RoomPurpose.WardChamber, RoomPurpose.Refuge };

    protected override string Banner => "===================== GLADE SPIKE =====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        CheckGeneration();
        CheckBoards();
        await CheckCrawl(ForestCrawl, "fringe");
        await CheckCrawl(DeepCrawl, "deepwood");
        if (DisplayServer.GetName() != "headless") await RenderRow();
        FinishAndQuit("GladeSpike");
    }

    private void CheckGeneration()
    {
        var sides = Enum.GetValues<DoorSide>();
        int[] sizes = { 12, 14, 16, 18 };
        string[] floors = { "grassland", "deepforest" };
        int invalid = 0, rebuilt = 0, raised = 0, wet = 0, bare = 0, fights = 0, withBroad = 0, openBroad = 0;
        int hedged = 0, quiet = 0, bareQuiet = 0;
        var clock = Stopwatch.StartNew();
        for (int seed = 1; seed <= Seeds; seed++)
        {
            var rng = new Random(seed);
            var doors = sides.Where(_ => rng.Next(2) == 0).DefaultIfEmpty(sides[rng.Next(4)]).ToArray();
            var purpose = (RoomPurpose)(seed % 12);
            var recipe = GladeRecipes.For(floors[seed % 2], purpose);
            var shape = new GladeShape(recipe, Combat: seed % 3 != 0, ZoneHalf: seed % 2 == 0 ? 4 : 5);
            int size = recipe.Size > 0 ? recipe.Size : sizes[seed % sizes.Length];
            var room = GladeGeneration.Generate(seed, size, doors, shape);
            if (!GladeGeneration.Valid(room)) invalid++;
            var again = GladeGeneration.Generate(seed, size, doors, shape);
            if (!again.Layout.Tiles.SequenceEqual(room.Layout.Tiles) || !again.Layout.Elevations.SequenceEqual(room.Layout.Elevations)
                || !again.Layout.CornerHeights.SequenceEqual(room.Layout.CornerHeights) || !again.Layout.Surfaces.SequenceEqual(room.Layout.Surfaces)) rebuilt++;
            var tiles = Interior(room.Layout).ToArray();
            if (tiles.Any(p => room.Layout.GetElevation(p.x, p.y) > 0)) raised++;
            if (tiles.Any(p => room.Layout.GetTile(p.x, p.y) == TileRole.Water)) wet++;
            var landmarks = GladeGeneration.LandmarkTiles(room.Props).ToHashSet();
            int n = room.Layout.Width;
            var trees = tiles.Where(p => room.Layout.GetTile(p.x, p.y) == TileRole.Wall && !landmarks.Contains((p.x, p.y))).ToArray();
            if (!trees.Any(p => Math.Min(Math.Min(p.x, p.y), Math.Min(n - 1 - p.x, n - 1 - p.y)) <= 2)) hedged++;
            if (!shape.Combat)
            {
                quiet++;
                if (trees.Length < 2) bareQuiet++;
                continue;
            }
            fights++;
            int cover = tiles.Count(p => room.Layout.GetTile(p.x, p.y) == TileRole.Cover);
            int trunks = trees.Length;
            var broad = room.Props.Where(p => p.Kind == GladeGeneration.BigTree).ToArray();
            if (cover < 3 || trunks + broad.Length < 2) bare++;
            if (broad.Length > 0) withBroad++;
            foreach (var tile in GladeGeneration.LandmarkTiles(broad))
                if (room.Layout.GetTile(tile.X, tile.Y) != TileRole.Wall) openBroad++;
        }
        double ms = clock.Elapsed.TotalMilliseconds / (Seeds * 2.0);
        Check($"{Seeds} glades keep the room contract (mouths at ground level, reachable, zones open): {invalid} invalid", invalid == 0);
        Check($"the same seed builds the same glade, corners and surfaces included: {rebuilt} differ", rebuilt == 0);
        Check($"glades build fast enough for a 12-room floor ({ms:F0} ms each, limit {MaxMillisecondsPerGlade})", ms <= MaxMillisecondsPerGlade);
        Check($"every fight glade has 3+ cover rocks and 2+ trees inside: {bare} of {fights} bare", bare == 0);
        Check($"broad trees fill a whole 2x2 block, like a Large creature: {openBroad} open tiles, {withBroad} of {fights} fight glades have one", openBroad == 0 && withBroad > fights / 2);
        Check($"trees step in from the ring in every glade: {hedged} of {Seeds} keep a clean hedge", hedged == 0);
        Check($"glades without a fight still hold 2+ trees inside: {bareQuiet} of {quiet} bare", bareQuiet == 0);
        GD.Print($"[GladeSpike] raised ground in {raised} of {Seeds}, water in {wet} of {Seeds}");
    }

    private static IEnumerable<PF2e.Vector2Int> Interior(MapLayout layout)
    {
        for (int y = 1; y < layout.Height - 1; y++)
            for (int x = 1; x < layout.Width - 1; x++)
                yield return new PF2e.Vector2Int(x, y);
    }

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
            glade.PurposeOverride = RowPurposes[i];
            glade.Combat = i == 1;
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
        var marks = GladeGeneration.LandmarkTiles(middle.Generated.Props).ToHashSet();
        var inside = Interior(middle.Generated.Layout).Where(p => middle.Generated.Layout.GetTile(p.x, p.y) == TileRole.Wall && !marks.Contains((p.x, p.y))).Count();
        int broad = middle.Generated.Props.Count(p => p.Kind == GladeGeneration.BigTree);
        Check($"the guardian glade has its landmarks, broad trees and trunks ({string.Join(", ", middle.Generated.Props.Select(p => p.Kind))}; {inside} small trunks)", middle.Generated.Props.Count - broad == 2 && broad + inside >= 2);
        world.Position = -middle.Position;
        middle.SetDoorsOpen(true, instant: true);
        foreach (var glade in glades) glade.SetDoorsOpen(true, instant: true);
        glades[0].Shell!.SetLight(0.5f);
        glades[2].Shell!.SetLight(0.15f);
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
