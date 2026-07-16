using System;
using System.Collections.Generic;
using System.Linq;
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
///  (B) BuildingInstance.Apply against an in-memory-packed synthetic building (Node2D root +
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
/// </summary>
public partial class BuildingVisualsSpike : SpikeBase
{
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
        }
        catch (Exception e)
        {
            GD.PushError($"[BuildingVisualsSpike] Unhandled exception: {e}");
            Fail();
        }

        FinishAndQuit("BuildingVisualsSpike");
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

        // Per-stage collision follows visibility (Stage1 carries its own CollisionShape2D).
        var stage1Shape = FindCollisionShape(StageNode(full, 1));
        Check("(B) stage 1 has a collision shape to test", stage1Shape != null);
        full.Apply(1, false, Array.Empty<string>());
        Check("(B) visible stage's collision is enabled", stage1Shape != null && !stage1Shape.Disabled);
        full.Apply(2, false, Array.Empty<string>());
        Check("(B) hidden stage's collision is disabled (hidden CanvasItems still collide — the fix)",
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

            var host = new Node2D { Name = "LoaderHost" };
            AddChild(host);
            var marker = new Marker2D { Name = $"Building_{SpikeBuildingId}" };
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

        var host = new Node2D { Name = "BackCompatHost" };
        AddChild(host);
        var marker = new Marker2D { Name = "Building_farmhouse", Position = new Vector2(64, 32) };
        host.AddChild(marker);

        int tier = 1;
        // No isUnderConstruction/calendar/hasFlag delegates — must fall back to plain tier→SetStage.
        var loader = new BuildingLoader(host, id => id == "farmhouse" ? tier : 0);
        loader.PlaceCommissioned();

        var inst = FindBuildingInstance(host);
        Check("(D) farmhouse placed at its marker (real, read-only shipped scene)",
            inst != null && inst.GlobalPosition == marker.GlobalPosition);
        Check("(D) placed building keeps its %Footprint", inst?.GetNodeOrNull("%Footprint") is StaticBody2D);
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

            var host = new Node2D { Name = "RuinHost" };
            AddChild(host);
            var marker = new Marker2D { Name = $"Building_{SpikeRuinBuildingId}" };
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
            Check("(E) placed ruin still carries a %Footprint (rubble blocks the tiles)",
                inst?.GetNodeOrNull("%Footprint") is StaticBody2D);

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
            var host = new Node2D { Name = "UpgradeHost" };
            AddChild(host);
            var marker = new Marker2D { Name = $"Building_{SpikeUpgradeBuildingId}" };
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
    /// Loads each SHIPPED building scene (scenes/buildings/*.tscn, authored by BuildingSceneBuilder)
    /// and validates the placement contract against its Buildings.cs data: it instantiates as a
    /// BuildingInstance; its %Stages child count equals maxStageIndex+1; %Footprint carries a
    /// CollisionShape2D; EVERY TileMapLayer under %Stages has collision_enabled == false (the footprint
    /// owns all blocking); and Apply() over every valid stage index plus the scaffold path runs without
    /// throwing. A scene with a missing ext_resource (prop/tileset/frames) fails to instantiate cleanly,
    /// so a non-null instance with painted stage tiles is itself the missing-resource guard.
    /// </summary>
    private void RunShippedBuildingScenes()
    {
        GD.Print("-------------------- (G) shipped building scenes --------------------");

        foreach (string id in new[] { "command_post", "trading_post", "kitchen", "farmhouse" })
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
            Check($"(G) {id}: %Stages child count == maxStageIndex+1 ({expectedStages})",
                stages != null && stages.GetChildCount() == expectedStages);

            var footprint = inst.GetNodeOrNull("%Footprint");
            Check($"(G) {id}: %Footprint is a StaticBody2D", footprint is StaticBody2D);
            Check($"(G) {id}: %Footprint has a CollisionShape2D", FindCollisionShape(footprint) != null);

            int layers = 0, colliding = 0;
            foreach (Node n in Descendants(stages!))
                if (n is TileMapLayer tml)
                {
                    layers++;
                    if (tml.CollisionEnabled) colliding++;
                }
            Check($"(G) {id}: has painted TileMapLayers under %Stages ({layers})", layers > 0);
            Check($"(G) {id}: EVERY TileMapLayer under %Stages has collision_enabled == false",
                colliding == 0);

            // Apply over every valid stage index + the scaffold path must run clean.
            bool threw = false;
            try
            {
                for (int i = 0; i < expectedStages; i++)
                    inst.Apply(i, false, Array.Empty<string>());
                inst.Apply(1, true, Array.Empty<string>());  // scaffold path
                inst.Apply(1, false, Array.Empty<string>());
            }
            catch (Exception e)
            {
                threw = true;
                GD.PushError($"[BuildingVisualsSpike] {id} Apply threw: {e}");
            }
            Check($"(G) {id}: Apply over all stages + scaffold runs without throwing", !threw);

            // Stage 1 (the day-one restored look) must actually carry painted tiles somewhere.
            inst.Apply(1, false, Array.Empty<string>());
            int stage1Cells = 0;
            if (stages!.GetChildCount() > 1)
                foreach (Node n in Descendants(stages.GetChild(1)))
                    if (n is TileMapLayer tml) stage1Cells += tml.GetUsedCells().Count;
            Check($"(G) {id}: Stage1 has painted tiles ({stage1Cells} cells)", stage1Cells > 0);

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

        var stages = new Node2D { Name = "Stages", UniqueNameInOwner = true };
        root.AddChild(stages);
        stages.Owner = root;
        AddStage(stages, root, "Stage0", withCollision: false);
        AddStage(stages, root, "Stage1", withCollision: true);
        AddStage(stages, root, "Stage2", withCollision: false);

        if (withScaffoldAndOverlays)
        {
            var scaffold = new Node2D { Name = "Scaffold", UniqueNameInOwner = true, Visible = false };
            root.AddChild(scaffold);
            scaffold.Owner = root;
            AddCollisionBody(scaffold, root);

            var overlays = new Node2D { Name = "Overlays", UniqueNameInOwner = true };
            root.AddChild(overlays);
            overlays.Owner = root;
            foreach (string key in new[] { "Spring", "Summer", "Fall", "Winter", "Festival_Harvest", "Memorial_Plaque" })
            {
                var c = new ColorRect { Name = key, Visible = false, Size = new Vector2(4, 4) };
                overlays.AddChild(c);
                c.Owner = root;
            }
        }

        var footprint = new StaticBody2D { Name = "Footprint", UniqueNameInOwner = true };
        root.AddChild(footprint);
        footprint.Owner = root;
        var footprintShape = new CollisionShape2D { Name = "CollisionShape2D", Shape = new RectangleShape2D { Size = new Vector2(20, 20) } };
        footprint.AddChild(footprintShape);
        footprintShape.Owner = root;

        var interact = new Marker2D { Name = "Interact", UniqueNameInOwner = true };
        root.AddChild(interact);
        interact.Owner = root;

        return root;
    }

    private static void AddStage(Node2D stages, Node root, string name, bool withCollision)
    {
        var stage = new Node2D { Name = name, Visible = false };
        stages.AddChild(stage);
        stage.Owner = root;
        if (withCollision)
            AddCollisionBody(stage, root);
    }

    /// <summary>A unique StaticBody2D + CollisionShape2D under <paramref name="parent"/> (per the
    /// unique-collision-shapes convention — never a shared sub_resource).</summary>
    private static void AddCollisionBody(Node2D parent, Node root)
    {
        var body = new StaticBody2D { Name = "Body" };
        parent.AddChild(body);
        body.Owner = root;
        var shape = new CollisionShape2D { Name = "CollisionShape2D", Shape = new RectangleShape2D { Size = new Vector2(8, 8) } };
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
        => StageNode(inst, index) is CanvasItem ci && ci.Visible;

    private static bool ScaffoldVisible(BuildingInstance? inst)
        => inst?.GetNodeOrNull("%Scaffold") is CanvasItem ci && ci.Visible;

    private static bool OverlayVisible(BuildingInstance? inst, string key)
    {
        var overlays = inst?.GetNodeOrNull("%Overlays");
        return overlays?.GetNodeOrNull(key) is CanvasItem ci && ci.Visible;
    }

    private static CollisionShape2D? FindCollisionShape(Node? root)
    {
        if (root == null)
            return null;
        foreach (Node child in root.GetChildren())
        {
            if (child is CollisionShape2D cs)
                return cs;
            var found = FindCollisionShape(child);
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
}
