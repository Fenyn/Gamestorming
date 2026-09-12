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
using PF2e.Grid;
using PF2e.TurnManagement;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// The board reading that used to be dead code. Covers the reactive-strike threat list and what it
/// costs to walk through one, the flanking test asked of a tile before moving to it, the turn-order
/// and concentration terms in target choice, and the per-role profile table.
/// </summary>
public partial class AiTacticsSpike : SpikeBase
{
    protected override string Banner => "==================== AI TACTICS SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        using var reactions = UsePassthroughReactions();
        using var queries = UseCombatQueries();

        ScenarioA_ReactiveThreats(data);
        ScenarioB_Flanking(data);
        ScenarioC_TargetChoice(data);
        ScenarioD_RoleProfiles(data);

        return Task.CompletedTask;
    }

    // ─────────────────── (a) who threatens a free swing, and what it costs ───────────────────

    private void ScenarioA_ReactiveThreats(DataManager data)
    {
        GD.Print("-- (a) reactive strikes the planner can actually see --");

        var (grid, _) = MakeArena();

        // A Fighter has Reactive Strike from level 1; a goblin warrior has no reaction at all.
        var fighter = PresetCharacters.BuildPlayer(level: 2, teamId: 2);
        var goblin = MakeGoblin(data);
        var actor = PresetCharacters.BuildElara(level: 2, teamId: 1);

        grid.PlaceCreature(actor, new PF2eVec(2, 6));
        grid.PlaceCreature(fighter, new PF2eVec(6, 6));
        grid.PlaceCreature(goblin, new PF2eVec(6, 9));
        Register(actor, fighter, goblin);

        var ctx = AIContextBuilder.Build(actor, grid);

        Check($"(a) exactly one of the two enemies threatens a reaction ({ctx.ReactiveThreats.Count})",
            ctx.ReactiveThreats.Count == 1);
        Check("(a) and it is the one with Reactive Strike",
            ctx.ReactiveThreats.Count == 1
            && ReferenceEquals(ctx.ReactiveThreats[0].Creature, fighter));

        var q = new DelveCombatQueries();
        float beside = q.ScoreReactiveStrikeDanger(new PF2eVec(5, 6), 1, ctx.ReactiveThreats, 1f);
        float clear = q.ScoreReactiveStrikeDanger(new PF2eVec(2, 2), 1, ctx.ReactiveThreats, 1f);
        float timid = q.ScoreReactiveStrikeDanger(new PF2eVec(5, 6), 1, ctx.ReactiveThreats, 0.5f);

        GD.Print($"    beside the fighter: {beside:F1}, across the board: {clear:F1}, " +
            $"beside at half fear: {timid:F1}");

        Check($"(a) a tile inside its reach costs score ({beside:F1})", beside > 0f);
        Check("(a) a tile outside its reach costs nothing", clear == 0f);
        Check("(a) fear scales the cost", timid < beside);

        // Spend the reaction and the threat is gone.
        fighter.Actions.TryConsumeReaction();
        var spent = AIContextBuilder.Build(actor, grid);
        Check("(a) a spent reaction stops threatening", spent.ReactiveThreats.Count == 0);

        Cleanup(actor, fighter, goblin);
    }

    // ─────────────────── (b) is this tile a flank, asked before moving ───────────────────

    private void ScenarioB_Flanking(DataManager data)
    {
        GD.Print("-- (b) the flanking test on a tile the actor has not moved to --");

        var (grid, _) = MakeArena();

        var actor = PresetCharacters.BuildElara(level: 2, teamId: 1);
        var friend = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var target = MakeGoblin(data);

        // Friend west of the goblin. The tile east of it is the opposite side.
        grid.PlaceCreature(actor, new PF2eVec(2, 6));
        grid.PlaceCreature(friend, new PF2eVec(5, 6));
        grid.PlaceCreature(target, new PF2eVec(6, 6));
        Register(actor, friend, target);

        var q = new DelveCombatQueries();
        bool opposite = q.WouldFlankFrom(new PF2eVec(7, 6), actor.TileWidth, target, actor);
        bool sameSide = q.WouldFlankFrom(new PF2eVec(6, 5), actor.TileWidth, target, actor);
        bool tooFar = q.WouldFlankFrom(new PF2eVec(10, 6), actor.TileWidth, target, actor);

        GD.Print($"    opposite the friend: {opposite}, beside it: {sameSide}, far off: {tooFar}");

        Check("(b) the tile opposite an engaged friend flanks", opposite);
        Check("(b) a tile off to the side does not", !sameSide);
        Check("(b) a tile out of reach of the target does not", !tooFar);

        Cleanup(actor, friend, target);
    }

    // ─────────────────── (c) which enemy is worth the turn ───────────────────

    private void ScenarioC_TargetChoice(DataManager data)
    {
        GD.Print("-- (c) target choice reads the turn order and where the allies already are --");

        var (grid, _) = MakeArena();

        // A wizard is clever enough for the tactical terms; a goblin is not.
        var actor = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var soon = MakeGoblin(data);
        var late = MakeGoblin(data);

        // Both one tile away, so distance cannot decide it.
        grid.PlaceCreature(actor, new PF2eVec(5, 5));
        grid.PlaceCreature(soon, new PF2eVec(6, 5));
        grid.PlaceCreature(late, new PF2eVec(6, 4));
        Register(actor, soon, late);

        var chosen = TargetInOrder(actor, grid, new[] { actor, soon, late });
        var flipped = TargetInOrder(actor, grid, new[] { actor, late, soon });

        GD.Print($"    order [soon, late] picks {chosen?.Name} at {chosen?.GridPosition}; " +
            $"order [late, soon] picks {flipped?.Name} at {flipped?.GridPosition}");

        Check("(c) of two equally close enemies it takes the one acting next",
            ReferenceEquals(chosen, soon));
        Check("(c) and follows the order when it reverses",
            ReferenceEquals(flipped, late));

        Cleanup(actor, soon, late);

        // Concentration: same distance, same place in the order, one already engaged by a friend.
        var (grid2, _) = MakeArena();
        var caster = PresetCharacters.BuildFenwick(level: 2, teamId: 1);
        var friend = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var engaged = MakeGoblin(data);
        var loose = MakeGoblin(data);

        grid2.PlaceCreature(caster, new PF2eVec(5, 5));
        grid2.PlaceCreature(engaged, new PF2eVec(6, 5));
        grid2.PlaceCreature(loose, new PF2eVec(6, 4));
        grid2.PlaceCreature(friend, new PF2eVec(7, 5));
        Register(caster, friend, engaged, loose);

        // Both enemies sit in the same slot relative to the actor, so only the friend differs.
        var picked = TargetInOrder(caster, grid2, new[] { caster, engaged, loose, friend });
        GD.Print($"    with a friend already on one of them, picks {picked?.Name} " +
            $"at {picked?.GridPosition}");

        Check("(c) it piles onto the enemy a friend is already fighting",
            ReferenceEquals(picked, engaged));

        Cleanup(caster, friend, engaged, loose);
    }

    // ─────────────────── (d) what each role is willing to risk ───────────────────

    private void ScenarioD_RoleProfiles(DataManager data)
    {
        GD.Print("-- (d) role defaults --");

        var brute = new AIProfile();
        AIProfileDefaults.ApplyRole(brute, CreatureRole.Melee);
        var archer = new AIProfile();
        AIProfileDefaults.ApplyRole(archer, CreatureRole.Ranged);
        var caster = new AIProfile();
        AIProfileDefaults.ApplyRole(caster, CreatureRole.Caster);
        var skirmisher = new AIProfile();
        AIProfileDefaults.ApplyRole(skirmisher, CreatureRole.Skirmisher);

        Check("(d) a brute plans exactly as before (caution 0)", brute.Caution == 0f);
        Check("(d) an archer minds its skin", archer.Caution > 0f);
        Check("(d) a caster minds it more", caster.Caution > archer.Caution);
        Check("(d) a skirmisher works for the flank", skirmisher.FlankingValue > brute.FlankingValue);
        Check("(d) and both dodge free swings harder than a brute",
            skirmisher.ReactiveStrikeFear > brute.ReactiveStrikeFear
            && caster.ReactiveStrikeFear > brute.ReactiveStrikeFear);

        // The real path a monster takes to its profile, not just the table.
        var (grid, _) = MakeArena();
        var goblin = MakeGoblin(data);
        var enemy = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        grid.PlaceCreature(goblin, new PF2eVec(5, 5));
        grid.PlaceCreature(enemy, new PF2eVec(7, 5));
        Register(goblin, enemy);

        var resolved = AIContextBuilder.Build(goblin, grid).ResolvedProfile;
        GD.Print($"    goblin warrior resolves to role={resolved.PrimaryRole}, " +
            $"caution={resolved.Caution:F1}");

        Check("(d) a goblin warrior is still a brute and still reckless",
            resolved.PrimaryRole == CreatureRole.Melee && resolved.Caution == 0f);

        Cleanup(goblin, enemy);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    /// <summary>The primary target chosen with the turn order fixed to <paramref name="order"/>.</summary>
    private static ICharacter? TargetInOrder(ICharacter actor, BattleGrid grid, ICharacter[] order)
    {
        var turns = TurnManager.Instance;
        turns.StartEncounterWithFixedOrder(new List<ICharacter>(order));

        var ctx = AIContextBuilder.Build(actor, grid);
        var target = AITargetSelector.SelectPrimaryTarget(ctx);

        turns.EndEncounter();
        return target;
    }

    /// <summary>Installs the spatial query object an encounter would, since these scenarios build a
    /// bare grid rather than running one.</summary>
    private static System.IDisposable UseCombatQueries()
    {
        AIContextBuilder.CombatQueries = new DelveCombatQueries();
        return new Restore(() => AIContextBuilder.CombatQueries = null!);
    }

    private sealed class Restore : System.IDisposable
    {
        private readonly System.Action _undo;
        public Restore(System.Action undo) => _undo = undo;
        public void Dispose() => _undo();
    }

    private static (BattleGrid grid, AITurnExecutor executor) MakeArena()
    {
        Rng.Seed(1234);

        var grid = BattleGrid.CreateFlat(20, 12);
        var runner = new BattleRunner();
        runner.SetPresenter(_ => Task.CompletedTask);

        _ = new AIBattleSimulator(grid, runner);

        return (grid, new AITurnExecutor(runner, grid));
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
