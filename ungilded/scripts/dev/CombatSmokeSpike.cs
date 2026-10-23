using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Ungilded.Autoload;
using Ungilded.Combat;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// Smoke test for the copied combat layer. It starts the <see cref="HarnessEncounter"/> fight in the
/// full combat scene, drives the first hero through <see cref="PlayerActionExecutor"/> (Stride
/// into reach over up to <see cref="MaxApproachTurns"/> turns, Strike once), passes every other
/// hero turn and waits for one enemy turn to finish. Every kill must play one CreatureDied right
/// after the DamageDealt that caused it.
/// Headless it checks the rules path. Rendered, it also saves the board at the first hero turn to
/// <see cref="ShotPath"/>.
/// </summary>
public partial class CombatSmokeSpike : SpikeBase
{
    [Export] public PackedScene? CombatScene { get; set; }

    /// <summary>Use the generated biome map (rendered shot) instead of the flat board.</summary>
    [Export] public bool UseGeneratedMap { get; set; } = true;

    /// <summary>Biome id of the generated map. The UNGILDED_SMOKE_BIOME environment variable
    /// overrides it, and the capture then takes the biome as a file name suffix.</summary>
    [Export] public string Biome { get; set; } = HarnessEncounter.SewerBiome;

    [Export(PropertyHint.Range, "1,10,1")] public int StartLevel { get; set; } = 2;
    [Export] public int MapSeed { get; set; } = 20260804;
    [Export] public int CombatSeed { get; set; } = 1337;

    /// <summary>Where the rendered run saves its capture.</summary>
    [Export] public string ShotPath { get; set; } = "";

    /// <summary>Capture size; under the 1900 px review limit.</summary>
    [Export] public Vector2I ShotSize { get; set; } = new(1600, 900);

    /// <summary>Seconds to wait for the first hero turn, and then for one enemy turn.</summary>
    [Export] public float TurnWaitSeconds { get; set; } = 60f;

    /// <summary>Seconds the board settles before the capture.</summary>
    [Export] public float SettleSeconds { get; set; } = 2f;

    /// <summary>Hero turns the first hero gets to bring a rat into reach before the Strike check fails.</summary>
    [Export(PropertyHint.Range, "1,6,1")] public int MaxApproachTurns { get; set; } = 3;

    /// <summary>Polling interval while waiting on the encounter loop.</summary>
    [Export] public float PollSeconds { get; set; } = 0.1f;

    /// <summary>Rendered runs with UNGILDED_SMOKE_STRIKE_FRAMES set save a frame of the hero's Strike
    /// every <see cref="StrikeFrameSeconds"/>, from the order until the Strike resolves. The variable's
    /// value, when it is a number, replaces <see cref="StrikeFrameLimit"/>.</summary>
    [Export] public float StrikeFrameSeconds { get; set; } = 0.15f;
    [Export] public int StrikeFrameLimit { get; set; } = 48;
    [Export] public Vector2I StrikeFrameSize { get; set; } = new(960, 540);

    protected override string Banner => "==================== COMBAT SMOKE SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (!Headless) GetWindow().SetFlag(Window.Flags.NoFocus, true);
        if (CombatScene == null) { AbortFail("[CombatSmoke] CombatScene not assigned."); return; }

        string shotPath = ShotPath;
        string biomeOverride = OS.GetEnvironment("UNGILDED_SMOKE_BIOME");
        if (biomeOverride.Length > 0)
        {
            Biome = biomeOverride;
            shotPath = ShotPath.GetBaseDir().PathJoin($"{ShotPath.GetFile().GetBaseName()}_{Biome}.png");
        }

        CheckDamageRoll();

        var setup = HarnessEncounter.Build(data, StartLevel, UseGeneratedMap, Biome, MapSeed, CombatSeed);
        Check("the harness encounter builds", setup != null);
        if (setup == null) return;

        var scene = CombatScene.Instantiate<CombatScene>();
        AddChild(scene);
        scene.StartEncounter(setup);
        var session = scene.Session;
        Check("the encounter started a session", session != null);
        if (session == null) return;
        Check("two heroes and two rats are on the board", session.Team1.Count == 2 && session.Team2.Count == 2);
        foreach (var hero in session.Team1) session.SetAutoReactions(hero, true);

        BattleResult result = BattleResult.InProgress;
        session.EncounterFinished += r => result = r;
        var presented = new List<BattleEvent>();
        session.EventPresented += presented.Add;

        await WaitFor(() => scene.IsPlayerTurn || result != BattleResult.InProgress);
        Check("a hero turn arrived", scene.IsPlayerTurn);
        if (!scene.IsPlayerTurn) return;
        var actor = session.CurrentActor!;

        if (!Headless && shotPath.Length > 0)
        {
            await WaitSeconds(SettleSeconds);
            Check("the board capture saved", SaveViewportCapture(shotPath, ShotSize) == Error.Ok);
        }

        // A large map can keep the rats out of reach for a turn or two, so the hero closes in over
        // several turns while the rats come the other way.
        ICharacter? enemy = null;
        bool enemyTurnDone = false;
        bool struck = false;
        for (int turn = 1; turn <= MaxApproachTurns && result == BattleResult.InProgress; turn++)
        {
            if (turn > 1)
            {
                await WaitFor(() =>
                {
                    if (result != BattleResult.InProgress) return true;
                    var current = session.CurrentActor;
                    if (enemy == null && current != null && current.TeamId != actor.TeamId) enemy = current;
                    else if (enemy != null && !ReferenceEquals(current, enemy)) enemyTurnDone = true;
                    if (!scene.IsPlayerTurn) return false;
                    if (ReferenceEquals(current, actor)) return true;
                    session.RequestEndPlayerTurn();
                    return false;
                });
                if (!scene.IsPlayerTurn || !ReferenceEquals(session.CurrentActor, actor)) break;
            }
            struck = await PlayHeroTurn(session, actor);
            if (struck) break;
            session.RequestEndPlayerTurn();
        }
        Check($"a rat came in reach for the Strike within {MaxApproachTurns} hero turns", struck);

        await WaitFor(() =>
        {
            if (result != BattleResult.InProgress) return true;
            var current = session.CurrentActor;
            if (enemy == null && current != null && current.TeamId != actor.TeamId) enemy = current;
            else if (enemy != null && !ReferenceEquals(current, enemy)) enemyTurnDone = true;
            else if (current != null && current.TeamId == actor.TeamId && scene.IsPlayerTurn)
                session.RequestEndPlayerTurn();
            return enemyTurnDone;
        });
        Check($"an enemy turn ran to its end ({enemy?.Name ?? "none"})", enemyTurnDone);
        CheckKills(presented);

        scene.EndHostedEncounter();
    }

    /// <summary>Stride toward the nearest rat until one is in reach, then Strike it once. Returns
    /// false, with no Strike, when no rat is in reach by the last action.</summary>
    private async Task<bool> PlayHeroTurn(CombatSession session, ICharacter hero)
    {
        var exec = session.PlayerActions;
        int strides = 0;
        while (exec.GetStrikeTargets(hero).Count == 0 && hero.Actions!.TotalActionsRemaining > 1)
        {
            var distances = WalkDistancesToRats(session);
            var dest = BestApproachTile(exec, hero, distances);
            if (dest == null || Distance(distances, dest.Value) >= Distance(distances, hero.GridPosition)) break;
            var before = hero.GridPosition;
            int actionsBefore = hero.Actions.TotalActionsRemaining;
            bool ok = await exec.ExecuteStride(hero, dest.Value);
            Check($"{hero.Name} Strides to ({dest.Value.x},{dest.Value.y})", ok);
            if (!ok) break;
            Check("the Stride moved the hero and spent one action",
                hero.GridPosition != before && hero.Actions.TotalActionsRemaining == actionsBefore - 1);
            strides++;
        }
        GD.Print($"[CombatSmoke] {hero.Name} strode {strides} time(s).");

        var targets = exec.GetStrikeTargets(hero);
        if (targets.Count == 0) return false;

        var target = targets[0];
        int mapBefore = exec.GetCurrentMap(hero);
        int actionsLeft = hero.Actions!.TotalActionsRemaining;
        int hpBefore = target.Health.CurrentHP;
        var strike = exec.ExecuteStrike(hero, target);
        await CaptureStrikeFrames(strike);
        Check("the Strike resolves", await strike);
        Check("the Strike spent one action", hero.Actions.TotalActionsRemaining == actionsLeft - 1);
        Check($"the next Strike takes the multiple attack penalty ({mapBefore} -> {exec.GetCurrentMap(hero)})",
            exec.GetCurrentMap(hero) < mapBefore);
        GD.Print($"[CombatSmoke] {hero.Name} struck {target.Name}: HP {hpBefore} -> {target.Health.CurrentHP}.");
        session.RequestEndPlayerTurn();
        return true;
    }

    private static PF2eVec? BestApproachTile(PlayerActionExecutor exec, ICharacter hero, Dictionary<PF2eVec, int> distances)
    {
        PF2eVec? best = null;
        int bestDist = int.MaxValue;
        foreach (var tile in exec.GetReachableTiles(hero))
        {
            int d = Distance(distances, tile);
            if (d < bestDist) { bestDist = d; best = tile; }
        }
        return best;
    }

    private static int Distance(Dictionary<PF2eVec, int> distances, PF2eVec tile)
        => distances.TryGetValue(tile, out int d) ? d : int.MaxValue;

    /// <summary>Tiles walked from each tile to the nearest living rat, around walls and cliffs, so
    /// a wall between the hero and the rats cannot trap the approach.</summary>
    private static Dictionary<PF2eVec, int> WalkDistancesToRats(CombatSession session)
    {
        var grid = session.Grid;
        var distances = new Dictionary<PF2eVec, int>();
        var frontier = new Queue<PF2eVec>();
        foreach (var e in session.Team2)
        {
            if (e.Health?.IsAlive != true) continue;
            distances[e.GridPosition] = 0;
            frontier.Enqueue(e.GridPosition);
        }
        while (frontier.Count > 0)
        {
            var here = frontier.Dequeue();
            foreach (var next in grid.GetNeighbors(here))
            {
                if (distances.ContainsKey(next)) continue;
                var tile = grid.GetTile(next);
                if (tile == null || tile.IsBlocked || !grid.CanTraverseEdge(next, here)) continue;
                distances[next] = distances[here] + 1;
                frontier.Enqueue(next);
            }
        }
        return distances;
    }

    /// <summary>The damage row's parts add up to the damage dealt: a 1d6+1 hit for 5 on a target with
    /// weakness 3 deals 8, and the same hit against resistance 2 deals 3.</summary>
    private void CheckDamageRoll()
    {
        PF2e.Data.DamageResult Hit(int weakness, int resistance) => new()
        {
            Formula = new PF2e.Data.DiceFormula(1, 6, 1),
            DiceRolls = new List<int> { 4 },
            PreMitigationDamage = 5,
            WeaknessApplied = weakness,
            ResistanceApplied = resistance,
            TotalDamage = 5 + weakness - resistance,
            DamageType = PF2e.Data.DamageType.Acid,
        };
        var weak = Ungilded.UI.DamageRoll.From(Hit(3, 0));
        Check("a weakness hit's damage row shows Weakness +3 and totals 8",
            weak is { Weakness: 3, Resistance: 0, Total: 8, Flat: 1, Extras.Count: 0 });
        var resisted = Ungilded.UI.DamageRoll.From(Hit(0, 2));
        Check("a resisted hit's damage row shows Resist -2 and totals 3",
            resisted is { Weakness: 0, Resistance: 2, Total: 3, Extras.Count: 0 });
    }

    private double _processSeconds;

    public override void _Process(double delta) => _processSeconds += delta;

    /// <summary>Frames are spaced in process time, which drives every tween, so a slow capture
    /// does not stretch the gaps between them.</summary>
    private async Task CaptureStrikeFrames(Task strike)
    {
        string setting = OS.GetEnvironment("UNGILDED_SMOKE_STRIKE_FRAMES");
        if (Headless || setting.Length == 0 || ShotPath.Length == 0) return;
        int limit = int.TryParse(setting, out int count) && count > 0 ? count : StrikeFrameLimit;
        string stem = ShotPath.GetBaseDir().PathJoin($"{ShotPath.GetFile().GetBaseName()}_strike");
        double start = _processSeconds;
        for (int frame = 0; frame < limit && !strike.IsCompleted; frame++)
        {
            SaveViewportCapture($"{stem}_{frame:00}.png", StrikeFrameSize);
            GD.Print($"[CombatSmoke] strike frame {frame:00} at {_processSeconds - start:0.00} s");
            while (_processSeconds - start < (frame + 1) * StrikeFrameSeconds && !strike.IsCompleted)
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
    }

    private async Task WaitFor(Func<bool> done)
    {
        for (float waited = 0; !done() && waited < TurnWaitSeconds; waited += PollSeconds)
            await WaitSeconds(PollSeconds);
    }
}
