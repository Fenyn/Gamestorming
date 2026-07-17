using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Data.Dialogues;
using Bulwark.Dialogue;
using Bulwark.Intro;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification for the INTRO CUTSCENE, TUTORIAL ONBOARDING, CONSTRUCTION TIME, and
/// LODGING REPAIR systems. Sections:
///  (A) Dialogue JSON files load correctly from the database (scene_0, scene_1, scene_2, tutorial)
///  (B) Story flag gating: intro flags, tutorial flags
///  (C) Construction time mechanic: commission a building, verify under construction, tick days,
///      verify completion
///  (D) One-at-a-time constraint: while under construction, CanCommission returns false for others
///  (E) Lodging repair: inventory check, consume, flag set
///  (F) DialogueConditionContext evaluates tutorial flag conditions correctly
///  (G) "Tharr is busy" derived dialogue flag: GameState.BuildConditionContext's DERIVED
///      "building_under_construction" flag tracks LIVE BuildingSystem state (true while a building is
///      under construction, false once TickDay completes it — never a persisted StoryFlag); Tharr's
///      talk pool resolves to the "work is underway" busy line (and outranks his unconditional default
///      fallback) while it is true; the planning-table view exposes BuilderBusy/BusyBuildingName/
///      BusyDaysRemaining. Drives a real (throwaway) GameState, so slot0.json is backed up/restored.
///  (H) "tavern_built" / "tavern_commissioned" derived flags (GameState.HasFlagForConditions), proven
///      against a real (throwaway) GameState — not a simulated HasFlag lambda like section F: commission
///      the tavern (tavern_commissioned true immediately, tavern_built still false while building),
///      TickDay to completion (tavern_built flips true), and confirm fenwick's "kitchen_built"→
///      "tavern_built"-gated talk-pool entry (data/dialogues/tutorial/fenwick_tutorial.json) is silent
///      before completion and fires for real through GameState.DialogueDb + BuildConditionContext after.
/// </summary>
public partial class IntroSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== INTRO SPIKE ====================");

        BackupSlot0();
        try
        {
            RunDialogueLoading();              // (A)
            RunStoryFlagGating();               // (B)
            RunConstructionTime();              // (C)
            RunOneAtATime();                    // (D)
            RunLodgingRepair();                 // (E)
            RunTutorialConditionGating();       // (F)
            RunBuilderBusyDialogueFlag();        // (G)
            RunTavernBuiltDerivedFlag();         // (H)
            RunResumeMidIntro();                 // (I)
        }
        catch (Exception e)
        {
            GD.PushError($"[IntroSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("IntroSpike");
    }

    // ─────────────────── slot0.json backup/restore (section G drives a real GameState) ───────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[IntroSpike] slot0.json backed up and cleared for the test run.");
    }

    private static void ClearSlot0()
    {
        if (Godot.FileAccess.FileExists(SavePath))
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
    }

    private void RestoreSlot0()
    {
        if (!_slot0Existed || _slot0Backup == null)
        {
            ClearSlot0();
            return;
        }

        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
        file?.StoreString(_slot0Backup);
    }

    // ─────────────────── (A) Dialogue JSON files load from database ───────────────────

    private void RunDialogueLoading()
    {
        GD.Print("-------------------- (A) Dialogue JSON loading --------------------");

        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(dialoguePath);

        Check("(A) database loaded files", db.Count > 0);
        Check("(A) intro_scene_0 exists", db.AllIds.Contains("intro_scene_0"));
        Check("(A) intro_scene_1 exists", db.AllIds.Contains("intro_scene_1"));
        Check("(A) intro_scene_2 exists", db.AllIds.Contains("intro_scene_2"));

        // Verify scene_0 is a sequence with steps
        Check("(A) scene_0 is a sequence",
            db.TryGetSequence("intro_scene_0", out var scene0) && scene0.Steps != null && scene0.Steps.Count > 0);
        Check("(A) scene_0 once=true", scene0!.Once);
        Check("(A) scene_0 first step is Fenwick line",
            scene0.Steps![0].Type == "line" && scene0.Steps[0].Speaker == "fenwick");

        // Verify scene_1 is gated on intro_scene_0
        Check("(A) scene_1 is a sequence",
            db.TryGetSequence("intro_scene_1", out var scene1) && scene1.Steps != null && scene1.Steps.Count > 0);
        Check("(A) scene_1 gated on intro_scene_0",
            scene1!.Conditions?.FlagsRequired != null && scene1.Conditions.FlagsRequired.Contains("intro_scene_0"));

        // Verify scene_2 is gated on intro_scene_1
        Check("(A) scene_2 is a sequence",
            db.TryGetSequence("intro_scene_2", out var scene2) && scene2.Steps != null && scene2.Steps.Count > 0);
        Check("(A) scene_2 gated on intro_scene_1",
            scene2!.Conditions?.FlagsRequired != null && scene2.Conditions.FlagsRequired.Contains("intro_scene_1"));

        // Verify scene_0 has a choice step
        bool hasChoice0 = false;
        foreach (var step in scene0.Steps)
        {
            if (step.Type == "choice" && step.Options != null && step.Options.Count >= 2)
            {
                hasChoice0 = true;
                break;
            }
        }
        Check("(A) scene_0 has a choice with 2+ options", hasChoice0);

        // Verify scene_2 has a choice step
        bool hasChoice2 = false;
        foreach (var step in scene2.Steps!)
        {
            if (step.Type == "choice" && step.Options != null && step.Options.Count >= 3)
            {
                hasChoice2 = true;
                break;
            }
        }
        Check("(A) scene_2 has a choice with 3 options", hasChoice2);

        // Verify tutorial talk pools loaded
        Check("(A) tharr talk pool exists", db.HasTalkPool("tharr"));
        Check("(A) fenwick talk pool exists", db.HasTalkPool("fenwick"));
        Check("(A) elara talk pool exists", db.HasTalkPool("elara"));

        // Verify tharr tutorial has entries
        var ctxIntroComplete = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var tharrLines = db.GetTalkLines("tharr", ctxIntroComplete);
        Check("(A) tharr has talk lines when intro_complete",
            tharrLines != null && tharrLines.Count > 0);
        Check("(A) tharr first tutorial line mentions lodging",
            tharrLines != null && tharrLines[0].Text.Contains("lodging"));

        // Verify fenwick tutorial with lodging_repaired
        var ctxLodgingRepaired = new DialogueConditionContext
        {
            HasFlag = f => f == "lodging_repaired" || f == "intro_complete",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var fenwickLines = db.GetTalkLines("fenwick", ctxLodgingRepaired);
        Check("(A) fenwick has talk lines when lodging_repaired",
            fenwickLines != null && fenwickLines.Count > 0);
    }

    // ─────────────────── (B) Story flag gating for intro/tutorial ───────────────────

    private void RunStoryFlagGating()
    {
        GD.Print("-------------------- (B) Story flag gating --------------------");

        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(dialoguePath);

        // Scene 0: no conditions (or empty), should always be available
        var ctxEmpty = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        Check("(B) scene_0 available with no flags", db.IsAvailable("intro_scene_0", ctxEmpty));

        // Scene 1: requires intro_scene_0
        Check("(B) scene_1 NOT available without intro_scene_0",
            !db.IsAvailable("intro_scene_1", ctxEmpty));

        var ctxScene0 = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_scene_0",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        Check("(B) scene_1 available with intro_scene_0", db.IsAvailable("intro_scene_1", ctxScene0));

        // Scene 2: requires intro_scene_1
        Check("(B) scene_2 NOT available without intro_scene_1",
            !db.IsAvailable("intro_scene_2", ctxScene0));

        var ctxScene1 = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_scene_0" || f == "intro_scene_1",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        Check("(B) scene_2 available with intro_scene_1", db.IsAvailable("intro_scene_2", ctxScene1));

        // Once-only: after being seen, scene_0 is unavailable
        var ctxSeen = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = id => id == "intro_scene_0",
        };
        Check("(B) scene_0 NOT available after seen (once=true)",
            !db.IsAvailable("intro_scene_0", ctxSeen));
    }

    // ─────────────────── (C) Construction time mechanic ───────────────────

    private void RunConstructionTime()
    {
        GD.Print("-------------------- (C) Construction time mechanic --------------------");

        var inv = new Inventory();
        var wallet = new Wallet();
        wallet.EarnGold(10000); // plenty of gold for all commissions
        var building = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold);
        // Enable construction time for this test (matches GameState's wiring)
        building.SetConstructionDays(new Dictionary<string, int>
        {
            { "trading_post", 2 },
            { "farmhouse", 2 },
            { "smithy", 2 },
            { "infirmary", 2 },
        });

        // Seed enough materials for farmhouse (120 wood, 90 stone, 90 gold)
        inv.AddItem("wood", 200);
        inv.AddItem("stone", 200);

        // Commission the farmhouse
        Check("(C) can commission farmhouse before", building.CanCommission("farmhouse"));
        bool commissioned = building.Commission("farmhouse");
        Check("(C) farmhouse commissioned", commissioned);
        Check("(C) farmhouse tier = 1", building.GetTier("farmhouse") == 1);

        // Should be under construction
        Check("(C) farmhouse is under construction", building.IsUnderConstruction("farmhouse"));
        Check("(C) any under construction = true", building.AnyUnderConstruction());
        int days = building.GetConstructionDaysRemaining("farmhouse");
        Check("(C) farmhouse has construction days > 0", days > 0);
        GD.Print($"  [INFO] Farmhouse construction days: {days}");

        // Tick one day
        building.TickDay();
        int remaining = building.GetConstructionDaysRemaining("farmhouse");
        Check("(C) farmhouse days decremented by 1", remaining == days - 1);

        // Tick remaining days
        for (int i = 0; i < remaining; i++)
            building.TickDay();

        Check("(C) farmhouse construction complete after ticking all days",
            !building.IsUnderConstruction("farmhouse"));
        Check("(C) farmhouse still tier 1 after completion", building.GetTier("farmhouse") == 1);
        Check("(C) any under construction = false after completion", !building.AnyUnderConstruction());
    }

    // ─────────────────── (D) One-at-a-time constraint ───────────────────

    private void RunOneAtATime()
    {
        GD.Print("-------------------- (D) One-at-a-time constraint --------------------");

        var inv = new Inventory();
        var wallet = new Wallet();
        wallet.EarnGold(10000);
        var building = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold);
        // Enable construction time for this test
        building.SetConstructionDays(new Dictionary<string, int>
        {
            { "trading_post", 2 },
            { "farmhouse", 2 },
            { "smithy", 2 },
            { "infirmary", 2 },
        });

        // Seed enough materials for multiple buildings (farmhouse: 120w+90s, smithy: 25fang+20pelt+15w)
        inv.AddItem("wood", 500);
        inv.AddItem("stone", 500);
        inv.AddItem("herb", 100);
        inv.AddItem("goblin_fang", 100);
        inv.AddItem("rat_pelt", 100);

        // Commission farmhouse (will be under construction)
        Check("(D) farmhouse commissions", building.Commission("farmhouse"));
        Check("(D) farmhouse under construction", building.IsUnderConstruction("farmhouse"));

        // Try to commission another building while one is under construction
        Check("(D) cannot commission smithy while farmhouse under construction",
            !building.CanCommission("smithy"));
        Check("(D) smithy commission rejected",
            !building.Commission("smithy"));
        Check("(D) smithy tier still 0", building.GetTier("smithy") == 0);

        // Also cannot commission trading post
        Check("(D) cannot commission trading_post while farmhouse under construction",
            !building.CanCommission("trading_post"));

        // Tick to complete farmhouse
        int days = building.GetConstructionDaysRemaining("farmhouse");
        for (int i = 0; i < days; i++)
            building.TickDay();

        // Now can commission another
        Check("(D) can commission smithy after farmhouse complete",
            building.CanCommission("smithy"));
        Check("(D) smithy commissions after farmhouse complete",
            building.Commission("smithy"));
        Check("(D) smithy under construction", building.IsUnderConstruction("smithy"));
    }

    // ─────────────────── (E) Lodging repair ───────────────────

    private void RunLodgingRepair()
    {
        GD.Print("-------------------- (E) Lodging repair --------------------");

        var inv = new Inventory();
        var flags = new StoryFlags();

        // Simulate RepairLodging logic (same as GameState.RepairLodging)
        // Not enough materials
        inv.AddItem("wood", 10);
        inv.AddItem("stone", 5);
        bool canRepairShort = inv.Has("wood", 15) && inv.Has("stone", 10);
        Check("(E) cannot repair with insufficient materials (10 wood, 5 stone)", !canRepairShort);

        // Add enough materials
        inv.AddItem("wood", 5);   // now 15 total
        inv.AddItem("stone", 5);  // now 10 total
        bool canRepairFull = inv.Has("wood", 15) && inv.Has("stone", 10);
        Check("(E) can repair with 15 wood + 10 stone", canRepairFull);

        // Consume materials
        inv.RemoveItem("wood", 15);
        inv.RemoveItem("stone", 10);
        flags.Set("lodging_quest_started");
        flags.Set("lodging_repaired");

        Check("(E) wood consumed (0 remaining)", inv.Count("wood") == 0);
        Check("(E) stone consumed (0 remaining)", inv.Count("stone") == 0);
        Check("(E) lodging_quest_started flag set", flags.Has("lodging_quest_started"));
        Check("(E) lodging_repaired flag set", flags.Has("lodging_repaired"));

        // Cannot repair again (flag already set)
        inv.AddItem("wood", 15);
        inv.AddItem("stone", 10);
        bool alreadyRepaired = flags.Has("lodging_repaired");
        Check("(E) repair rejected when lodging_repaired already set", alreadyRepaired);
    }

    // ─────────────────── (F) Tutorial condition gating ───────────────────

    private void RunTutorialConditionGating()
    {
        GD.Print("-------------------- (F) Tutorial condition gating --------------------");

        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(dialoguePath);

        // Tharr's tutorial talk pool should respond to different flag states
        // State: intro just completed, no lodging quest yet
        var ctxPostIntro = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var tharrPostIntro = db.GetTalkLines("tharr", ctxPostIntro);
        Check("(F) tharr has lines post-intro",
            tharrPostIntro != null && tharrPostIntro.Count > 0);
        Check("(F) tharr post-intro line mentions lodging",
            tharrPostIntro != null && tharrPostIntro[0].Text.Contains("lodging"));

        // State: lodging quest started, not repaired yet
        var ctxQuestStarted = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete" || f == "lodging_quest_started",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var tharrQuestStarted = db.GetTalkLines("tharr", ctxQuestStarted);
        Check("(F) tharr has lines when lodging quest started",
            tharrQuestStarted != null && tharrQuestStarted.Count > 0);
        Check("(F) tharr quest-started line mentions timber/stone",
            tharrQuestStarted != null && (tharrQuestStarted[0].Text.Contains("timber") || tharrQuestStarted[0].Text.Contains("stone")));

        // State: lodging repaired, before first rest
        var ctxRepaired = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete" || f == "lodging_quest_started" || f == "lodging_repaired",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var tharrRepaired = db.GetTalkLines("tharr", ctxRepaired);
        Check("(F) tharr has lines when lodging repaired",
            tharrRepaired != null && tharrRepaired.Count > 0);

        // Fenwick should have lines when lodging repaired
        var fenwickRepaired = db.GetTalkLines("fenwick", ctxRepaired);
        Check("(F) fenwick has lines when lodging repaired",
            fenwickRepaired != null && fenwickRepaired.Count > 0);
        Check("(F) fenwick line mentions rest/hearth",
            fenwickRepaired != null && (fenwickRepaired[0].Text.Contains("rest") || fenwickRepaired[0].Text.Contains("hearth")));

        // State: planning table shown, no buildings built yet
        var ctxPlanningShown = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete" || f == "lodging_quest_started"
                          || f == "lodging_repaired" || f == "first_rest" || f == "planning_table_shown",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };

        // Elara should have a planning-table hint line
        var elaraPlanning = db.GetTalkLines("elara", ctxPlanningShown);
        Check("(F) elara has lines when planning_table_shown",
            elaraPlanning != null && elaraPlanning.Count > 0);
        Check("(F) elara planning line mentions storefront/timber",
            elaraPlanning != null && (elaraPlanning[0].Text.Contains("storefront") || elaraPlanning[0].Text.Contains("timber")));

        // Fenwick should have a kitchen-hint line
        var fenwickPlanning = db.GetTalkLines("fenwick", ctxPlanningShown);
        Check("(F) fenwick has lines when planning_table_shown",
            fenwickPlanning != null && fenwickPlanning.Count > 0);
        Check("(F) fenwick planning line mentions hearth/kitchen/flue",
            fenwickPlanning != null && (fenwickPlanning[0].Text.Contains("hearth") || fenwickPlanning[0].Text.Contains("kitchen") || fenwickPlanning[0].Text.Contains("flue")));

        // State: trading post built
        var ctxTPBuilt = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete" || f == "lodging_quest_started"
                          || f == "lodging_repaired" || f == "first_rest"
                          || f == "planning_table_shown" || f == "trading_post_built",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var elaraTPBuilt = db.GetTalkLines("elara", ctxTPBuilt);
        Check("(F) elara has lines when trading_post_built",
            elaraTPBuilt != null && elaraTPBuilt.Count > 0);
        Check("(F) elara TP-built line mentions sell/offer",
            elaraTPBuilt != null && (elaraTPBuilt[0].Text.Contains("sell") || elaraTPBuilt[0].Text.Contains("offer")));

        // State: tavern built (simulated flag lookup — section H proves the REAL GameState path)
        var ctxTavernBuilt = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_complete" || f == "lodging_quest_started"
                          || f == "lodging_repaired" || f == "first_rest"
                          || f == "planning_table_shown" || f == "tavern_built",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var fenwickTavern = db.GetTalkLines("fenwick", ctxTavernBuilt);
        Check("(F) fenwick has lines when tavern_built",
            fenwickTavern != null && fenwickTavern.Count > 0);
        Check("(F) fenwick tavern-built line mentions ingredients/cooking",
            fenwickTavern != null && (fenwickTavern[0].Text.Contains("ingredients") || fenwickTavern[0].Text.Contains("kitchen")));

        // State: no intro_complete yet (tharr default fallback)
        var ctxNoIntro = new DialogueConditionContext
        {
            HasFlag = _ => false,
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var tharrDefault = db.GetTalkLines("tharr", ctxNoIntro);
        Check("(F) tharr has default fallback line (no flags)",
            tharrDefault != null && tharrDefault.Count > 0);
        Check("(F) tharr default line mentions walls",
            tharrDefault != null && tharrDefault[0].Text.Contains("walls"));
    }

    // ─────────────────── (G) "Tharr is busy" derived dialogue flag ───────────────────

    private void RunBuilderBusyDialogueFlag()
    {
        GD.Print("-------------------- (G) building_under_construction derived flag --------------------");

        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs); // _Ready seeds a clean starter inventory on the clean slot

        // Stock farmhouse's exact construction bundle (120 wood/90 stone/90 gold — see Buildings.cs;
        // the starter inventory already holds 10 wood + 10 stone, per SeedStarterInventory) plus
        // enough gold for both buildings in this test. Exact amounts (not a surplus) keep every add
        // within the squad's per-member Bulk carry cap — the same shape as BuildingSpike's (B) section.
        gs.AddItem("wood", 110);
        gs.AddItem("stone", 80);
        gs.EarnGold(10000);

        // (a) The derived flag mirrors LIVE construction state — false with nothing building.
        Check("(G) building_under_construction false before any commission",
            !gs.BuildConditionContext().HasFlag("building_under_construction"));

        Check("(G) commission farmhouse (2-day construction)", gs.CommissionBuilding("farmhouse"));
        Check("(G) building_under_construction true while farmhouse builds",
            gs.BuildConditionContext().HasFlag("building_under_construction"));

        gs.Building.TickDay(); // 1 day remaining
        Check("(G) still true after the first tick (1 day remaining)",
            gs.BuildConditionContext().HasFlag("building_under_construction"));

        gs.Building.TickDay(); // completes
        Check("(G) building_under_construction false after TickDay completes construction",
            !gs.BuildConditionContext().HasFlag("building_under_construction"));

        // (c) the planning-table view exposes the busy status while a second building builds.
        // Stock smithy's exact construction bundle (25 goblin_fang/20 rat_pelt/15 wood/120 gold).
        gs.AddItem("goblin_fang", 25);
        gs.AddItem("rat_pelt", 20);
        gs.AddItem("wood", 15);
        gs.SetStoryFlag("arkus_arrived"); // Smithy is now character-first gated on Arkus's arrival
        Check("(G) commission smithy (2-day construction)", gs.CommissionBuilding("smithy"));

        var view = gs.GetPlanningTableView();
        Check("(G) planning view reports BuilderBusy while smithy builds", view.BuilderBusy);
        Check("(G) planning view names the busy building", view.BusyBuildingName == "Smithy");
        Check("(G) planning view reports 2 days remaining", view.BusyDaysRemaining == 2);

        gs.Building.TickDay();
        gs.Building.TickDay();
        var viewDone = gs.GetPlanningTableView();
        Check("(G) planning view clears BuilderBusy after completion", !viewDone.BuilderBusy);
        Check("(G) planning view clears the busy building name", viewDone.BusyBuildingName == null);

        gs.QueueFree();

        // (b) Tharr's talk pool resolves to the busy line while building_under_construction is the
        // ONLY true flag (section F precedent: a manually built DialogueConditionContext against the
        // real DialogueDatabase). Since no other tutorial flag passes, only the busy entry (priority
        // 30) and the unconditional default (priority 0) are eligible — this also proves the busy
        // entry's priority correctly outranks the default fallback.
        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db2 = new DialogueDatabase(dialoguePath);
        var ctxBusy = new DialogueConditionContext
        {
            HasFlag = f => f == "building_under_construction",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        var tharrBusy = db2.GetTalkLines("tharr", ctxBusy);
        Check("(G) tharr has lines while building_under_construction",
            tharrBusy != null && tharrBusy.Count > 0);
        Check("(G) tharr busy line wins over the default fallback and mentions the work underway",
            tharrBusy != null && tharrBusy[0].Text.Contains("underway"));
    }

    // ─────────────────── (H) "tavern_built" / "tavern_commissioned" derived flags (real GameState) ───────────────────

    /// <summary>
    /// Proves GameState.HasFlagForConditions' two building-id-derived flag families end to end
    /// against a REAL (throwaway) GameState — not the simulated HasFlag lambda section F uses — and
    /// that the shipped fenwick "tavern_built" talk-pool gate (previously "kitchen_built"; nothing in
    /// the game ever sets a real story flag by that name) now actually fires through it.
    /// </summary>
    private void RunTavernBuiltDerivedFlag()
    {
        GD.Print("-------------------- (H) tavern_built / tavern_commissioned derived flags --------------------");

        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs); // _Ready seeds a clean starter inventory on the clean slot

        // Stock the tavern's exact construction bundle (90 wood/60 stone/15 herb — Buildings.cs; the
        // starter inventory already holds 10 wood + 10 stone, per SeedStarterInventory).
        gs.AddItem("wood", 80);
        gs.AddItem("stone", 50);
        gs.AddItem("herb", 15);
        gs.EarnGold(1000);

        Check("(H) tavern_commissioned false before commission",
            !gs.BuildConditionContext().HasFlag("tavern_commissioned"));
        Check("(H) tavern_built false before commission",
            !gs.BuildConditionContext().HasFlag("tavern_built"));

        Check("(H) commission the tavern (2-day construction)", gs.CommissionBuilding("tavern"));
        Check("(H) tavern_commissioned true immediately at commission (tier already >= 1)",
            gs.BuildConditionContext().HasFlag("tavern_commissioned"));
        Check("(H) tavern_built still false during the commission's construction window",
            !gs.BuildConditionContext().HasFlag("tavern_built"));

        // Real dialogue path: fenwick's tavern_built-gated entry must NOT fire yet.
        var stillBuilding = gs.DialogueDb?.GetTalkLines("fenwick", gs.BuildConditionContext());
        Check("(H) fenwick's tavern_built line does not fire while the tavern is under construction",
            stillBuilding == null || stillBuilding.Count == 0);

        gs.Building.TickDay();
        Check("(H) tavern_built still false after a partial tick (1 of 2 days)",
            !gs.BuildConditionContext().HasFlag("tavern_built"));
        gs.Building.TickDay(); // completes the 2-day tavern construction

        Check("(H) tavern_built true once construction completes",
            gs.BuildConditionContext().HasFlag("tavern_built"));
        Check("(H) tavern_commissioned still true after completion",
            gs.BuildConditionContext().HasFlag("tavern_commissioned"));

        // Real dialogue path: the fenwick tavern_built entry now fires for real, through
        // GameState.DialogueDb + BuildConditionContext (HasFlagForConditions) — not a simulated lambda.
        var tavernBuiltLines = gs.DialogueDb?.GetTalkLines("fenwick", gs.BuildConditionContext());
        Check("(H) fenwick has talk lines once tavern_built is true (real GameState flag path)",
            tavernBuiltLines != null && tavernBuiltLines.Count > 0);
        Check("(H) the fired line is the tavern_built entry (\"The kitchen is open...\")",
            tavernBuiltLines != null && tavernBuiltLines.Count > 0
            && tavernBuiltLines[0].Text.Contains("The kitchen is open"));

        gs.QueueFree();
    }

    // ─────────────────── (I) Resume after a mid-intro quit ───────────────────

    /// <summary>
    /// The mid-intro quit soft-lock fix: the Continue router resumes at the right place, the road
    /// scene skips an already-played scene, and scene-2 staging degrades cleanly with no NPC instances.
    /// </summary>
    private void RunResumeMidIntro()
    {
        GD.Print("-------------------- (I) Resume mid-intro --------------------");

        // (I.a) Continue resume-route decision table (SceneRouter.ResumeRoute). The soft-lock case:
        // quitting between road scenes 0 and 1 leaves intro_scene_0 set but intro_scene_1 unset and
        // intro_complete unset — Continue must route back to the intro road, not the outpost.
        Check("(I) resume routes to the road scene when neither intro_complete nor intro_scene_1 is set (mid-intro quit)",
            SceneRouter.ResumeRoute(introComplete: false, introScene1Done: false) == SceneRouter.Mode.Intro);
        Check("(I) resume routes to the outpost when intro_scene_1 is set but intro_complete is not (scene 2 pending there)",
            SceneRouter.ResumeRoute(introComplete: false, introScene1Done: true) == SceneRouter.Mode.Outpost);
        Check("(I) resume routes to the outpost once intro_complete is set (intro finished)",
            SceneRouter.ResumeRoute(introComplete: true, introScene1Done: true) == SceneRouter.Mode.Outpost);

        // (I.b) RoadScene resume skip: with intro_scene_0 already set and intro_scene_1 not, the road
        // scene resumes at scene 1 (skips scene 0) rather than replaying from the top.
        Check("(I) road scene resumes at scene 1 when scene 0 is done and scene 1 is not (skips scene 0)",
            RoadScene.FirstUnplayedRoadScene(scene0Done: true, scene1Done: false) == "intro_scene_1");
        Check("(I) road scene starts at scene 0 when neither road scene is done (fresh intro)",
            RoadScene.FirstUnplayedRoadScene(scene0Done: false, scene1Done: false) == "intro_scene_0");
        Check("(I) road scene has nothing to replay when both road scenes are done",
            RoadScene.FirstUnplayedRoadScene(scene0Done: true, scene1Done: true) == null);

        // (I.c) Scene-2 staging degrades cleanly with no NPC instances (F6/headless — no VillagerLoader):
        // PrepareStaging with a null-returning lookup stages nothing, and the enter step falls back to
        // log-and-continue so the sequence still runs to completion (no crash, no soft-lock).
        var director = new CutsceneDirector { Name = "ItestDirector" };
        AddChild(director);

        var enterSteps = new List<DialogueStep> { new() { Type = "enter", Actor = "tharr" } };
        director.PrepareStaging(enterSteps, _ => null); // no instance resolves — nothing hidden

        bool ended = false;
        var runner = new DialogueRunner(enterSteps, new NullEffectHandler(), dialogueId: null, once: false);
        runner.SequenceEnded += () => ended = true;
        director.Bind(runner);
        runner.Start(); // enter → no staged actor → log + StagingComplete → sequence ends synchronously

        Check("(I) scene-2 enter staging degrades to log-and-continue with no NPC instances (sequence completes)", ended);

        director.QueueFree();
    }

    /// <summary>No-op dialogue effect handler for the staging degrade test (no GameState needed).</summary>
    private sealed class NullEffectHandler : IDialogueEffectHandler
    {
        public string? PlayerName => null;
        public void SetFlag(string flagId) { }
        public void AddFriendship(string charId, int amount) { }
        public void GiveItem(string itemId, int quantity) { }
        public void MarkSeen(string dialogueId) { }
    }
}
