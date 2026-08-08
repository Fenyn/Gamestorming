using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.UI;
using Godot;

using Bulwark.Quests;
namespace Bulwark.Dev;

/// <summary>
/// Headless verification for the title screen, name entry, quest log, and front-end flow:
///  (A) Quest log: start quest, update progress, complete quest, events fire
///  (B) Quest log: save/restore round-trip
///  (C) Quest definitions: tutorial quests exist and have correct objectives
///  (D) Title screen scene instantiates without error
///  (E) Name entry scene instantiates, emits signal on confirm
///  (F) GameState.StartNewGame sets name, seeds inventory, and RESETS all prior state to fresh
/// </summary>
public partial class MenuSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== MENU SPIKE ====================");

        try
        {
            RunQuestLogBasics();      // (A)
            RunQuestSaveRestore();    // (B)
            RunQuestDefinitions();    // (C)
            await RunTitleScreen();   // (D)
            await RunNameEntry();     // (E)
            RunStartNewGame();        // (F)
        }
        catch (Exception e)
        {
            GD.PushError($"[MenuSpike] Unhandled exception: {e}");
            Fail();
        }

        FinishAndQuit("MenuSpike");
    }

    // ─────────────────── (A) Quest log basics ───────────────────

    private void RunQuestLogBasics()
    {
        GD.Print("-------------------- (A) Quest log basics --------------------");

        var log = new QuestLog();
        log.Register(new QuestDefinition("test_q", "Test Quest", new QuestObjective[]
        {
            new("Gather wood", "wood", 10),
            new("Talk to NPC"),
        }));

        // Events
        string? startedId = null;
        string? completedId = null;
        int progressedCount = 0;
        log.QuestStarted += id => startedId = id;
        log.QuestCompleted += id => completedId = id;
        log.ObjectiveProgressed += (_, _) => progressedCount++;

        // Start
        log.StartQuest("test_q");
        Check("(A) quest started event fires", startedId == "test_q");
        Check("(A) quest is active", log.IsActive("test_q"));
        Check("(A) quest is not completed", !log.IsCompleted("test_q"));

        // Duplicate start is no-op
        startedId = null;
        log.StartQuest("test_q");
        Check("(A) duplicate start is no-op", startedId == null);

        // Unknown quest is no-op
        log.StartQuest("nonexistent");
        Check("(A) unknown quest start is no-op", !log.IsActive("nonexistent"));

        // Progress
        log.UpdateProgress("test_q", 0, 3);
        Check("(A) progress event fires", progressedCount == 1);

        var view = log.GetView();
        Check("(A) view has 1 active quest", view.Active.Count == 1);
        Check("(A) objective 0 progress is 3/10",
            view.Active[0].Objectives[0].Progress == 3 && view.Active[0].Objectives[0].Target == 10);

        // Progress beyond target clamps
        log.UpdateProgress("test_q", 0, 20);
        view = log.GetView();
        Check("(A) progress clamps at target", view.Active[0].Objectives[0].Progress == 10);
        Check("(A) objective 0 is done", view.Active[0].Objectives[0].Done);

        // Complete objective 1 (talk to NPC — target 1)
        log.CompleteObjective("test_q", 1);
        view = log.GetView();
        Check("(A) objective 1 completed via CompleteObjective", view.Active[0].Objectives[1].Done);

        // Complete quest
        log.CompleteQuest("test_q");
        Check("(A) quest completed event fires", completedId == "test_q");
        Check("(A) quest is no longer active", !log.IsActive("test_q"));
        Check("(A) quest is completed", log.IsCompleted("test_q"));

        view = log.GetView();
        Check("(A) view has 0 active, 1 completed", view.Active.Count == 0 && view.Completed.Count == 1);
    }

    // ─────────────────── (B) Quest log save/restore ───────────────────

    private void RunQuestSaveRestore()
    {
        GD.Print("-------------------- (B) Quest save/restore --------------------");

        var log = new QuestLog();
        log.Register(new QuestDefinition("q1", "Quest 1", new QuestObjective[]
        {
            new("Obj A", "wood", 5),
            new("Obj B"),
        }));
        log.Register(new QuestDefinition("q2", "Quest 2", new QuestObjective[]
        {
            new("Obj C"),
        }));

        log.StartQuest("q1");
        log.UpdateProgress("q1", 0, 3);
        log.StartQuest("q2");
        log.CompleteQuest("q2");

        var dtos = log.Capture();
        Check("(B) capture produces 2 DTOs", dtos.Count == 2);

        // Restore into a fresh log
        var log2 = new QuestLog();
        log2.Register(new QuestDefinition("q1", "Quest 1", new QuestObjective[]
        {
            new("Obj A", "wood", 5),
            new("Obj B"),
        }));
        log2.Register(new QuestDefinition("q2", "Quest 2", new QuestObjective[]
        {
            new("Obj C"),
        }));
        log2.Restore(dtos);

        Check("(B) restored q1 is active", log2.IsActive("q1"));
        Check("(B) restored q2 is completed", log2.IsCompleted("q2"));

        var view = log2.GetView();
        Check("(B) restored q1 progress preserved", view.Active[0].Objectives[0].Progress == 3);

        // Null restore clears
        log2.Restore(null);
        Check("(B) null restore clears all quests", !log2.IsActive("q1") && !log2.IsCompleted("q2"));
    }

    // ─────────────────── (C) Quest definitions ───────────────────

    private void RunQuestDefinitions()
    {
        GD.Print("-------------------- (C) Quest definitions --------------------");

        Check("(C) repair_lodging defined", Bulwark.Data.Quests.TryGet("repair_lodging", out var rl));
        Check("(C) repair_lodging has 3 objectives", rl!.Objectives.Length == 3);
        Check("(C) repair_lodging obj 0 tracks wood x15",
            rl.Objectives[0].TrackingItemId == "wood" && rl.Objectives[0].TargetCount == 15);
        Check("(C) repair_lodging obj 1 tracks stone x10",
            rl.Objectives[1].TrackingItemId == "stone" && rl.Objectives[1].TargetCount == 10);

        Check("(C) planning_table defined", Bulwark.Data.Quests.TryGet("planning_table", out var pt));
        Check("(C) planning_table has 1 objective", pt!.Objectives.Length == 1);

        Check("(C) raise_the_hearths defined", Bulwark.Data.Quests.TryGet("raise_the_hearths", out var rh));
        Check("(C) raise_the_hearths starts on planning_table_shown",
            rh!.StartWhen != null && Array.IndexOf(rh.StartWhen, "planning_table_shown") >= 0);

        Check("(C) mend_the_wounded defined", Bulwark.Data.Quests.TryGet("mend_the_wounded", out var mw));
        Check("(C) mend_the_wounded has 2 objectives", mw!.Objectives.Length == 2);

        // 2 hand-wired opening quests + the 9-quest "The First Season" arc (design/tutorial_quests.md).
        Check("(C) All contains the 2 hand-wired + 9 arc quests", Bulwark.Data.Quests.All.Count == 11);
    }

    // ─────────────────── (D) Title screen scene ───────────────────

    private async Task RunTitleScreen()
    {
        GD.Print("-------------------- (D) Title screen --------------------");

        var packed = GD.Load<PackedScene>("res://scenes/ui/title_screen.tscn");
        Check("(D) title_screen.tscn loads", packed != null);
        if (packed == null) return;

        var title = packed.Instantiate<TitleScreen>();
        AddChild(title);
        await Frames(2);

        Check("(D) title screen instantiates and enters tree", title.IsInsideTree());
        Check("(D) %NewGameButton resolves", title.GetNodeOrNull("%NewGameButton") != null);
        Check("(D) %ContinueButton resolves", title.GetNodeOrNull("%ContinueButton") != null);
        Check("(D) %OptionsButton resolves", title.GetNodeOrNull("%OptionsButton") != null);
        Check("(D) %ToastLabel resolves", title.GetNodeOrNull("%ToastLabel") != null);

        // Test events
        int newGame = 0, cont = 0, opts = 0;
        title.NewGameRequested += () => newGame++;
        title.ContinueRequested += () => cont++;
        title.OptionsRequested += () => opts++;

        title.GetNode<Button>("%NewGameButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) NewGameRequested fires", newGame == 1);

        title.GetNode<Button>("%ContinueButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) ContinueRequested fires", cont == 1);

        title.GetNode<Button>("%OptionsButton").EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) OptionsRequested fires", opts == 1);
        Check("(D) options panel opens on Options press", title.IsOptionsPanelOpen);

        title.SetContinueVisible(false);
        Check("(D) SetContinueVisible(false) hides continue", !title.GetNode<Button>("%ContinueButton").Visible);

        title.QueueFree();
        await Frames(1);
    }

    // ─────────────────── (E) Name entry scene ───────────────────

    private async Task RunNameEntry()
    {
        GD.Print("-------------------- (E) Name entry --------------------");

        var packed = GD.Load<PackedScene>("res://scenes/ui/name_entry.tscn");
        Check("(E) name_entry.tscn loads", packed != null);
        if (packed == null) return;

        var entry = packed.Instantiate<NameEntryScreen>();
        AddChild(entry);
        await Frames(2);

        Check("(E) name entry instantiates and enters tree", entry.IsInsideTree());
        Check("(E) %NameInput resolves", entry.GetNodeOrNull("%NameInput") != null);
        Check("(E) %ConfirmButton resolves", entry.GetNodeOrNull("%ConfirmButton") != null);

        var input = entry.GetNode<LineEdit>("%NameInput");
        var confirm = entry.GetNode<Button>("%ConfirmButton");

        Check("(E) default name is Warden", input.Text == "Warden");
        Check("(E) confirm enabled with default name", !confirm.Disabled);

        // Empty name disables confirm
        input.Text = "";
        input.EmitSignal(LineEdit.SignalName.TextChanged, "");
        Check("(E) confirm disabled when empty", confirm.Disabled);

        // Set a name and confirm
        input.Text = "TestPlayer";
        input.EmitSignal(LineEdit.SignalName.TextChanged, "TestPlayer");
        Check("(E) confirm enabled with name", !confirm.Disabled);

        string? confirmedName = null;
        entry.NameConfirmed += name => confirmedName = name;
        confirm.EmitSignal(BaseButton.SignalName.Pressed);
        Check("(E) NameConfirmed fires with correct name", confirmedName == "TestPlayer");

        entry.QueueFree();
        await Frames(1);
    }

    // ─────────────────── (F) GameState.StartNewGame ───────────────────

    private void RunStartNewGame()
    {
        GD.Print("-------------------- (F) StartNewGame --------------------");

        var gs = GameState.Instance;
        if (gs == null)
        {
            GD.PushWarning("[MenuSpike] GameState not available — skipping StartNewGame checks.");
            return;
        }

        // This section mutates and DELETES the save slot; protect the user's real save around it.
        BackupSlot0();
        try
        {
            RunStartNewGameReset(gs);
        }
        finally
        {
            RestoreSlot0();
        }
    }

    private void RunStartNewGameReset(GameState gs)
    {
        // ── Simulate a played session: dirty a spread of persisted systems ──
        // clock date, gold, inventory, story flags (incl. the intro gate), quest log, a building,
        // friendship points, and a seen once-only dialogue.
        gs.Clock.RestoreState(1000, 5, gs.Clock.Season, gs.Clock.Year); // Day 5, ~4:40 PM
        gs.EarnGold(500);
        gs.AddItem("wood", 90);
        gs.AddItem("stone", 60);
        gs.SetStoryFlag("intro_complete");   // would skip the intro on a contaminated New Game
        gs.SetStoryFlag("lodging_repaired"); // completes repair_lodging
        gs.SetStoryFlag("first_rest");       // the scripted Day-1 close → starts planning_table
        gs.MarkDialogueSeen("intro_scene_0");
        gs.AddDialogueFriendship("tharr", 300); // 300 pts → ≥ 1 heart (PointsPerHeart = 250)

        // A building commission is the heaviest persisted mutation (consumes the wood/stone above +
        // gold, latches tier 1, and SAVES). Guarded: if the economy rejects it we skip only the
        // building assertions, never fail the reset proof.
        bool commissioned = gs.CommissionBuilding("trading_post");

        // Preconditions: confirm the mutations actually landed (else the reset asserts are hollow).
        Check("(F) pre: clock advanced to Day 5", gs.Clock.Day == 5);
        Check("(F) pre: gold mutated", gs.Gold > 0);
        Check("(F) pre: intro_complete flag set", gs.HasStoryFlag("intro_complete"));
        Check("(F) pre: repair_lodging completed, planning_table active",
            gs.IsQuestCompleted("repair_lodging") && gs.IsQuestActive("planning_table"));
        Check("(F) pre: dialogue marked seen", gs.HasSeenDialogue("intro_scene_0"));
        Check("(F) pre: friendship earned (tharr ≥ 1 heart)", gs.HeartsOf("tharr") >= 1);
        if (commissioned)
            Check("(F) pre: trading_post commissioned (tier ≥ 1)", gs.GetBuildingTier("trading_post") >= 1);
        Check("(F) pre: a save file was written", gs.SaveExists());

        // ── New Game: must wipe every one of the above back to fresh ──
        gs.StartNewGame("TestWarden");

        Check("(F) PlayerName set", gs.PlayerName == "TestWarden");
        Check("(F) clock reset to Day 1 at day-start",
            gs.Clock.Day == 1 && gs.Clock.MinuteOfDay == DayClock.DayStartMinute);
        Check("(F) clock reset to Spring, Year 1",
            gs.Clock.Season == Season.Spring && gs.Clock.Year == 1);
        Check("(F) gold reset to 0", gs.Gold == 0);
        Check("(F) intro_complete flag cleared (intro will play)", !gs.HasStoryFlag("intro_complete"));
        Check("(F) lodging_repaired flag cleared", !gs.HasStoryFlag("lodging_repaired"));
        Check("(F) quest log cleared (repair_lodging not completed)", !gs.IsQuestCompleted("repair_lodging"));
        Check("(F) quest log cleared (planning_table not active)", !gs.IsQuestActive("planning_table"));
        Check("(F) seen dialogues cleared", !gs.HasSeenDialogue("intro_scene_0"));
        Check("(F) friendship reset (tharr back to 0 hearts)", gs.HeartsOf("tharr") == 0);
        if (commissioned)
            Check("(F) building reset (trading_post back to tier 0)", gs.GetBuildingTier("trading_post") == 0);

        // Starter inventory re-seeded onto the now-empty pool (wood back to the starter 10, not 100).
        Check("(F) starter inventory seeded (turnip_seed)", gs.Inventory.Count("turnip_seed") > 0);
        Check("(F) starter inventory reset to starter amount (wood == 10)",
            gs.Inventory.Count("wood") == 10);
        Check("(F) prior save deleted by New Game", !gs.SaveExists());

        var qView = gs.GetQuestView();
        Check("(F) quest view accessible (not null)", qView != null);
        Check("(F) quest view has no completed quests", qView != null && qView.Completed.Count == 0);
    }

    // ── Save-slot protection (this section deletes user://save/slot0.json + its .bak) ──

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;
        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read);
        _slot0Backup = file?.GetAsText();
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        }
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
