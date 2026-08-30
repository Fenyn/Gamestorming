using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Presets;
using Delve.Run;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using RunState = Delve.Run.RunState;

namespace Delve.Dev;

/// <summary>
/// Headless regression for the floor-and-Wardstone encounter model
/// (design/core_concept.md "Wardstone", "Bosses", "Run flow"). Asserts: compositions are
/// deterministic per seed and never null on every floor; a rolled tier is the floor's base
/// distribution plus the ward upshift (plus the Lair bonus); XP lands within the engine's
/// one-tier tolerance on floor 1, where the fixed level-2 party matches the band; every floor
/// roster and boss slug resolves from the packs; each authored boss hits its pinned budget; Elite
/// spawning never corrupts the cached definition; and the ward burns and refills on the doc's
/// triggers. XP-tolerance checks for floors 2-3 wait for the levelling feature - their rosters sit
/// above a level-2 party by design.
/// </summary>
public partial class RunEncounterSpike : SpikeBase
{
    private static readonly int[] SweepSeeds = { 11, 90210, 777 };
    private static readonly int[] WardLevels = { 100, 50, 20, 5 };

    protected override string Banner => "==================== RUN ENCOUNTER SPIKE ====================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        CheckTables(data);
        CheckDeterminism(data);
        CheckSweep(data);
        CheckElitePurity(data);
        CheckBossMath(data);
        CheckBossSetup(data);
        CheckWardBurnAndRefill();
        CheckLeveling(data);
        return Task.CompletedTask;
    }

    // ------------------------------------------------------------- Data tables

    private void CheckTables(DataManager data)
    {
        Check("the floor table and the boss table pair 1:1",
            FloorThemes.Count == 3 && BossEncounters.ForStratum(FloorThemes.Count - 1).Id == "depths-warden");

        for (int stratum = 0; stratum < FloorThemes.Count; stratum++)
        {
            var theme = FloorThemes.ForStratum(stratum);
            int unresolved = 0, unspawnable = 0;
            foreach (var @ref in theme.Roster)
            {
                var def = data.ResolveCreature(@ref);
                if (def == null) { unresolved++; continue; }
                if (!FloorThemes.IsSpawnable(def)) unspawnable++;
            }
            Check($"floor {stratum + 1} roster ({theme.Roster.Count} slugs) all resolve and can fight on a ground board",
                unresolved == 0 && unspawnable == 0);

            int bossUnresolved = 0;
            foreach (var line in BossEncounters.ForStratum(stratum).Spawns)
            {
                if (data.ResolveCreature(line.Creature) == null) bossUnresolved++;
            }
            Check($"floor {stratum + 1} boss spawns all resolve", bossUnresolved == 0);
        }
    }

    // ------------------------------------------------------------- Determinism

    private void CheckDeterminism(DataManager data)
    {
        var perSeed = new List<string>();
        bool identicalTwice = true;

        foreach (int seed in SweepSeeds)
        {
            string first = ComposeAll(data, seed, strata: 2);
            string second = ComposeAll(data, seed, strata: 2);
            if (first != second) identicalTwice = false;
            perSeed.Add(first);
        }

        bool seedsDiffer = false;
        for (int i = 1; i < perSeed.Count; i++)
        {
            if (perSeed[i] != perSeed[0]) seedsDiffer = true;
        }

        Check($"({SweepSeeds.Length} seeds) the same seed composes the identical encounters across floors", identicalTwice);
        Check("different seeds compose different encounters", seedsDiffer);

        // The same node id on the next floor must roll fresh.
        var state = NewState(SweepSeeds[0], maxWard: 100);
        string floor1 = SerializeMap(state.Map);
        state.AdvanceStratum();
        string floor2 = SerializeMap(state.Map);
        var twin = NewState(SweepSeeds[0], maxWard: 100);
        twin.AdvanceStratum();
        Check("descending regenerates a different map, deterministically",
            floor1 != floor2 && SerializeMap(twin.Map) == floor2);
    }

    /// <summary>Every fight node's composition for a seed over the first N floors. Fresh state per call.</summary>
    private static string ComposeAll(DataManager data, int seed, int strata)
    {
        var state = NewState(seed, maxWard: 100);
        var rules = new EncounterGenRules();
        var sb = new StringBuilder();
        for (int stratum = 0; stratum < strata; stratum++)
        {
            if (stratum > 0) state.AdvanceStratum();
            foreach (var node in state.Map.Nodes)
            {
                if (node.Kind != NodeKind.Combat && node.Kind != NodeKind.Elite) continue;
                var encounter = GeneratedEncounters.Generate(state, node, data.ResolveCreature, rules);
                sb.Append(stratum).Append('.').Append(node.Id).Append(':')
                  .Append(Serialize(encounter)).Append('|');
            }
        }
        return sb.ToString();
    }

    // ------------------------------------------------------------- Tier, budget, band

    private void CheckSweep(DataManager data)
    {
        var rules = new EncounterGenRules();
        int nulls = 0, badBase = 0, tolerance = 0, bandBreaks = 0, lethalShort = 0, notMonotonic = 0;
        int fights = 0;

        foreach (int seed in SweepSeeds)
        {
            foreach (int ward in WardLevels)
            {
                // Sweep floors 1-3 for composition; budget tolerance only on floor 1 (see class doc).
                for (int stratum = 0; stratum < FloorThemes.Count; stratum++)
                {
                    var state = NewState(seed, maxWard: ward);
                    for (int i = 0; i < stratum; i++) state.AdvanceStratum();

                    var theme = FloorThemes.ForStratum(stratum);
                    int size = state.Party.Members.Count;
                    int upshift = state.Wardstone.Upshift;

                    foreach (var node in state.Map.Nodes)
                    {
                        if (node.Kind != NodeKind.Combat && node.Kind != NodeKind.Elite) continue;
                        fights++;

                        var tier = GeneratedEncounters.RollTier(
                            state.StratumSeed, node, theme.Weights, upshift, rules);

                        // The un-shifted base must be a tier the floor's weights can deal.
                        int baseTier = (int)tier - upshift
                            - (node.Kind == NodeKind.Elite ? rules.LairTierBonus : 0);
                        if (baseTier <= (int)ThreatTier.Extreme && !BaseAllowed(theme.Weights, baseTier))
                            badBase++;

                        // More burned ward can never LOWER the tier of the same node.
                        var calm = GeneratedEncounters.RollTier(
                            state.StratumSeed, node, theme.Weights, upshift: 0, rules);
                        if ((int)tier < (int)calm) notMonotonic++;

                        var encounter = GeneratedEncounters.Generate(state, node, data.ResolveCreature, rules);
                        if (encounter == null) { nulls++; continue; }

                        int xp = EncounterXPCalculator.CalculateTotalXP(encounter, state.Party.Level);
                        if (stratum == 0)
                        {
                            if (tier == ThreatTier.Lethal)
                            {
                                if (xp < state.Wardstone.LethalBudget(size)
                                    && encounter.TotalEnemyCount < rules.MaxEnemies)
                                    lethalShort++;
                            }
                            else
                            {
                                var actual = EncounterXPCalculator.GetDifficulty(xp, size);
                                if (Math.Abs((int)actual - (int)tier) > 1) tolerance++;
                            }

                            var band = GeneratedEncounters.LevelBand(state.Party.Level, node.Floor, rules);
                            foreach (var spawn in encounter.EnemySpawns)
                            {
                                int level = spawn.Definition.StatBlock.CreatureLevel;
                                if (level < band.Min || level > band.Max) bandBreaks++;
                            }
                        }
                    }
                }
            }
        }

        GD.Print($"  sweep: {fights} fight nodes across {SweepSeeds.Length} seeds x {WardLevels.Length} ward levels x {FloorThemes.Count} floors.");
        Check("every fight node composes (never null)", nulls == 0);
        Check("every rolled tier decomposes to a base the floor's weights allow", badBase == 0);
        Check("burning ward never lowers a node's tier", notMonotonic == 0);
        Check("floor 1: generated XP lands within one tier of the rolled tier", tolerance == 0);
        Check("floor 1: every spawned creature sits inside the row's level band", bandBreaks == 0);
        Check("floor 1: a Lethal fight reaches its budget or the enemy cap", lethalShort == 0);
    }

    private static bool BaseAllowed(TierWeights weights, int baseTier) => baseTier switch
    {
        (int)ThreatTier.Low => weights.Low > 0,
        (int)ThreatTier.Moderate => weights.Moderate > 0,
        (int)ThreatTier.Severe => weights.Severe > 0,
        (int)ThreatTier.Extreme => weights.Extreme > 0,
        _ => false,
    };

    // ------------------------------------------------------------- Elite purity

    private void CheckElitePurity(DataManager data)
    {
        var wolfRef = new CreatureRef
        {
            DisplayName = "Wolf", Pack = "pathfinder-monster-core", Slug = "wolf",
        };
        var def = data.ResolveCreature(wolfRef);
        if (def == null)
        {
            Check("wolf resolves for the elite purity check", false);
            return;
        }

        int ac = def.StatBlock.AC;
        int maxHp = def.StatBlock.MaxHP;
        int attack = def.StatBlock.Strikes[0].AttackBonus;

        var elites = new List<PF2eCharacter>();
        for (int i = 0; i < 3; i++)
            elites.Add(CreatureFactory.Create(def, teamId: 2, CreatureAdjustment.Elite));

        Check("three Elite spawns leave the cached definition pristine",
            def.StatBlock.AC == ac && def.StatBlock.MaxHP == maxHp
            && def.StatBlock.Strikes[0].AttackBonus == attack);
        // Wolf is level 1: the Elite bracket adds 10 HP, cached into Health before Initialize.
        Check("an Elite's Health caches the adjusted MaxHP", elites[0].Health.MaxHP == maxHp + 10);

        var normal = CreatureFactory.Create(def, teamId: 2);
        Check("a Normal spawn after Elites matches the untouched definition",
            normal.CreatureStats.Data.AC == ac && normal.Health.MaxHP == maxHp);
    }

    // ------------------------------------------------------------- Bosses

    /// <summary>Every authored boss re-derived at its pinned yardstick: the design-time budget must
    /// hold, so a table edit that drifts fails here instead of shipping quietly.</summary>
    private void CheckBossMath(DataManager data)
    {
        for (int stratum = 0; stratum < FloorThemes.Count; stratum++)
        {
            var spec = BossEncounters.ForStratum(stratum);
            int xp = 0;
            foreach (var line in spec.Spawns)
            {
                var def = data.ResolveCreature(line.Creature);
                if (def == null) { xp = -1; break; }
                xp += line.Count * EncounterXPCalculator.GetCreatureXP(
                    def.StatBlock.CreatureLevel, spec.PinnedLevel, line.Adjustment);
            }
            var difficulty = EncounterXPCalculator.GetDifficulty(Math.Max(0, xp), spec.PinnedPartySize);
            Check($"boss '{spec.Id}' holds its authored budget ({xp} XP at 4@{spec.PinnedLevel}: {difficulty})",
                difficulty >= EncounterDifficulty.Moderate && difficulty <= EncounterDifficulty.Extreme);
        }
    }

    private void CheckBossSetup(DataManager data)
    {
        var state = NewState(seed: 90210, maxWard: 100);
        var bossNode = state.Map.Node(state.Map.BossId)!;

        var setup = EncounterFactory.Build(state, bossNode, data.ResolveCreature);
        if (setup == null)
        {
            Check("the floor 1 boss node builds a setup", false);
            return;
        }

        int alphas = 0, wolves = 0;
        foreach (var (enemy, _) in setup.Enemies)
        {
            if (enemy.Name == "Elite Dire Wolf") alphas++;
            else if (enemy.Name == "Wolf") wolves++;
        }
        Check("floor 1 boss at full ward is the authored lair: Elite Dire Wolf + 3 Wolves (ward ignored)",
            setup.Enemies.Count == 4 && alphas == 1 && wolves == 3);
    }

    // ------------------------------------------------------------- Ward burn and refill

    private void CheckWardBurnAndRefill()
    {
        var party = BuildParty();
        var clock = new DayClock(shortRestsPerDay: 3);
        var wardstone = new Wardstone();
        var rules = new RecoveryRules();
        int burn = wardstone.Rules.ShortRestBurn;

        ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules, wardstone: wardstone);
        Check($"a short rest burns {burn} ward", wardstone.Ward == wardstone.Rules.MaxWard - burn);

        ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules, wardstone: wardstone);
        ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules, wardstone: wardstone);
        int afterThree = wardstone.Ward;
        var refused = ShortRest.Perform(party, clock, ShortRestKind.Refocus, null, rules, wardstone: wardstone);
        Check("a refused block burns nothing", !refused.Performed && wardstone.Ward == afterThree);

        int refill = wardstone.Rules.CampsiteRefill;
        PartyRecovery.LongRest(party, clock, rules, wardstone);
        Check($"a Campsite night restores {refill} ward",
            wardstone.Ward == Math.Min(wardstone.Rules.MaxWard, afterThree + refill));

        PartyRecovery.LongRest(party, clock, rules, wardstone);
        PartyRecovery.LongRest(party, clock, rules, wardstone);
        Check("the Campsite refill never exceeds the maximum", wardstone.Ward <= wardstone.Rules.MaxWard);

        var spent = new Wardstone(new WardstoneRules { MaxWard = 100, ShortRestBurn = 95 });
        spent.BurnShortRest();
        Check("upshift reaches +3 when the ward is nearly gone", spent.Upshift == 3);
        spent.RefillFull();
        Check("beating a floor boss restores the ward in full",
            spent.Ward == spent.Rules.MaxWard && spent.Upshift == 0);
    }

    // ------------------------------------------------------------- Leveling

    private void CheckLeveling(DataManager data)
    {
        var state = NewState(seed: 42, maxWard: 100);
        int threshold = state.Leveling.XpPerLevel;
        int startLevel = state.Party.Level;

        // Damage one member so the level-up must preserve the wound through the HP recompute.
        var wounded = state.Party.Members[0];
        int missing = 5;
        wounded.Health!.SetCurrentHP(wounded.Health.MaxHP - missing);

        Check("XP below the threshold levels nobody",
            PartyLeveling.Award(state, threshold - 1) == 0 && state.Party.Level == startLevel);

        int hpBefore = wounded.Health.MaxHP;
        int gained = PartyLeveling.Award(state, 1); // tips the pool over the threshold
        bool allAtLevel = true;
        foreach (var member in state.Party.Members)
            allAtLevel &= member.Stats?.Level == startLevel + 1;
        Check("crossing the threshold levels the whole party in place",
            gained == 1 && state.Party.Level == startLevel + 1 && allAtLevel && state.Xp == 0);
        Check("the level-up raises max HP and preserves damage taken",
            wounded.Health.MaxHP > hpBefore
            && wounded.Health.CurrentHP == wounded.Health.MaxHP - missing);

        // A newcomer joins at the party's current level, not the build default.
        var late = NewState(seed: 43, maxWard: 100);
        // Fresh solo party so a slot is open.
        var solo = Party.Build(PresetCharacters.PlayerId, new List<string>(), new UnlockState(), Party.DefaultLevel);
        var soloState = RunState.Start(43, solo, new RunMapConfig());
        PartyLeveling.Award(soloState, soloState.Leveling.XpPerLevel * 3);
        solo.AddMember(PresetCharacters.ElaraId, new UnlockState());
        var newcomer = solo.Find(PresetCharacters.ElaraId);
        Check("a newcomer joins at the leveled party's level",
            newcomer?.Stats?.Level == solo.Level && solo.Level == Party.DefaultLevel + 3);

        // The cap: a huge award levels every class (both casters included) to MaxLevel in place
        // and never past it - this exercises the full combo scripts to L10.
        int capGained = PartyLeveling.Award(state, state.Leveling.XpPerLevel * 40);
        bool allCapped = true;
        foreach (var member in state.Party.Members)
            allCapped &= member.Stats?.Level == state.Leveling.MaxLevel;
        Check($"a huge award caps the party at level {state.Leveling.MaxLevel}",
            state.Party.Level == state.Leveling.MaxLevel && allCapped
            && state.Xp <= state.Leveling.XpPerLevel);

        // Fights carry their award: a generated fight node's setup pays real XP.
        var fightNode = FirstFightNode(late);
        var setup = fightNode == null ? null : EncounterFactory.Build(late, fightNode, data.ResolveCreature);
        Check("a built fight carries a positive XP award", setup != null && setup.XpAward > 0);
    }

    private static MapNode? FirstFightNode(RunState state)
    {
        foreach (var node in state.Map.Nodes)
        {
            if (node.Kind == NodeKind.Combat || node.Kind == NodeKind.Elite) return node;
        }
        return null;
    }

    // ------------------------------------------------------------- Helpers

    private static RunState NewState(int seed, int maxWard) =>
        RunState.Start(
            seed, BuildParty(), new RunMapConfig(),
            wardRules: new WardstoneRules { MaxWard = maxWard });

    private static Party BuildParty() => Party.Build(
        PresetCharacters.PlayerId,
        new List<string> { PresetCharacters.ElaraId, PresetCharacters.TharrId, PresetCharacters.FenwickId },
        new UnlockState(),
        Party.DefaultLevel);

    private static string Serialize(EncounterDefinition? encounter)
    {
        if (encounter == null) return "null";
        var sb = new StringBuilder();
        foreach (var spawn in encounter.EnemySpawns)
            sb.Append(spawn.Definition.CreatureId).Append('x').Append(spawn.Count)
              .Append('/').Append(spawn.Adjustment).Append(',');
        return sb.ToString();
    }

    private static string SerializeMap(RunMap map)
    {
        var sb = new StringBuilder();
        foreach (var node in map.Nodes)
            sb.Append(node.Floor).Append(',').Append(node.Lane).Append(',').Append((int)node.Kind).Append(';');
        return sb.ToString();
    }
}
