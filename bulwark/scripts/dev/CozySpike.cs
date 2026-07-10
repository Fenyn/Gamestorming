using System.Linq;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the M2 cozy core: day clock advance, till/plant/water/harvest loop,
/// unwatered plots not growing, save→mutate→load restore, and season/year rollover. Drives the
/// plain C# systems directly (no UI, no GameState autoload dependency) so assertions are
/// deterministic. Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class CozySpike : Node
{
    private int _failures;

    public override void _Ready()
    {
        GD.Print("==================== COZY SPIKE ====================");

        TestClockAdvance();
        TestFarmLoop();
        TestUnwateredDoesNotGrow();
        TestSaveLoadRoundTrip();
        TestSeasonRollover();

        GD.Print("---------------------------------------------------");
        bool pass = _failures == 0;
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    // ---- Assertion helpers ----

    private void Check(bool condition, string label)
    {
        if (condition)
        {
            GD.Print($"[PASS] {label}");
        }
        else
        {
            GD.PushError($"[FAIL] {label}");
            GD.Print($"[FAIL] {label}");
            _failures++;
        }
    }

    // ---- Tests ----

    private void TestClockAdvance()
    {
        GD.Print("-- clock --");
        var clock = new DayClock();
        Check(clock.Hour == 6 && clock.Minute == 0, "clock starts at 6:00");
        Check(clock.TimeString() == "6:00 AM", $"time string formats ({clock.TimeString()})");

        int minuteEvents = 0, hourEvents = 0;
        clock.MinuteChanged += () => minuteEvents++;
        clock.HourChanged += () => hourEvents++;

        clock.SpendTime(90); // 6:00 -> 7:30
        Check(clock.Hour == 7 && clock.Minute == 30, $"SpendTime(90) → 7:30 (got {clock.TimeString()})");
        Check(minuteEvents == 90, $"90 MinuteChanged events ({minuteEvents})");
        Check(hourEvents == 1, $"1 HourChanged event ({hourEvents})");

        // Advance to the collapse boundary and confirm DayEnded fires once, then freezes.
        bool dayEnded = false;
        clock.DayEnded += () => dayEnded = true;
        clock.SpendTime(2000); // well past 26:00
        Check(dayEnded, "DayEnded fired reaching 26:00");
        Check(clock.Hour == 26 && clock.Minute == 0, $"clock clamps at 26:00 (got {clock.TimeString()})");
        Check(clock.DayIsOver, "DayIsOver latched");

        int before = clock.MinuteOfDay;
        clock.SpendTime(60);
        Check(clock.MinuteOfDay == before, "clock frozen after day end");

        clock.StartNextDay();
        Check(clock.Hour == 6 && clock.Minute == 0 && !clock.DayIsOver, "StartNextDay resets to 6:00");
        Check(clock.Day == 2, $"StartNextDay advanced to day 2 ({clock.Day})");
    }

    private void TestFarmLoop()
    {
        GD.Print("-- farm loop --");
        var inv = new Inventory();
        var clock = new DayClock(); // Spring day 1
        var farm = new FarmSystem(inv, () => clock.Season);
        inv.AddItem("turnip_seed", 2);

        var tile = new Vector2I(3, 4);
        Check(farm.TillPlot(tile), "till bare plot");
        Check(farm.GetPlot(tile)!.Stage == PlotStage.Tilled, "plot is tilled");

        Check(farm.PlantCrop(tile, "turnip"), "plant turnip");
        Check(inv.Count("turnip_seed") == 1, $"seed consumed ({inv.Count("turnip_seed")} left)");
        Check(farm.GetPlot(tile)!.Stage == PlotStage.Planted, "plot is planted");

        // Turnip: 4 growth days. Water + sleep four times.
        for (int day = 1; day <= 4; day++)
        {
            Check(farm.WaterPlot(tile), $"water day {day}");
            farm.OnDayEnded();
        }
        Check(farm.GetPlot(tile)!.Stage == PlotStage.Mature, "turnip matured after 4 watered days");

        Check(farm.HarvestPlot(tile), "harvest turnip");
        Check(inv.Count("turnip") == 1, $"turnip yielded to inventory ({inv.Count("turnip")})");
        Check(farm.GetPlot(tile)!.Stage == PlotStage.Tilled, "plot reset to tilled after harvest");

        // Out-of-season planting is rejected.
        clock.RestoreState(DayClock.DayStartMinute, 1, Season.Winter, 1);
        farm.TillPlot(tile);
        Check(!farm.PlantCrop(tile, "turnip"), "cannot plant turnip in Winter");
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

        Check(farm.GetPlot(tile)!.DaysGrown == 0, $"unwatered plot has 0 growth ({farm.GetPlot(tile)!.DaysGrown})");
        Check(farm.GetPlot(tile)!.Stage == PlotStage.Planted, "unwatered plot still just planted");
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

        var captured = SaveState.Capture(clock, inv, farm, collapsedLastNight: true);
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
        Check(loaded != null, "save JSON deserialized");
        bool collapsed = SaveState.Restore(loaded!, clock, inv, farm);

        Check(collapsed, "CollapsedLastNight flag restored");
        Check(clock.Day == 12 && clock.Season == Season.Summer && clock.Year == 3, "clock calendar restored");
        Check(clock.Hour == 11, $"clock time restored ({clock.TimeString()})");
        Check(inv.Count("wood") == 7, $"inventory wood restored to 7 ({inv.Count("wood")})");
        Check(inv.Count("potato_seed") == 3, $"potato seeds restored (planted 1 of 4 → 3)");
        Check(farm.GetPlot(new Vector2I(9, 9)) == null, "post-capture plot cleared by load");
        var p = farm.GetPlot(tile);
        Check(p != null && p.CropId == "potato" && p.WateredToday, "planted+watered plot restored");
    }

    private void TestSeasonRollover()
    {
        GD.Print("-- season rollover --");
        var clock = new DayClock();
        clock.RestoreState(DayClock.DayStartMinute, 28, Season.Spring, 1);

        clock.SpendTime(2000);      // hit day end
        clock.StartNextDay();       // day 28 -> Summer 1
        Check(clock.Season == Season.Summer && clock.Day == 1, $"Spring 28 → Summer 1 ({clock.DateString()})");

        // Fast-forward to Winter 28, Year 1 → Spring 1, Year 2.
        clock.RestoreState(DayClock.DayStartMinute, 28, Season.Winter, 1);
        clock.StartNextDay();
        Check(clock.Season == Season.Spring && clock.Day == 1 && clock.Year == 2,
            $"Winter 28 Y1 → Spring 1 Y2 ({clock.DateString()})");
    }
}
