using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.UI;
using Godot;
using PF2e.Conditions;

namespace Delve.Dev;

/// <summary>Move bands under conditions: a prone hero's Crawl bands with the Prone hint and the Stand
/// chip, then the same hero grabbed with no bands, the Immobilized hint and the Escape chip.</summary>
public partial class CombatShotSpike
{
    private async Task CaptureMoveConditions(CombatScene scene, DataManager data)
    {
        var session = await StartCluster(scene, data);
        if (session?.CurrentActor is not { } actor)
        {
            Check("a player turn opens for the move condition captures", false);
            return;
        }
        var db = ConditionDatabase.Instance;
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var controller = (PlayerTurnController)typeof(CombatScene)
            .GetField("_controller", BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(scene)!;

        actor.Conditions.AddCondition(db.Prone);
        controller.Cancel();
        scene.ClearHover();
        await WaitSeconds(PoseSeconds);
        var plan = session.PlayerActions.GetMovePlan(actor);
        Check($"prone capture: Crawl bands only ({plan.Options.Count} tiles)",
            plan.Options.Count > 0 && plan.Options.Values.All(o => o.Kind == MoveKind.Crawl));
        Check($"prone capture: hint reads '{bar.Decision.HintText}'", bar.Decision.HintText == "Prone: Crawl 5 ft or Stand");
        AssertZones(scene, "move_prone_crawl.png");
        Capture("move_prone_crawl.png");

        actor.Conditions.RemoveCondition(db.Prone);
        actor.Conditions.AddCondition(db.Grabbed, source: session.Team2.First());
        controller.Cancel();
        await WaitSeconds(PoseSeconds);
        Check("grabbed capture: no bands", session.PlayerActions.GetMovePlan(actor).Options.Count == 0);
        Check($"grabbed capture: hint reads '{bar.Decision.HintText}'", bar.Decision.HintText == "Immobilized: cannot move");
        AssertZones(scene, "move_grabbed.png");
        Capture("move_grabbed.png");
        actor.Conditions.RemoveCondition(db.Grabbed);
        controller.Cancel();
    }
}
