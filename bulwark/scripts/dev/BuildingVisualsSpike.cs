using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the building visual stage/overlay system (design/building_visuals.md).
/// Everything is built SYNTHETICALLY in code — no shipped scenes/buildings/*.tscn are read or
/// modified. Sections:
///  (A) BuildingVisualState (pure evaluator): tier-mapping passthrough with no rules; stage-override
///      last-match-wins; window-rule day-boundary inclusive/exclusive edges; flag rule +
///      UnlessFlag retirement; the season auto-key is always present; an invalid rule (both/neither
///      of OverlayKey+StageOverride set) is ignored with no crash.
///  (B) BuildingInstance.Apply against an in-memory-packed synthetic building (Node3D root +
///      %Stages/%Scaffold/%Overlays/%Footprint, one stage carrying its own collision shape): exactly
///      one stage visible at a time; scaffold shown + all stages hidden while under construction;
///      per-stage/scaffold collision Disabled tracks visibility; overlays toggle by key; null-safe on
///      a synthetic scene missing %Scaffold/%Overlays.
///  (C) BuildingLoader end-to-end against a synthetic catalog + a temp scene file written ONLY for
///      this spike (res://scenes/buildings/spike_visual_building.tscn, deleted afterward — never a
///      shipped id): an under-construction building places WITH its scaffold; TickDay completion →
///      Refresh swaps to the tier stage; a flag flip → stage override; a season change → overlay key
///      change.
///  (D) Back-compat: a BuildingLoader constructed WITHOUT the new delegates behaves exactly as
///      before — plain tier→SetStage — against the real (read-only) farmhouse.tscn.
///  (E) Pre-commission ruin placement: a tier-0 (never-commissioned) building with a marker + scene
///      is PLACED by the loader and shows Stage0 (the ruined/site look), keeps its %Footprint
///      collision, still honours season overlays and a story stage-override even at tier 0.
///  (F) Upgrade construction time: an upgrade (not just a commission) starts a construction window —
///      the loader shows %Scaffold during it, the building's PRIOR tier's effects stay live
///      (BuildingSystem.ActiveEffects) while the INCOMING tier's effects are suppressed, another
///      building's commission is blocked while the upgrade is in flight (one-at-a-time), and
///      completion (TickDay) flips the scaffold back to the new tier stage and admits the new tier's
///      effects.
///  (G) Shipped building scenes: loads every scenes/buildings/*.tscn and validates the placement
///      contract against Buildings.cs.
///  (H) Pre-placed instance adoption (Task B): the PRIMARY placement strategy is now a
///      BuildingInstance the user instances directly in outpost.tscn (matched by SceneFilePath, never
///      node name) — the loader ADOPTS it (drives it via Apply, tracks it) rather than spawning a
///      second instance, and NEVER repositions it. Proven against a host with NO %Building_&lt;id&gt;
///      marker at all, so a pass can only mean adoption worked.
///  (I) The tavern's lodging-repair visual payoff, full arc (design/tutorial.md Day 1 + Buildings.cs
///      Tavern.VisualRules), AND the "&lt;id&gt;_built"/"&lt;id&gt;_commissioned" derived-flag semantics
///      (GameState.HasFlagForConditions) — driven end to end through a real (throwaway) GameState +
///      the real BuildingLoader/BuildingVisualState against the real (read-only) shipped tavern.tscn:
///      Stage0 ruin on day one → RepairLodging sets the early Stage1 payoff (tier still 0) →
///      commissioning the tavern retires the override and shows the scaffold (tavern_commissioned
///      flips true immediately, tavern_built stays false) → completion shows Stage1 via ordinary tier
///      mapping (tavern_built flips true) → a tier-2 upgrade re-scaffolds (tavern_built stays true
///      throughout) → completion shows Stage2.
/// </summary>
public partial class BuildingVisualsSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== BUILDING VISUALS SPIKE ====================");
        try
        {
            RunEvaluator();
            RunInstanceApply();
            RunLoaderEndToEnd();
            RunBackCompat();
            RunTier0RuinPlacement();
            RunUpgradeConstructionWindow();
            RunShippedBuildingScenes();
            RunLoaderAdoption();
            RunLodgingRepairVisualArc();
        }
        catch (Exception e)
        {
            GD.PushError($"[BuildingVisualsSpike] Unhandled exception: {e}");
            Fail();
        }

        FinishAndQuit("BuildingVisualsSpike");
    }

    // ─────────────────── slot0.json backup/restore (section I drives a real GameState) ───────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[BuildingVisualsSpike] slot0.json backed up and cleared for the test run.");
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

    // ─────────────────────────── (A) BuildingVisualState evaluator ───────────────────────────

    private static readonly BuildingDefinition EvalDef = new()
    {
        Id = "spike_eval_building",
        DisplayName = "Spike Eval Building",
        ConstructionBundle = Array.Empty<BundleRequirement>(),
        Tiers = new BuildingTier[]
        {
            new() { Tier = 1, StageIndex = 1 },
            new() { Tier = 2, StageIndex = 2 },
            new() { Tier = 3, StageIndex = 3 },
        },
        VisualRules = new BuildingVisualRule[]
        {
            // Stage-override last-match-wins: rule A then rule B — B must win when both flags are set.
            new() { FlagId = "flagA", StageOverride = 10 },
            new() { FlagId = "flagB", StageOverride = 20 },
            // Window rule: Summer days 10..12 inclusive.
            new() { OverlayKey = "Festival_Harvest", Season = Season.Summer, FromDay = 10, ToDay = 12 },
            // Flag + UnlessFlag retirement.
            new() { OverlayKey = "Memorial_Plaque", FlagId = "flagC", UnlessFlagId = "flagD" },
            // Invalid: both OverlayKey and StageOverride set — must be ignored, never crash.
            new() { OverlayKey = "Bad", StageOverride = 99 },
            // Invalid: neither set — must also be ignored, never crash.
            new(),
        },
    };

    private void RunEvaluator()
    {
        GD.Print("-------------------- (A) BuildingVisualState evaluator --------------------");
        static bool NoFlags(string _) => false;

        // Tier-mapping passthrough: no rules match → StageIndexForTier(tier).
        var r1 = BuildingVisualState.Evaluate(EvalDef, tier: 2, isUnderConstruction: false, Season.Spring, dayOfSeason: 1, NoFlags);
        Check("(A) tier mapping passthrough (tier 2 → stage 2)", r1.StageIndex == 2);

        var r1b = BuildingVisualState.Evaluate(EvalDef, tier: 3, isUnderConstruction: true, Season.Spring, dayOfSeason: 1, NoFlags);
        Check("(A) isUnderConstruction does not affect StageIndex here (tier 3 → stage 3 regardless)", r1b.StageIndex == 3);

        // Stage-override last-match-wins.
        var r2 = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Spring, 1, f => f == "flagA");
        Check("(A) single override rule wins (flagA → 10)", r2.StageIndex == 10);

        var r3 = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Spring, 1, f => f == "flagA" || f == "flagB");
        Check("(A) last matching override wins when both flags set (flagB → 20, not 10)", r3.StageIndex == 20);

        // Window rule day-boundary inclusive/exclusive edges (Season.Summer, 10..12 inclusive).
        var beforeWindow = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Summer, dayOfSeason: 9, NoFlags);
        Check("(A) window: day 9 (before FromDay 10) does not match", !beforeWindow.OverlayKeys.Contains("Festival_Harvest"));

        var atFromDay = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Summer, dayOfSeason: 10, NoFlags);
        Check("(A) window: day 10 (FromDay, inclusive) matches", atFromDay.OverlayKeys.Contains("Festival_Harvest"));

        var atToDay = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Summer, dayOfSeason: 12, NoFlags);
        Check("(A) window: day 12 (ToDay, inclusive) matches", atToDay.OverlayKeys.Contains("Festival_Harvest"));

        var afterWindow = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Summer, dayOfSeason: 13, NoFlags);
        Check("(A) window: day 13 (after ToDay) does not match", !afterWindow.OverlayKeys.Contains("Festival_Harvest"));

        var wrongSeason = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Spring, dayOfSeason: 11, NoFlags);
        Check("(A) window: matching day but wrong season does not match", !wrongSeason.OverlayKeys.Contains("Festival_Harvest"));

        // Flag rule + UnlessFlag retirement.
        var flagOnly = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Spring, 1, f => f == "flagC");
        Check("(A) flag rule active once FlagId is set", flagOnly.OverlayKeys.Contains("Memorial_Plaque"));

        var flagRetired = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Spring, 1, f => f == "flagC" || f == "flagD");
        Check("(A) UnlessFlag retires an otherwise-active overlay", !flagRetired.OverlayKeys.Contains("Memorial_Plaque"));

        // Season auto-key always present, regardless of rules/flags.
        var auto1 = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Winter, 1, NoFlags);
        Check("(A) season auto-key always present (Winter)", auto1.OverlayKeys.Contains("Winter"));
        var auto2 = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Fall, 1, f => true);
        Check("(A) season auto-key present even with every flag set (Fall)", auto2.OverlayKeys.Contains("Fall"));

        // Invalid rules ignored with no crash, regardless of flags (Bad has both set; the trailing
        // rule has neither set).
        var invalid = BuildingVisualState.Evaluate(EvalDef, tier: 1, false, Season.Spring, 1, f => true);
        Check("(A) invalid rule (both keys set) never contributes an overlay key", !invalid.OverlayKeys.Contains("Bad"));
        Check("(A) invalid rule does not affect StageIndex (only valid overrides do — last valid is flagB → 20)",
            invalid.StageIndex == 20);
        Check("(A) evaluating a definition with invalid rules does not throw (reached this line)", true);
    }

    // ─────────────────────────── (B) BuildingInstance.Apply ───────────────────────────

    private void RunInstanceApply()
    {
        GD.Print("-------------------- (B) BuildingInstance.Apply --------------------");

        var full = PackRoot(BuildSyntheticRoot("SyntheticFull", withScaffoldAndOverlays: true)).Instantiate<BuildingInstance>();
        AddChild(full);

        // Exactly one stage visible at a time.
        full.Apply(1, false, Array.Empty<string>());
        Check("(B) stage 1 visible, siblings hidden", StageVisible(full, 1) && !StageVisible(full, 0) && !StageVisible(full, 2));

        full.Apply(2, false, Array.Empty<string>());
        Check("(B) switching to stage 2 hides stage 1", StageVisible(full, 2) && !StageVisible(full, 1));

        // Per-stage collision follows visibility (Stage1 carries its own CollisionShape3D).
        var stage1Shape = FindCollisionShape(StageNode(full, 1));
        Check("(B) stage 1 has a collision shape to test", stage1Shape != null);
        full.Apply(1, false, Array.Empty<string>());
        Check("(B) visible stage's collision is enabled", stage1Shape != null && !stage1Shape.Disabled);
        full.Apply(2, false, Array.Empty<string>());
        Check("(B) hidden stage's collision is disabled (hidden nodes still collide — the fix)",
            stage1Shape != null && stage1Shape.Disabled);

        // Scaffold shown + all stages hidden while under construction; scaffold collision enabled.
        full.Apply(1, true, Array.Empty<string>());
        Check("(B) scaffold visible while under construction", ScaffoldVisible(full));
        Check("(B) every stage hidden while scaffolded",
            !StageVisible(full, 0) && !StageVisible(full, 1) && !StageVisible(full, 2));
        var scaffoldShape = FindCollisionShape(full.GetNodeOrNull("%Scaffold"));
        Check("(B) scaffold has a collision shape to test", scaffoldShape != null);
        Check("(B) scaffold collision enabled while shown", scaffoldShape != null && !scaffoldShape.Disabled);

        full.Apply(1, false, Array.Empty<string>());
        Check("(B) scaffold hides once construction ends, stage 1 shows", !ScaffoldVisible(full) && StageVisible(full, 1));
        Check("(B) scaffold collision disabled once hidden", scaffoldShape != null && scaffoldShape.Disabled);

        // Overlays toggle by key.
        full.Apply(1, false, new[] { "Spring", "Festival_Harvest" });
        Check("(B) Spring overlay visible", OverlayVisible(full, "Spring"));
        Check("(B) Festival_Harvest overlay visible", OverlayVisible(full, "Festival_Harvest"));
        Check("(B) Summer overlay hidden (not in the key set)", !OverlayVisible(full, "Summer"));
        Check("(B) Memorial_Plaque overlay hidden (not in the key set)", !OverlayVisible(full, "Memorial_Plaque"));

        full.Apply(1, false, new[] { "Winter" });
        Check("(B) a new key set fully replaces the old (Spring now hidden, Winter shown)",
            !OverlayVisible(full, "Spring") && OverlayVisible(full, "Winter"));

        // Null-safe on a synthetic scene missing %Scaffold/%Overlays.
        var minimal = PackRoot(BuildSyntheticRoot("SyntheticMinimal", withScaffoldAndOverlays: false)).Instantiate<BuildingInstance>();
        AddChild(minimal);
        bool threw = false;
        try
        {
            minimal.Apply(1, true, new[] { "Spring" }); // underConstruction true, but no %Scaffold to swap to
        }
        catch
        {
            threw = true;
        }
        Check("(B) Apply on a scene missing %Scaffold/%Overlays does not throw", !threw);
        Check("(B) missing %Scaffold: falls back to showing the stage normally", StageVisible(minimal, 1));

        full.QueueFree();
        minimal.QueueFree();
    }

    // ─────────────────────────── (C) BuildingLoader end-to-end ───────────────────────────

    private const string SpikeBuildingId = "spike_visual_building";

    private static readonly BuildingDefinition SpikeVisualDef = new()
    {
        Id = SpikeBuildingId,
        DisplayName = "Spike Visual Building",
        ConstructionBundle = new BundleRequirement[] { new() { ItemId = "wood", Quantity = 1 } },
        Tiers = new BuildingTier[] { new() { Tier = 1, StageIndex = 1 } },
        VisualRules = new BuildingVisualRule[]
        {
            new() { FlagId = "spike_burned", StageOverride = 2 },
            new() { OverlayKey = "Festival_Harvest", Season = Season.Summer, FromDay = 10, ToDay = 15 },
        },
    };

    private void RunLoaderEndToEnd()
    {
        GD.Print("-------------------- (C) BuildingLoader end-to-end --------------------");

        string scenePath = SpikeVisualDef.ScenePath;
        string absPath = ProjectSettings.GlobalizePath(scenePath);
        bool preExisted = Godot.FileAccess.FileExists(scenePath);
        Check("(C) spike scene path is not a shipped building (nothing to protect)", !preExisted);
        if (preExisted)
            return; // never touch a file that was already there

        var packed = PackRoot(BuildSyntheticRoot("SpikeVisualBuilding", withScaffoldAndOverlays: true));
        Error saveErr = ResourceSaver.Save(packed, scenePath);
        Check("(C) synthetic building scene saved for the duration of this test", saveErr == Error.Ok);

        try
        {
            var inv = new Inventory();
            inv.AddItem("wood", 5);
            var wallet = new Wallet();
            var catalog = new[] { SpikeVisualDef };

            var bs = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold, catalog);
            bs.SetConstructionDays(new Dictionary<string, int> { [SpikeBuildingId] = 2 });

            var host = new Node3D { Name = "LoaderHost" };
            AddChild(host);
            var marker = new Marker3D { Name = $"Building_{SpikeBuildingId}" };
            host.AddChild(marker);

            Season season = Season.Spring;
            int day = 1;
            var storyFlags = new HashSet<string>();

            var loader = new BuildingLoader(
                host,
                id => bs.GetTier(id),
                id => bs.IsUnderConstruction(id),
                () => (season, day),
                id => storyFlags.Contains(id),
                catalog);

            Check("(C) commission the spike building", bs.Commission(SpikeBuildingId));
            Check("(C) commissioned building is under construction (tier already >= 1)",
                bs.GetTier(SpikeBuildingId) == 1 && bs.IsUnderConstruction(SpikeBuildingId));

            loader.PlaceCommissioned();
            var inst = FindBuildingInstance(host);
            Check("(C) under-construction building IS placed (not skipped)", inst != null);
            Check("(C) placed WITH scaffold visible", ScaffoldVisible(inst));
            Check("(C) placed with every stage hidden while scaffolded", !StageVisible(inst, 1));

            // TickDay completion (2-day build) → Refresh shows the tier stage only once fully done.
            bs.TickDay();
            loader.Refresh(SpikeBuildingId);
            Check("(C) still under construction after a partial tick (1 of 2 days)", bs.IsUnderConstruction(SpikeBuildingId));
            Check("(C) scaffold still visible mid-construction", ScaffoldVisible(inst));

            bs.TickDay();
            loader.Refresh(SpikeBuildingId);
            Check("(C) construction complete after the final TickDay", !bs.IsUnderConstruction(SpikeBuildingId));
            Check("(C) scaffold hides once construction completes", !ScaffoldVisible(inst));
            Check("(C) tier-1 stage shows once construction completes", StageVisible(inst, 1));

            // Flag flip → stage override.
            storyFlags.Add("spike_burned");
            loader.Refresh(SpikeBuildingId);
            Check("(C) flag-driven stage override shows stage 2 instead of the tier stage",
                StageVisible(inst, 2) && !StageVisible(inst, 1));

            // Season change → overlay key change.
            season = Season.Spring;
            day = 1;
            loader.Refresh(SpikeBuildingId);
            Check("(C) Spring overlay visible in Spring", OverlayVisible(inst, "Spring"));
            Check("(C) Festival_Harvest overlay hidden outside its window", !OverlayVisible(inst, "Festival_Harvest"));

            season = Season.Summer;
            day = 12;
            loader.Refresh(SpikeBuildingId);
            Check("(C) Spring overlay hides once season changes", !OverlayVisible(inst, "Spring"));
            Check("(C) Summer overlay shows once season changes", OverlayVisible(inst, "Summer"));
            Check("(C) Festival_Harvest overlay shows inside its window", OverlayVisible(inst, "Festival_Harvest"));

            Check("(C) RefreshAll is idempotent (no duplicate instance)", CountBuildingInstances(host) == 1);
            loader.RefreshAll();
            Check("(C) RefreshAll still no duplicate instance", CountBuildingInstances(host) == 1);
        }
        finally
        {
            if (Godot.FileAccess.FileExists(scenePath))
                DirAccess.RemoveAbsolute(absPath);
            string uidPath = absPath + ".uid";
            if (System.IO.File.Exists(uidPath))
                System.IO.File.Delete(uidPath);
            GD.Print("[BuildingVisualsSpike] temp spike building scene removed.");
        }
    }

    // ─────────────────────────── (D) Back-compat ───────────────────────────

    private void RunBackCompat()
    {
        GD.Print("-------------------- (D) Back-compat: loader without new delegates --------------------");

        var host = new Node3D { Name = "BackCompatHost" };
        AddChild(host);
        var marker = new Marker3D { Name = "Building_farmhouse", Position = new Vector3(6f, 0f, 3f) };
        host.AddChild(marker);

        int tier = 1;
        // No isUnderConstruction/calendar/hasFlag delegates — must fall back to plain tier→SetStage.
        var loader = new BuildingLoader(host, id => id == "farmhouse" ? tier : 0);
        loader.PlaceCommissioned();

        var inst = FindBuildingInstance(host);
        Check("(D) farmhouse placed at its marker (real, read-only shipped scene)",
            inst != null && inst.GlobalPosition == marker.GlobalPosition);
        Check("(D) placed building keeps its %Footprint", inst?.GetNodeOrNull("%Footprint") is StaticBody3D);
        Check("(D) tier 1 shows stage index 1 (plain SetStage behavior)", StageVisible(inst, 1) && !StageVisible(inst, 0));

        tier = 2;
        loader.Refresh("farmhouse");
        Check("(D) tier 2 swaps to stage index 2", StageVisible(inst, 2) && !StageVisible(inst, 1));
        Check("(D) refresh did not duplicate the instance", CountBuildingInstances(host) == 1);
    }

    // ─────────────────────────── (E) Pre-commission ruin placement (Change 1) ───────────────────────────

    private const string SpikeRuinBuildingId = "spike_ruin_building";

    private static readonly BuildingDefinition SpikeRuinDef = new()
    {
        Id = SpikeRuinBuildingId,
        DisplayName = "Spike Ruin Building",
        ConstructionBundle = new BundleRequirement[] { new() { ItemId = "wood", Quantity = 1 } },
        Tiers = new BuildingTier[] { new() { Tier = 1, StageIndex = 1 } },
        VisualRules = new BuildingVisualRule[]
        {
            new() { FlagId = "spike_ruin_rebuilt", StageOverride = 2 },
        },
    };

    /// <summary>
    /// design/building_visuals.md's authoring contract: "Stage0 = ruined site". A building nobody has
    /// commissioned yet is STILL placed in the world at its marker, showing Stage0 — never
    /// skipped/invisible (the intro has Elara spotting the collapsed trading post before it is ever
    /// commissioned). Overlay keys (season) and a story stage-override both still apply at tier 0.
    /// </summary>
    private void RunTier0RuinPlacement()
    {
        GD.Print("-------------------- (E) pre-commission ruin placement (tier 0) --------------------");

        string scenePath = SpikeRuinDef.ScenePath;
        string absPath = ProjectSettings.GlobalizePath(scenePath);
        bool preExisted = Godot.FileAccess.FileExists(scenePath);
        Check("(E) spike scene path is not a shipped building (nothing to protect)", !preExisted);
        if (preExisted)
            return; // never touch a file that was already there

        var packed = PackRoot(BuildSyntheticRoot("SpikeRuinBuilding", withScaffoldAndOverlays: true));
        Error saveErr = ResourceSaver.Save(packed, scenePath);
        Check("(E) synthetic building scene saved for the duration of this test", saveErr == Error.Ok);

        try
        {
            var catalog = new[] { SpikeRuinDef };
            var storyFlags = new HashSet<string>();
            Season season = Season.Winter;
            int day = 1;

            var host = new Node3D { Name = "RuinHost" };
            AddChild(host);
            var marker = new Marker3D { Name = $"Building_{SpikeRuinBuildingId}" };
            host.AddChild(marker);

            // tierOf always 0 — nothing ever commissions this building in this test.
            var loader = new BuildingLoader(
                host,
                _ => 0,
                _ => false,
                () => (season, day),
                id => storyFlags.Contains(id),
                catalog);

            loader.PlaceAll();
            var inst = FindBuildingInstance(host);
            Check("(E) tier-0 building IS placed by the loader (ruin visible from day one)", inst != null);
            Check("(E) tier-0 shows Stage0 (the ruined/site look)", StageVisible(inst, 0) && !StageVisible(inst, 1));
            Check("(E) placed ruin still carries a %Footprint (rubble blocks the cells)",
                inst?.GetNodeOrNull("%Footprint") is StaticBody3D);

            // Overlay keys still apply at stage 0 (a snowy ruin is fine and free).
            Check("(E) season overlay still applies at tier 0 (Winter)", OverlayVisible(inst, "Winter"));

            // A story stage-override still applies at tier 0 — BuildingVisualState computes StageIndex
            // from the rules/flags independent of tier (verified here, not assumed).
            storyFlags.Add("spike_ruin_rebuilt");
            loader.Refresh(SpikeRuinBuildingId);
            Check("(E) a story stage-override still wins at tier 0", StageVisible(inst, 2) && !StageVisible(inst, 0));

            Check("(E) RefreshAll is idempotent (no duplicate instance)", CountBuildingInstances(host) == 1);
        }
        finally
        {
            if (Godot.FileAccess.FileExists(scenePath))
                DirAccess.RemoveAbsolute(absPath);
            string uidPath = absPath + ".uid";
            if (System.IO.File.Exists(uidPath))
                System.IO.File.Delete(uidPath);
            GD.Print("[BuildingVisualsSpike] temp ruin building scene removed.");
        }
    }

    // ─────────────────────────── (F) Upgrade construction time (Change 2) ───────────────────────────

    private const string SpikeUpgradeBuildingId = "spike_upgrade_building";
    private const string SpikeUpgradeOtherBuildingId = "spike_upgrade_other";

    private static readonly BuildingDefinition SpikeUpgradeDef = new()
    {
        Id = SpikeUpgradeBuildingId,
        DisplayName = "Spike Upgrade Building",
        ConstructionBundle = Array.Empty<BundleRequirement>(),
        Tiers = new BuildingTier[]
        {
            new()
            {
                Tier = 1, StageIndex = 1,
                Effects = new BuildingEffect[] { new() { Type = BuildingEffectType.CategoryUnlock, Detail = "spike_tier1_shop" } },
            },
            new()
            {
                Tier = 2, StageIndex = 2,
                UpgradeBundle = new BundleRequirement[] { new() { ItemId = "wood", Quantity = 1 } },
                Effects = new BuildingEffect[] { new() { Type = BuildingEffectType.CategoryUnlock, Detail = "spike_tier2_shop" } },
            },
        },
    };

    /// <summary>A second, unrelated building in the same catalog — only used to prove the
    /// one-at-a-time constraint blocks a commission while a DIFFERENT building upgrades.</summary>
    private static readonly BuildingDefinition SpikeUpgradeOtherDef = new()
    {
        Id = SpikeUpgradeOtherBuildingId,
        DisplayName = "Spike Upgrade Other",
        ConstructionBundle = Array.Empty<BundleRequirement>(),
        Tiers = new BuildingTier[] { new() { Tier = 1, StageIndex = 1 } },
    };

    /// <summary>
    /// design/tutorial.md: "Tharr ... will be busy performing the upgrades for a day or two." An
    /// UPGRADE now starts a construction window exactly like a commission does — one-at-a-time
    /// enforced, the loader scaffolds the building, and TickDay completion is what admits the
    /// incoming tier. The nuance: unlike a commission (nothing live yet), an upgrade's PRIOR tier
    /// stays live throughout construction — Elara's store must not close while the addition goes up.
    /// </summary>
    private void RunUpgradeConstructionWindow()
    {
        GD.Print("-------------------- (F) upgrade construction window (prior tier stays live) --------------------");

        string scenePath = SpikeUpgradeDef.ScenePath;
        string absPath = ProjectSettings.GlobalizePath(scenePath);
        bool preExisted = Godot.FileAccess.FileExists(scenePath);
        Check("(F) spike scene path is not a shipped building (nothing to protect)", !preExisted);
        if (preExisted)
            return; // never touch a file that was already there

        var packed = PackRoot(BuildSyntheticRoot("SpikeUpgradeBuilding", withScaffoldAndOverlays: true));
        Error saveErr = ResourceSaver.Save(packed, scenePath);
        Check("(F) synthetic building scene saved for the duration of this test", saveErr == Error.Ok);

        try
        {
            var inv = new Inventory();
            inv.AddItem("wood", 5);
            var catalog = new[] { SpikeUpgradeDef, SpikeUpgradeOtherDef };
            var bs = new BuildingSystem(inv, catalog: catalog);
            // Same duration Commission uses (a per-tier duration is not needed). The "other" building
            // is left at the default (0 = instant) so its own commission timing never confuses this test.
            bs.SetConstructionDays(new Dictionary<string, int> { [SpikeUpgradeBuildingId] = 2 });

            // Commission also takes the configured 2 days (same lookup) — complete it first so the
            // rest of this test isolates the UPGRADE window specifically.
            Check("(F) commission spike_upgrade_building", bs.Commission(SpikeUpgradeBuildingId));
            Check("(F) tier1 effect NOT active during the commission's own construction window",
                !bs.ActiveEffects().Any(e => e.Detail == "spike_tier1_shop"));
            CompleteConstruction(bs);
            Check("(F) tier1 effect active once the commission completes",
                bs.ActiveEffects().Any(e => e.Detail == "spike_tier1_shop"));

            // Place it in the world and confirm the tier-1 stage shows, not scaffolded.
            var host = new Node3D { Name = "UpgradeHost" };
            AddChild(host);
            var marker = new Marker3D { Name = $"Building_{SpikeUpgradeBuildingId}" };
            host.AddChild(marker);
            var loader = new BuildingLoader(
                host,
                id => bs.GetTier(id),
                id => bs.IsUnderConstruction(id),
                () => (Season.Spring, 1),
                _ => false,
                catalog);
            loader.PlaceAll();
            var inst = FindBuildingInstance(host);
            Check("(F) tier-1 building placed, showing its stage (not scaffolded)",
                inst != null && StageVisible(inst, 1) && !ScaffoldVisible(inst));

            // Contribute + upgrade to tier 2 — now the UPGRADE's construction window starts.
            Check("(F) contribute wood toward the tier-2 bundle", bs.Contribute(SpikeUpgradeBuildingId, "wood", 1));
            Check("(F) upgrade accepted (starts the construction window)", bs.Upgrade(SpikeUpgradeBuildingId));
            Check("(F) tier reads 2 immediately (mirrors Commission's immediate tier-1 bump)",
                bs.GetTier(SpikeUpgradeBuildingId) == 2);
            Check("(F) building is under construction during the upgrade window",
                bs.IsUnderConstruction(SpikeUpgradeBuildingId));

            // One-at-a-time: another building's commission is blocked while this upgrade is in flight.
            Check("(F) another building's commission is blocked while this one upgrades",
                !bs.CanCommission(SpikeUpgradeOtherBuildingId) && !bs.Commission(SpikeUpgradeOtherBuildingId));

            // Effects nuance: prior tier (1) stays live, incoming tier (2) is suppressed.
            Check("(F) tier1 effect STAYS LIVE during the upgrade window (the store doesn't close)",
                bs.ActiveEffects().Any(e => e.Detail == "spike_tier1_shop"));
            Check("(F) tier2 effect is SUPPRESSED during the upgrade window",
                !bs.ActiveEffects().Any(e => e.Detail == "spike_tier2_shop"));

            // Visual: the loader shows the scaffold during the upgrade window too (it keys off
            // IsUnderConstruction, which is now true for upgrades as well as commissions).
            loader.Refresh(SpikeUpgradeBuildingId);
            Check("(F) upgrade window shows the scaffold (Tharr busy)", ScaffoldVisible(inst));
            Check("(F) every stage hides while scaffolded", !StageVisible(inst, 1) && !StageVisible(inst, 2));

            // Completion: TickDay closes the window, the loader swaps to the tier-2 stage, and the
            // incoming tier's effect finally arrives.
            CompleteConstruction(bs);
            Check("(F) upgrade construction complete", !bs.IsUnderConstruction(SpikeUpgradeBuildingId));
            loader.Refresh(SpikeUpgradeBuildingId);
            Check("(F) scaffold hides once the upgrade completes", !ScaffoldVisible(inst));
            Check("(F) tier-2 stage shows once the upgrade completes", StageVisible(inst, 2));
            Check("(F) tier2 effect now active after completion", bs.ActiveEffects().Any(e => e.Detail == "spike_tier2_shop"));
            Check("(F) tier1 effect still active (cumulative tiers stay)", bs.ActiveEffects().Any(e => e.Detail == "spike_tier1_shop"));

            // Now that this upgrade is done, the other building's commission is unblocked again.
            Check("(F) the other building can commission again now that nothing is under construction",
                bs.CanCommission(SpikeUpgradeOtherBuildingId));
        }
        finally
        {
            if (Godot.FileAccess.FileExists(scenePath))
                DirAccess.RemoveAbsolute(absPath);
            string uidPath = absPath + ".uid";
            if (System.IO.File.Exists(uidPath))
                System.IO.File.Delete(uidPath);
            GD.Print("[BuildingVisualsSpike] temp upgrade building scene removed.");
        }
    }

    private static void CompleteConstruction(BuildingSystem bs)
    {
        while (bs.AnyUnderConstruction())
            bs.TickDay();
    }

    // ─────────────────────────── (G) Shipped building scenes ───────────────────────────

    /// <summary>
    /// Loads each SHIPPED building scene (scenes/buildings/*.tscn) and validates the placement
    /// contract against its Buildings.cs data: it instantiates as a BuildingInstance; its %Stages
    /// child count is at least maxStageIndex+1; %Footprint is a StaticBody3D carrying a collision
    /// shape; every stage is built from MeshInstance3D geometry (greybox or an instanced .glb, both
    /// import as MeshInstance3D descendants); Apply(i, ...) leaves EXACTLY ONE stage visible for every
    /// valid index i; a stage that carries its OWN collider (a stage that changes the building's
    /// OUTLINE — trading_post's Stage0 ruin, command_post's Stage1 porch — per
    /// design/building_authoring_guide.md) tracks visibility exactly: enabled only while ITS OWN stage
    /// is the one Apply() shows, disabled under every other stage; and Apply() over every valid stage
    /// index plus the scaffold path runs without throwing. A scene with a missing ext_resource fails
    /// to instantiate cleanly, so a non-null instance with stage geometry is itself the
    /// missing-resource guard.
    /// </summary>
    private void RunShippedBuildingScenes()
    {
        GD.Print("-------------------- (G) shipped building scenes --------------------");

        foreach (string id in new[] { "command_post", "trading_post", "tavern", "farmhouse" })
        {
            var def = Buildings.Get(id);
            int expectedStages = MaxStageIndex(def) + 1;

            string scenePath = def.ScenePath;
            Check($"(G) {id}: scene file exists", Godot.FileAccess.FileExists(scenePath));
            var packed = GD.Load<PackedScene>(scenePath);
            Check($"(G) {id}: scene loads as PackedScene", packed != null);
            if (packed == null) continue;

            var inst = packed.InstantiateOrNull<BuildingInstance>();
            Check($"(G) {id}: instantiates as BuildingInstance", inst != null);
            if (inst == null) continue;
            AddChild(inst);

            var stages = inst.GetNodeOrNull("%Stages");
            Check($"(G) {id}: has %Stages", stages != null);
            // >= rather than == : command_post's scene still carries its full Stage0-4 art from
            // before the 2026-07-16 Command Post tier-deferral (design/economy/buildings.md) — its
            // BuildingDefinition now ships tier 1 only, so the scene legitimately has MORE painted
            // stages than the current data ladder uses, ready for whenever upgrade tiers are designed.
            Check($"(G) {id}: %Stages child count >= maxStageIndex+1 ({expectedStages})",
                stages != null && stages.GetChildCount() >= expectedStages);

            var footprint = inst.GetNodeOrNull("%Footprint");
            Check($"(G) {id}: %Footprint is a StaticBody3D", footprint is StaticBody3D);
            Check($"(G) {id}: %Footprint has a collision shape (box or polygon)",
                FindCollisionShape(footprint) != null || FindCollisionPolygon(footprint) != null);

            int meshes = 0;
            foreach (Node n in Descendants(stages!))
                if (n is MeshInstance3D) meshes++;
            Check($"(G) {id}: has geometry under %Stages ({meshes} MeshInstance3D)", meshes > 0);

            // Apply over every valid stage index + the scaffold path must run clean. Any stage-local
            // collider must track visibility: enabled only while its own stage is the one shown.
            bool threw = false;
            try
            {
                for (int i = 0; i < expectedStages; i++)
                {
                    inst.Apply(i, false, Array.Empty<string>());

                    int visibleCount = 0;
                    for (int j = 0; j < stages!.GetChildCount(); j++)
                    {
                        bool shouldBeEnabled = j == i;
                        var stageNode = stages.GetChild(j);
                        if (stageNode is Node3D stage3D && stage3D.Visible) visibleCount++;
                        foreach (Node n in Descendants(stageNode))
                        {
                            if (n is CollisionShape3D cs)
                                Check($"(G) {id}: stage {j} collider {(shouldBeEnabled ? "enabled" : "disabled")} while stage {i} shows",
                                    cs.Disabled == !shouldBeEnabled);
                            else if (n is CollisionPolygon3D cp)
                                Check($"(G) {id}: stage {j} collider {(shouldBeEnabled ? "enabled" : "disabled")} while stage {i} shows",
                                    cp.Disabled == !shouldBeEnabled);
                        }
                    }
                    Check($"(G) {id}: exactly one stage visible after Apply({i})", visibleCount == 1);
                }
                inst.Apply(1, true, Array.Empty<string>());  // scaffold path
                inst.Apply(1, false, Array.Empty<string>());
            }
            catch (Exception e)
            {
                threw = true;
                GD.PushError($"[BuildingVisualsSpike] {id} Apply threw: {e}");
            }
            Check($"(G) {id}: Apply over all stages + scaffold runs without throwing", !threw);

            // Stage 1 (the day-one restored look) must actually carry geometry.
            inst.Apply(1, false, Array.Empty<string>());
            int stage1Meshes = 0;
            if (stages!.GetChildCount() > 1)
                foreach (Node n in Descendants(stages.GetChild(1)))
                    if (n is MeshInstance3D) stage1Meshes++;
            Check($"(G) {id}: Stage1 has greybox geometry ({stage1Meshes} meshes)", stage1Meshes > 0);

            inst.QueueFree();
        }
    }

    private static int MaxStageIndex(BuildingDefinition def)
    {
        int max = 0;
        foreach (var t in def.Tiers)
            if (t.StageIndex > max) max = t.StageIndex;
        return max;
    }

    private static IEnumerable<Node> Descendants(Node node)
    {
        foreach (Node child in node.GetChildren())
        {
            yield return child;
            foreach (Node g in Descendants(child))
                yield return g;
        }
    }

    // ─────────────────────────── Synthetic scene builder ───────────────────────────

    /// <summary>
    /// Build a synthetic BuildingInstance node tree (never touching scenes/buildings/*.tscn):
    ///   Stages/Stage0,Stage1(+collision),Stage2 — Scaffold(+collision, optional) — Overlays
    ///   (Spring/Summer/Fall/Winter/Festival_Harvest/Memorial_Plaque, optional) — Footprint(+collision)
    ///   — Interact. Every node's Owner is wired to <paramref name="rootName"/>'s root so
    ///   <see cref="PackRoot"/> + Instantiate (or ResourceSaver.Save + GD.Load) round-trips the
    ///   %UniqueName lookups exactly like a real hand-authored building scene.
    /// </summary>
    private static BuildingInstance BuildSyntheticRoot(string rootName, bool withScaffoldAndOverlays)
    {
        var root = new BuildingInstance { Name = rootName };

        var stages = new Node3D { Name = "Stages", UniqueNameInOwner = true };
        root.AddChild(stages);
        stages.Owner = root;
        AddStage(stages, root, "Stage0", withCollision: false);
        AddStage(stages, root, "Stage1", withCollision: true);
        AddStage(stages, root, "Stage2", withCollision: false);

        if (withScaffoldAndOverlays)
        {
            var scaffold = new Node3D { Name = "Scaffold", UniqueNameInOwner = true, Visible = false };
            root.AddChild(scaffold);
            scaffold.Owner = root;
            AddCollisionBody(scaffold, root);

            var overlays = new Node3D { Name = "Overlays", UniqueNameInOwner = true };
            root.AddChild(overlays);
            overlays.Owner = root;
            foreach (string key in new[] { "Spring", "Summer", "Fall", "Winter", "Festival_Harvest", "Memorial_Plaque" })
            {
                var c = new Node3D { Name = key, Visible = false };
                overlays.AddChild(c);
                c.Owner = root;
            }
        }

        var footprint = new StaticBody3D { Name = "Footprint", UniqueNameInOwner = true };
        root.AddChild(footprint);
        footprint.Owner = root;
        var footprintShape = new CollisionShape3D { Name = "CollisionShape3D", Shape = new BoxShape3D { Size = new Vector3(2f, 2f, 2f) } };
        footprint.AddChild(footprintShape);
        footprintShape.Owner = root;

        var interact = new Marker3D { Name = "Interact", UniqueNameInOwner = true };
        root.AddChild(interact);
        interact.Owner = root;

        return root;
    }

    private static void AddStage(Node3D stages, Node root, string name, bool withCollision)
    {
        var stage = new Node3D { Name = name, Visible = false };
        stages.AddChild(stage);
        stage.Owner = root;
        if (withCollision)
            AddCollisionBody(stage, root);
    }

    /// <summary>A unique StaticBody3D + CollisionShape3D under <paramref name="parent"/> (per the
    /// unique-collision-shapes convention — never a shared sub_resource).</summary>
    private static void AddCollisionBody(Node3D parent, Node root)
    {
        var body = new StaticBody3D { Name = "Body" };
        parent.AddChild(body);
        body.Owner = root;
        var shape = new CollisionShape3D { Name = "CollisionShape3D", Shape = new BoxShape3D { Size = new Vector3(0.8f, 0.8f, 0.8f) } };
        body.AddChild(shape);
        shape.Owner = root;
    }

    private static PackedScene PackRoot(Node root)
    {
        var packed = new PackedScene();
        Error err = packed.Pack(root);
        if (err != Error.Ok)
            throw new InvalidOperationException($"[BuildingVisualsSpike] pack failed: {err}");
        return packed;
    }

    // ─────────────────────────── Query helpers ───────────────────────────

    private static Node? StageNode(BuildingInstance? inst, int index)
    {
        var stages = inst?.GetNodeOrNull("%Stages");
        if (stages == null || index < 0 || index >= stages.GetChildCount())
            return null;
        return stages.GetChild(index);
    }

    private static bool StageVisible(BuildingInstance? inst, int index)
        => StageNode(inst, index) is Node3D n3 && n3.Visible;

    private static bool ScaffoldVisible(BuildingInstance? inst)
        => inst?.GetNodeOrNull("%Scaffold") is Node3D n3 && n3.Visible;

    private static bool OverlayVisible(BuildingInstance? inst, string key)
    {
        var overlays = inst?.GetNodeOrNull("%Overlays");
        return overlays?.GetNodeOrNull(key) is Node3D n3 && n3.Visible;
    }

    private static CollisionShape3D? FindCollisionShape(Node? root)
    {
        if (root == null)
            return null;
        foreach (Node child in root.GetChildren())
        {
            if (child is CollisionShape3D cs)
                return cs;
            var found = FindCollisionShape(child);
            if (found != null)
                return found;
        }
        return null;
    }

    private static CollisionPolygon3D? FindCollisionPolygon(Node? root)
    {
        if (root == null)
            return null;
        foreach (Node child in root.GetChildren())
        {
            if (child is CollisionPolygon3D cp)
                return cp;
            var found = FindCollisionPolygon(child);
            if (found != null)
                return found;
        }
        return null;
    }

    private static BuildingInstance? FindBuildingInstance(Node host)
    {
        foreach (Node c in host.GetChildren())
            if (c is BuildingInstance bi)
                return bi;
        return null;
    }

    private static int CountBuildingInstances(Node host)
    {
        int n = 0;
        foreach (Node c in host.GetChildren())
            if (c is BuildingInstance)
                n++;
        return n;
    }

    // ─────────────────────────── (H) BuildingLoader pre-placed instance adoption (Task B) ───────────────────────────

    private const string SpikeAdoptBuildingId = "spike_adopt_building";

    private static readonly BuildingDefinition SpikeAdoptDef = new()
    {
        Id = SpikeAdoptBuildingId,
        DisplayName = "Spike Adopt Building",
        ConstructionBundle = new BundleRequirement[] { new() { ItemId = "wood", Quantity = 1 } },
        Tiers = new BuildingTier[] { new() { Tier = 1, StageIndex = 1 } },
    };

    /// <summary>
    /// Task B: the PRIMARY placement strategy is now a pre-placed <see cref="BuildingInstance"/> the
    /// user instances directly in outpost.tscn — matched by <see cref="Node.SceneFilePath"/>, never by
    /// node name — with the marker+instantiate path demoted to a fallback. Proves the loader ADOPTS a
    /// pre-placed instance (drives it via Apply, exactly like a spawned one), never spawns a SECOND
    /// instance alongside it, and NEVER repositions it (the user's hand-placement is authoritative).
    /// The host in this test carries NO %Building_&lt;id&gt; marker at all, so a pass can only mean
    /// adoption worked — a marker-fallback bug would find nothing and every check would fail.
    /// </summary>
    private void RunLoaderAdoption()
    {
        GD.Print("-------------------- (H) BuildingLoader pre-placed instance adoption --------------------");

        string scenePath = SpikeAdoptDef.ScenePath;
        string absPath = ProjectSettings.GlobalizePath(scenePath);
        bool preExisted = Godot.FileAccess.FileExists(scenePath);
        Check("(H) spike scene path is not a shipped building (nothing to protect)", !preExisted);
        if (preExisted)
            return; // never touch a file that was already there

        var packed = PackRoot(BuildSyntheticRoot("SpikeAdoptBuilding", withScaffoldAndOverlays: true));
        Error saveErr = ResourceSaver.Save(packed, scenePath);
        Check("(H) synthetic building scene saved for the duration of this test", saveErr == Error.Ok);

        try
        {
            var catalog = new[] { SpikeAdoptDef };

            // Pre-place the instance ourselves, exactly like the user would in the outpost editor:
            // load the shipped scene, instance it, give it an UNRELATED name, and drop it at an
            // arbitrary hand-picked position — no %Building_<id> marker anywhere in this host.
            var host = new Node3D { Name = "AdoptHost" };
            AddChild(host);
            var prePlacedScene = GD.Load<PackedScene>(scenePath);
            var prePlaced = prePlacedScene?.Instantiate<BuildingInstance>();
            Check("(H) pre-placed instance loads from its shipped scene path", prePlaced != null);
            if (prePlaced == null)
                return;
            prePlaced.Name = "HandPlacedTavernLikeThing"; // deliberately NOT "Building_spike_adopt_building"
            host.AddChild(prePlaced);
            var handPlacedPosition = new Vector3(77.7f, 0f, 33.3f);
            prePlaced.GlobalPosition = handPlacedPosition;
            Check("(H) pre-placed instance carries the definition's SceneFilePath",
                prePlaced.SceneFilePath == scenePath);

            var inv = new Inventory();
            inv.AddItem("wood", 5);
            var wallet = new Wallet();
            var bs = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold, catalog);

            var loader = new BuildingLoader(
                host,
                id => bs.GetTier(id),
                id => bs.IsUnderConstruction(id),
                () => (Season.Spring, 1),
                _ => false,
                catalog);

            loader.PlaceAll();

            Check("(H) no marker existed, yet the building IS placed (adopted, not marker-spawned)",
                FindBuildingInstance(host) != null);
            Check("(H) adoption did not duplicate the instance (still exactly one)",
                CountBuildingInstances(host) == 1);
            var adopted = FindBuildingInstance(host);
            Check("(H) the adopted instance IS the exact pre-placed node (same instance id)",
                adopted != null && adopted.GetInstanceId() == prePlaced.GetInstanceId());
            Check("(H) adoption never repositions the pre-placed instance",
                adopted != null && adopted.GlobalPosition == handPlacedPosition);
            Check("(H) the loader DRIVES the adopted instance (tier 0 → Stage0 now visible, was saved hidden)",
                StageVisible(adopted, 0));

            Check("(H) commission the adopted building", bs.Commission(SpikeAdoptBuildingId));
            loader.Refresh(SpikeAdoptBuildingId);
            Check("(H) after commission the SAME adopted instance now shows tier 1",
                StageVisible(adopted, 1) && !StageVisible(adopted, 0));
            Check("(H) still exactly one instance after the refresh (no duplicate spawned)",
                CountBuildingInstances(host) == 1);
        }
        finally
        {
            if (Godot.FileAccess.FileExists(scenePath))
                DirAccess.RemoveAbsolute(absPath);
            string uidPath = absPath + ".uid";
            if (System.IO.File.Exists(uidPath))
                System.IO.File.Delete(uidPath);
            GD.Print("[BuildingVisualsSpike] temp adopt building scene removed.");
        }
    }

    // ─────────────────────────── (I) Tavern lodging-repair arc + derived flags (Task C) ───────────────────────────

    /// <summary>
    /// Full end-to-end arc for Buildings.cs' Tavern.VisualRules payoff, driven through a real
    /// (throwaway) GameState + the real BuildingLoader/BuildingVisualState against the real,
    /// read-only shipped tavern.tscn (never written to). Also proves the "&lt;id&gt;_built" /
    /// "&lt;id&gt;_commissioned" derived-flag semantics inline as the arc progresses (Task C.1):
    /// tavern_built is false throughout the tavern's OWN commission construction window and true only
    /// once it completes; tavern_commissioned is true from the instant of commission, including
    /// throughout every later construction window (commission AND upgrade).
    /// </summary>
    private void RunLodgingRepairVisualArc()
    {
        GD.Print("-------------------- (I) tavern lodging-repair visual payoff — full arc --------------------");

        BackupSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs); // _Ready seeds a clean starter inventory (10 wood / 10 stone) on the clean slot

        try
        {
            var host = new Node3D { Name = "LodgingArcHost" };
            AddChild(host);
            var marker = new Marker3D { Name = "Building_tavern" };
            host.AddChild(marker);

            // No catalog passed → the loader drives off the REAL Buildings.All registry (includes the
            // shipped Tavern definition + its VisualRules), and gs.HasFlagForConditions is the REAL
            // derived-flag lookup (not a simulated lambda).
            var loader = new BuildingLoader(
                host,
                id => gs.GetBuildingTier(id),
                id => gs.Building.IsUnderConstruction(id),
                () => (gs.Clock.Season, gs.Clock.Day),
                id => gs.HasFlagForConditions(id));

            loader.PlaceAll();
            var inst = FindBuildingInstance(host);
            Check("(I) tavern instantiates at its marker from the real shipped scene", inst != null);
            Check("(I) day one: tavern shows Stage0 (the ruin) before repair/commission", StageVisible(inst, 0));
            Check("(I) tavern_built false before any of this", !gs.HasFlagForConditions("tavern_built"));
            Check("(I) tavern_commissioned false before any of this", !gs.HasFlagForConditions("tavern_commissioned"));

            // RepairLodging (15 wood / 10 stone) — starter inventory already holds 10/10; top up wood.
            gs.AddItem("wood", 5);
            Check("(I) RepairLodging succeeds", gs.RepairLodging());
            loader.Refresh("tavern");
            Check("(I) lodging_repaired flips the tavern to Stage1 EARLY (the visual payoff) despite tier 0",
                StageVisible(inst, 1) && !StageVisible(inst, 0));
            Check("(I) tavern_built still false (this is the early payoff, not an actual build)",
                !gs.HasFlagForConditions("tavern_built"));

            // Commission the tavern (90 wood / 60 stone / 15 herb / 70 gold) — the override must retire.
            gs.AddItem("wood", 90);
            gs.AddItem("stone", 60);
            gs.AddItem("herb", 15);
            gs.EarnGold(200);
            Check("(I) commission the tavern", gs.CommissionBuilding("tavern"));
            Check("(I) tavern_commissioned true immediately at commission",
                gs.HasFlagForConditions("tavern_commissioned"));
            loader.Refresh("tavern");
            Check("(I) commission retires the lodging-repair override — scaffold shows instead",
                ScaffoldVisible(inst));
            Check("(I) every stage hidden while scaffolded", !StageVisible(inst, 0) && !StageVisible(inst, 1));
            Check("(I) tavern_built still false during the tavern's OWN commission construction window",
                !gs.HasFlagForConditions("tavern_built"));

            // Complete the tavern's 2-day commission construction window (GameState wires tavern → 2 days).
            gs.Building.TickDay();
            Check("(I) still under construction after 1 of 2 days", gs.Building.IsUnderConstruction("tavern"));
            Check("(I) tavern_built still false mid-construction", !gs.HasFlagForConditions("tavern_built"));
            gs.Building.TickDay();
            Check("(I) construction complete after 2 days", !gs.Building.IsUnderConstruction("tavern"));
            loader.Refresh("tavern");
            Check("(I) completion: scaffold hides, Stage1 shows via ordinary tier mapping",
                !ScaffoldVisible(inst) && StageVisible(inst, 1));
            Check("(I) tavern_built true now that tier 1 has completed", gs.HasFlagForConditions("tavern_built"));
            Check("(I) tavern_commissioned still true after completion",
                gs.HasFlagForConditions("tavern_commissioned"));

            // Tier-2 upgrade (mead/egg/wild_mushroom/log_mushroom) — re-scaffolds; built stays true.
            gs.AddItem("mead", 15);
            gs.AddItem("egg", 25);
            gs.AddItem("wild_mushroom", 20);
            gs.AddItem("log_mushroom", 15);
            gs.EarnGold(500);
            Check("(I) contribute the full tier-2 bundle",
                gs.ContributeBundle("tavern", "mead", 15)
                && gs.ContributeBundle("tavern", "egg", 25)
                && gs.ContributeBundle("tavern", "wild_mushroom", 20)
                && gs.ContributeBundle("tavern", "log_mushroom", 15));
            Check("(I) upgrade to tier 2", gs.UpgradeBuilding("tavern"));
            loader.Refresh("tavern");
            Check("(I) upgrade window shows the scaffold again", ScaffoldVisible(inst));
            Check("(I) tavern_built STAYS true during the upgrade window (tier 1 already completed)",
                gs.HasFlagForConditions("tavern_built"));

            gs.Building.TickDay();
            gs.Building.TickDay();
            loader.Refresh("tavern");
            Check("(I) tier-2 upgrade completes: scaffold hides, Stage2 shows",
                !ScaffoldVisible(inst) && StageVisible(inst, 2));
            Check("(I) tavern_built still true after the upgrade completes", gs.HasFlagForConditions("tavern_built"));
        }
        finally
        {
            gs.QueueFree();
            RestoreSlot0();
        }
    }
}
