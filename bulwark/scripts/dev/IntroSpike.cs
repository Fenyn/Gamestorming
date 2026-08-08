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
///  (A) Dialogue JSON files load correctly from the database (scene_0, scene_1a, scene_1b, scene_2,
///      tutorial). Scene 1 is split into two sequences on the top-down interior/exterior
///      convention — scene_1a plays outdoors (ford/yard/camp beats, gated on intro_scene_0, sets
///      intro_scene_1a) and scene_1b plays indoors (hearth beat onward, gated on intro_scene_1a,
///      sets the ORIGINAL intro_scene_1 flag that scene_2 and the outpost still gate on)
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
///  (I) Resume after a mid-intro quit: SceneRouter.ResumeRoute's five-state decision table
///      (fresh/scene0-done/scene1a-done/scene1-done/intro-complete), and scene-2 staging degrading
///      cleanly with no NPC instances.
///  (J) Simulated end-to-end playthrough of scene_0, scene_1a, and scene_1b: a real DialogueRunner
///      is driven over the authored steps with a stub director (auto-advance lines, auto-pick a
///      choice option, synchronous StagingComplete) to prove the whole sequence runs to
///      SequenceEnded and sets its closing flag — scene_0 runs twice (once per choice branch) to
///      prove both converge; scene_1a has no choice and runs once (asserts intro_scene_1a); scene_1b
///      runs three times (once per footing-choice option), each asserting the ORIGINAL intro_scene_1
///      flag, for the same convergence reason.
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
            RunScene0Playthrough();              // (J)
            RunScene1aPlaythrough();             // (J)
            RunScene1bPlaythrough();             // (J)
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
        Check("(A) intro_scene_1a exists", db.AllIds.Contains("intro_scene_1a"));
        Check("(A) intro_scene_1b exists", db.AllIds.Contains("intro_scene_1b"));
        Check("(A) intro_scene_2 exists", db.AllIds.Contains("intro_scene_2"));

        // Verify scene_0 is a sequence with steps (scene_0 is translated from its script — full
        // content checks apply).
        Check("(A) scene_0 is a sequence",
            db.TryGetSequence("intro_scene_0", out var scene0) && scene0.Steps != null && scene0.Steps.Count > 0);
        Check("(A) scene_0 once=true", scene0!.Once);

        // The first STEP overall is now staging (fade/camera/move precede any dialogue), so check
        // the first LINE step specifically.
        var scene0FirstLine = scene0.Steps!.FirstOrDefault(s => s.Type == "line");
        Check("(A) scene_0 first line step is Fenwick's \"Ah.\"",
            scene0FirstLine != null && scene0FirstLine.Speaker == "fenwick" && scene0FirstLine.Text == "Ah.");

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

        // Verify scene_0 sets the intro_scene_0 flag at the end
        Check("(A) scene_0 has a flag step setting intro_scene_0",
            scene0.Steps.Any(s => s.Type == "flag" && s.Set == "intro_scene_0"));

        // Verify every step type (including nested choice-option steps) is in the known vocabulary.
        // "prop" is the new staging type (scene node visibility toggle) a parallel engine agent is
        // wiring up in CutsceneDirector/DialogueRunner alongside scene_1's JSON.
        var knownStepTypes = new HashSet<string>
        {
            "line", "choice", "flag", "friendship", "item",
            "fade", "wait", "move", "enter", "exit", "face", "camera", "sfx", "emote", "prop",
        };
        Check("(A) scene_0 every step type is in the known vocabulary", AllStepTypesKnown(scene0.Steps, knownStepTypes));

        // scene_1a/scene_1b are translated from their script (design/story/intro_scene_1.md), split
        // on the top-down interior/exterior convention at the camp beat's relenting line — full
        // content checks apply to both, same as scene_0.
        Check("(A) scene_1a is a sequence",
            db.TryGetSequence("intro_scene_1a", out var scene1a) && scene1a.Steps != null && scene1a.Steps.Count > 0);
        Check("(A) scene_1a once=true", scene1a!.Once);
        Check("(A) scene_1a gated on intro_scene_0",
            scene1a.Conditions?.FlagsRequired != null && scene1a.Conditions.FlagsRequired.Contains("intro_scene_0"));

        Check("(A) scene_1b is a sequence",
            db.TryGetSequence("intro_scene_1b", out var scene1b) && scene1b.Steps != null && scene1b.Steps.Count > 0);
        Check("(A) scene_1b once=true", scene1b!.Once);
        Check("(A) scene_1b gated on intro_scene_1a",
            scene1b.Conditions?.FlagsRequired != null && scene1b.Conditions.FlagsRequired.Contains("intro_scene_1a"));

        // The first STEP overall is staging (enter/camera/prop/fade precede any dialogue), so check
        // the first LINE step specifically.
        var scene1aFirstLine = scene1a.Steps!.FirstOrDefault(s => s.Type == "line");
        Check("(A) scene_1a first line step is Fenwick's \"The far bank at last...\"",
            scene1aFirstLine != null && scene1aFirstLine.Speaker == "fenwick"
            && scene1aFirstLine.Text != null && scene1aFirstLine.Text.StartsWith("The far bank at last"));

        var scene1bFirstLine = scene1b.Steps!.FirstOrDefault(s => s.Type == "line");
        Check("(A) scene_1b first line step is Fenwick's \"Right. Let us see...\"",
            scene1bFirstLine != null && scene1bFirstLine.Speaker == "fenwick"
            && scene1bFirstLine.Text != null && scene1bFirstLine.Text.StartsWith("Right. Let us see"));

        // scene_1a is exterior staging only — it ends on the camp beat's relenting line and carries
        // no player choice (the footing choice moved indoors with the hearth beat).
        Check("(A) scene_1a has no choice step",
            !scene1a.Steps.Any(s => s.Type == "choice"));

        // Verify scene_1b has the footing choice with exactly 3 options
        bool hasChoice1b = false;
        foreach (var step in scene1b.Steps)
        {
            if (step.Type == "choice" && step.Options != null && step.Options.Count == 3)
            {
                hasChoice1b = true;
                break;
            }
        }
        Check("(A) scene_1b has a choice with exactly 3 options", hasChoice1b);

        // Verify scene_1a sets its own intro_scene_1a flag at the end (the exterior/interior split point).
        Check("(A) scene_1a has a flag step setting intro_scene_1a",
            scene1a.Steps.Any(s => s.Type == "flag" && s.Set == "intro_scene_1a"));

        // Verify scene_1b sets the ORIGINAL intro_scene_1 flag at the end — load-bearing: scene_2's
        // gating and the outpost's post-intro dialogue/quest flow key off this exact flag name, not
        // "intro_scene_1b".
        Check("(A) scene_1b has a flag step setting intro_scene_1 (the original flag, not intro_scene_1b)",
            scene1b.Steps.Any(s => s.Type == "flag" && s.Set == "intro_scene_1"));

        Check("(A) scene_1a every step type is in the known vocabulary", AllStepTypesKnown(scene1a.Steps, knownStepTypes));
        Check("(A) scene_1b every step type is in the known vocabulary", AllStepTypesKnown(scene1b.Steps, knownStepTypes));

        // scene_2 is intentionally an EMPTY placeholder awaiting its script (its design/story doc has
        // not been translated yet). Only existence + condition-gating are checked here; steps-non-empty
        // and choice-content checks return once that script is translated.
        Check("(A) scene_2 is a sequence",
            db.TryGetSequence("intro_scene_2", out var scene2) && scene2.Steps != null);
        Check("(A) scene_2 gated on intro_scene_1",
            scene2!.Conditions?.FlagsRequired != null && scene2.Conditions.FlagsRequired.Contains("intro_scene_1"));

        // ─── Staging integrity: scene_0's move/enter/exit/camera markers and actor ids must resolve
        // against road.tscn's marker/actor contract (scene_0's staging stays there). scene_1's
        // homestead staging is now split across TWO scenes on the top-down interior/exterior
        // convention — res://scenes/intro/homestead_exterior.tscn and
        // res://scenes/intro/homestead_interior.tscn — the parallel engine agent is building both to
        // this exact contract: road.tscn keeps only scene_0's ford/track markers (MarkPlayerStop,
        // MarkFenwickStop, MarkElaraEnter, MarkElaraLevel, MarkTrackBend, MarkTrackExit, MarkPilings)
        // plus %ActorPlayer/%ActorFenwick/%ActorElara; homestead_exterior.tscn holds scene_1a's ford/
        // yard/camp staging (MarkFordPlayer/Fenwick/Elara, MarkYardPlayer/Fenwick/Elara, the new door
        // marker MarkDoor, camera target MarkHomesteadCam, prop node EveningTint) plus its own
        // %ActorPlayer/%ActorFenwick/%ActorElara; homestead_interior.tscn holds scene_1b's hearth
        // staging (the new door marker MarkDoorInside, MarkHearthPlayer/Fenwick/Elara, camera target
        // MarkInteriorCam, prop nodes HearthFire / EveningTint) plus its own %ActorPlayer/
        // %ActorFenwick/%ActorElara — this check is written against that contract even though the
        // current files may predate it.
        var actorNodeNames = new Dictionary<string, string>
        {
            { "player", "ActorPlayer" },
            { "fenwick", "ActorFenwick" },
            { "elara", "ActorElara" },
        };

        var roadScenePacked = GD.Load<PackedScene>("res://scenes/intro/road.tscn");
        Check("(A) road.tscn loads as a PackedScene", roadScenePacked != null);
        if (roadScenePacked != null)
        {
            Node roadInstance = roadScenePacked.Instantiate();

            var markers0 = new HashSet<string>();
            var actorIds0 = new HashSet<string>();
            var propMarkers0 = new HashSet<string>();
            CollectStagingMarkers(scene0.Steps, markers0, actorIds0, propMarkers0);

            foreach (var marker in markers0)
            {
                Check($"(A) road.tscn marker %{marker} resolves",
                    roadInstance.GetNodeOrNull<Node3D>($"%{marker}") != null);
            }

            foreach (var actorId in actorIds0)
            {
                Check($"(A) road.tscn actor node for '{actorId}' resolves",
                    actorNodeNames.TryGetValue(actorId, out var nodeName)
                    && roadInstance.GetNodeOrNull<Node3D>($"%{nodeName}") != null);
            }

            // scene_0 has no "prop" steps today, but this stays generic in case it grows some.
            foreach (var propMarker in propMarkers0)
            {
                Check($"(A) road.tscn prop node %{propMarker} resolves",
                    roadInstance.GetNodeOrNull<Node>($"%{propMarker}") != null);
            }

            roadInstance.Free();
        }

        var homesteadExteriorPacked = GD.Load<PackedScene>("res://scenes/intro/homestead_exterior.tscn");
        Check("(A) homestead_exterior.tscn loads as a PackedScene", homesteadExteriorPacked != null);
        if (homesteadExteriorPacked != null)
        {
            Node exteriorInstance = homesteadExteriorPacked.Instantiate();

            var markers1a = new HashSet<string>();
            var actorIds1a = new HashSet<string>();
            var propMarkers1a = new HashSet<string>();
            CollectStagingMarkers(scene1a.Steps, markers1a, actorIds1a, propMarkers1a);

            foreach (var marker in markers1a)
            {
                Check($"(A) homestead_exterior.tscn marker %{marker} resolves",
                    exteriorInstance.GetNodeOrNull<Node3D>($"%{marker}") != null);
            }

            foreach (var actorId in actorIds1a)
            {
                Check($"(A) homestead_exterior.tscn actor node for '{actorId}' resolves",
                    actorNodeNames.TryGetValue(actorId, out var nodeName)
                    && exteriorInstance.GetNodeOrNull<Node3D>($"%{nodeName}") != null);
            }

            // "prop" step markers name a scene node whose visibility is toggled — e.g. %EveningTint
            // (a Node3D holding the dusk key light) — so resolve as a plain Node, which covers any shape.
            foreach (var propMarker in propMarkers1a)
            {
                Check($"(A) homestead_exterior.tscn prop node %{propMarker} resolves",
                    exteriorInstance.GetNodeOrNull<Node>($"%{propMarker}") != null);
            }

            exteriorInstance.Free();
        }

        var homesteadInteriorPacked = GD.Load<PackedScene>("res://scenes/intro/homestead_interior.tscn");
        Check("(A) homestead_interior.tscn loads as a PackedScene", homesteadInteriorPacked != null);
        if (homesteadInteriorPacked != null)
        {
            Node interiorInstance = homesteadInteriorPacked.Instantiate();

            var markers1b = new HashSet<string>();
            var actorIds1b = new HashSet<string>();
            var propMarkers1b = new HashSet<string>();
            CollectStagingMarkers(scene1b.Steps, markers1b, actorIds1b, propMarkers1b);

            foreach (var marker in markers1b)
            {
                Check($"(A) homestead_interior.tscn marker %{marker} resolves",
                    interiorInstance.GetNodeOrNull<Node3D>($"%{marker}") != null);
            }

            foreach (var actorId in actorIds1b)
            {
                Check($"(A) homestead_interior.tscn actor node for '{actorId}' resolves",
                    actorNodeNames.TryGetValue(actorId, out var nodeName)
                    && interiorInstance.GetNodeOrNull<Node3D>($"%{nodeName}") != null);
            }

            // "prop" step markers name a scene node whose visibility is toggled — e.g. %HearthFire
            // (a Node3D holding the emissive grate + its OmniLight3D) and %EveningTint (a Node3D
            // holding the dusk fill light) — so resolve as a plain Node, which covers any shape.
            foreach (var propMarker in propMarkers1b)
            {
                Check($"(A) homestead_interior.tscn prop node %{propMarker} resolves",
                    interiorInstance.GetNodeOrNull<Node>($"%{propMarker}") != null);
            }

            interiorInstance.Free();
        }

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

    /// <summary>True when every step's Type is in <paramref name="knownTypes"/>, recursing into
    /// choice options' inline continuation steps as well as the top-level list.</summary>
    private static bool AllStepTypesKnown(IEnumerable<DialogueStep> steps, HashSet<string> knownTypes)
    {
        foreach (var step in steps)
        {
            if (!knownTypes.Contains(step.Type))
                return false;

            if (step.Type == "choice" && step.Options != null)
            {
                foreach (var option in step.Options)
                {
                    if (option.Steps != null && !AllStepTypesKnown(option.Steps, knownTypes))
                        return false;
                }
            }
        }
        return true;
    }

    /// <summary>Collect move/enter/exit/camera markers (skipping "return"), actor ids, and prop-step
    /// markers from a step list — recursing into choice-option inline steps — for the road.tscn
    /// staging-integrity check.</summary>
    private static void CollectStagingMarkers(IEnumerable<DialogueStep> steps, HashSet<string> markers,
        HashSet<string> actorIds, HashSet<string> propMarkers)
    {
        foreach (var step in steps)
        {
            if (step.Type is "move" or "enter" or "exit" or "camera"
                && !string.IsNullOrEmpty(step.Marker)
                && !step.Marker.Equals("return", StringComparison.OrdinalIgnoreCase))
            {
                markers.Add(step.Marker);
            }
            if (!string.IsNullOrEmpty(step.Actor))
                actorIds.Add(step.Actor);
            if (step.Type == "prop" && !string.IsNullOrEmpty(step.Marker))
                propMarkers.Add(step.Marker);

            if (step.Type == "choice" && step.Options != null)
            {
                foreach (var option in step.Options)
                {
                    if (option.Steps != null)
                        CollectStagingMarkers(option.Steps, markers, actorIds, propMarkers);
                }
            }
        }
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

        // Scene 1a (exterior): requires intro_scene_0
        Check("(B) scene_1a NOT available without intro_scene_0",
            !db.IsAvailable("intro_scene_1a", ctxEmpty));

        var ctxScene0 = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_scene_0",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        Check("(B) scene_1a available with intro_scene_0", db.IsAvailable("intro_scene_1a", ctxScene0));

        // Scene 1b (interior): requires intro_scene_1a — NOT satisfied by intro_scene_0 alone.
        Check("(B) scene_1b NOT available without intro_scene_1a",
            !db.IsAvailable("intro_scene_1b", ctxScene0));

        var ctxScene1a = new DialogueConditionContext
        {
            HasFlag = f => f == "intro_scene_0" || f == "intro_scene_1a",
            GetHearts = _ => 0,
            CurrentSeason = "spring",
            HasSeenDialogue = _ => false,
        };
        Check("(B) scene_1b available with intro_scene_1a", db.IsAvailable("intro_scene_1b", ctxScene1a));

        // Scene 2: requires intro_scene_1 (unchanged — set by scene_1b, the interior half, at the end
        // of the split sequence)
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

        // Seed enough materials for multiple buildings (farmhouse: 120w+90s; smithy: 90w+40 hardwood+
        // 25fang — Buildings.cs; rat_pelt is no longer part of the smithy bundle, left seeded but unused).
        // Note: this is a raw BuildingSystem with no flagSatisfied resolver passed, so smithy's
        // RequiredFlagId gate is inert here (BuildingSystem's ctor comment: null resolver => every gate
        // treated as satisfied) — the checks below exercise one-at-a-time construction pacing only.
        inv.AddItem("wood", 500);
        inv.AddItem("stone", 500);
        inv.AddItem("herb", 100);
        inv.AddItem("goblin_fang", 100);
        inv.AddItem("rat_pelt", 100);
        inv.AddItem("hardwood", 100);

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
        // Stock smithy's exact construction bundle (90 wood/40 hardwood/25 goblin_fang/120 gold —
        // Buildings.cs; rat_pelt is no longer part of it).
        gs.AddItem("wood", 90);
        gs.AddItem("hardwood", 40);
        gs.AddItem("goblin_fang", 25);
        gs.SetStoryFlag("arkus_awake"); // Smithy's RequiredFlagId (Buildings.cs) — Arkus waking, not his arrival
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
    /// The mid-intro quit soft-lock fix: the Continue router resumes at the right place — Intro,
    /// HomesteadExterior, HomesteadInterior, or Outpost, depending on how far the intro flags got —
    /// and scene-2 staging degrades cleanly with no NPC instances.
    /// </summary>
    private void RunResumeMidIntro()
    {
        GD.Print("-------------------- (I) Resume mid-intro --------------------");

        // (I.a) Continue resume-route decision table (SceneRouter.ResumeRoute, now 4-arg with the
        // scene_1a split): introComplete OR scene1Done routes to the outpost; scene0Done+scene1aDone
        // (scene1 not yet played — the mid-intro quit soft-lock case, indoors) routes to the
        // homestead INTERIOR scene; scene0Done alone (scene1a not yet played — quit before the door)
        // routes to the homestead EXTERIOR scene instead of replaying the road from the top; no
        // flags set routes to the intro from the very beginning. Five meaningful states in all.
        Check("(I) resume routes to the intro when no scene flags are set (fresh start)",
            SceneRouter.ResumeRoute(introComplete: false, scene0Done: false, scene1aDone: false, scene1Done: false) == SceneRouter.Mode.Intro);
        Check("(I) resume routes to the homestead exterior when scene 0 is done but scene 1a is not (mid-intro quit before the door)",
            SceneRouter.ResumeRoute(introComplete: false, scene0Done: true, scene1aDone: false, scene1Done: false) == SceneRouter.Mode.HomesteadExterior);
        Check("(I) resume routes to the homestead interior when scene 1a is done but scene 1 is not (mid-intro quit at the hearth)",
            SceneRouter.ResumeRoute(introComplete: false, scene0Done: true, scene1aDone: true, scene1Done: false) == SceneRouter.Mode.HomesteadInterior);
        Check("(I) resume routes to the outpost when scene 1 is done but intro_complete is not (scene 2 pending there)",
            SceneRouter.ResumeRoute(introComplete: false, scene0Done: true, scene1aDone: true, scene1Done: true) == SceneRouter.Mode.Outpost);
        Check("(I) resume routes to the outpost once intro_complete is set (intro finished)",
            SceneRouter.ResumeRoute(introComplete: true, scene0Done: true, scene1aDone: true, scene1Done: true) == SceneRouter.Mode.Outpost);

        // (I.b) Scene-2 staging degrades cleanly with no NPC instances (F6/headless — no VillagerLoader):
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

    // ─────────────────── (J) Simulated end-to-end playthrough of scene_0 ───────────────────

    /// <summary>
    /// Drives a real <see cref="DialogueRunner"/> over scene_0's authored steps with a stub director
    /// (StageCommand completes synchronously) and auto-advance on every line, to prove the whole
    /// sequence — every staging step, every line, the choice branch, and the closing flag — runs
    /// start to finish without stalling. Run twice, once per choice option, to prove both branches
    /// converge to the same end.
    /// </summary>
    private void RunScene0Playthrough()
    {
        GD.Print("-------------------- (J) Scene 0 simulated playthrough --------------------");

        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(dialoguePath);
        bool loaded = db.TryGetSequence("intro_scene_0", out var scene0) && scene0.Steps != null;
        Check("(J) intro_scene_0 loads for playthrough", loaded);
        if (!loaded)
            return;

        PlayScene0Once(scene0!.Steps!, choiceIndex: 0, label: "option 0");
        PlayScene0Once(scene0.Steps!, choiceIndex: 1, label: "option 1");
    }

    /// <summary>One simulated playthrough of scene_0, auto-advancing lines, auto-completing staging,
    /// and picking <paramref name="choiceIndex"/> at the choice — asserts it reaches SequenceEnded and
    /// sets intro_scene_0.</summary>
    private void PlayScene0Once(List<DialogueStep> steps, int choiceIndex, string label)
    {
        var handler = new NullEffectHandler();
        var runner = new DialogueRunner(steps, handler, dialogueId: "intro_scene_0", once: true);

        bool ended = false;
        runner.LineReady += (_, _, _, _, _) => runner.Advance();
        runner.ChoicesReady += _ => runner.SelectChoice(choiceIndex);
        runner.StageCommand += _ => runner.StagingComplete();
        runner.SequenceEnded += () => ended = true;

        runner.Start();

        Check($"(J) scene_0 playthrough ({label}) reaches SequenceEnded", ended);
        Check($"(J) scene_0 playthrough ({label}) sets intro_scene_0", handler.SetFlags.Contains("intro_scene_0"));
    }

    // ─────────────────── (J) Simulated end-to-end playthrough of scene_1a ───────────────────

    /// <summary>
    /// Same harness as <see cref="RunScene0Playthrough"/>, driven over scene_1a's authored steps.
    /// scene_1a (exterior) carries no player choice, so it runs exactly once.
    /// </summary>
    private void RunScene1aPlaythrough()
    {
        GD.Print("-------------------- (J) Scene 1a simulated playthrough --------------------");

        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(dialoguePath);
        bool loaded = db.TryGetSequence("intro_scene_1a", out var scene1a) && scene1a.Steps != null;
        Check("(J) intro_scene_1a loads for playthrough", loaded);
        if (!loaded)
            return;

        PlayScene1aOnce(scene1a!.Steps!);
    }

    /// <summary>One simulated playthrough of scene_1a, auto-advancing lines and auto-completing every
    /// staging command (enter/camera/prop/fade/move/exit — no choice step exists in this half) —
    /// asserts it reaches SequenceEnded and sets intro_scene_1a (its own closing flag, distinct from
    /// the original intro_scene_1 that scene_1b sets).</summary>
    private void PlayScene1aOnce(List<DialogueStep> steps)
    {
        var handler = new NullEffectHandler();
        var runner = new DialogueRunner(steps, handler, dialogueId: "intro_scene_1a", once: true);

        bool ended = false;
        runner.LineReady += (_, _, _, _, _) => runner.Advance();
        runner.StageCommand += _ => runner.StagingComplete();
        runner.SequenceEnded += () => ended = true;

        runner.Start();

        Check("(J) scene_1a playthrough reaches SequenceEnded", ended);
        Check("(J) scene_1a playthrough sets intro_scene_1a", handler.SetFlags.Contains("intro_scene_1a"));
    }

    // ─────────────────── (J) Simulated end-to-end playthrough of scene_1b ───────────────────

    /// <summary>
    /// Same harness as <see cref="RunScene0Playthrough"/>, driven over scene_1b's authored steps. Run
    /// three times, once per footing-choice option, to prove all three converge to the same end.
    /// </summary>
    private void RunScene1bPlaythrough()
    {
        GD.Print("-------------------- (J) Scene 1b simulated playthrough --------------------");

        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(dialoguePath);
        bool loaded = db.TryGetSequence("intro_scene_1b", out var scene1b) && scene1b.Steps != null;
        Check("(J) intro_scene_1b loads for playthrough", loaded);
        if (!loaded)
            return;

        PlayScene1bOnce(scene1b!.Steps!, choiceIndex: 0, label: "option 0");
        PlayScene1bOnce(scene1b.Steps!, choiceIndex: 1, label: "option 1");
        PlayScene1bOnce(scene1b.Steps!, choiceIndex: 2, label: "option 2");
    }

    /// <summary>One simulated playthrough of scene_1b, auto-advancing lines, auto-completing staging,
    /// and picking <paramref name="choiceIndex"/> at the choice — asserts it reaches SequenceEnded and
    /// sets intro_scene_1 (the ORIGINAL flag — scene_1b, not scene_1a, is the half that closes the
    /// scene 1 arc that scene_2's gating and the outpost depend on).</summary>
    private void PlayScene1bOnce(List<DialogueStep> steps, int choiceIndex, string label)
    {
        var handler = new NullEffectHandler();
        var runner = new DialogueRunner(steps, handler, dialogueId: "intro_scene_1b", once: true);

        bool ended = false;
        runner.LineReady += (_, _, _, _, _) => runner.Advance();
        runner.ChoicesReady += _ => runner.SelectChoice(choiceIndex);
        runner.StageCommand += _ => runner.StagingComplete();
        runner.SequenceEnded += () => ended = true;

        runner.Start();

        Check($"(J) scene_1b playthrough ({label}) reaches SequenceEnded", ended);
        Check($"(J) scene_1b playthrough ({label}) sets intro_scene_1 (the original flag)", handler.SetFlags.Contains("intro_scene_1"));
    }

    /// <summary>No-op dialogue effect handler for the staging degrade test (section I) and the scene_0/
    /// scene_1a/scene_1b playthroughs (section J) — no GameState needed. Records every
    /// <see cref="SetFlag"/> call so a playthrough can assert on which flags were set.</summary>
    private sealed class NullEffectHandler : IDialogueEffectHandler
    {
        public List<string> SetFlags { get; } = new();
        public string? PlayerName => null;
        public void SetFlag(string flagId) => SetFlags.Add(flagId);
        public void AddFriendship(string charId, int amount) { }
        public void GiveItem(string itemId, int quantity) { }
        public void MarkSeen(string dialogueId) { }
    }
}
