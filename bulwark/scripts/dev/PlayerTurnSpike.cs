using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the player action path: builds the Veteran vs two Goblin Warriors,
/// programmatically drives <see cref="PlayerActionExecutor"/> through a scripted first turn
/// (reachable check → Stride → MAP-checked Strikes → shield/exhaustion), then lets the session run
/// AI turns to a decisive result. Prints per-assertion PASS/FAIL and a final SPIKE RESULT line.
/// </summary>
public partial class PlayerTurnSpike : Node
{
    private int _asserts;
    private int _failures;
    private int _playerTurns;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== PLAYER TURN SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[Spike] DataManager not loaded — aborting.");
            GD.Print("SPIKE RESULT: FAIL");
            GetTree().Quit(1);
            return;
        }

        var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);
        var goblinDef = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");
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

        Assert("encounter reached a decisive result",
            finalResult is BattleResult.Team1Wins or BattleResult.Team2Wins);
        Assert("Veteran survived", veteran.Health.IsAlive);
        Assert("all goblins defeated", !g1.Health.IsAlive && !g2.Health.IsAlive);

        GD.Print("---------------------------------------------------------");
        GD.Print($"[Spike] Result: {finalResult} | player turns driven: {_playerTurns}");
        GD.Print($"[Spike] Asserts passed: {_asserts - _failures}/{_asserts}");
        bool pass = _failures == 0;
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    private async Task DrivePlayerTurn(ICharacter c, CombatSession session)
    {
        _playerTurns++;
        bool first = _playerTurns == 1;
        var exec = session.PlayerActions;

        if (first)
            Assert("reachable tiles non-empty at turn start", exec.GetReachableTiles(c).Count > 0);

        int strikeIndex = 0;

        while ((c.Actions?.TotalActionsRemaining ?? 0) > 0)
        {
            var targets = exec.GetStrikeTargets(c);
            if (targets.Count > 0)
            {
                var target = targets[0];
                int mapBefore = exec.GetCurrentMap(c);
                if (first && strikeIndex == 0)
                    Assert("MAP is 0 before first Strike", mapBefore == 0);
                if (first && strikeIndex == 1)
                    Assert("MAP is -5 before second Strike", mapBefore == -5);

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
                    Assert("position changed after Stride",
                        c.GridPosition.x != before.x || c.GridPosition.y != before.y);
                    Assert("one action spent by Stride (2 remain)",
                        c.Actions.TotalActionsRemaining == actionsBefore - 1);
                }
            }
        }

        if (first)
        {
            bool canRaise = c.Equipment?.CanRaiseShield() == true
                            && (c.Actions?.TotalActionsRemaining ?? 0) > 0;
            if (canRaise)
                Assert("Raise Shield succeeded", await exec.ExecuteRaiseShield(c));
            else
                Assert("actions exhausted at end of turn", (c.Actions?.TotalActionsRemaining ?? 0) == 0);
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

    private void Assert(string label, bool condition)
    {
        _asserts++;
        if (!condition) _failures++;
        GD.Print($"  [{(condition ? "PASS" : "FAIL")}] {label}");
    }

    private static void OnLog(CombatLogEntry entry)
    {
        string prefix = entry.IsDetail ? "      - " : "    [log] ";
        GD.Print($"{prefix}{entry.Message}");
    }
}
