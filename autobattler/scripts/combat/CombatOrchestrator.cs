using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using PF2e;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public class CombatOrchestrator
{
    public const int GridWidth = 8;
    public const int GridHeight = 8;

    public BattleResult LastResult { get; private set; }
    public List<ICharacter> Team1 { get; private set; } = new();
    public List<ICharacter> Team2 { get; private set; } = new();
    public BattleGrid Grid { get; private set; }
    public AIBattleSimulator Simulator { get; private set; }
    public BattleRunner Runner { get; private set; }

    public void SetupEncounter(
        List<(EnemyDefinition def, PF2eVec position)> playerUnits,
        List<(EnemyDefinition def, PF2eVec position)> enemyUnits,
        int? seed = null)
    {
        if (seed.HasValue)
            Rng.Seed(seed.Value);

        Grid = BattleGrid.CreateFlat(GridWidth, GridHeight);
        Runner = new BattleRunner();
        Simulator = new AIBattleSimulator(Grid, Runner);

        Team1 = new List<ICharacter>();
        Team2 = new List<ICharacter>();

        foreach (var (def, pos) in playerUnits)
        {
            var character = CreatureFactory.Create(def, teamId: 1);
            Simulator.PlaceCreature(character, pos);
            Team1.Add(character);
        }

        foreach (var (def, pos) in enemyUnits)
        {
            var character = CreatureFactory.Create(def, teamId: 2);
            Simulator.PlaceCreature(character, pos);
            Team2.Add(character);
        }

        GD.Print($"[Combat] Setup complete: {Team1.Count} vs {Team2.Count}");
    }

    public async Task<BattleResult> RunEncounterWithPresenter(System.Func<BattleEvent, Task> presenter)
    {
        if (presenter != null)
            Runner.SetPresenter(presenter);

        GD.Print($"[Combat] Starting encounter");
        LastResult = await Simulator.RunEncounter(Team1, Team2);
        GD.Print($"[Combat] Result: {LastResult}");
        return LastResult;
    }

    public async Task<BattleResult> RunCombat(
        List<(EnemyDefinition def, PF2eVec position)> playerUnits,
        List<(EnemyDefinition def, PF2eVec position)> enemyUnits,
        System.Func<BattleEvent, Task> presenter = null,
        int? seed = null)
    {
        SetupEncounter(playerUnits, enemyUnits, seed);
        return await RunEncounterWithPresenter(presenter);
    }

    public int CountSurvivingEnemies()
    {
        int count = 0;
        foreach (var c in Team2)
        {
            if (c.Health != null && c.Health.IsAlive)
                count++;
        }
        return count;
    }

    public int CountSurvivingAllies()
    {
        int count = 0;
        foreach (var c in Team1)
        {
            if (c.Health != null && c.Health.IsAlive)
                count++;
        }
        return count;
    }
}
