using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.Data;

namespace Autobattler;

public class ShopSystem
{
    public const int ShopSlots = 5;
    public const int RefreshCost = 2;

    private readonly DataManager _dataManager;
    private readonly Random _rng;

    public List<EnemyDefinition> CurrentOfferings { get; private set; } = new();

    public ShopSystem(DataManager dataManager, int? seed = null)
    {
        _dataManager = dataManager;
        _rng = seed.HasValue ? new Random(seed.Value) : new Random();
    }

    public void GenerateOfferings(int playerLevel, int roundNumber)
    {
        CurrentOfferings.Clear();

        var tierWeights = GetTierWeights(playerLevel, roundNumber);

        for (int i = 0; i < ShopSlots; i++)
        {
            int tier = RollTier(tierWeights);
            var candidates = _dataManager.GetCreaturesForTier(tier);

            if (candidates.Count == 0)
            {
                for (int fallback = tier - 1; fallback >= 1; fallback--)
                {
                    candidates = _dataManager.GetCreaturesForTier(fallback);
                    if (candidates.Count > 0) break;
                }
            }

            if (candidates.Count > 0)
                CurrentOfferings.Add(candidates[_rng.Next(candidates.Count)]);
        }
    }

    public OwnedUnit BuyUnit(int slotIndex, PlayerState player)
    {
        if (slotIndex < 0 || slotIndex >= CurrentOfferings.Count) return null;

        var def = CurrentOfferings[slotIndex];
        int tier = DataManager.GetTier(def.StatBlock.CreatureLevel);
        int cost = DataManager.GetCost(tier);

        if (!player.CanBuy(cost)) return null;
        if (!player.CanAddToBench()) return null;

        var unit = new OwnedUnit(def);
        player.BuyUnit(unit);
        CurrentOfferings[slotIndex] = null;

        GD.Print($"[Shop] Bought {def.CreatureName} (Tier {tier}) for {cost}g");
        return unit;
    }

    public bool Refresh(PlayerState player)
    {
        if (!player.CanBuy(RefreshCost)) return false;

        player.Gold -= RefreshCost;
        GenerateOfferings(player.Level, player.RoundNumber);
        GD.Print($"[Shop] Refreshed for {RefreshCost}g");
        return true;
    }

    private Dictionary<int, float> GetTierWeights(int playerLevel, int roundNumber)
    {
        var weights = new Dictionary<int, float>();

        if (roundNumber <= 3)
        {
            weights[1] = 0.85f;
            weights[2] = 0.15f;
        }
        else if (roundNumber <= 6)
        {
            weights[1] = 0.50f;
            weights[2] = 0.35f;
            weights[3] = 0.15f;
        }
        else if (roundNumber <= 10)
        {
            weights[1] = 0.20f;
            weights[2] = 0.35f;
            weights[3] = 0.30f;
            weights[4] = 0.15f;
        }
        else
        {
            weights[1] = 0.10f;
            weights[2] = 0.20f;
            weights[3] = 0.30f;
            weights[4] = 0.25f;
            weights[5] = 0.15f;
        }

        if (playerLevel >= 4 && !weights.ContainsKey(4))
            weights[4] = 0.05f;
        if (playerLevel >= 6 && !weights.ContainsKey(5))
            weights[5] = 0.05f;

        return weights;
    }

    private int RollTier(Dictionary<int, float> weights)
    {
        float roll = (float)_rng.NextDouble();
        float cumulative = 0;

        foreach (var kvp in weights.OrderBy(k => k.Key))
        {
            cumulative += kvp.Value;
            if (roll <= cumulative) return kvp.Key;
        }

        return weights.Keys.Max();
    }
}
