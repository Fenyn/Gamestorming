using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// M0 engine spike. Headless dev scene that proves the two Pf2e.Core PC integration paths:
///   1. Authoring a PC in code from a ClassDefinition (the Veteran).
///   2. Subclass overlay (Sentinel) + Free-Archetype dedication feat (Bastion) via level-up.
/// Then runs a seeded AI-vs-AI encounter and prints the trace, before quitting.
/// </summary>
public partial class SpikeEncounter : Node
{
    private const int ExpectedLevel1StrikeBonus = 9; // level 1 (+1) + expert (+4) + Str +4

    public override void _Ready()
    {
        _ = RunSpikeAsync();
    }

    private async Task RunSpikeAsync()
    {
        GD.Print("==================== BULWARK M0 SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[Spike] DataManager not loaded — aborting.");
            GetTree().Quit(1);
            return;
        }

        GD.Print(
            $"[Spike] Packs: {data.ConditionCount} conditions, {data.SpellCount} spells, "
            + $"{data.EquipmentCount} equipment, {data.CreatureCount} creatures");

        // --- Math cross-check: level-1 longsword strike bonus should be +9 ---
        var veteranL1 = PresetCharacters.BuildVeteran(level: 1);
        int actualL1 = StrikeBonus(veteranL1);
        bool pass = actualL1 == ExpectedLevel1StrikeBonus;
        GD.Print(
            $"[Spike] Strike-bonus check (level 1 longsword): expected +{ExpectedLevel1StrikeBonus}, "
            + $"actual +{actualL1} → {(pass ? "PASS" : "FAIL")}");

        // --- Build the level-2 Veteran (so the Bastion free-archetype feat applies) ---
        var veteran = PresetCharacters.BuildVeteran(level: 2);
        PrintStatblock(veteran);

        // --- Assemble the encounter ---

        // ReactionEvents.DeliverDamage throws if no OnDamageReactionCheck subscriber is present.
        // This is a pass-through stand-in until M1 adds a real reaction-prompt system (Shield
        // Block, etc.) — it just applies damage unconditionally.
        ReactionEvents.OnDamageReactionCheck += (src, tgt, result, applyDamage) => applyDamage();

        var grid = BattleGrid.CreateFlat(8, 8);
        var runner = new BattleRunner();
        runner.SetPresenter(evt =>
        {
            if (!string.IsNullOrEmpty(evt.Description))
                GD.Print($"  [event] {evt.Description}");
            return Task.CompletedTask;
        });
        var simulator = new AIBattleSimulator(grid, runner);

        int lastRound = 0;
        simulator.TurnManager.OnRoundStart += r => lastRound = r;
        CombatLog.OnLogEntry += OnCombatLog;

        Rng.Seed(42);

        var team1 = new List<ICharacter> { veteran };
        simulator.PlaceCreature(veteran, new PF2eVec(1, 4));

        var team2 = new List<ICharacter>();
        var goblinDef = data.FindCreature("Goblin Warrior")
            ?? data.LoadCreatureFile("pathfinder-monster-core", "goblin-warrior");
        var goblinPositions = new[] { new PF2eVec(6, 3), new PF2eVec(6, 5) };
        for (int i = 0; i < goblinPositions.Length; i++)
        {
            var goblin = CreatureFactory.Create(goblinDef, teamId: 2);
            simulator.PlaceCreature(goblin, goblinPositions[i]);
            team2.Add(goblin);
        }

        GD.Print($"[Spike] Encounter: {veteran.Name} (team 1) vs {team2.Count} Goblin Warriors (team 2), seed 42");
        GD.Print("---------------------- COMBAT ----------------------");

        BattleResult result = await simulator.RunEncounter(team1, team2);

        CombatLog.OnLogEntry -= OnCombatLog;

        GD.Print("---------------------- RESULT ----------------------");
        GD.Print($"[Spike] Winner: {result} | Rounds: {lastRound}");
        GD.Print($"[Spike] Veteran HP: {veteran.Health.CurrentHP}/{veteran.Health.MaxHP} (alive: {veteran.Health.IsAlive})");
        int goblinsAlive = team2.FindAll(g => g.Health.IsAlive).Count;
        GD.Print($"[Spike] Goblins alive: {goblinsAlive}/{team2.Count}");
        GD.Print("==================== SPIKE COMPLETE ====================");

        GetTree().Quit();
    }

    private static void OnCombatLog(CombatLogEntry entry)
    {
        string prefix = entry.IsDetail ? "    - " : "  [log] ";
        GD.Print($"{prefix}{entry.Message}  ({entry.Severity})");
    }

    private static int StrikeBonus(ICharacter character)
    {
        var weapon = WeaponAttackCalculator.ResolveWeapon(character);
        return WeaponAttackCalculator.CalculateAttackBonus(character, weapon);
    }

    private static void PrintStatblock(PF2eCharacter c)
    {
        var stats = c.Stats;
        var cls = stats.CharacterClass;
        int level = stats.Level;

        int ac = StatsCalculator.CalculateAC(c);
        int fort = StatsCalculator.CalculateSave(c, SavingThrow.Fortitude);
        int reflex = StatsCalculator.CalculateSave(c, SavingThrow.Reflex);
        int will = StatsCalculator.CalculateSave(c, SavingThrow.Will);
        int strike = StrikeBonus(c);
        var heavyArmorProf = cls.GetArmorProficiency(ArmorCategory.Heavy, level);

        GD.Print("-------------------- STATBLOCK --------------------");
        GD.Print($"  Name        : {c.Name}");
        GD.Print($"  Class       : Fighter / {cls.ClassName}   (subclass overlay resolved)");
        GD.Print($"  Level       : {level}");
        GD.Print($"  HP          : {c.Health.MaxHP}");
        GD.Print($"  AC          : {ac}");
        GD.Print($"  Saves       : Fort +{fort}, Ref +{reflex}, Will +{will}");
        GD.Print($"  Longsword   : +{strike} to hit");
        GD.Print($"  Heavy armor : {heavyArmorProf}  (Sentinel override: Trained → Expert)");
        GD.Print("  Granted features:");
        foreach (var feature in c.Features.ActiveFeatures)
        {
            string label = string.IsNullOrEmpty(feature.DisplayName)
                ? feature.GetType().Name
                : feature.DisplayName;
            GD.Print($"    - {label}");
        }
        GD.Print("---------------------------------------------------");
    }
}
