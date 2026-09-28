using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Flow;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>Playable full-roster camp, selection limit, embark, and return.</summary>
public partial class FullRosterCampSpike : SpikeBase
{
    [Export] public PackedScene RunScene { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var run = RunScene.Instantiate<RunDirector>();
        Check("main dungeon scene uses normal recruitment", !run.TestFullRoster);
        run.TestFullRoster = true;
        run.Seed = 90210;
        AddChild(run);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var panel = run.FindChildren("*", "", true, false).OfType<HeroSelectPanel>().Single();
        var residents = HeroSelectChecks.Cards(panel);
        Check("all 18 residents appear", residents.Count == CharacterCatalog.All.Count && residents.Count == 18);
        Check("all 18 can be selected", CharacterCatalog.All.All(def => panel.CanPick(def.Id)));
        Check("normal campaigns still start with four unlocks", new CampaignProgress().Unlocks.UnlockedIds.Count == 4);
        foreach (string id in new[] { "arkus", "sera", "hilde", "flick" }) panel.Pick(id);
        Check("four recruits can form a party", panel.CanEmbark && panel.SelectedIds.Count == 4);
        panel.Pick("oskar");
        Check("fifth member is rejected", panel.SelectedIds.Count == 4 && !panel.SelectedIds.Contains("oskar"));
        await ToSignal(GetTree().CreateTimer(1.2), SceneTreeTimer.SignalName.Timeout);
        string output = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        if (!string.IsNullOrEmpty(output) && DisplayServer.GetName() != "headless")
        {
            Check("full roster screenshot saved", SaveViewportCapture(output + "/full-roster-camp.png") == Error.Ok);
        }
        panel.Embark();
        Check("recruit party embarks into the dungeon", run.State != null && run.Phase == RunPhase.Map
            && run.State.Party.Members.Select(member => member.Id).ToHashSet().SetEquals(new[] { "arkus", "sera", "hilde", "flick" }));
        run.NewRun();
        Check("returning to camp retains all 18 and clears selection", HeroSelectChecks.Cards(panel).Count == 18
            && panel.SelectedIds.Count == 0);
        run.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
