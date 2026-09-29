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
        await Wait(SettleSeconds);
        var here = crawl.Current;
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
}
