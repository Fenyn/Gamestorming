using System.Linq;
using System.Threading.Tasks;
using Delve.Dungeon;
using Godot;

namespace Delve.Dev;

public partial class GladeSpike
{
    /// <summary>The standalone forest crawl: glade rooms, trails, and the three fog tiers. Rendered, it
    /// also photographs the entrance glade and the next room.</summary>
    private async Task CheckCrawl(PackedScene? scene, string tag)
    {
        if (scene == null)
        {
            Check($"{tag} crawl scene is wired", false);
            return;
        }
        var crawl = scene.Instantiate<DungeonDirector>();
        AddChild(crawl);
        var here = crawl.Current;
        var view = crawl.CurrentView;
        Check($"the {tag} party walks in from off the floor", crawl.WalkingIn);
        CheckArrival(crawl, tag);
        if (DisplayServer.GetName() != "headless")
        {
            await Wait(ArrivalShotSeconds);
            Check($"{tag} arrival shot saved", SaveViewportCapture($"user://dev_shots/{tag}_arrival.png") == Error.Ok);
        }
        for (float waited = 0; crawl.WalkingIn && waited < ArrivalTimeout; waited += 0.1f) await Wait(0.1f);
        var centre = new Vector3(view.Width / 2f, 0, view.Width / 2f);
        var party = crawl.GetNode<Node3D>("%TravelParty").GetChildren().OfType<Node3D>().ToArray();
        Check($"the walk in ends with the party in the middle of the glade",
            !crawl.WalkingIn && party.Length > 0 && party.All(t => (t.Position with { Y = 0 }).DistanceTo(centre) < 3));
        if (DisplayServer.GetName() != "headless")
        {
            var rig = crawl.GetNode<Delve.Combat.OrbitCameraRig>("ExploreCamera");
            var side = crawl.Floor.ArrivalSide;
            rig.FocusOn(view.DoorPosition(side) + DungeonRoomPrefab.Outward(side) * 4, 0, false);
            await Wait(0.3f);
            Check($"{tag} arrival close shot saved", SaveViewportCapture($"user://dev_shots/{tag}_arrival_close.png") == Error.Ok);
            rig.FocusOn(centre, 0, false);
        }
        await Wait(SettleSeconds);
        Check($"the {tag} crawl builds its rooms as glades", crawl.CurrentView.Shell is GladeShell);
        var neighbours = here.Doors.Select(d => d.Other(here.Id)).ToArray();
        Check($"unvisited neighbours show dark ({string.Join(", ", neighbours.Select(id => crawl.RoomLightOf(id).ToString("F2")))})",
            neighbours.All(id => crawl.RoomShown(id) && crawl.RoomLightOf(id) < crawl.Scenery.ExploredLight));
        Check("the entrance glade is lit", Mathf.IsEqualApprox(crawl.RoomLightOf(here.Id), crawl.Scenery.CurrentLight));
        if (DisplayServer.GetName() != "headless")
            Check($"{tag} entrance shot saved", SaveViewportCapture($"user://dev_shots/{tag}_entrance.png") == Error.Ok);

        int from = here.Id;
        await crawl.Travel(here.Doors[0].Side(from));
        await Wait(SettleSeconds);
        Check($"the room left behind stays drawn half-dim ({crawl.RoomLightOf(from):F2})",
            crawl.RoomShown(from) && Mathf.IsEqualApprox(crawl.RoomLightOf(from), crawl.Scenery.ExploredLight));
        Check("the room entered is lit", Mathf.IsEqualApprox(crawl.RoomLightOf(crawl.Current.Id), crawl.Scenery.CurrentLight));
        if (DisplayServer.GetName() != "headless")
            Check($"{tag} second room shot saved ({crawl.Phase})", SaveViewportCapture($"user://dev_shots/{tag}_next.png") == Error.Ok);
        crawl.QueueFree();
        await Wait(0.2f);
    }

    /// <summary>Seconds into the walk in the arrival shot is taken, and the longest the walk may run.</summary>
    private const float ArrivalShotSeconds = 1.0f, ArrivalTimeout = 8f;

    /// <summary>The entrance opens a doorless mouth on an outer side, dressed with the floor's arrival
    /// prop, and a worn road runs from it to the middle of the glade.</summary>
    private void CheckArrival(DungeonDirector crawl, string tag)
    {
        var here = crawl.Current;
        var view = crawl.CurrentView;
        var side = crawl.Floor.ArrivalSide;
        var layout = view.Generated.Layout;
        int n = layout.Width;
        Check($"the {tag} entrance arrives through its outer {side} side, which has no door",
            view.Arrival?.Side == side && here.Doors.All(d => d.Side(here.Id) != side)
            && view.Arrival.Prop == crawl.Words.ArrivalProp);
        var mouth = RoomGeneration.Threshold(n, side).ToArray();
        var inside = RoomGeneration.Inside(n, side);
        Check($"the arrival mouth is at ground level and opens onto walkable ground",
            mouth.All(p => layout.GetElevation(p.x, p.y) == 0) && layout.GetTile(inside.x, inside.y) != PF2e.MapGen.TileRole.Wall);
        var road = Enumerable.Range(1, n / 2).Select(step => side switch
        {
            DoorSide.North => (X: n / 2, Y: step),
            DoorSide.South => (X: n / 2, Y: n - 1 - step),
            DoorSide.West => (X: step, Y: n / 2),
            _ => (X: n - 1 - step, Y: n / 2)
        }).Where(p => layout.GetTile(p.X, p.Y) == PF2e.MapGen.TileRole.Ground).ToArray();
        Check($"a dirt road runs from the arrival mouth to the middle ({road.Length} ground tiles)",
            road.Length > 0 && road.All(p => layout.GetSurface(p.X, p.Y) == PF2e.MapGen.SurfaceType.Dirt));
    }
}
