using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2e.Events;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// Anti-stacking regression spike. Runs a fully AI-driven encounter — 4 Goblin Warriors (team 2,
/// full planner) vs the Veteran + Recruit (team 1, weapon fallback) — under a fixed seed, and after
/// every MovementCompleted / TurnEnded event asserts the two occupancy invariants that the planner +
/// BattleGrid transit fix must uphold:
///   1. Distinct tiles: no two living combatants share a GridPosition (PF2e: you may move THROUGH an
///      ally's space but never END movement in an occupied one).
///   2. Registration integrity: Grid.GetGroundOccupant(c.GridPosition) == c for every living
///      combatant (a transit must never delete or clobber another creature's registration).
/// Also verifies at least one goblin ran the planner (a "[AI] ... executing plan" log line).
/// </summary>
public partial class AiStackSpike : SpikeBase
{
    private readonly List<ICharacter> _all = new();
    private BattleGrid _grid = null!;

    private int _movementEvents;
    private int _turnEndEvents;
    private int _distinctFailures;
    private int _registrationFailures;
    private bool _plannerObserved;

    private Action<string>? _priorInfoSink;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== AI STACK SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[Spike] DataManager not loaded — aborting.");
            return;
        }

        Rng.Seed(1234);

        // Pass-through reaction handler (StrikeResolver.DeliverDamage throws without one).
        ReactionEvents.DamageReactionHandler damageHandler = (src, tgt, result, applyDamage) => { applyDamage(); return System.Threading.Tasks.Task.CompletedTask; };
        ReactionEvents.OnDamageReactionCheck += damageHandler;

        // Observe engine info logs to confirm the goblins ran the planner. DataManager already
        // routes Log.OnInfo to GD.Print; chain through it so console output is preserved.
        _priorInfoSink = Log.OnInfo;
        Log.OnInfo = msg =>
        {
            _priorInfoSink?.Invoke(msg);
            if (msg != null && msg.Contains("executing plan") && msg.Contains("Goblin"))
                _plannerObserved = true;
        };

        _grid = BattleGrid.CreateFlat(14, 12);
        var runner = new BattleRunner();
        runner.SetPresenter(CheckOnEvent);
        var simulator = new AIBattleSimulator(_grid, runner);

        // Team 1: two AI-driven PCs (weapon fallback path).
        var veteran = PresetCharacters.BuildVeteran(level: 2, teamId: 1);
        var recruit = PresetCharacters.BuildRecruit(level: 2, teamId: 1);
        var team1 = new List<ICharacter> { veteran, recruit };
        simulator.PlaceCreature(veteran, new PF2eVec(2, 5));
        simulator.PlaceCreature(recruit, new PF2eVec(2, 7));

        // Team 2: four Goblin Warriors (full planner) clustered so they must fan out to avoid stacking.
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var goblinPositions = new[]
        {
            new PF2eVec(11, 4), new PF2eVec(11, 5),
            new PF2eVec(11, 6), new PF2eVec(11, 7),
        };
        var team2 = new List<ICharacter>();
        foreach (var pos in goblinPositions)
        {
            var g = CreatureFactory.Create(goblinDef, teamId: 2);
            simulator.PlaceCreature(g, pos);
            team2.Add(g);
        }

        _all.AddRange(team1);
        _all.AddRange(team2);

        GD.Print($"[Spike] {team1.Count} PCs (team 1, AI) vs {team2.Count} Goblin Warriors (team 2), seed 1234");

        // Assert the starting layout is already clean.
        CheckInvariants("initial placement");

        BattleResult result = await simulator.RunEncounter(team1, team2);

        // Restore the log sink.
        Log.OnInfo = _priorInfoSink;
        ReactionEvents.OnDamageReactionCheck -= damageHandler;

        GD.Print($"[Spike] Result: {result}");
        GD.Print($"[Spike] Movement events checked: {_movementEvents}, turn-end events checked: {_turnEndEvents}");

        Check($"distinct-tiles: no two living combatants share a tile ({_distinctFailures} violations)",
            _distinctFailures == 0);
        Check($"registration-integrity: GetGroundOccupant(pos)==c ({_registrationFailures} violations)",
            _registrationFailures == 0);
        Check("a goblin ran the planner (\"executing plan\")", _plannerObserved);
        Check($"encounter reached a decisive result ({result})",
            result is BattleResult.Team1Wins or BattleResult.Team2Wins);

        FinishAndQuit("AiStackSpike");
    }

    private Task CheckOnEvent(BattleEvent evt)
    {
        if (evt.Type == BattleEventType.MovementCompleted)
        {
            _movementEvents++;
            CheckInvariants($"after MovementCompleted ({evt.Source?.Name})");
        }
        else if (evt.Type == BattleEventType.TurnEnded)
        {
            _turnEndEvents++;
            CheckInvariants($"after TurnEnded ({evt.Source?.Name})");
        }
        return Task.CompletedTask;
    }

    private void CheckInvariants(string context)
    {
        var seen = new Dictionary<PF2eVec, ICharacter>();
        foreach (var c in _all)
        {
            if (c.Health == null || !c.Health.IsAlive) continue;

            var pos = c.GridPosition;

            // Distinct tiles.
            if (seen.TryGetValue(pos, out var other))
            {
                _distinctFailures++;
                GD.PushError($"[Spike] STACK {context}: {c.Name} and {other.Name} both on {pos}");
            }
            else
            {
                seen[pos] = c;
            }

            // Registration integrity.
            var occupant = _grid.GetGroundOccupant(pos);
            if (!ReferenceEquals(occupant, c))
            {
                _registrationFailures++;
                GD.PushError($"[Spike] REGISTRATION {context}: {c.Name}@{pos} but occupant is {occupant?.Name ?? "null"}");
            }
        }
    }
}
