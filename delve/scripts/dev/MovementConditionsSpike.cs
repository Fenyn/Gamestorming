using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using PF2e;
using PF2e.Conditions;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless check of the movement condition gates. A prone hero gets one-tile Crawl bands, the
/// Prone hint and a Stand chip, and cannot Stride. A grabbed hero gets no bands, the Immobilized
/// hint and an Escape chip. A grabbed goblin never moves on its turn, and a prone goblin never
/// Strides while prone.
/// </summary>
public partial class MovementConditionsSpike : SpikeBase
{
    protected override string Banner => "================ MOVEMENT CONDITIONS SPIKE ================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        using var reactions = UsePassthroughReactions();
        await RunHero(data, prone: true);
        await RunHero(data, prone: false);
        await RunAi(data);
    }

    private static CombatSession NewSession(DataManager data, ICharacter hero, out ICharacter g1, out ICharacter g2,
        PF2eVec heroAt, PF2eVec g1At, PF2eVec g2At)
    {
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        g1 = CreatureFactory.Create(goblinDef, teamId: 2);
        g2 = CreatureFactory.Create(goblinDef, teamId: 2);
        var session = new CombatSession();
        session.Setup(new CombatSetup
        {
            GridWidth = 20, GridHeight = 8, RngSeed = 11,
            Party = { (hero, heroAt) },
            Enemies = { (g1, g1At), (g2, g2At) },
        });
        return session;
    }

    private async Task RunHero(DataManager data, bool prone)
    {
        Godot.GD.Print(prone ? "-------------------- prone hero --------------------"
                             : "-------------------- grabbed hero --------------------");
        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var session = NewSession(data, hero, out var g1, out _, new PF2eVec(3, 4), new PF2eVec(17, 2), new PF2eVec(17, 6));
        session.SetPresenter(_ => Task.CompletedTask);
        var cts = new CancellationTokenSource();
        session.PlayerTurnStarted += c => { _ = (prone ? DriveProne(c, session, cts) : DriveGrabbed(c, g1, session, cts)); };
        await session.RunAsync(cts.Token);
        session.Teardown();
    }

    private async Task DriveProne(ICharacter c, CombatSession session, CancellationTokenSource cts)
    {
        try
        {
            var exec = session.PlayerActions;
            c.Conditions.AddCondition(ConditionDatabase.Instance.Prone);
            var controller = new PlayerTurnController(exec);
            ActionBarState? bar = null;
            controller.ButtonStateChanged += s => bar = s;
            controller.BeginTurn(c);

            int actions = c.Actions.TotalActionsRemaining;
            var plan = exec.GetMovePlan(c);
            Check($"prone: one Crawl band per action ({plan.BandCount} of {actions})", plan.BandCount == actions);
            Check("prone: every option is a Crawl", plan.Options.Count > 0 && plan.Options.Values.All(o => o.Kind == MoveKind.Crawl));
            Check("prone: band 1 is the adjacent tiles only", plan.Options.Where(o => o.Value.Actions == 1)
                .All(o => Math.Max(Math.Abs(o.Key.x - c.GridPosition.x), Math.Abs(o.Key.y - c.GridPosition.y)) == 1));
            Check("prone: no Step tiles", exec.GetStepTiles(c).Count == 0);
            Check($"prone: hint reads \"{bar?.MoveRestriction}\"", bar?.MoveRestriction == "Prone: Crawl 5 ft or Stand");
            var stand = bar?.SkillEntries.FirstOrDefault(s => s.ActionId == "stand");
            Check("prone: Stand chip is castable and first on the signature row",
                stand is { Castable: true, SignaturePriority: 1 });

            var start = c.GridPosition;
            Check("prone: Stride is refused", !await exec.ExecuteStride(c, new PF2eVec(start.x + 3, start.y)));
            Check("prone: the refused Stride spent nothing", c.GridPosition == start && c.Actions.TotalActionsRemaining == actions);

            var crawlTile = plan.Options.First(o => o.Value.Actions == 1 && o.Key.x > start.x).Key;
            controller.BeginMove();
            await Click(controller, () => controller.TileClicked(crawlTile));
            Check("prone: a band click crawls 5 ft", c.GridPosition == crawlTile);
            Check("prone: the Crawl spent 1 action and kept prone",
                c.Actions.TotalActionsRemaining == actions - 1 && c.Conditions.HasCondition(Condition.Prone));

            await Click(controller, () => controller.BeginSkill("stand"));
            Check("prone: Stand ends prone for 1 action",
                !c.Conditions.HasCondition(Condition.Prone) && c.Actions.TotalActionsRemaining == actions - 2);
            var upright = exec.GetMovePlan(c);
            Check("prone: standing restores Stride bands", upright.Options.Values.Any(o => o.Kind == MoveKind.Stride));
            Check("prone: the hint clears after Stand", bar?.MoveRestriction == null);
            Check("prone: the Stand chip leaves the bar", bar?.SkillEntries.All(s => s.ActionId != "stand") == true);
            controller.EndControl();
        }
        finally
        {
            cts.Cancel();
            session.RequestEndPlayerTurn();
        }
    }

    private async Task DriveGrabbed(ICharacter c, ICharacter grabber, CombatSession session, CancellationTokenSource cts)
    {
        try
        {
            var exec = session.PlayerActions;
            c.Conditions.AddCondition(ConditionDatabase.Instance.Grabbed, source: grabber, dc: 16);
            var controller = new PlayerTurnController(exec);
            ActionBarState? bar = null;
            controller.ButtonStateChanged += s => bar = s;
            controller.BeginTurn(c);

            var start = c.GridPosition;
            int actions = c.Actions.TotalActionsRemaining;
            Check("grabbed: no move bands", exec.GetMovePlan(c).Options.Count == 0);
            Check("grabbed: no Step tiles", exec.GetStepTiles(c).Count == 0);
            Check($"grabbed: hint reads \"{bar?.MoveRestriction}\"", bar?.MoveRestriction == "Immobilized: cannot move");
            Check("grabbed: Stride is refused", !await exec.ExecuteStride(c, new PF2eVec(start.x + 2, start.y)));
            Check("grabbed: Step is refused", !await exec.ExecuteStep(c, new PF2eVec(start.x + 1, start.y)));
            Check("grabbed: nothing moved or spent", c.GridPosition == start && c.Actions.TotalActionsRemaining == actions);
            var escape = bar?.SkillEntries.FirstOrDefault(s => s.ActionId == "escape");
            Check("grabbed: Escape chip is offered and castable", escape is { Castable: true, SignaturePriority: 2 });
            Check("grabbed: no Stand chip while upright", bar?.SkillEntries.All(s => s.ActionId != "stand") == true);
            controller.EndControl();
        }
        finally
        {
            cts.Cancel();
            session.RequestEndPlayerTurn();
        }
    }

    private static async Task Click(PlayerTurnController controller, Action click)
    {
        var done = new TaskCompletionSource();
        void OnDone() => done.TrySetResult();
        controller.ActionCompleted += OnDone;
        click();
        await Task.WhenAny(done.Task, Task.Delay(5000));
        controller.ActionCompleted -= OnDone;
    }

    private async Task RunAi(DataManager data)
    {
        Godot.GD.Print("-------------------- AI --------------------");
        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var session = NewSession(data, hero, out var grabbed, out var prone,
            new PF2eVec(2, 4), new PF2eVec(14, 2), new PF2eVec(14, 6));
        grabbed.Conditions.AddCondition(ConditionDatabase.Instance.Grabbed, source: hero, dc: 30);
        prone.Conditions.AddCondition(ConditionDatabase.Instance.Prone);
        var grabbedStart = grabbed.GridPosition;
        var proneStart = prone.GridPosition;

        int grabbedMoves = 0, proneStrides = 0, proneMoves = 0;
        session.SetPresenter(evt =>
        {
            if (evt.Type == BattleEventType.MovementStarted && evt.Path == null)
            {
                if (evt.Source == grabbed) grabbedMoves++;
                if (evt.Source == prone)
                {
                    proneMoves++;
                    if (prone.Conditions.HasCondition(Condition.Prone) && evt.Description?.Contains("Strides") == true)
                        proneStrides++;
                }
            }
            return Task.CompletedTask;
        });

        var cts = new CancellationTokenSource();
        int heroTurns = 0;
        session.PlayerTurnStarted += _ =>
        {
            if (++heroTurns >= 2) cts.Cancel();
            session.RequestEndPlayerTurn();
        };
        await session.RunAsync(cts.Token);
        session.Teardown();

        Check($"AI: a grabbed goblin does not move ({grabbedMoves} moves)",
            grabbedMoves == 0 && grabbed.GridPosition == grabbedStart);
        Check($"AI: a prone goblin never Strides while prone ({proneStrides})", proneStrides == 0);
        Check("AI: the prone goblin stood or crawled",
            !prone.Conditions.HasCondition(Condition.Prone) || prone.GridPosition != proneStart);
        Godot.GD.Print($"[Spike] prone goblin moves: {proneMoves}, prone now: {prone.Conditions.HasCondition(Condition.Prone)}");
    }
}
