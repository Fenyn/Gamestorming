using System;
using System.Collections.Generic;
using Delve.Data;
using PF2e;
using PF2e.Data;
using PF2e.Utilities;

namespace Delve.Run;

/// <summary>
/// Rolls what a generated fight node contains: a base threat tier from the floor's
/// <see cref="TierWeights"/>, upshifted by the Wardstone as it burns down (and by the Lair bonus),
/// a creature level band from the depth, and a composition from the engine's
/// <see cref="EncounterGenerator"/> over the floor's roster. Godot-free; creature resolution comes
/// in through a delegate the same way <see cref="EncounterFactory"/> takes one.
///
/// Determinism: the tier roll uses its own <see cref="RunRng"/> stream, and the composition seeds
/// the engine's global <see cref="Rng"/> under a node-scoped tag - the same pattern CombatSession
/// uses for combat dice - so a seed replays identically and the later "fight" stream never shifts.
/// Both streams key on <see cref="RunState.StratumSeed"/>, so the same node id on a deeper floor
/// rolls fresh.
/// </summary>
public static class GeneratedEncounters
{
    /// <summary>
    /// Threat tier for a node: a weighted roll over the floor's base distribution, plus the ward
    /// upshift, plus <see cref="EncounterGenRules.LairTierBonus"/> on an Elite node, clamped at
    /// Lethal. Deterministic per (stratum seed, node).
    /// </summary>
    public static ThreatTier RollTier(
        int stratumSeed, MapNode node, TierWeights weights, int upshift, EncounterGenRules rules)
    {
        var rng = new Random(RunRng.StableSeed(stratumSeed, node.Id, "tier"));
        int tier = (int)RollBase(rng, weights);
        tier += upshift;
        if (node.Kind == NodeKind.Elite) tier += rules.LairTierBonus;
        return (ThreatTier)Math.Min(tier, (int)ThreatTier.Lethal);
    }

    /// <summary>The base tier a floor deals before any upshift: weighted over Low..Extreme.</summary>
    public static ThreatTier RollBase(Random rng, TierWeights weights)
    {
        int total = weights.Low + weights.Moderate + weights.Severe + weights.Extreme;
        if (total <= 0) return ThreatTier.Moderate;

        int roll = rng.Next(total);
        if (roll < weights.Low) return ThreatTier.Low;
        roll -= weights.Low;
        if (roll < weights.Moderate) return ThreatTier.Moderate;
        roll -= weights.Moderate;
        if (roll < weights.Severe) return ThreatTier.Severe;
        return ThreatTier.Extreme;
    }

    /// <summary>Creature levels allowed on a map row: party level plus
    /// [<see cref="EncounterGenRules.MinOffset"/> .. the depth-ramped max offset].</summary>
    public static (int Min, int Max) LevelBand(int partyLevel, int floor, EncounterGenRules rules)
    {
        int maxOffset = Math.Min(
            rules.MaxOffsetCap,
            rules.EntranceMaxOffset + floor / Math.Max(1, rules.FloorsPerOffsetStep));
        return (partyLevel + rules.MinOffset, partyLevel + maxOffset);
    }

    /// <summary>
    /// Build the composition for a generated fight node, or null only when the floor roster
    /// resolves to nothing at all. Budgets use every party member, dead or alive - carrying a body
    /// does not soften the delve.
    /// </summary>
    public static EncounterDefinition? Generate(
        RunState state,
        MapNode node,
        Func<CreatureRef, EnemyDefinition?> resolve,
        EncounterGenRules rules)
    {
        var theme = FloorThemes.ForStratum(state.Stratum);
        int partyLevel = state.Party.Level;
        int partySize = state.Party.Members.Count;
        var (minLevel, maxLevel) = LevelBand(partyLevel, node.Floor, rules);

        var roster = new List<EnemyDefinition>();
        foreach (var @ref in theme.Roster)
        {
            var def = resolve(@ref);
            if (def == null || !FloorThemes.IsSpawnable(def)) continue;
            roster.Add(def);
        }
        if (roster.Count == 0) return null;

        var pool = roster.FindAll(def =>
        {
            int level = def.StatBlock.CreatureLevel;
            return level >= minLevel && level <= maxLevel;
        });
        // A party below the floor's roster (no levelling yet, or a deliberate rush) still fights:
        // the pool falls back to the roster's nearest levels, and the fight is as unfair as
        // walking that floor at that level deserves.
        if (pool.Count == 0) pool = NearestByLevel(roster, minLevel, maxLevel);

        var tier = RollTier(state.StratumSeed, node, theme.Weights, state.Wardstone.Upshift, rules);
        Rng.Seed(RunRng.StableSeed(state.StratumSeed, node.Id, "encgen"));

        // Lethal sits above the book ladder: generate an Extreme fight, then pile on.
        var bookTier = tier == ThreatTier.Lethal ? EncounterDifficulty.Extreme : (EncounterDifficulty)tier;
        var encounter = EncounterGenerator.GenerateEncounter(
            bookTier, partyLevel, partySize, pool.ToArray(), state.RecentTemplates)
            ?? BuildFromPool(bookTier, partyLevel, partySize, pool, rules.MaxEnemies);

        if (tier == ThreatTier.Lethal)
            TopUpToLethal(encounter, pool, partyLevel, state.Wardstone.LethalBudget(partySize), rules.MaxEnemies);

        state.RecentTemplates.Add(encounter.EncounterName);
        while (state.RecentTemplates.Count > rules.RecentTemplateMemory)
            state.RecentTemplates.RemoveAt(0);

        return encounter;
    }

    /// <summary>The roster entries closest to the band, for a party outside the floor's level
    /// range: everything within one level of the least-distant creature.</summary>
    private static List<EnemyDefinition> NearestByLevel(
        List<EnemyDefinition> roster, int minLevel, int maxLevel)
    {
        int Distance(EnemyDefinition def)
        {
            int level = def.StatBlock.CreatureLevel;
            return level < minLevel ? minLevel - level : level > maxLevel ? level - maxLevel : 0;
        }

        int best = int.MaxValue;
        foreach (var def in roster) best = Math.Min(best, Distance(def));
        return roster.FindAll(def => Distance(def) <= best + 1);
    }

    /// <summary>
    /// The guaranteed-fight fallback for when the template generator returns null (it discards
    /// compositions that miss their tier): greedy random fill from the pool toward the tier budget.
    /// Never returns null on a non-empty pool.
    /// </summary>
    private static EncounterDefinition BuildFromPool(
        EncounterDifficulty tier, int partyLevel, int partySize,
        List<EnemyDefinition> pool, int maxEnemies)
    {
        int budget = EncounterXPCalculator.GetDifficultyBudget(tier, partySize);
        var counts = new Dictionary<EnemyDefinition, int>();
        int totalXp = 0;
        int totalCount = 0;

        while (totalCount < maxEnemies)
        {
            // Random pick among the creatures that still fit the remaining budget; the first
            // creature always fits (a fight of one off-budget creature beats no fight at all).
            var fitting = new List<EnemyDefinition>();
            foreach (var def in pool)
            {
                int xp = EncounterXPCalculator.GetCreatureXP(def.StatBlock.CreatureLevel, partyLevel);
                if (totalCount == 0 || totalXp + xp <= budget) fitting.Add(def);
            }
            if (fitting.Count == 0) break;

            var pick = fitting[Rng.Next(0, fitting.Count)];
            counts.TryGetValue(pick, out int have);
            counts[pick] = have + 1;
            totalXp += EncounterXPCalculator.GetCreatureXP(pick.StatBlock.CreatureLevel, partyLevel);
            totalCount++;
            if (totalXp >= budget) break;
        }

        return FromCounts(counts, $"{tier} Delve Pack", "delve_pool");
    }

    /// <summary>Add pool creatures (highest XP that fits first) until the Lethal budget or the
    /// enemy cap is reached.</summary>
    private static void TopUpToLethal(
        EncounterDefinition encounter, List<EnemyDefinition> pool,
        int partyLevel, int lethalBudget, int maxEnemies)
    {
        int totalXp = EncounterXPCalculator.CalculateTotalXP(encounter, partyLevel);
        var spawns = new List<EnemySpawn>(encounter.EnemySpawns ?? Array.Empty<EnemySpawn>());
        int count = encounter.TotalEnemyCount;

        // Highest-XP creatures first, so the top-up adds menace, not chaff.
        pool.Sort((a, b) =>
            EncounterXPCalculator.GetCreatureXP(b.StatBlock.CreatureLevel, partyLevel)
            - EncounterXPCalculator.GetCreatureXP(a.StatBlock.CreatureLevel, partyLevel));

        while (totalXp < lethalBudget && count < maxEnemies)
        {
            var pick = pool[0];
            AddOne(spawns, pick);
            totalXp += EncounterXPCalculator.GetCreatureXP(pick.StatBlock.CreatureLevel, partyLevel);
            count++;
        }

        encounter.EnemySpawns = spawns.ToArray();
        encounter.EncounterName = $"Lethal {encounter.EncounterName}";
    }

    private static void AddOne(List<EnemySpawn> spawns, EnemyDefinition def)
    {
        for (int i = 0; i < spawns.Count; i++)
        {
            if (ReferenceEquals(spawns[i].Definition, def)
                && spawns[i].Adjustment == CreatureAdjustment.Normal)
            {
                var spawn = spawns[i];
                spawn.Count++;
                spawns[i] = spawn;
                return;
            }
        }
        spawns.Add(new EnemySpawn { Definition = def, Count = 1, SpawnZone = SpawnZone.Front });
    }

    private static EncounterDefinition FromCounts(
        Dictionary<EnemyDefinition, int> counts, string name, string id)
    {
        var spawns = new List<EnemySpawn>(counts.Count);
        foreach (var (def, count) in counts)
            spawns.Add(new EnemySpawn { Definition = def, Count = count, SpawnZone = SpawnZone.Random });
        return new EncounterDefinition
        {
            EncounterId = id,
            EncounterName = name,
            EnemySpawns = spawns.ToArray(),
        };
    }
}
