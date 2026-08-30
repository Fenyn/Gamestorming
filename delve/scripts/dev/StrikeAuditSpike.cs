using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Range/positioning audit. Runs seeded AI-vs-AI encounters and, for EVERY resolved strike
/// (StrikeResolver.OnStrikeResolved), compares the attacker->defender PF2e distance at strike time
/// against the strike's legal range:
///   melee   -> weapon/strike reach in tiles (violation if farther),
///   ranged  -> 6 range increments (hard PF2e maximum; violation if farther).
/// Every strike is logged with positions so violations can be traced to the deciding code path.
/// </summary>
public partial class StrikeAuditSpike : SpikeBase
{
    private const int MaxRangeIncrements = 6;

    private int _strikes;
    private int _violations;

    protected override string Banner => "==================== STRIKE AUDIT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        using var reactions = UsePassthroughReactions();
        StrikeResolver.OnStrikeResolved += OnStrike;
        try
        {
            foreach (int seed in new[] { 1234, 777, 42 })
                await RunEncounter(data, seed);
        }
        finally
        {
            StrikeResolver.OnStrikeResolved -= OnStrike;
        }

        GD.Print($"[Audit] Strikes audited: {_strikes}, range violations: {_violations}");
        Check($"strikes were actually audited ({_strikes})", _strikes > 0);
        Check($"no range violations ({_violations})", _violations == 0);
    }

    private async Task RunEncounter(DataManager data, int seed)
    {
        GD.Print($"-------------------- encounter, seed {seed} --------------------");
        Rng.Seed(seed);

        var grid = BattleGrid.CreateFlat(14, 12);
        var runner = new BattleRunner();
        runner.SetPresenter(_ => Task.CompletedTask);
        var simulator = new AIBattleSimulator(grid, runner);

        var veteran = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var recruit = PresetCharacters.BuildRecruit(level: 2, teamId: 1);
        var team1 = new List<ICharacter> { veteran, recruit };
        simulator.PlaceCreature(veteran, new PF2eVec(2, 5));
        simulator.PlaceCreature(recruit, new PF2eVec(2, 7));

        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        var team2 = new List<ICharacter>();
        var positions = new[]
        {
            new PF2eVec(11, 4), new PF2eVec(11, 5),
            new PF2eVec(11, 6), new PF2eVec(11, 7),
        };
        foreach (var pos in positions)
        {
            var g = CreatureFactory.Create(goblinDef, teamId: 2);
            simulator.PlaceCreature(g, pos);
            team2.Add(g);
        }

        var result = await simulator.RunEncounter(team1, team2);
        GD.Print($"[Audit] seed {seed} result: {result}");
    }

    private void OnStrike(StrikeStatEvent evt)
    {
        var ctx = evt.Context;
        var attacker = evt.Attacker;
        var target = evt.Target;
        if (attacker == null || target == null || ctx == null) return;

        _strikes++;
        int dist = AreaCalculator.GetPF2eDistance(
            attacker.GridPosition, attacker.TileWidth,
            target.GridPosition, target.TileWidth);

        (int allowed, string basis) = AllowedRangeTiles(ctx, attacker);
        bool violation = dist > allowed;
        if (violation) _violations++;

        string line = $"[Audit] {(violation ? "VIOLATION " : "")}{attacker.Name}@{attacker.GridPosition} " +
            $"-> {target.Name}@{target.GridPosition} \"{ctx.StrikeName}\" " +
            $"{(ctx.IsMelee ? "melee" : "ranged")} dist={dist} allowed={allowed} ({basis})";
        if (violation) GD.PushError(line);
        else GD.Print(line);
    }

    private static (int allowed, string basis) AllowedRangeTiles(StrikeContext ctx, ICharacter attacker)
    {
        // Creature statblock strike.
        if (ctx.CreatureStrikeIndex.HasValue && attacker.CreatureStats != null)
        {
            var s = attacker.CreatureStats.GetStrike(ctx.CreatureStrikeIndex.Value);
            if (s.HasValue)
            {
                if (s.Value.RangeFeet > 0)
                    return (s.Value.RangeFeet / 5 * MaxRangeIncrements, $"ranged, increment {s.Value.RangeFeet}ft x{MaxRangeIncrements}");
                int reach = Math.Max(1, s.Value.ReachFeet / 5);
                if (s.Value.HasReach && reach < 2) reach = 2;
                return (reach, $"melee reach {reach} tiles");
            }
        }

        // Equipment weapon (PC path).
        if (ctx.Weapon != null)
        {
            int tiles = ctx.Weapon.GetRangeInTiles();
            if (ctx.IsMelee) return (tiles, $"weapon melee reach {tiles} tiles");
            return (tiles * MaxRangeIncrements, $"weapon ranged {tiles} tiles x{MaxRangeIncrements}");
        }

        return (1, "unarmed fallback");
    }
}
