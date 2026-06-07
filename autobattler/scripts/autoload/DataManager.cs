using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e;
using PF2e.Core;
using PF2e.Data;
using PF2e.Import;

namespace Autobattler;

public partial class DataManager : Node
{
    [Signal]
    public delegate void CombatLogReceivedEventHandler(string message, int severity);

    [Signal]
    public delegate void DataLoadedEventHandler(int creatureCount);

    public const string Pf2eDataPath = "F:/dev/Pf2e.Core/Data/pf2e-source/packs/pf2e";

    public Dictionary<int, List<EnemyDefinition>> CreaturesByTier { get; private set; } = new();
    public List<EnemyDefinition> AllCreatures { get; private set; } = new();
    public bool IsLoaded { get; private set; }

    public override void _Ready()
    {
        WireLogging();
        WireCombatLog();
        LoadGameData();
        BuildCreatureCatalog();

        IsLoaded = true;
        GD.Print($"[DataManager] Ready — {AllCreatures.Count} creatures across {CreaturesByTier.Count} tiers");
        EmitSignal(SignalName.DataLoaded, AllCreatures.Count);
    }

    private void WireLogging()
    {
        Log.OnInfo = msg => GD.Print($"[PF2e] {msg}");
        Log.OnWarn = msg => GD.PushWarning($"[PF2e WARN] {msg}");
        Log.OnError = msg => GD.PushError($"[PF2e ERROR] {msg}");
    }

    private void WireCombatLog()
    {
        CombatLog.OnLogEntry += entry =>
        {
            EmitSignal(SignalName.CombatLogReceived, entry.Message, (int)entry.Severity);
        };
    }

    private void LoadGameData()
    {
        GD.Print($"[DataManager] Loading PF2e data from: {Pf2eDataPath}");
        GameDataLoader.LoadAll(Pf2eDataPath);
        GD.Print($"[DataManager] Loaded {GameDataLoader.Spells.Count} spells, {GameDataLoader.Equipment.Count} equipment");
    }

    private void BuildCreatureCatalog()
    {
        string monsterCorePath = Pf2eDataPath + "/pathfinder-monster-core";
        string bestiaryPath = Pf2eDataPath + "/pathfinder-bestiary";

        var rawCreatures = new List<EnemyDefinition>();
        rawCreatures.AddRange(CreatureImporter.ImportAll(monsterCorePath));
        rawCreatures.AddRange(CreatureImporter.ImportAll(bestiaryPath));
        GD.Print($"[DataManager] Imported {rawCreatures.Count} raw creature definitions");

        AllCreatures = rawCreatures
            .Where(def => def.StatBlock.Strikes != null && def.StatBlock.Strikes.Length > 0)
            .Where(def => def.StatBlock.CreatureLevel <= 12)
            .ToList();

        CreaturesByTier = new Dictionary<int, List<EnemyDefinition>>();
        foreach (var def in AllCreatures)
        {
            int tier = GetTier(def.StatBlock.CreatureLevel);
            if (!CreaturesByTier.ContainsKey(tier))
                CreaturesByTier[tier] = new List<EnemyDefinition>();
            CreaturesByTier[tier].Add(def);
        }

        foreach (var kvp in CreaturesByTier.OrderBy(k => k.Key))
            GD.Print($"[DataManager] Tier {kvp.Key}: {kvp.Value.Count} creatures");
    }

    public static int GetTier(int creatureLevel)
    {
        if (creatureLevel <= 1) return 1;
        if (creatureLevel <= 3) return 2;
        if (creatureLevel <= 5) return 3;
        if (creatureLevel <= 8) return 4;
        return 5;
    }

    public static int GetCost(int tier) => tier;

    public static int GetSellPrice(int tier) => tier > 1 ? tier - 1 : 1;

    public List<EnemyDefinition> GetCreaturesForTier(int tier)
    {
        return CreaturesByTier.TryGetValue(tier, out var list) ? list : new List<EnemyDefinition>();
    }
}
