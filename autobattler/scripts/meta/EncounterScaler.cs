using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public class EncounterScaler
{
    private readonly DataManager _dataManager;
    private readonly Random _rng;

    public EncounterScaler(DataManager dataManager, int? seed = null)
    {
        _dataManager = dataManager;
        _rng = seed.HasValue ? new Random(seed.Value) : new Random();
    }

    public List<(EnemyDefinition def, PF2eVec position)> GenerateEnemyTeam(int roundNumber, int playerUnitCount)
    {
        int enemyCount = Math.Max(1, playerUnitCount + GetCountAdjustment(roundNumber));
        var defs = PickEnemyComposition(roundNumber, enemyCount);

        var result = new List<(EnemyDefinition, PF2eVec)>();
        int startRow = GridVisual.GridHeight - 1;

        for (int i = 0; i < defs.Count; i++)
        {
            int x = 1 + (i * 2) % (GridVisual.GridWidth - 2);
            int y = startRow - (i / ((GridVisual.GridWidth - 2) / 2));
            y = Math.Clamp(y, GridVisual.GridHeight - 4, GridVisual.GridHeight - 1);
            result.Add((defs[i], new PF2eVec(x, y)));
        }

        return result;
    }

    private int GetCountAdjustment(int roundNumber)
    {
        if (roundNumber <= 3) return 0;
        if (roundNumber <= 6) return 0;
        if (roundNumber <= 10) return 1;
        return 1;
    }

    private List<EnemyDefinition> PickEnemyComposition(int roundNumber, int count)
    {
        var result = new List<EnemyDefinition>();
        int maxTier = GetMaxTier(roundNumber);
        bool isBossRound = roundNumber % 5 == 0 && roundNumber > 0;

        if (isBossRound)
        {
            int bossTier = Math.Min(maxTier + 1, 5);
            var bossCandidates = _dataManager.GetCreaturesForTier(bossTier);
            if (bossCandidates.Count > 0)
            {
                result.Add(bossCandidates[_rng.Next(bossCandidates.Count)]);
                count--;
            }
        }

        string themeTraitId = TryPickTheme(roundNumber);

        for (int i = 0; i < count; i++)
        {
            int tier = PickFillerTier(roundNumber, maxTier);
            var candidates = _dataManager.GetCreaturesForTier(tier);

            if (themeTraitId != null)
            {
                var themed = candidates.Where(c =>
                    c.CreatureTraits != null && c.CreatureTraits.HasTraitById(themeTraitId)).ToList();
                if (themed.Count > 0)
                    candidates = themed;
            }

            if (candidates.Count > 0)
                result.Add(candidates[_rng.Next(candidates.Count)]);
        }

        return result;
    }

    private int GetMaxTier(int roundNumber)
    {
        if (roundNumber <= 3) return 1;
        if (roundNumber <= 6) return 2;
        if (roundNumber <= 10) return 3;
        if (roundNumber <= 15) return 4;
        return 5;
    }

    private int PickFillerTier(int roundNumber, int maxTier)
    {
        int baseTier = Math.Max(1, maxTier - 1);
        int range = maxTier - baseTier + 1;
        return baseTier + _rng.Next(range);
    }

    private string TryPickTheme(int roundNumber)
    {
        if (_rng.NextDouble() < 0.4) return null;

        string[] themes = { "undead", "beast", "humanoid", "fiend", "dragon", "elemental", "construct" };
        return themes[_rng.Next(themes.Length)];
    }
}
