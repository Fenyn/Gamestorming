using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Territory;
using Godot;

using Bulwark.Save;
namespace Bulwark.Dev;

/// <summary>
/// Headless verification spike for the forage spawn system (design/forage.md) and the RespawnDays
/// generalization. Pure-C# — drives ForageSystem/TerritorySystem directly with a fake cell
/// provider, no world scene. Proves: daily pass under the live cap, weighted table membership,
/// valid-cell spacing rules, the 7th-day sweep (before the pass), harvest pruning, save/load
/// round-trip, catch-up determinism across two independent runs, the 3-day tree /
/// one-shot / daily node respawn windows, and the debris second pass (initial 8–12 sprinkle,
/// cap 12 / 2–4 attempts, no weekly sweep, permanent clears, relaxed 1-cell trail clearance).
///   G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe --headless \
///     --path bulwark res://scenes/dev/forage_spike.tscn
/// </summary>
public partial class ForageSpike : SpikeBase
{
    private const string ForestId = "verdant_fringe";
    private const int Seed = 987654;

    /// <summary>Deterministic fake territory: a 40x30 field with a blocked stripe, a few reserved
    /// cells and two trail anchors on the stripe — the same shape every run, like a painted .tscn.</summary>
    private sealed class FakeCells : IForageCellProvider
    {
        public (int X0, int Y0, int X1, int Y1) PlayableRect => (1, 1, 40, 30);

        public bool IsOpenGround(int x, int y) => y != 12; // one blocked stripe (a "trail")

        public IReadOnlyCollection<(int X, int Y)> ReservedCells { get; } = new List<(int, int)>
        {
            (5, 5), (20, 8), (33, 22), (10, 25),
        };

        public IReadOnlyCollection<(int X, int Y)> TrailCells { get; } = new List<(int, int)>
        {
            (15, 12), (28, 12),
        };
    }

    /// <summary>A cramped trail-side strip: only the two rows hugging the trail are open ground, so
    /// every candidate cell sits exactly 1 cell (Chebyshev) from a trail cell. Forage (2-cell
    /// clearance) can never spawn here; debris (1-cell clearance) can.</summary>
    private sealed class TrailHuggingCells : IForageCellProvider
    {
        public (int X0, int Y0, int X1, int Y1) PlayableRect => (1, 11, 40, 13);

        public bool IsOpenGround(int x, int y) => y == 11 || y == 13; // y=12 is the trail itself

        public IReadOnlyCollection<(int X, int Y)> ReservedCells { get; } = new List<(int, int)>();

        public IReadOnlyCollection<(int X, int Y)> TrailCells { get; }

        public TrailHuggingCells()
        {
            var trail = new List<(int, int)>();
            for (int x = 1; x <= 40; x++)
                trail.Add((x, 12));
            TrailCells = trail;
        }
    }

    public override void _Ready()
    {
        try
        {
            TestDailyPassAndCap();
            TestSweep();
            TestPersistenceAndDeterminism();
            TestRespawnDays();
            TestDebris();
            TestDebrisTrailClearance();
        }
        catch (Exception e)
        {
            GD.PushError($"[ForageSpike] EXCEPTION: {e}");
            Fail();
        }
        FinishAndQuit("forage");
    }

    // ------------------------------------------------------ (1) daily pass, cap, valid cells

    private void TestDailyPassAndCap()
    {
        GD.Print("-------------------- (1) Daily pass / cap / valid cells --------------------");
        var cells = new FakeCells();
        var forage = new ForageSystem();
        forage.SetWorldSeed(Seed);

        int events = 0;
        forage.ForageChanged += id => { if (id == ForestId) events++; };

        forage.CatchUp(ForestId, 1, cells);
        var day1 = forage.GetLive(ForestId);
        Check($"(1) day 1 pass spawned within 1-4 attempts ({day1.Count})",
            day1.Count >= 0 && day1.Count <= ForageSystem.MaxAttemptsPerDay);
        Check("(1) ForageChanged raised once for the catch-up", events == 1);
        Check("(1) re-sync same day is a no-op (no event, no growth)",
            RunAndCount(() => forage.CatchUp(ForestId, 1, cells), ref events) == 0
            && forage.GetLive(ForestId).Count == day1.Count);

        // run to day 6 (no sweep yet) — cap must hold
        for (int day = 2; day <= 6; day++)
            forage.CatchUp(ForestId, day, cells);
        var day6 = forage.GetLive(ForestId);
        Check($"(1) live count through day 6 respects the cap ({day6.Count} <= {ForageSystem.LiveCap})",
            day6.Count <= ForageSystem.LiveCap);
        Check("(1) something spawned by day 6", day6.Count > 0);

        var tableIds = Territories.Forest.ForageTable.Select(e => e.NodeId).ToHashSet();
        Check("(1) every spawn is from the forest forage table",
            day6.All(s => tableIds.Contains(s.ResourceId)));
        Check("(1) every spawn resource id is a defined node",
            day6.All(s => ResourceNodes.IsDefined(s.ResourceId)));

        // valid-cell rules
        bool inRect = true, openGround = true, spacing = true;
        var all = day6.ToList();
        foreach (var s in all)
        {
            var (x0, y0, x1, y1) = cells.PlayableRect;
            inRect &= s.CellX >= x0 && s.CellX <= x1 && s.CellY >= y0 && s.CellY <= y1;
            openGround &= cells.IsOpenGround(s.CellX, s.CellY);
            foreach (var (rx, ry) in cells.ReservedCells)
                spacing &= Math.Max(Math.Abs(rx - s.CellX), Math.Abs(ry - s.CellY)) >= ForageSystem.MinSpacingCells;
        }
        for (int i = 0; i < all.Count; i++)
            for (int j = i + 1; j < all.Count; j++)
                spacing &= Math.Max(Math.Abs(all[i].CellX - all[j].CellX),
                    Math.Abs(all[i].CellY - all[j].CellY)) >= ForageSystem.MinSpacingCells;
        Check("(1) all spawns inside the playable rect", inRect);
        Check("(1) all spawns on open ground", openGround);
        Check("(1) >=2-cell spacing from reserved cells and each other", spacing);

        // harvest prune: mark one collected → gone from live now, entry pruned on the next pass
        string harvestedId = day6[0].NodeId;
        Check("(1) MarkHarvested accepts a live spawn", forage.MarkHarvested(ForestId, harvestedId));
        Check("(1) harvested spawn left the live set",
            forage.GetLive(ForestId).All(s => s.NodeId != harvestedId));
        Check("(1) harvested spawn still resolves today (occupies its cell)",
            forage.IsForageNode(ForestId, harvestedId) && forage.IsHarvested(ForestId, harvestedId));
    }

    private static int RunAndCount(Action action, ref int counter)
    {
        int before = counter;
        action();
        return counter - before;
    }

    // ------------------------------------------------------ (2) 7th-day sweep

    private void TestSweep()
    {
        GD.Print("-------------------- (2) 7th-day sweep --------------------");
        var cells = new FakeCells();
        var forage = new ForageSystem();
        forage.SetWorldSeed(Seed);

        for (int day = 1; day <= 6; day++)
            forage.CatchUp(ForestId, day, cells);
        int before = forage.GetLive(ForestId).Count;
        Check($"(2) pre-sweep buildup exists by day 6 ({before})", before > 0);

        forage.CatchUp(ForestId, 7, cells);
        var day7 = forage.GetLive(ForestId);
        Check("(2) day 7 sweep cleared everything older than day 7",
            day7.All(s => s.SpawnDay == 7));
        Check($"(2) the sweep ran BEFORE day 7's own pass (fresh spawns allowed: {day7.Count})",
            day7.Count <= ForageSystem.MaxAttemptsPerDay);
    }

    // ------------------------------------------------------ (3) persistence + determinism

    private void TestPersistenceAndDeterminism()
    {
        GD.Print("-------------------- (3) Persistence & determinism --------------------");
        var cells = new FakeCells();

        // Run A: straight through day 10.
        var a = new ForageSystem();
        a.SetWorldSeed(Seed);
        for (int day = 1; day <= 10; day++)
            a.CatchUp(ForestId, day, cells);

        // Run B: same seed, save at day 5, restore into a fresh system, continue to day 10.
        var b1 = new ForageSystem();
        b1.SetWorldSeed(Seed);
        for (int day = 1; day <= 5; day++)
            b1.CatchUp(ForestId, day, cells);
        var dto = b1.Capture();

        var b2 = new ForageSystem();
        b2.SetWorldSeed(Seed);
        b2.Restore(dto);
        Check("(3) restore reproduces the day-5 live set exactly",
            Fingerprint(b1.GetLive(ForestId)) == Fingerprint(b2.GetLive(ForestId)));
        for (int day = 6; day <= 10; day++)
            b2.CatchUp(ForestId, day, cells);

        string fpA = Fingerprint(a.GetLive(ForestId));
        string fpB = Fingerprint(b2.GetLive(ForestId));
        GD.Print($"  day-10 set: {fpA}");
        Check("(3) same seed + days -> identical spawn set across save/load boundary", fpA == fpB);

        // Different seed diverges (sanity that the seed actually feeds the rolls).
        var c = new ForageSystem();
        c.SetWorldSeed(Seed + 1);
        for (int day = 1; day <= 10; day++)
            c.CatchUp(ForestId, day, cells);
        Check("(3) a different world seed produces a different set",
            Fingerprint(c.GetLive(ForestId)) != fpA);

        // Harvested flag round-trips.
        var live = b2.GetLive(ForestId);
        if (live.Count > 0)
        {
            b2.MarkHarvested(ForestId, live[0].NodeId);
            var b3 = new ForageSystem();
            b3.SetWorldSeed(Seed);
            b3.Restore(b2.Capture());
            Check("(3) harvested flag survives the save round-trip",
                b3.IsHarvested(ForestId, live[0].NodeId)
                && Fingerprint(b3.GetLive(ForestId)) == Fingerprint(b2.GetLive(ForestId)));
        }
    }

    private static string Fingerprint(IReadOnlyList<ForageSpawn> spawns)
        => string.Join("|", spawns
            .OrderBy(s => s.NodeId, StringComparer.Ordinal)
            .Select(s => $"{s.NodeId}:{s.ResourceId}@{s.CellX},{s.CellY}"));

    // ------------------------------------------------------ (4) RespawnDays windows

    private void TestRespawnDays()
    {
        GD.Print("-------------------- (4) RespawnDays windows (1/1, 0/0, 7-14) --------------------");
        Check("(4) data: forest_tree window is 7-14",
            ResourceNodes.ForestTree.RespawnDaysMin == 7 && ResourceNodes.ForestTree.RespawnDaysMax == 14);
        Check("(4) data: pine_tree window is 7-14",
            ResourceNodes.PineTree.RespawnDaysMin == 7 && ResourceNodes.PineTree.RespawnDaysMax == 14);
        Check("(4) data: fallen_wood is one-shot (0/0)",
            ResourceNodes.FallenWood.RespawnDaysMin == 0 && ResourceNodes.FallenWood.RespawnDaysMax == 0);
        Check("(4) data: rock keeps the daily respawn (1/1)",
            ResourceNodes.Rock.RespawnDaysMin == 1 && ResourceNodes.Rock.RespawnDaysMax == 1);

        // The harvest-time roll: in range, deterministic per (seed, day, key), varying across keys.
        bool inRange = true, deterministic = true;
        var rolls = new HashSet<int>();
        for (int day = 1; day <= 30; day++)
        {
            int roll = TerritorySystem.RollRespawnDays(Seed, day, $"{ForestId}:tree_{day:00}", 7, 14);
            inRange &= roll is >= 7 and <= 14;
            deterministic &= roll == TerritorySystem.RollRespawnDays(Seed, day, $"{ForestId}:tree_{day:00}", 7, 14);
            rolls.Add(roll);
        }
        Check("(4) tree rolls stay inside 7-14 across 30 harvests", inRange);
        Check("(4) same (seed, day, key) always rolls the same window", deterministic);
        Check($"(4) the window actually varies across harvests ({rolls.Count} distinct values)", rolls.Count > 1);
        Check("(4) fixed cadence min==max skips the roll (1/1 -> 1)",
            TerritorySystem.RollRespawnDays(Seed, 3, "k", 1, 1) == 1);
        Check("(4) max<=0 means never (0)", TerritorySystem.RollRespawnDays(Seed, 3, "k", 0, 0) == 0);

        // Respawn-day entries via the save bridge — the exact shape SaveState round-trips. The
        // rolled day is PERSISTED (never re-rolled on load): a tree that rolled day 12 comes back
        // on day 12, whatever happens in between.
        var clock = new DayClock();
        clock.RestoreState(DayClock.DayStartMinute, 5, Season.Spring, 1); // ordinal 5
        var ts = new TerritorySystem(new Inventory(), clock, null, null);
        ts.RegisterScenePlacements(ForestId, new List<(string, string)>
        {
            ("tree_01", "forest_tree"),
            ("windfall_01", "fallen_wood"),
        });
        ts.RestoreState(new TerritoryDto
        {
            DepletedNodes = new List<DepletedNodeDto>
            {
                new() { Key = $"{ForestId}:tree_01", RespawnDay = 12 }, // rolled 7 at chop on day 5
                new() { Key = $"{ForestId}:windfall_01", RespawnDay = 0 }, // never
                new() { Key = $"{ForestId}:rock_1", RespawnDay = 6 },   // daily marker node
            },
        });

        Check("(4) day 5: tree depleted", ts.IsNodeDepleted(ForestId, "tree_01"));
        Check("(4) day 5: rock depleted", ts.IsNodeDepleted(ForestId, "rock_1"));

        clock.RestoreState(DayClock.DayStartMinute, 6, Season.Spring, 1);
        Check("(4) day 6: rock (respawn day 6) is back", !ts.IsNodeDepleted(ForestId, "rock_1"));
        Check("(4) day 6: tree still down", ts.IsNodeDepleted(ForestId, "tree_01"));

        clock.RestoreState(DayClock.DayStartMinute, 11, Season.Spring, 1);
        Check("(4) day 11: tree still down (respawns day 12)", ts.IsNodeDepleted(ForestId, "tree_01"));

        clock.RestoreState(DayClock.DayStartMinute, 12, Season.Spring, 1);
        Check("(4) day 12: tree is back on its persisted rolled day", !ts.IsNodeDepleted(ForestId, "tree_01"));
        Check("(4) day 12: one-shot fallen wood still gone", ts.IsNodeDepleted(ForestId, "windfall_01"));

        // Legacy save migration: keys-only DTO resolves through the authored defs — daily nodes
        // respawn tomorrow (old behavior), unresolvable keys are dropped.
        clock.RestoreState(DayClock.DayStartMinute, 10, Season.Spring, 1);
        ts.RestoreState(new TerritoryDto
        {
            DepletedNodeIds = new List<string> { $"{ForestId}:rock_1", $"{ForestId}:no_such_node" },
        });
        Check("(4) legacy keys-only save: rock depleted today", ts.IsNodeDepleted(ForestId, "rock_1"));
        Check("(4) legacy keys-only save: unresolvable key dropped",
            !ts.IsNodeDepleted(ForestId, "no_such_node"));
        clock.RestoreState(DayClock.DayStartMinute, 11, Season.Spring, 1);
        Check("(4) legacy keys-only save: rock back the next day", !ts.IsNodeDepleted(ForestId, "rock_1"));

        // Capture writes both the legacy keys and the respawn-day entries.
        var dto = ts.CaptureState();
        Check("(4) capture writes respawn-day entries alongside legacy keys",
            dto.DepletedNodes != null && dto.DepletedNodes.Count == dto.DepletedNodeIds.Count);
    }

    // ------------------------------------------------------ (5) debris second pass

    private void TestDebris()
    {
        GD.Print("-------------------- (5) Debris pass (design/forage.md third category) --------------------");

        // Data: three one-hit clears, 5 min, 1 yield, never respawn in place, prefabs declared.
        Check("(5) data: loose_stones = Pick -> 1 stone, 5 min, 0/0",
            ResourceNodes.LooseStones.Tool == ToolKind.Pick
            && ResourceNodes.LooseStones.YieldItemId == "stone" && ResourceNodes.LooseStones.YieldCount == 1
            && ResourceNodes.LooseStones.HarvestMinutes == 5
            && ResourceNodes.LooseStones.RespawnDaysMin == 0 && ResourceNodes.LooseStones.RespawnDaysMax == 0);
        Check("(5) data: fallen_branch = Axe -> 1 wood, 5 min, 0/0",
            ResourceNodes.FallenBranch.Tool == ToolKind.Axe
            && ResourceNodes.FallenBranch.YieldItemId == "wood" && ResourceNodes.FallenBranch.YieldCount == 1
            && ResourceNodes.FallenBranch.HarvestMinutes == 5
            && ResourceNodes.FallenBranch.RespawnDaysMin == 0 && ResourceNodes.FallenBranch.RespawnDaysMax == 0);
        Check("(5) data: scrub_weeds = Hand -> 1 fiber, 5 min, 0/0",
            ResourceNodes.ScrubWeeds.Tool == ToolKind.Hand
            && ResourceNodes.ScrubWeeds.YieldItemId == "fiber" && ResourceNodes.ScrubWeeds.YieldCount == 1
            && ResourceNodes.ScrubWeeds.HarvestMinutes == 5
            && ResourceNodes.ScrubWeeds.RespawnDaysMin == 0 && ResourceNodes.ScrubWeeds.RespawnDaysMax == 0);
        Check("(5) data: yield item ids exist (stone/wood/fiber)",
            Items.IsDefined("stone") && Items.IsDefined("wood") && Items.IsDefined("fiber"));
        Check("(5) data: all three debris prefab scenes exist",
            ResourceLoader.Exists(ResourceNodes.LooseStones.ScenePath ?? "")
            && ResourceLoader.Exists(ResourceNodes.FallenBranch.ScenePath ?? "")
            && ResourceLoader.Exists(ResourceNodes.ScrubWeeds.ScenePath ?? ""));

        var debrisTable = Territories.Forest.DebrisTable;
        var debrisIds = debrisTable.Select(e => e.NodeId).ToHashSet();
        Check("(5) forest debris table = stones/branch heavy, weeds medium",
            debrisIds.SetEquals(new[] { "loose_stones", "fallen_branch", "scrub_weeds" })
            && debrisTable.First(e => e.NodeId == "loose_stones").Weight
               == debrisTable.First(e => e.NodeId == "fallen_branch").Weight
            && debrisTable.First(e => e.NodeId == "scrub_weeds").Weight
               < debrisTable.First(e => e.NodeId == "loose_stones").Weight);

        // Initial sprinkle on the territory's first-ever pass.
        var cells = new FakeCells();
        var forage = new ForageSystem();
        forage.SetWorldSeed(Seed);
        forage.CatchUp(ForestId, 1, cells);
        var seeded = forage.GetLiveDebris(ForestId);
        Check($"(5) first-ever pass sprinkles 8-12 debris ({seeded.Count})",
            seeded.Count >= ForageSystem.DebrisSeedMin && seeded.Count <= ForageSystem.DebrisSeedMax);
        Check("(5) sprinkle pieces all stamped with the seeding day",
            seeded.All(s => s.SpawnDay == 1 && s.NodeId.StartsWith("debris_")));
        Check("(5) every debris piece is from the forest debris table",
            seeded.All(s => debrisIds.Contains(s.ResourceId)));
        Check("(5) forage pass unaffected by the sprinkle (own cap intact)",
            forage.GetLive(ForestId).Count <= ForageSystem.LiveCap);

        // Valid-cell rules: open ground, in rect, full spacing from reserved cells and spawns,
        // relaxed (>=1) clearance from the trail anchors.
        bool inRect = true, openGround = true, spacing = true, trailOk = true;
        var everything = forage.GetLive(ForestId).Concat(seeded).ToList();
        foreach (var s in everything)
        {
            var (x0, y0, x1, y1) = cells.PlayableRect;
            inRect &= s.CellX >= x0 && s.CellX <= x1 && s.CellY >= y0 && s.CellY <= y1;
            openGround &= cells.IsOpenGround(s.CellX, s.CellY);
            foreach (var (rx, ry) in cells.ReservedCells)
                spacing &= Math.Max(Math.Abs(rx - s.CellX), Math.Abs(ry - s.CellY)) >= ForageSystem.MinSpacingCells;
        }
        foreach (var s in seeded)
            foreach (var (tx, ty) in cells.TrailCells)
                trailOk &= Math.Max(Math.Abs(tx - s.CellX), Math.Abs(ty - s.CellY))
                    >= ForageSystem.DebrisTrailClearanceCells;
        for (int i = 0; i < everything.Count; i++)
            for (int j = i + 1; j < everything.Count; j++)
                spacing &= Math.Max(Math.Abs(everything[i].CellX - everything[j].CellX),
                    Math.Abs(everything[i].CellY - everything[j].CellY)) >= ForageSystem.MinSpacingCells;
        Check("(5) debris obeys rect/open-ground/reserved+spawn spacing", inRect && openGround && spacing);
        Check("(5) debris keeps at least the relaxed 1-cell trail clearance", trailOk);

        // Daily top-up: 2-4 attempts under cap 12, accumulating (never swept).
        int prev = seeded.Count;
        bool capOk = true, deltaOk = true, tableOk = true;
        for (int day = 2; day <= 30; day++)
        {
            forage.CatchUp(ForestId, day, cells);
            var live = forage.GetLiveDebris(ForestId);
            capOk &= live.Count <= ForageSystem.DebrisLiveCap;
            deltaOk &= live.Count >= prev && live.Count - prev <= ForageSystem.DebrisMaxAttemptsPerDay;
            tableOk &= live.All(s => debrisIds.Contains(s.ResourceId));
            prev = live.Count;
        }
        Check($"(5) debris never exceeds its cap through day 30 ({prev} <= {ForageSystem.DebrisLiveCap})", capOk);
        Check("(5) daily top-up adds at most 2-4 pieces, never removes", deltaOk);
        Check("(5) every topped-up piece is from the debris table", tableOk);
        Check("(5) uncleared debris accumulates all the way to cap", prev == ForageSystem.DebrisLiveCap);

        // No 7th-day sweep for debris; forage still sweeps.
        var f2 = new ForageSystem();
        f2.SetWorldSeed(Seed);
        for (int day = 1; day <= 7; day++)
            f2.CatchUp(ForestId, day, cells);
        Check("(5) day 7: debris older than day 7 survives (no sweep)",
            f2.GetLiveDebris(ForestId).Any(s => s.SpawnDay < 7));
        Check("(5) day 7: forage still swept (only day-7 spawns remain)",
            f2.GetLive(ForestId).All(s => s.SpawnDay == 7));

        // Clearing is permanent: the piece leaves the live set and never comes back.
        var target = forage.GetLiveDebris(ForestId)[0];
        Check("(5) MarkHarvested accepts a live debris piece", forage.MarkHarvested(ForestId, target.NodeId));
        Check("(5) cleared debris left the live set",
            forage.GetLiveDebris(ForestId).All(s => s.NodeId != target.NodeId));
        Check("(5) cleared debris still resolves today (occupies its cell)",
            forage.IsForageNode(ForestId, target.NodeId) && forage.IsHarvested(ForestId, target.NodeId));
        forage.CatchUp(ForestId, 31, cells);
        Check("(5) next pass prunes the cleared piece for good",
            !forage.IsForageNode(ForestId, target.NodeId)
            && forage.GetLiveDebris(ForestId).All(s => s.NodeId != target.NodeId));

        // Save round-trip + determinism across the boundary (the forage test's pattern, for debris).
        var a = new ForageSystem();
        a.SetWorldSeed(Seed);
        for (int day = 1; day <= 10; day++)
            a.CatchUp(ForestId, day, cells);

        var b1 = new ForageSystem();
        b1.SetWorldSeed(Seed);
        for (int day = 1; day <= 5; day++)
            b1.CatchUp(ForestId, day, cells);
        var b2 = new ForageSystem();
        b2.SetWorldSeed(Seed);
        b2.Restore(b1.Capture());
        Check("(5) restore reproduces the day-5 debris set exactly",
            Fingerprint(b1.GetLiveDebris(ForestId)) == Fingerprint(b2.GetLiveDebris(ForestId)));
        for (int day = 6; day <= 10; day++)
            b2.CatchUp(ForestId, day, cells);
        Check("(5) restore does not re-sprinkle (seeded flag round-trips)",
            b2.GetLiveDebris(ForestId).Count <= ForageSystem.DebrisLiveCap
            && b2.GetLiveDebris(ForestId).Count(s => s.SpawnDay == 6) <= ForageSystem.DebrisMaxAttemptsPerDay);
        Check("(5) same seed + days -> identical debris across the save/load boundary",
            Fingerprint(a.GetLiveDebris(ForestId)) == Fingerprint(b2.GetLiveDebris(ForestId)));

        var c = new ForageSystem();
        c.SetWorldSeed(Seed + 1);
        for (int day = 1; day <= 10; day++)
            c.CatchUp(ForestId, day, cells);
        Check("(5) a different world seed produces different debris",
            Fingerprint(c.GetLiveDebris(ForestId)) != Fingerprint(a.GetLiveDebris(ForestId)));

        // Pre-debris save migration: a v12 forage-only DTO (no debris section) sprinkles once on
        // its NEXT pass, not from day 1.
        var migrated = new ForageSystem();
        migrated.SetWorldSeed(Seed);
        migrated.Restore(new List<TerritoryForageDto>
        {
            new() { TerritoryId = ForestId, LastPassDay = 5 },
        });
        migrated.CatchUp(ForestId, 6, cells);
        var lateSeeded = migrated.GetLiveDebris(ForestId);
        Check($"(5) pre-debris save sprinkles 8-12 on its next pass ({lateSeeded.Count})",
            lateSeeded.Count >= ForageSystem.DebrisSeedMin && lateSeeded.Count <= ForageSystem.DebrisSeedMax
            && lateSeeded.All(s => s.SpawnDay == 6));
    }

    // ------------------------------------------------------ (6) trail clearance difference

    private void TestDebrisTrailClearance()
    {
        GD.Print("-------------------- (6) Trail clearance (forage 2 cells, debris 1) --------------------");
        var cells = new TrailHuggingCells();
        var forage = new ForageSystem();
        forage.SetWorldSeed(Seed);
        for (int day = 1; day <= 10; day++)
            forage.CatchUp(ForestId, day, cells);

        // Every open cell sits exactly 1 cell from the trail: forage's 2-cell clearance rejects
        // them all, debris' 1-cell clearance accepts them.
        Check("(6) forage never spawns inside its 2-cell trail clearance",
            forage.GetLive(ForestId).Count == 0);
        var debris = forage.GetLiveDebris(ForestId);
        Check($"(6) debris spawns 1 cell from the trail ({debris.Count} pieces)", debris.Count > 0);
        Check("(6) all debris exactly 1 cell (Chebyshev) from a trail cell",
            debris.All(s => cells.TrailCells.Min(t =>
                Math.Max(Math.Abs(t.X - s.CellX), Math.Abs(t.Y - s.CellY))) == 1));
    }
}
