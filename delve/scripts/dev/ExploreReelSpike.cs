using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Dungeon;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered camera reel for the exploration crawl: frames of the walk in, the settled room, and one
/// crossing into a neighbour, for each crawl scene. Frames go to user://dev_shots/reel/ as
/// <c>&lt;tag&gt;_&lt;beat&gt;_&lt;nn&gt;.png</c>, one every <see cref="FrameSeconds"/>, for before and after
/// comparisons of camera work. Must run rendered.
/// </summary>
public partial class ExploreReelSpike : SpikeBase
{
    [Export] public PackedScene[] Crawls { get; set; } = System.Array.Empty<PackedScene>();
    [Export] public string[] Tags { get; set; } = System.Array.Empty<string>();

    /// <summary>Seconds between reel frames.</summary>
    [Export] public float FrameSeconds { get; set; } = 0.25f;

    /// <summary>Longest a beat is filmed before the reel moves on.</summary>
    [Export] public float BeatSeconds { get; set; } = 6f;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (DisplayServer.GetName() == "headless") { Check("the reel runs rendered", false); return; }
        DirAccess.MakeDirRecursiveAbsolute(ProjectSettings.GlobalizePath("user://dev_shots/reel"));
        for (int i = 0; i < Crawls.Length; i++) await Film(Crawls[i], Tags[i]);
    }

    private async Task Film(PackedScene scene, string tag)
    {
        var crawl = scene.Instantiate<DungeonDirector>();
        AddChild(crawl);
        int frame = 0;
        for (float t = 0; t < BeatSeconds && (crawl.WalkingIn || t < 1); t += FrameSeconds)
        {
            await Wait(FrameSeconds);
            Shot(tag, "arrive", frame++);
        }
        await Wait(1f);
        Shot(tag, "settled", 0);
        var rig = crawl.GetNode<Delve.Combat.OrbitCameraRig>("%ExploreCamera");
        GD.Print($"[reel] {tag} settled: distance {rig.Distance:0.0}, dolly {rig.Dolly:0.00}, view {rig.ViewDistance:0.0}, composition {rig.Composition}, room {crawl.CurrentView.Width}");

        var here = crawl.Current;
        var door = here.Doors.OrderBy(d => DungeonFloor.Kind(crawl.Floor.Rooms[d.Other(here.Id)].Family) is Delve.Run.NodeKind.Combat
            or Delve.Run.NodeKind.Elite or Delve.Run.NodeKind.Boss).First();
        var travel = crawl.Travel(door.Side(here.Id));
        frame = 0;
        for (float t = 0; t < BeatSeconds && (!travel.IsCompleted || t < 2.5f); t += FrameSeconds)
        {
            await Wait(FrameSeconds);
            Shot(tag, "cross", frame++);
        }
        Check($"{tag}: the crossing finished ({crawl.Phase})", travel.IsCompleted);
        crawl.QueueFree();
        await Wait(0.3f);
    }

    private void Shot(string tag, string beat, int frame)
        => Check($"{tag} {beat} {frame:00} saved", SaveViewportCapture($"user://dev_shots/reel/{tag}_{beat}_{frame:00}.png") == Error.Ok);

    private async Task Wait(float seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
}
