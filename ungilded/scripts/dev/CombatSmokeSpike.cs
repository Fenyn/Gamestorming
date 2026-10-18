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
/// full combat scene, drives the first hero turn through <see cref="PlayerActionExecutor"/> (Stride
/// into reach, Strike once), passes every later hero turn and waits for one enemy turn to finish.
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

    /// <summary>Polling interval while waiting on the encounter loop.</summary>
    [Export] public float PollSeconds { get; set; } = 0.1f;

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

        await WaitFor(() => scene.IsPlayerTurn || result != BattleResult.InProgress);
        Check("a hero turn arrived", scene.IsPlayerTurn);
        if (!scene.IsPlayerTurn) return;
        var actor = session.CurrentActor!;

        if (!Headless && shotPath.Length > 0)
        {
            await WaitSeconds(SettleSeconds);
            Check("the board capture saved", SaveViewportCapture(shotPath, ShotSize) == Error.Ok);
        }

        await PlayHeroTurn(session, actor);

        ICharacter? enemy = null;
        bool enemyTurnDone = false;
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

        scene.EndHostedEncounter();
    }

    /// <summary>Stride toward the nearest rat until one is in reach, then Strike it once.</summary>
    private async Task PlayHeroTurn(CombatSession session, ICharacter hero)
    {
        var exec = session.PlayerActions;
        int strides = 0;
        while (exec.GetStrikeTargets(hero).Count == 0 && hero.Actions!.TotalActionsRemaining > 1)
        {
            var dest = BestApproachTile(session, exec, hero);
            if (dest == null) break;
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
        Check("a rat is in reach for the Strike", targets.Count > 0);
        if (targets.Count == 0) { session.RequestEndPlayerTurn(); return; }

        var target = targets[0];
        int mapBefore = exec.GetCurrentMap(hero);
        int actionsLeft = hero.Actions!.TotalActionsRemaining;
        int hpBefore = target.Health.CurrentHP;
        Check("the Strike resolves", await exec.ExecuteStrike(hero, target));
        Check("the Strike spent one action", hero.Actions.TotalActionsRemaining == actionsLeft - 1);
        Check($"the next Strike takes the multiple attack penalty ({mapBefore} -> {exec.GetCurrentMap(hero)})",
            exec.GetCurrentMap(hero) < mapBefore);
        GD.Print($"[CombatSmoke] {hero.Name} struck {target.Name}: HP {hpBefore} -> {target.Health.CurrentHP}.");
        session.RequestEndPlayerTurn();
    }

    private static PF2eVec? BestApproachTile(CombatSession session, PlayerActionExecutor exec, ICharacter hero)
    {
        var enemies = new List<PF2eVec>();
        foreach (var e in session.Team2)
            if (e.Health?.IsAlive == true) enemies.Add(e.GridPosition);
        PF2eVec? best = null;
        int bestDist = int.MaxValue;
        foreach (var tile in exec.GetReachableTiles(hero))
        {
            int d = int.MaxValue;
            foreach (var e in enemies)
                d = Math.Min(d, Math.Max(Math.Abs(tile.x - e.x), Math.Abs(tile.y - e.y)));
            if (d < bestDist) { bestDist = d; best = tile; }
        }
        return best;
    }

    private async Task WaitFor(Func<bool> done)
    {
        for (float waited = 0; !done() && waited < TurnWaitSeconds; waited += PollSeconds)
            await WaitSeconds(PollSeconds);
    }
}
