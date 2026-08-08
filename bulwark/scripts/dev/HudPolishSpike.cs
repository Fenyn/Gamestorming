using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.UI;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the quest/item toast feedback, interaction prompts, and calendar panel
/// polish pass. Sections:
///  (A) CalendarView (GameState.GetCalendarView): 28 days, current day flagged, Tharr's shipped
///      Summer-11 birthday lands on the right day IN Summer and is absent OUT of season, and
///      construction-completion mark math (commission farmhouse's 2-day build, verify the mark lands
///      on Clock.Day + days-remaining).
///  (B) CozyHud instantiates; ShowQuestBanner/ShowItemGain don't throw; same-item gains within the
///      aggregate window merge into one feed row with a summed count.
///  (C) CozyHud.SetInteractionPrompt shows/hides the floating prompt; a bare CozyWorldScene subclass
///      (no override) proves GetInteractionHint defaults to null.
///  (D) calendar_panel.tscn instantiates, renders a fake 28-day view, Toggled fires on Open()/Close(),
///      and a synthetic ui_cancel closes it (the PauseOptionsSpike (E) precedent for driving
///      _UnhandledInput directly).
///  (E) BuildingSystem.ConstructionCompleted fires exactly once, only when TickDay finishes a
///      building's construction timer — distinct from the broader Changed event.
///  (F) Event wiring: a fresh GameState + a REAL OutpostScene instance prove QuestStarted actually
///      reaches CozyHud.ShowQuestBanner through CozyWorldScene's wiring (not just that the method
///      exists in isolation).
/// The user's real user://save/slot0.json is backed up before (A)/(F) and restored in `finally`
/// (both sections drive a real/throwaway GameState, which persists on every mutating command).
/// </summary>
public partial class HudPolishSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== HUD POLISH SPIKE ====================");

        BackupSlot0();
        try
        {
            RunCalendarViewSpike();          // (A)
            await RunHudBannerAndFeedSpike(); // (B)
            await RunInteractionPromptSpike(); // (C)
            await RunCalendarPanelSpike();     // (D)
            RunConstructionCompletedSpike();   // (E)
            await RunEventWiringSpike();       // (F)
        }
        catch (Exception e)
        {
            GD.PushError($"[HudPolishSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("HudPolishSpike");
    }

    // ─────────────────────────── (A) CalendarView ───────────────────────────

    private void RunCalendarViewSpike()
    {
        GD.Print("-------------------- (A) CalendarView: birthdays + construction --------------------");

        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs); // _Ready seeds a clean save on the cleared slot

        // Move the clock into Summer so Tharr's shipped Summer-11 birthday is in season.
        gs.Clock.RestoreState(DayClock.DayStartMinute, day: 1, Season.Summer, year: 1);

        var baseline = gs.GetCalendarView();
        Check("(A) CalendarView reports 28 days", baseline.Days.Count == DayClock.DaysPerSeason);
        Check("(A) CalendarView season/year mirror the clock", baseline.Season == Season.Summer && baseline.Year == 1);
        Check("(A) CalendarView.CurrentDay mirrors the clock", baseline.CurrentDay == 1);
        Check("(A) day 1 is flagged IsToday", baseline.Days[0].Day == 1 && baseline.Days[0].IsToday);
        Check("(A) day 11 is NOT flagged today", !baseline.Days[10].IsToday);

        var birthdayDay = baseline.Days.FirstOrDefault(d => d.Day == 11);
        Check("(A) Tharr's Summer-11 birthday mark lands on day 11",
            birthdayDay != null && birthdayDay.Marks.Any(m => m.Contains("Tharr") && m.Contains("birthday")));

        // Move off Summer — the birthday mark is season-scoped and must disappear.
        gs.Clock.RestoreState(DayClock.DayStartMinute, day: 1, Season.Spring, year: 1);
        var offSeason = gs.GetCalendarView();
        var offSeasonDay11 = offSeason.Days.FirstOrDefault(d => d.Day == 11);
        Check("(A) birthday mark absent outside its season",
            offSeasonDay11 != null && offSeasonDay11.Marks.Count == 0);

        // Construction mark math: commission farmhouse (a 2-day build per GameState._Ready's
        // SetConstructionDays) and verify the completion-day mark.
        gs.AddItem("wood", 200);
        gs.AddItem("stone", 200);
        gs.EarnGold(500);
        gs.Clock.RestoreState(DayClock.DayStartMinute, day: 3, Season.Spring, year: 1);
        Check("(A) commission farmhouse (starts its construction timer)", gs.CommissionBuilding("farmhouse"));
        Check("(A) farmhouse reports under construction", gs.Building.IsUnderConstruction("farmhouse"));

        int completionDay = gs.Clock.Day + gs.Building.GetConstructionDaysRemaining("farmhouse");
        var withConstruction = gs.GetCalendarView();
        var completionMarkDay = withConstruction.Days.FirstOrDefault(d => d.Day == completionDay);
        Check($"(A) construction-completion mark lands on day {completionDay}",
            completionMarkDay != null && completionMarkDay.Marks.Any(m => m.Contains("Farmhouse") && m.Contains("completes")));

        gs.QueueFree();
    }

    // ─────────────────────────── (B) Quest banner + item feed ───────────────────────────

    private async Task RunHudBannerAndFeedSpike()
    {
        GD.Print("-------------------- (B) quest banner + item feed --------------------");

        var packed = GD.Load<PackedScene>("res://scenes/ui/cozy_hud.tscn");
        Check("(B) cozy_hud.tscn loads", packed != null);
        if (packed == null)
            return;

        var hud = packed.Instantiate<CozyHud>();
        AddChild(hud);
        await Frames(2);

        Check("(B) %QuestBannerPanel resolves", hud.GetNodeOrNull("%QuestBannerPanel") != null);
        Check("(B) %ItemFeedList resolves", hud.GetNodeOrNull("%ItemFeedList") != null);
        Check("(B) %InteractionPrompt resolves", hud.GetNodeOrNull("%InteractionPrompt") != null);
        Check("(B) %TimeBox resolves", hud.GetNodeOrNull("%TimeBox") != null);

        bool threw = false;
        try
        {
            hud.ShowQuestBanner("New Quest", "Repair the Lodging");
            hud.ShowQuestBanner("Quest Complete", "Repair the Lodging"); // exercises the queue path
            hud.ShowItemGain("Wood", 3);
        }
        catch (Exception e)
        {
            threw = true;
            GD.PushError($"[HudPolishSpike] ShowQuestBanner/ShowItemGain threw: {e}");
        }
        Check("(B) ShowQuestBanner/ShowItemGain don't throw", !threw);
        await Frames(2);

        var bannerPanel = hud.GetNode<PanelContainer>("%QuestBannerPanel");
        Check("(B) the first queued banner is visible", bannerPanel.Visible);
        Check("(B) headline text set", hud.GetNode<Label>("%QuestBannerHeadline").Text == "New Quest");
        Check("(B) title text set", hud.GetNode<Label>("%QuestBannerTitleLabel").Text == "Repair the Lodging");

        // Aggregation: a second gain of the SAME item within the window merges into one row.
        var feed = hud.GetNode<VBoxContainer>("%ItemFeedList");
        Check("(B) first Wood gain produced one feed row", feed.GetChildCount() == 1);
        hud.ShowItemGain("Wood", 2);
        await Frames(1);
        Check("(B) merged gain of the same item stays at one row", feed.GetChildCount() == 1);

        var rowPanel = feed.GetChild<PanelContainer>(0);
        var rowLabel = rowPanel.GetChild<Label>(0);
        Check("(B) merged row shows the summed count (+5 Wood)", rowLabel.Text == "+5 Wood");

        // A different item is its own, additional row.
        hud.ShowItemGain("Stone", 1);
        await Frames(1);
        Check("(B) a different item adds a second row", feed.GetChildCount() == 2);

        hud.QueueFree();
        await Frames(1);
    }

    // ─────────────────────────── (C) Interaction prompt ───────────────────────────

    private async Task RunInteractionPromptSpike()
    {
        GD.Print("-------------------- (C) interaction prompt --------------------");

        var packed = GD.Load<PackedScene>("res://scenes/ui/cozy_hud.tscn");
        Check("(C) cozy_hud.tscn loads", packed != null);
        if (packed != null)
        {
            var hud = packed.Instantiate<CozyHud>();
            AddChild(hud);
            await Frames(2);

            var prompt = hud.GetNode<PanelContainer>("%InteractionPrompt");
            Check("(C) prompt starts hidden", !prompt.Visible);

            hud.SetInteractionPrompt("Talk");
            Check("(C) SetInteractionPrompt(\"Talk\") shows the prompt", prompt.Visible);
            Check("(C) prompt label reads \"E — Talk\"", hud.GetNode<Label>("%InteractionPromptLabel").Text == "E — Talk");

            hud.SetInteractionPrompt(null);
            Check("(C) SetInteractionPrompt(null) hides the prompt", !prompt.Visible);

            hud.SetInteractionPrompt("Sleep");
            hud.SetInteractionPrompt(""); // empty string also hides
            Check("(C) SetInteractionPrompt(\"\") hides the prompt too", !prompt.Visible);

            hud.QueueFree();
            await Frames(1);
        }

        // GetInteractionHint defaults to null on a bare CozyWorldScene subclass (no override).
        var bare = new BareWorldScene();
        AddChild(bare);
        await Frames(1);
        Check("(C) GetInteractionHint defaults to null on a bare CozyWorldScene", bare.PublicHint == null);
        bare.QueueFree();
        await Frames(1);
    }

    /// <summary>Minimal concrete CozyWorldScene that overrides nothing beyond the two abstract
    /// members — proves the base class's <c>GetInteractionHint</c> default (null) without pulling in
    /// a real world scene's proximity logic.</summary>
    private sealed partial class BareWorldScene : CozyWorldScene
    {
        public string? PublicHint => GetInteractionHint();
        protected override Vector3 GetPlayerSpawnPosition() => Vector3.Zero;
        protected override void OnInteractRequested(ToolKind tool) { }
    }

    // ─────────────────────────── (D) Calendar panel ───────────────────────────

    private async Task RunCalendarPanelSpike()
    {
        GD.Print("-------------------- (D) calendar panel --------------------");

        var packed = GD.Load<PackedScene>("res://scenes/ui/calendar_panel.tscn");
        Check("(D) calendar_panel.tscn loads", packed != null);
        if (packed == null)
            return;

        var panel = packed.Instantiate<CalendarPanel>();
        AddChild(panel);
        await Frames(2);

        Check("(D) %TitleLabel resolves", panel.GetNodeOrNull("%TitleLabel") != null);
        Check("(D) %DayGrid resolves", panel.GetNodeOrNull("%DayGrid") != null);
        Check("(D) panel starts closed", !panel.Visible);

        panel.Render(BuildFakeCalendarView());
        await Frames(1);

        var grid = panel.GetNode<GridContainer>("%DayGrid");
        Check("(D) renders 28 day cells", grid.GetChildCount() == DayClock.DaysPerSeason);
        Check("(D) title reflects the rendered view", panel.GetNode<Label>("%TitleLabel").Text == "Calendar — Summer, Year 1");

        var toggles = new List<bool>();
        panel.Toggled += open => toggles.Add(open);

        panel.Open();
        Check("(D) Open() shows the panel and fires Toggled(true)", panel.Visible && toggles.Count == 1 && toggles[0]);

        var esc = new InputEventAction { Action = "ui_cancel", Pressed = true };
        panel._UnhandledInput(esc);
        Check("(D) Esc closes the panel and fires Toggled(false)", !panel.Visible && toggles.Count == 2 && !toggles[1]);

        // Toggle() flips open/closed — the seam the HUD's clock-click drives.
        panel.Toggle();
        Check("(D) Toggle() opens from closed", panel.Visible);
        panel.Toggle();
        Check("(D) Toggle() closes from open", !panel.Visible);

        panel.QueueFree();
        await Frames(1);
    }

    private static CalendarView BuildFakeCalendarView()
    {
        var days = new List<CalendarDayView>(DayClock.DaysPerSeason);
        for (int d = 1; d <= DayClock.DaysPerSeason; d++)
        {
            var marks = d == 11 ? new List<string> { "Tharr's birthday" } : new List<string>();
            days.Add(new CalendarDayView(d, d == 5, marks));
        }
        return new CalendarView(Season.Summer, 1, 5, days);
    }

    // ─────────────────────────── (E) ConstructionCompleted ───────────────────────────

    private void RunConstructionCompletedSpike()
    {
        GD.Print("-------------------- (E) BuildingSystem.ConstructionCompleted --------------------");

        var inv = new Inventory();
        inv.AddItem("wood", 200);
        inv.AddItem("stone", 200);
        var wallet = new Wallet();
        wallet.EarnGold(500);

        var bs = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold);
        bs.SetConstructionDays(new Dictionary<string, int> { { "farmhouse", 2 } });

        var completed = new List<string>();
        bs.ConstructionCompleted += id => completed.Add(id);
        int changedCount = 0;
        bs.Changed += _ => changedCount++;

        Check("(E) commission farmhouse (2-day construction)", bs.Commission("farmhouse"));
        Check("(E) ConstructionCompleted has not fired yet", completed.Count == 0);
        Check("(E) Changed DID fire for the commission itself", changedCount == 1);

        bs.TickDay(); // 1 day remaining
        Check("(E) still not fired after the first tick", completed.Count == 0 && bs.IsUnderConstruction("farmhouse"));

        bs.TickDay(); // completes
        Check("(E) ConstructionCompleted fires exactly once, with the building id", completed is ["farmhouse"]);
        Check("(E) building no longer under construction", !bs.IsUnderConstruction("farmhouse"));
        Check("(E) Changed also fired for the completion tick", changedCount == 2);

        // A building whose construction was never started never fires ConstructionCompleted on TickDay.
        bs.TickDay();
        Check("(E) TickDay with nothing under construction raises no further events", completed.Count == 1);
    }

    // ─────────────────────────── (F) Event wiring ───────────────────────────

    private async Task RunEventWiringSpike()
    {
        GD.Print("-------------------- (F) event wiring: QuestStarted -> quest banner --------------------");

        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs); // _Ready seeds a clean quest log and becomes the live GameState.Instance

        var packed = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn");
        Check("(F) outpost.tscn loads", packed != null);
        if (packed == null)
        {
            gs.QueueFree();
            return;
        }

        var outpost = packed.Instantiate<OutpostScene>();
        AddChild(outpost);
        await PhysicsFrames(2);

        var hud = outpost.GetNodeOrNull<CozyHud>("CozyHud");
        Check("(F) outpost spawned its CozyHud", hud != null);

        if (hud != null)
        {
            var bannerPanel = hud.GetNodeOrNull<PanelContainer>("%QuestBannerPanel");
            var titleLabel = hud.GetNodeOrNull<Label>("%QuestBannerTitleLabel");
            Check("(F) quest banner starts hidden", bannerPanel != null && !bannerPanel.Visible);

            Check("(F) raise_the_hearths is not yet active on the fresh quest log", !gs.IsQuestActive("raise_the_hearths"));
            gs.StartQuest("raise_the_hearths");
            await Frames(2);

            Check("(F) QuestStarted reached the HUD: banner now visible", bannerPanel != null && bannerPanel.Visible);
            Check("(F) banner shows the quest's title", titleLabel != null && titleLabel.Text == Bulwark.Data.Quests.RaiseTheHearths.Title);
        }

        outpost.QueueFree();
        gs.QueueFree();
        await PhysicsFrames(1);
    }

    // ─────────────────────────── helpers ───────────────────────────

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task PhysicsFrames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
    }

    // ─────────────────────────── save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[HudPolishSpike] slot0.json backed up and cleared for the test run.");
    }

    private static void ClearSlot0()
    {
        if (Godot.FileAccess.FileExists(SavePath))
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[HudPolishSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[HudPolishSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
