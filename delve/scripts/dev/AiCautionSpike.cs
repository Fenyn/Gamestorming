using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.AI;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// The self-preservation layer a Wayfarer ally fights with. Covers the risk arithmetic
/// (<see cref="AICaution"/>), that a caution of 0 changes nothing, and that the same character on
/// the same board engages a pack of three at full HP but stays out of its reach at a quarter.
/// </summary>
public partial class AiCautionSpike : SpikeBase
{
    protected override string Banner => "==================== AI CAUTION SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        using var reactions = UsePassthroughReactions();

        ScenarioA_Risk(data);
        await ScenarioB_FightsButDoesNotDie(data);
        ScenarioC_TurnOrder(data);
    }

    // ─────────────────── (a) the risk arithmetic ───────────────────

    private void ScenarioA_Risk(DataManager data)
    {
        GD.Print("-- (a) risk is a round of incoming damage against the HP that is left --");

        var (grid, _, _) = MakeArena();

        var ally = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var friend = PresetCharacters.BuildTharr(level: 2, teamId: 1);
        var pack = new[] { MakeGoblin(data), MakeGoblin(data), MakeGoblin(data) };

        var stand = new PF2eVec(4, 6);
        var clear = new PF2eVec(1, 6);
        grid.PlaceCreature(ally, stand);
        grid.PlaceCreature(friend, new PF2eVec(3, 6));
        grid.PlaceCreature(pack[0], new PF2eVec(5, 6));
        grid.PlaceCreature(pack[1], new PF2eVec(5, 5));
        grid.PlaceCreature(pack[2], new PF2eVec(5, 7));
        Register(ally, friend, pack[0], pack[1], pack[2]);

        var ctx = AIContextBuilder.Build(ally, grid);
        ctx.ResolvedProfile = AllyAiRules.Default.Apply(ctx.ResolvedProfile);

        float threat = AICaution.Threat(ctx, stand);
        int support = AICaution.Support(ctx, stand);
        float incoming = AICaution.IncomingDamage(ctx, stand);
        float healthyRisk = AICaution.Risk(ctx, stand);

        Check($"(a) three adjacent enemies bear on the tile ({threat:F1})",
            Math.Abs(threat - 3f) < 0.01f);
        Check($"(a) the one nearby friend counts as support ({support})", support == 1);
        Check($"(a) they threaten real damage ({incoming:F1} a round)", incoming > 0f);
        Check("(a) a clear tile is worth more than the one inside the pack",
            AICaution.Risk(ctx, clear) < healthyRisk);
        Check($"(a) a healthy ally can afford this fight ({healthyRisk:F2} risk)",
            AICaution.EndPositionPenalty(ctx, stand) == 0f);

        // Down to a quarter HP the same three goblins are lethal, so the same tile now costs.
        ally.Health!.TakeDamage(new DamageResult
        {
            TotalDamage = ally.Health.MaxHP - ally.Health.MaxHP / 4,
            DamageType = DamageType.Slashing
        });
        var hurt = AIContextBuilder.Build(ally, grid);
        hurt.ResolvedProfile = AllyAiRules.Default.Apply(hurt.ResolvedProfile);

        Check($"(a) the same tile is lethal at a quarter HP ({AICaution.Risk(hurt, stand):F2} risk)",
            AICaution.Risk(hurt, stand) > healthyRisk);
        Check("(a) and now costs plan score",
            AICaution.EndPositionPenalty(hurt, stand) > 0f);
        Check("(a) an uncautious profile pays nothing (caution 0 = old behaviour)",
            AICaution.EndPositionPenalty(AIContextBuilder.Build(ally, grid), stand) == 0f);

        Cleanup(ally, friend, pack[0], pack[1], pack[2]);
    }

    // ─────────────────── (b) fights while it can, backs out when it cannot ───────────────────

    private async Task ScenarioB_FightsButDoesNotDie(DataManager data)
    {
        GD.Print("-- (b) a cautious ally still engages, until the fight would kill it --");

        int reckless = await RunApproach(data, cautious: false, woundedToQuarter: false);
        int healthy = await RunApproach(data, cautious: true, woundedToQuarter: false);
        int wounded = await RunApproach(data, cautious: true, woundedToQuarter: true);

        Check($"(b) the reckless ally closes into the pack ({reckless} enemies in reach)",
            reckless >= 1);
        Check($"(b) a healthy cautious ally still engages ({healthy} enemies in reach)",
            healthy >= 1);
        Check($"(b) at a quarter HP it stays out of reach ({wounded} enemies in reach)",
            wounded < healthy);
    }

    /// <summary>One AI turn walking toward three packed goblins. Returns how many of them ended
    /// within reach of the actor.</summary>
    private async Task<int> RunApproach(DataManager data, bool cautious, bool woundedToQuarter)
    {
        var (grid, _, executor) = MakeArena();

        var ally = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var pack = new[] { MakeGoblin(data), MakeGoblin(data), MakeGoblin(data) };

        grid.PlaceCreature(ally, new PF2eVec(8, 6));
        grid.PlaceCreature(pack[0], new PF2eVec(13, 5));
        grid.PlaceCreature(pack[1], new PF2eVec(13, 6));
        grid.PlaceCreature(pack[2], new PF2eVec(13, 7));
        Register(ally, pack[0], pack[1], pack[2]);

        if (woundedToQuarter)
            ally.Health!.TakeDamage(new DamageResult
            {
                TotalDamage = ally.Health.MaxHP - ally.Health.MaxHP / 4,
                DamageType = DamageType.Slashing
            });

        if (cautious)
            AIContextBuilder.ProfileOverride = (c, p) =>
                ReferenceEquals(c, ally) ? AllyAiRules.Default.Apply(p) : p;

        try
        {
            ally.Actions.RefillActions();
            await executor.ExecuteTurn(ally);
        }
        finally
        {
            AIContextBuilder.ProfileOverride = null!;
        }

        int adjacent = 0;
        foreach (var goblin in pack)
        {
            int dist = AreaCalculator.GetPF2eDistance(
                ally.GridPosition, ally.TileWidth,
                goblin.GridPosition, goblin.TileWidth);
            if (dist <= 1) adjacent++;
        }

        GD.Print($"    {(cautious ? "cautious" : "reckless")}" +
            $"{(woundedToQuarter ? " at a quarter HP" : "")}: ends at {ally.GridPosition}, " +
            $"{adjacent} enemies in reach, {ally.Health!.CurrentHP}/{ally.Health.MaxHP} HP");
        Cleanup(ally, pack[0], pack[1], pack[2]);
        return adjacent;
    }

    // ─────────────────── (c) the same tile, read through the turn order ───────────────────

    private void ScenarioC_TurnOrder(DataManager data)
    {
        GD.Print("-- (c) the same spot costs more when the enemies all act before any friend --");

        var (grid, _, _) = MakeArena();

        var ally = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var friendA = PresetCharacters.BuildTharr(level: 2, teamId: 1);
        var friendB = PresetCharacters.BuildElara(level: 2, teamId: 1);
        var pack = new[] { MakeGoblin(data), MakeGoblin(data), MakeGoblin(data) };

        var stand = new PF2eVec(4, 6);
        grid.PlaceCreature(ally, stand);
        grid.PlaceCreature(friendA, new PF2eVec(3, 6));
        grid.PlaceCreature(friendB, new PF2eVec(3, 5));
        grid.PlaceCreature(pack[0], new PF2eVec(5, 6));
        grid.PlaceCreature(pack[1], new PF2eVec(5, 5));
        grid.PlaceCreature(pack[2], new PF2eVec(5, 7));
        Register(ally, friendA, friendB, pack[0], pack[1], pack[2]);

        // Same board, same wounds, same everyone. Only the initiative differs.
        var massed = Risk(ally, grid,
            new[] { ally, pack[0], pack[1], pack[2], friendA, friendB }, stand);
        var interleaved = Risk(ally, grid,
            new[] { ally, pack[0], friendA, pack[1], friendB, pack[2] }, stand);

        GD.Print($"    all three goblins first: {massed.risk:F2} risk, " +
            $"{massed.exposure} enemy turns before relief");
        GD.Print($"    friends in between: {interleaved.risk:F2} risk, " +
            $"{interleaved.exposure} enemy turns before relief");

        Check($"(c) three enemy turns pass before a friend acts ({massed.exposure})",
            massed.exposure == 3);
        Check($"(c) one does when the friends are spread through the order ({interleaved.exposure})",
            interleaved.exposure == 1);
        Check("(c) the same tile is riskier with no friend acting in between",
            massed.risk > interleaved.risk);

        // Wounded enough that the order decides whether the tile is affordable at all.
        ally.Health!.TakeDamage(new DamageResult
        {
            TotalDamage = ally.Health.MaxHP - ally.Health.MaxHP / 3,
            DamageType = DamageType.Slashing
        });

        float massedPenalty = Penalty(ally, grid,
            new[] { ally, pack[0], pack[1], pack[2], friendA, friendB }, stand);
        float interleavedPenalty = Penalty(ally, grid,
            new[] { ally, pack[0], friendA, pack[1], friendB, pack[2] }, stand);

        GD.Print($"    at a third HP: massed costs {massedPenalty:F1} score, " +
            $"interleaved costs {interleavedPenalty:F1}");

        Check($"(c) a wounded ally pays to stand there when nobody relieves it ({massedPenalty:F1})",
            massedPenalty > 0f);
        Check("(c) and pays less when its friends act in between",
            interleavedPenalty < massedPenalty);

        Cleanup(ally, friendA, friendB, pack[0], pack[1], pack[2]);
    }

    /// <summary>Risk and exposure for one tile under a given initiative, with the actor acting now.</summary>
    private static (float risk, int exposure) Risk(
        ICharacter actor, BattleGrid grid, ICharacter[] order, PF2eVec tile)
    {
        var ctx = ContextInOrder(actor, grid, order);
        return (AICaution.Risk(ctx, tile), ctx.TurnWindow.EnemyTurnsBeforeRelief);
    }

    private static float Penalty(
        ICharacter actor, BattleGrid grid, ICharacter[] order, PF2eVec tile)
        => AICaution.EndPositionPenalty(ContextInOrder(actor, grid, order), tile);

    /// <summary>An AI context built with the turn order fixed to <paramref name="order"/>, the actor
    /// first. The encounter ends before returning so the next call starts clean.</summary>
    private static AIContext ContextInOrder(ICharacter actor, BattleGrid grid, ICharacter[] order)
    {
        var turns = TurnManager.Instance;
        turns.StartEncounterWithFixedOrder(new List<ICharacter>(order));

        var ctx = AIContextBuilder.Build(actor, grid);
        ctx.ResolvedProfile = AllyAiRules.Default.Apply(ctx.ResolvedProfile);

        turns.EndEncounter();
        return ctx;
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private static (BattleGrid grid, List<BattleEvent> events, AITurnExecutor executor) MakeArena()
    {
        Rng.Seed(1234);

        var grid = BattleGrid.CreateFlat(20, 12);
        var events = new List<BattleEvent>();
        var runner = new BattleRunner();
        runner.SetPresenter(evt =>
        {
            events.Add(evt);
            return Task.CompletedTask;
        });

        _ = new AIBattleSimulator(grid, runner);

        return (grid, events, new AITurnExecutor(runner, grid));
    }

    private static void Register(params ICharacter[] characters)
    {
        foreach (var c in characters)
            CombatantRegistry.Instance.Register(c);
    }

    private static void Cleanup(params ICharacter[] characters)
    {
        foreach (var c in characters)
            CombatantRegistry.Instance.Unregister(c);
    }

    private static ICharacter MakeGoblin(DataManager data)
    {
        var def = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
        return CreatureFactory.Create(def, teamId: 2);
    }
}
