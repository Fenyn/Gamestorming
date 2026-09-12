using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Combat;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless verification of the player action path: builds the Veteran vs two Goblin Warriors,
/// programmatically drives <see cref="PlayerActionExecutor"/> through a scripted first turn
/// (move-plan checks → Stride → MAP-checked Strikes → shield/exhaustion), then lets the session run
/// AI turns to a decisive result. A second, wider board then proves the smart-move plan executes:
/// a band-2 tile is reached by walking its two legs, and a Step tile spends one action with no
/// per-tile stride events. Prints per-assertion PASS/FAIL and a final SPIKE RESULT line.
/// </summary>
public partial class PlayerTurnSpike : SpikeBase
{
    private int _playerTurns;

    protected override string Banner => "==================== PLAYER TURN SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        await RunFight(data);
        await RunSmartMove(data);
    }

    private async Task RunFight(DataManager data)
    {
        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var g1 = CreatureFactory.Create(goblinDef, teamId: 2);
        var g2 = CreatureFactory.Create(goblinDef, teamId: 2);

        var session = new CombatSession();
        session.Setup(new CombatSetup
        {
            GridWidth = 12,
            GridHeight = 10,
            RngSeed = 99,
            Party = { (veteran, new PF2eVec(1, 4)) },
            Enemies = { (g1, new PF2eVec(6, 3)), (g2, new PF2eVec(6, 5)) },
        });
        session.SetPresenter(_ => Task.CompletedTask);

        CombatLog.OnLogEntry += OnLog;

        BattleResult finalResult = BattleResult.InProgress;
        session.EncounterFinished += r => finalResult = r;
        session.PlayerTurnStarted += ch => { _ = DrivePlayerTurn(ch, session); };

        await session.RunAsync();

        CombatLog.OnLogEntry -= OnLog;
        session.Teardown();

        Check("encounter reached a decisive result",
            finalResult is BattleResult.Team1Wins or BattleResult.Team2Wins);
        Check("Veteran survived", veteran.Health.IsAlive);
        Check("all goblins defeated", !g1.Health.IsAlive && !g2.Health.IsAlive);

        GD.Print($"[Spike] Result: {finalResult} | player turns driven: {_playerTurns}");
    }

    /// <summary>
    /// One scripted player turn on a long board with the goblins out of reach: walk a band-2 tile
    /// leg by leg, then Step. The encounter is cancelled afterwards; the AI half is covered above.
    /// </summary>
    private async Task RunSmartMove(DataManager data)
    {
        GD.Print("-------------------- smart move --------------------");
        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var g1 = CreatureFactory.Create(goblinDef, teamId: 2);
        var g2 = CreatureFactory.Create(goblinDef, teamId: 2);

        var session = new CombatSession();
        session.Setup(new CombatSetup
        {
            GridWidth = 24,
            GridHeight = 6,
            RngSeed = 7,
            Party = { (veteran, new PF2eVec(1, 3)) },
            Enemies = { (g1, new PF2eVec(22, 2)), (g2, new PF2eVec(22, 4)) },
        });
        int stepEvents = 0;
        session.SetPresenter(evt =>
        {
            if (evt.Type == BattleEventType.MovementStep) stepEvents++;
            return Task.CompletedTask;
        });

        var cts = new System.Threading.CancellationTokenSource();
        session.PlayerTurnStarted += ch => { _ = DriveSmartMoveTurn(ch, session, () => stepEvents, cts); };
        await session.RunAsync(cts.Token);
        session.Teardown();
    }

    private async Task DriveSmartMoveTurn(ICharacter c, CombatSession session, Func<int> stepEvents,
        System.Threading.CancellationTokenSource cts)
    {
        var exec = session.PlayerActions;
        var plan = exec.GetMovePlan(c);
        int actions = c.Actions!.TotalActionsRemaining;
        Check($"plan built one band per action ({plan.BandCount} of {actions})", plan.BandCount == actions);

        PF2eVec? band2 = null;
        foreach (var (tile, option) in plan.Options)
            if (option.Kind == MoveKind.Stride && option.Actions == 2 && (band2 == null || tile.x > band2.Value.x))
                band2 = tile;
        Check("a band-2 tile exists on the long board", band2 != null);

        if (band2 != null)
        {
            var path = plan.PathTo(band2.Value, out var legs);
            Check("band-2 route has two legs, the first inside band 1",
                path != null && legs.Count == 2 && legs[1] == band2.Value
                && plan.Options[legs[0]] is { Kind: MoveKind.Stride, Actions: 1 });
            Check("route starts on the actor and ends on the tile",
                path != null && path[0] == c.GridPosition && path[^1] == band2.Value);

            bool ok = true;
            foreach (var leg in legs)
                ok &= await exec.ExecuteStride(c, leg);
            Check("both legs executed", ok);
            Check("two Strides spent two actions", c.Actions.TotalActionsRemaining == actions - 2);
            Check("and the actor stands on the band-2 tile", c.GridPosition == band2.Value);
        }

        var replan = exec.GetMovePlan(c);
        Check("one action left builds one band", replan.BandCount == 1);
        PF2eVec? step = null;
        foreach (var (tile, option) in replan.Options)
            if (option.Kind == MoveKind.Step) { step = tile; break; }
        Check("a Step tile is offered beside the actor", step != null);
        if (step != null)
        {
            int before = stepEvents();
            var path = replan.PathTo(step.Value, out var legs);
            Check("a Step route is two tiles and one leg", path?.Count == 2 && legs.Count == 1);
            Check("Step executes", await exec.ExecuteStep(c, step.Value));
            Check("a Step spends the last action and emits no per-tile stride events",
                c.Actions.TotalActionsRemaining == 0 && stepEvents() == before);
        }

        Check("no actions left builds no bands", exec.GetMovePlan(c).Options.Count == 0);
        cts.Cancel();
        session.RequestEndPlayerTurn();
    }

    private async Task DrivePlayerTurn(ICharacter c, CombatSession session)
    {
        _playerTurns++;
        bool first = _playerTurns == 1;
        var exec = session.PlayerActions;

        if (first)
        {
            var plan = exec.GetMovePlan(c);
            var reachable = exec.GetReachableTiles(c);
            var steps = exec.GetStepTiles(c);
            int actions = c.Actions!.TotalActionsRemaining;
            int maxBand = 0;
            bool stepsMatch = true;
            bool band1Matches = true;
            foreach (var (tile, option) in plan.Options)
            {
                maxBand = Math.Max(maxBand, option.Actions);
                if (option.Kind == MoveKind.Step && !steps.Contains(tile)) stepsMatch = false;
                if (option.Kind == MoveKind.Stride && option.Actions == 1 && !reachable.Contains(tile)) band1Matches = false;
            }
            foreach (var tile in steps)
                if (!plan.Options.TryGetValue(tile, out var o) || o.Kind != MoveKind.Step) stepsMatch = false;
            foreach (var tile in reachable)
                if (!plan.Options.TryGetValue(tile, out var o) || o.Actions != 1) band1Matches = false;

            Check("move plan non-empty at turn start", plan.Options.Count > 0);
            Check($"no band exceeds the actions remaining ({maxBand} <= {actions})", maxBand <= actions);
            Check("Step options are exactly the step-legal neighbours", stepsMatch);
            Check("band 1 is exactly the one-Stride reach", band1Matches);
        }

        int strikeIndex = 0;

        while ((c.Actions?.TotalActionsRemaining ?? 0) > 0)
        {
            var targets = exec.GetStrikeTargets(c);
            if (targets.Count > 0)
            {
                var target = targets[0];
                int mapBefore = exec.GetCurrentMap(c);
                if (first && strikeIndex == 0)
                    Check("MAP is 0 before first Strike", mapBefore == 0);
                if (first && strikeIndex == 1)
                    Check("MAP is -5 before second Strike", mapBefore == -5);

                if (!await exec.ExecuteStrike(c, target))
                    break;
                strikeIndex++;
            }
            else
            {
                var dest = BestApproachTile(exec, c);
                if (dest == null) break;

                var before = c.GridPosition;
                int actionsBefore = c.Actions!.TotalActionsRemaining;
                if (!await exec.ExecuteStride(c, dest.Value))
                    break;

                if (first)
                {
                    Check("position changed after Stride",
                        c.GridPosition.x != before.x || c.GridPosition.y != before.y);
                    Check("one action spent by Stride (2 remain)",
                        c.Actions.TotalActionsRemaining == actionsBefore - 1);
                }
            }
        }

        if (first)
        {
            bool canRaise = c.Equipment?.CanRaiseShield() == true
                            && (c.Actions?.TotalActionsRemaining ?? 0) > 0;
            if (canRaise)
                Check("Raise Shield succeeded", await exec.ExecuteRaiseShield(c));
            else
                Check("actions exhausted at end of turn", (c.Actions?.TotalActionsRemaining ?? 0) == 0);
        }

        session.RequestEndPlayerTurn();
    }

    private static PF2eVec? BestApproachTile(PlayerActionExecutor exec, ICharacter c)
    {
        var reachable = exec.GetReachableTiles(c);
        if (reachable.Count == 0) return null;

        var enemies = new List<PF2eVec>();
        foreach (var e in CombatantRegistry.Instance.All)
            if (e.TeamId != c.TeamId && e.Health?.IsAlive == true)
                enemies.Add(e.GridPosition);
        if (enemies.Count == 0) return null;

        PF2eVec? best = null;
        int bestDist = int.MaxValue;
        foreach (var tile in reachable)
        {
            int d = int.MaxValue;
            foreach (var e in enemies)
                d = Math.Min(d, Math.Max(Math.Abs(tile.x - e.x), Math.Abs(tile.y - e.y)));
            if (d < bestDist)
            {
                bestDist = d;
                best = tile;
            }
        }
        return best;
    }

    private static void OnLog(CombatLogEntry entry)
    {
        string prefix = entry.IsDetail ? "      - " : "    [log] ";
        GD.Print($"{prefix}{entry.Message}");
    }
}
