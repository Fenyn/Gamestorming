using System.Collections.Generic;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Conditions;
using PF2e.Core;

using Bulwark.Save;
namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the M2 cozy core: day clock advance, till/plant/water/harvest loop,
/// unwatered plots not growing, save→mutate→load restore (incl. legacy-save tolerance), and
/// season/year rollover — driven on the plain C# systems for deterministic assertions. The final
/// scenario drives a REAL GameState on a protected save slot to prove the world rules: the midnight
/// fatigue latch fires exactly once and the 30:00 all-nighter dawn rollover advances the calendar
/// with the player position untouched. The day-ledger tests cover the end-of-day summary: pure
/// DayLedger math, then a REAL GameState proving starter seeding is not counted, harvest/node/XP
/// tallies land in the staged one-shot summary, the ledger resets each day, the sleep path carries
/// its level-ups, the rollover flags the all-nighter, and the defeat wake stages the loss.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class CozySpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== COZY SPIKE ====================");

        TestClockAdvance();
        TestFarmLoop();
        TestUnwateredDoesNotGrow();
        TestSaveLoadRoundTrip();
        TestSeasonRollover();
        TestFatigueAndRollover();
        TestDayLedgerUnit();
        TestDaySummaryFlow();

        FinishAndQuit("CozySpike");
    }

    // ---- Tests ----

    private void TestClockAdvance()
    {
        GD.Print("-- clock --");
        var clock = new DayClock();
        Check("clock starts at 6:00", clock.Hour == 6 && clock.Minute == 0);
        Check($"time string formats ({clock.TimeString()})", clock.TimeString() == "6:00 AM");

        int minuteEvents = 0, hourEvents = 0;
        clock.MinuteChanged += () => minuteEvents++;
        clock.HourChanged += () => hourEvents++;

        clock.SpendTime(90); // 6:00 -> 7:30
        Check($"SpendTime(90) → 7:30 (got {clock.TimeString()})", clock.Hour == 7 && clock.Minute == 30);
        Check($"90 MinuteChanged events ({minuteEvents})", minuteEvents == 90);
        Check($"1 HourChanged event ({hourEvents})", hourEvents == 1);

        // Advance to the 30:00 rollover boundary and confirm DayEnded fires once, then freezes
        // (no handler restarts the day on this plain clock — GameState's rollover owns that).
        int dayEndedEvents = 0;
        clock.DayEnded += () => dayEndedEvents++;
        clock.SpendTime(3000); // well past 30:00
        Check($"DayEnded fired once reaching 30:00 ({dayEndedEvents})", dayEndedEvents == 1);
        Check($"clock clamps at 30:00 (got {clock.TimeString()})", clock.Hour == 30 && clock.Minute == 0);
        Check($"30:00 renders as 6:00 AM ({clock.TimeString()})", clock.TimeString() == "6:00 AM");
        Check("DayIsOver latched", clock.DayIsOver);

        int before = clock.MinuteOfDay;
        clock.SpendTime(60);
        Check("clock frozen after day end", clock.MinuteOfDay == before && dayEndedEvents == 1);

        clock.StartNextDay();
        Check("StartNextDay resets to 6:00", clock.Hour == 6 && clock.Minute == 0 && !clock.DayIsOver);
        Check($"StartNextDay advanced to day 2 ({clock.Day})", clock.Day == 2);

        // Late-night display sanity for the extended day.
        clock.RestoreState(27 * 60 + 30, clock.Day, clock.Season, clock.Year);
        Check($"27:30 renders 3:30 AM (got {clock.TimeString()})", clock.TimeString() == "3:30 AM");
    }

    private void TestFarmLoop()
    {
        GD.Print("-- farm loop --");
        var inv = new Inventory();
        var clock = new DayClock(); // Spring day 1
        var farm = new FarmSystem(inv, () => clock.Season);
        inv.AddItem("turnip_seed", 2);

        var tile = new Vector2I(3, 4);
        Check("till bare plot", farm.TillPlot(tile));
        Check("plot is tilled", farm.GetPlot(tile)!.Stage == PlotStage.Tilled);

        Check("plant turnip", farm.PlantCrop(tile, "turnip"));
        Check($"seed consumed ({inv.Count("turnip_seed")} left)", inv.Count("turnip_seed") == 1);
        Check("plot is planted", farm.GetPlot(tile)!.Stage == PlotStage.Planted);

        // Turnip: 4 growth days. Water + sleep four times.
        for (int day = 1; day <= 4; day++)
        {
            Check($"water day {day}", farm.WaterPlot(tile));
            farm.OnDayEnded();
        }
        Check("turnip matured after 4 watered days", farm.GetPlot(tile)!.Stage == PlotStage.Mature);

        Check("harvest turnip", farm.HarvestPlot(tile));
        Check($"turnip yielded to inventory ({inv.Count("turnip")})", inv.Count("turnip") == 1);
        Check("plot reset to tilled after harvest", farm.GetPlot(tile)!.Stage == PlotStage.Tilled);

        // Out-of-season planting is rejected.
        clock.RestoreState(DayClock.DayStartMinute, 1, Season.Winter, 1);
        farm.TillPlot(tile);
        Check("cannot plant turnip in Winter", !farm.PlantCrop(tile, "turnip"));
    }

    private void TestUnwateredDoesNotGrow()
    {
        GD.Print("-- unwatered --");
        var inv = new Inventory();
        var clock = new DayClock();
        var farm = new FarmSystem(inv, () => clock.Season);
        inv.AddItem("turnip_seed", 1);

        var tile = new Vector2I(1, 1);
        farm.TillPlot(tile);
        farm.PlantCrop(tile, "turnip");

        // Three days without watering.
        for (int i = 0; i < 3; i++)
            farm.OnDayEnded();

        Check($"unwatered plot has 0 growth ({farm.GetPlot(tile)!.DaysGrown})", farm.GetPlot(tile)!.DaysGrown == 0);
        Check("unwatered plot still just planted", farm.GetPlot(tile)!.Stage == PlotStage.Planted);
    }

    private void TestSaveLoadRoundTrip()
    {
        GD.Print("-- save/load --");
        var inv = new Inventory();
        var clock = new DayClock();
        var farm = new FarmSystem(inv, () => clock.Season);

        // Build a distinctive state.
        clock.SpendTime(300);                        // 11:00
        clock.RestoreState(clock.MinuteOfDay, 12, Season.Summer, 3);
        inv.AddItem("wood", 7);
        inv.AddItem("potato_seed", 4);
        var tile = new Vector2I(5, 6);
        farm.TillPlot(tile);
        farm.PlantCrop(tile, "potato");
        farm.WaterPlot(tile);

        var captured = SaveState.Capture(clock, inv, farm);
        string json = SaveSerializer.Serialize(captured);

        // Prove it also survives a real file round-trip through Godot IO.
        const string path = "user://save/cozy_spike.json";
        DirAccess.MakeDirRecursiveAbsolute("user://save");
        using (var w = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Write))
            w.StoreString(json);
        string readBack;
        using (var r = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Read))
            readBack = r.GetAsText();

        // Mutate the live systems AFTER capture — load must clobber these back.
        inv.AddItem("wood", 99);
        farm.TillPlot(new Vector2I(9, 9));
        clock.StartNextDay();

        var loaded = SaveSerializer.Deserialize(readBack);
        Check("save JSON deserialized", loaded != null);
        SaveState.Restore(loaded!, clock, inv, farm);

        Check("clock calendar restored", clock.Day == 12 && clock.Season == Season.Summer && clock.Year == 3);
        Check($"clock time restored ({clock.TimeString()})", clock.Hour == 11);
        Check($"inventory wood restored to 7 ({inv.Count("wood")})", inv.Count("wood") == 7);
        Check($"potato seeds restored (planted 1 of 4 → 3)", inv.Count("potato_seed") == 3);
        Check("post-capture plot cleared by load", farm.GetPlot(new Vector2I(9, 9)) == null);
        var p = farm.GetPlot(tile);
        Check("planted+watered plot restored", p != null && p.CropId == "potato" && p.WateredToday);

        // Save compat: pre-rework saves carry a "Flags" object (the retired CollapsedLastNight
        // collapse flag). System.Text.Json must ignore the unknown member and load the rest.
        string legacyJson = readBack.Replace("\"Clock\":",
            "\"Flags\": { \"CollapsedLastNight\": true },\n  \"Clock\":");
        Check("legacy JSON actually carries the retired Flags field",
            legacyJson.Contains("CollapsedLastNight"));
        var legacy = SaveSerializer.Deserialize(legacyJson);
        Check("legacy save with retired Flags field still deserializes", legacy != null);
        Check("legacy clock payload intact around the ignored field",
            legacy != null && legacy.Clock.Day == 12 && legacy.Clock.Season == Season.Summer);
    }

    private void TestSeasonRollover()
    {
        GD.Print("-- season rollover --");
        var clock = new DayClock();
        clock.RestoreState(DayClock.DayStartMinute, 28, Season.Spring, 1);

        clock.SpendTime(2000);      // hit day end
        clock.StartNextDay();       // day 28 -> Summer 1
        Check($"Spring 28 → Summer 1 ({clock.DateString()})", clock.Season == Season.Summer && clock.Day == 1);

        // Fast-forward to Winter 28, Year 1 → Spring 1, Year 2.
        clock.RestoreState(DayClock.DayStartMinute, 28, Season.Winter, 1);
        clock.StartNextDay();
        Check($"Winter 28 Y1 → Spring 1 Y2 ({clock.DateString()})", clock.Season == Season.Spring && clock.Day == 1 && clock.Year == 2);
    }

    /// <summary>
    /// The new day lifecycle on a REAL GameState (protected save slot): (a) crossing midnight
    /// (GameState.FatigueMinuteOfDay) applies Fatigued to every living member and fires the
    /// status notice exactly once (latched); (b) reaching 30:00 fires DayEnded once and the
    /// all-nighter rollover advances the calendar in place — the player stays in the territory,
    /// no rest benefits, Fatigued persists.
    /// </summary>
    private void TestFatigueAndRollover()
    {
        GD.Print("-- fatigue latch / dawn rollover --");
        BackupSlot0();
        try
        {
            var gs = new GameState { RealSecondsPerGameMinute = 0 };
            AddChild(gs);
            var squad = gs.Squad;
            Check("fresh GameState built a squad of 4", squad != null && squad.Members.Count == 4);
            if (squad == null)
                return;

            var notices = new List<string>();
            gs.SquadStatusNotice += n => notices.Add(n);
            int dayEndedEvents = 0;
            gs.Clock.DayEnded += () => dayEndedEvents++;

            // March into the territory so "the rollover relocates nobody" is observable.
            Check("travel into the forest accepted", gs.TravelToTerritory("verdant_fringe"));

            // (a) One minute before the threshold: nobody fatigued, no notice yet.
            gs.Clock.SpendTime(GameState.FatigueMinuteOfDay - 1 - gs.Clock.MinuteOfDay);
            Check($"no fatigue before the threshold (at {gs.Clock.TimeString()})",
                notices.Count == 0 && squad.Members.All(m => !HasFatigued(m)));

            gs.Clock.SpendTime(1); // midnight — the up-too-late threshold
            Check($"threshold fired the fatigue notice exactly once ({notices.Count})", notices.Count == 1);
            Check("all living members Fatigued at the threshold", squad.Members.All(HasFatigued));

            gs.Clock.SpendTime(180); // deep into the night — the latch holds
            Check("latch holds: still exactly one fatigue notice", notices.Count == 1);

            // (b) Ride the clock to 30:00 — the dawn rollover, in place.
            int dayBefore = gs.Clock.Day;
            gs.Clock.SpendTime(DayClock.DayRolloverMinute - gs.Clock.MinuteOfDay);
            Check($"DayEnded fired exactly once at 30:00 ({dayEndedEvents})", dayEndedEvents == 1);
            Check($"rollover advanced the calendar (day {dayBefore} → {gs.Clock.Day})",
                gs.Clock.Day == dayBefore + 1);
            Check("rollover reset the clock to 6:00",
                gs.Clock.MinuteOfDay == DayClock.DayStartMinute && !gs.Clock.DayIsOver);
            Check("player position untouched (still in the territory)",
                gs.Territory.CurrentTerritoryId == "verdant_fringe");
            Check($"rollover announced the all-nighter (second notice: {notices.Count})",
                notices.Count == 2);
            Check("squad still Fatigued after the rollover (no rest benefits)",
                squad.Members.All(HasFatigued));

            gs.QueueFree();
        }
        finally
        {
            RestoreSlot0();
        }
    }

    /// <summary>Pure DayLedger math: stacking item tallies, counters, flag, snapshot immutability,
    /// and a full reset (no GameState, no scene tree).</summary>
    private void TestDayLedgerUnit()
    {
        GD.Print("-- day ledger (pure) --");
        var ledger = new DayLedger();
        ledger.RecordItemGained("wood", 3);
        ledger.RecordItemGained("wood", 2);
        ledger.RecordItemGained("turnip", 1);
        ledger.RecordItemGained("stone", 0);   // non-positive adds are ignored
        ledger.RecordCropHarvested();
        ledger.RecordXpAwarded(40);
        ledger.RecordXpAwarded(40);
        ledger.RecordXpAwarded(0);             // defeat awards nothing
        ledger.RecordEncounter(victory: true);
        ledger.RecordEncounter(victory: false);
        ledger.RecordTreatWounds();
        ledger.MarkAllNighter();

        var ups = new List<SquadLevelUpView> { new("vet", "Veteran", 2, 3) };
        var view = ledger.BuildSummary("Spring 1, Year 1", ups, "notice");
        Check("ledger stacks repeat item gains (wood 3+2=5)",
            view.ItemsGained.TryGetValue("wood", out int wood) && wood == 5);
        Check("ledger tracks distinct items (turnip 1) and ignores zero adds",
            view.ItemsGained.TryGetValue("turnip", out int turnip) && turnip == 1
            && !view.ItemsGained.ContainsKey("stone"));
        Check("ledger sums XP awards (40+40+0=80)", view.XpAwarded == 80);
        Check("ledger counts crops / encounters / treatments",
            view.CropsHarvested == 1 && view.EncountersWon == 1 && view.EncountersLost == 1
            && view.TreatWoundsUses == 1);
        Check("summary carries date, level-ups, fatigue notice, and the all-nighter flag",
            view.Date == "Spring 1, Year 1" && view.LevelUps.Count == 1
            && view.FatigueNotice == "notice" && view.AllNighter);

        ledger.Reset();
        var fresh = ledger.BuildSummary("Spring 2, Year 1", null, null);
        Check("Reset clears every tally",
            fresh.ItemsGained.Count == 0 && fresh.CropsHarvested == 0 && fresh.XpAwarded == 0
            && fresh.EncountersWon == 0 && fresh.EncountersLost == 0
            && fresh.TreatWoundsUses == 0 && !fresh.AllNighter);
        Check("null level-ups become an empty list, not null",
            fresh.LevelUps != null && fresh.LevelUps.Count == 0);
        Check("earlier summary snapshot unaffected by the reset (immutable copy)",
            view.ItemsGained.Count == 2 && view.XpAwarded == 80 && view.AllNighter);
    }

    /// <summary>
    /// The end-of-day summary flow on a REAL GameState (protected save slot): starter seeding is
    /// NOT counted; AddItem grants and territory node yields flow through the single ItemAdded
    /// choke point; a mature-plot harvest bumps the crop count; encounter XP and the win land in
    /// the sleep summary together with the applied level-up; the staged summary is one-shot; the
    /// ledger resets for each new day; the 30:00 rollover flags the all-nighter with the fatigue
    /// notice; and the defeat wake stages a summary carrying the loss.
    /// </summary>
    private void TestDaySummaryFlow()
    {
        GD.Print("-- day summary flow --");
        BackupSlot0();
        try
        {
            var gs = new GameState { RealSecondsPerGameMinute = 0 };
            AddChild(gs);
            var squad = gs.Squad;
            Check("fresh GameState built a squad (day summary flow)",
                squad != null && squad.Members.Count == 4);
            if (squad == null)
                return;

            // ── Day 1: nothing happened — the starter seeding must NOT count as gains ──
            string date1 = gs.Clock.DateString();
            gs.Sleep();
            var s1 = gs.ConsumeDaySummary();
            Check("sleep staged a day summary", s1 != null);
            if (s1 == null)
                return;
            Check("starter-inventory seeding not counted as gains",
                s1.ItemsGained.Count == 0 && s1.CropsHarvested == 0);
            Check("empty day: no XP, no battles, no level-ups, no fatigue",
                s1.XpAwarded == 0 && s1.EncountersWon == 0 && s1.EncountersLost == 0
                && s1.LevelUps.Count == 0 && !s1.AllNighter && s1.FatigueNotice == null);
            Check($"summary dated the day that ENDED ({s1.Date})", s1.Date == date1);
            Check("staged summary is one-shot", gs.ConsumeDaySummary() == null);

            // ── Day 2: grant + node yield + farm harvest + won encounter + level-up ──
            gs.AddItem(Items.Wood.Id, 3);

            Check("travel out for the harvest/encounter day", gs.TravelToTerritory("verdant_fringe"));
            Check("node harvest accepted (rock_1, Pick)",
                gs.HarvestResourceNode("rock_1", ToolKind.Pick));

            // A mature plot injected through the save-restore seam: HarvestPlot must bump the
            // crop count and the yield must flow through ItemAdded like any other gain.
            gs.Farm.LoadPlots(new[]
            {
                new Plot { Tile = new Vector2I(2, 2), Stage = PlotStage.Mature, CropId = "turnip", DaysGrown = 99 },
            });
            Check("mature farm plot harvested", gs.HarvestPlot(new Vector2I(2, 2)));

            int scoutXpBefore = squad.GetXp(SquadRoster.ElaraId);
            Check("roamer contact accepted (gob_1)",
                gs.BeginTerritoryEncounter("gob_1", new Vector2(10f, 20f)));
            var outcome = gs.CompleteTerritoryEncounter(BattleResult.Team1Wins);
            Check("scripted victory outcome", outcome is { Victory: true });
            int encounterXp = squad.GetXp(SquadRoster.ElaraId) - scoutXpBefore;
            Check($"victory banked encounter XP ({encounterXp})", encounterXp > 0);

            squad.AddXp(SquadRoster.PlayerId, SquadRoster.XpPerLevel); // guarantee a level-up tonight

            string date2 = gs.Clock.DateString();
            gs.Sleep();
            var s2 = gs.ConsumeDaySummary();
            Check("day-2 summary staged", s2 != null);
            if (s2 == null)
                return;
            Check("direct grant counted through the AddItem choke point (wood 3)",
                s2.ItemsGained.TryGetValue(Items.Wood.Id, out int wood) && wood == 3);
            Check("territory node yield counted (stone 2)",
                s2.ItemsGained.TryGetValue(Items.Stone.Id, out int stone) && stone == 2);
            Check("farm yield counted (turnip 1) with the crop tally",
                s2.ItemsGained.TryGetValue("turnip", out int turnip) && turnip == 1
                && s2.CropsHarvested == 1);
            Check($"encounter XP counted ({s2.XpAwarded})", s2.XpAwarded == encounterXp);
            Check("won encounter counted", s2.EncountersWon == 1 && s2.EncountersLost == 0);
            Check("sleep summary includes the applied level-up (Veteran)",
                s2.LevelUps.Any(v => v.MemberId == SquadRoster.PlayerId && v.ToLevel == 3));
            Check("a slept day is not an all-nighter",
                !s2.AllNighter && s2.FatigueNotice == null);
            Check($"day-2 summary dated the ended day ({s2.Date})", s2.Date == date2);

            // ── Day 3: nothing gained; ride to 30:00 — the rollover flags the all-nighter ──
            string date3 = gs.Clock.DateString();
            gs.Clock.SpendTime(DayClock.DayRolloverMinute - gs.Clock.MinuteOfDay);
            var s3 = gs.ConsumeDaySummary();
            Check("rollover staged a day summary", s3 != null);
            if (s3 == null)
                return;
            Check("all-nighter flag set with the fatigue notice",
                s3.AllNighter && !string.IsNullOrEmpty(s3.FatigueNotice));
            Check("ledger was reset on the new day (no day-2 carry-over)",
                s3.ItemsGained.Count == 0 && s3.XpAwarded == 0
                && s3.EncountersWon == 0 && s3.CropsHarvested == 0);
            Check("rollover applies no level-ups", s3.LevelUps.Count == 0);
            Check($"rollover summary dated the ended day ({s3.Date})", s3.Date == date3);

            // ── Day 4: defeat wake stages a summary carrying the loss ──
            Check("travel out again", gs.TravelToTerritory("verdant_fringe"));
            Check("second roamer contact (gob_1, respawned with the new day)",
                gs.BeginTerritoryEncounter("gob_1", new Vector2(10f, 20f)));
            outcome = gs.CompleteTerritoryEncounter(BattleResult.Team2Wins);
            Check("scripted defeat outcome", outcome is { Victory: false });
            var s4 = gs.ConsumeDaySummary();
            Check("defeat wake staged a day summary", s4 != null);
            Check("defeat counted, no XP awarded",
                s4 is { EncountersLost: 1, EncountersWon: 0, XpAwarded: 0 });
            Check("defeat wake is not the all-nighter path", s4 is { AllNighter: false });

            gs.ConsumeDefeatSummary(); // drop the staged loss toast so nothing leaks past the test
            gs.QueueFree();
        }
        finally
        {
            RestoreSlot0();
        }
    }

    private static bool HasFatigued(PF2e.Core.ICharacter m)
        => m.Conditions?.HasCondition(Condition.Fatigued) == true;

    // ─────────────────────────── Save-slot protection (SleepLevelUpSpike pattern) ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[CozySpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[CozySpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[CozySpike] test slot0.json removed (no prior save existed).");
        }
    }
}
