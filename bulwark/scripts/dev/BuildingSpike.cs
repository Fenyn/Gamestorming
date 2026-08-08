using System;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.UI;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the Phase-2 build loop (planning table → commission → contribute →
/// upgrade + placement + persistence). Sections:
///  (A) BuildingSystem accounting over an unbound (flat, no Bulk cap) inventory — commission rejects
///      when unaffordable (nothing consumed) and accepts when affordable (bundle consumed, Built
///      tier 1); contributions accumulate partials, reject overshoot / off-bundle items / already-
///      satisfied lines; upgrade advances the tier ONLY when the bundle is complete; the planning
///      view reports have/need correctly.
///  (B) Full GameState command path + save/load: a rejected commission consumes nothing; a valid
///      commission + partial contribution round-trip exactly through SaveGame → a fresh GameState's
///      LoadGame (tier + accumulated contributions restored).
///  (C) BuildingLoader is null-safe with no marker/scene present (no throw), places a commissioned
///      building at its marker, and swaps its visual STAGE on tier change without duplicating it.
///  (D) UI smoke: build_panel.tscn instantiates, builds one row per building from the view-model,
///      and raises the commission intent when an enabled button is pressed.
///  (E) trading_post building commissions and upgrades through the normal build loop.
///  (F) Gold seam: a spike-local BuildingDefinition (never touching the shipped Buildings registry)
///      with a non-zero GoldCost/tier GoldCost, passed via BuildingSystem's optional catalog
///      parameter. Validates commission and upgrade each reject cleanly (nothing consumed, gold
///      untouched) when the wallet is short, and succeed with both the bundle AND gold deducted once
///      affordable — the same validate-then-spend shape as the material-only checks in (A).
/// The user's slot0.json is backed up and restored around the run.
/// </summary>
public partial class BuildingSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== BUILDING SPIKE ====================");

        BackupSlot0();
        try
        {
            RunAccounting();
            RunTradingPostBuilding();
            RunGameStateRoundTrip();
            RunLoaderNullSafe();
            await RunUiSmoke();
            RunGoldSeam();
        }
        catch (Exception e)
        {
            GD.PushError($"[BuildingSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("BuildingSpike");
    }

    // ─────────────────────────── (A) Accounting ───────────────────────────

    private void RunAccounting()
    {
        GD.Print("-------------------- (A) BuildingSystem accounting --------------------");
        var inv = new Inventory(); // unbound: flat warehouse pool, no Bulk caps
        inv.AddItem("wood", 340);
        inv.AddItem("stone", 100);
        inv.AddItem("wheat", 30);
        inv.AddItem("turnip", 25);

        // Every shipped building now carries a non-zero GoldCost (construction + tier upgrades), so a
        // wallet has to be wired in for commission/upgrade to succeed at all — earn enough up front to
        // cover farmhouse's construction (Gold 90) and tier-2 upgrade (Gold 400).
        var wallet = new Wallet();
        wallet.EarnGold(500);

        var bs = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold);
        int changed = 0;
        string? lastChanged = null;
        bs.Changed += id => { changed++; lastChanged = id; };

        // Commission REJECTED when unaffordable (infirmary needs herb; none held) — nothing consumed.
        bool rejected = bs.Commission("infirmary");
        Check("(A) commission rejected when construction bundle unaffordable", !rejected);
        Check("(A) rejected commission consumed nothing (wood still 340)", inv.Count("wood") == 340);
        Check("(A) rejected building not commissioned", !bs.IsCommissioned("infirmary") && bs.GetTier("infirmary") == 0);
        Check("(A) rejected commission raised no event", changed == 0);

        // Commission ACCEPTED: farmhouse needs wood 120 + stone 90 + Gold 90 → consumed, Built tier 1.
        bool ok = bs.Commission("farmhouse");
        Check("(A) commission accepted when affordable", ok);
        Check("(A) construction bundle consumed (wood 340→220, stone 100→10)",
            inv.Count("wood") == 220 && inv.Count("stone") == 10);
        Check("(A) building Built at tier 1", bs.GetTier("farmhouse") == 1 && bs.IsCommissioned("farmhouse"));
        Check("(A) commission raised Changed(farmhouse)", changed == 1 && lastChanged == "farmhouse");

        // Contribute toward tier 2 (needs turnip 25, wheat 25, wood 200). Partials allowed.
        Check("(A) partial contribute accepted (wheat 10)", bs.Contribute("farmhouse", "wheat", 10));
        Check("(A) partial consumed from inventory (wheat 30→20)", inv.Count("wheat") == 20);
        Check("(A) overshoot rejected (wheat 16 > remaining 15)", !bs.Contribute("farmhouse", "wheat", 16));
        Check("(A) overshoot consumed nothing (wheat still 20)", inv.Count("wheat") == 20);
        Check("(A) off-bundle item rejected (stone not in this bundle)", !bs.Contribute("farmhouse", "stone", 1));
        Check("(A) completing a line accepted (wheat +15 = 25)", bs.Contribute("farmhouse", "wheat", 15));
        Check("(A) already-satisfied line rejected (wheat +1)", !bs.Contribute("farmhouse", "wheat", 1));

        // Upgrade blocked while the bundle is incomplete.
        Check("(A) upgrade rejected while bundle incomplete", !bs.CanUpgrade("farmhouse") && !bs.Upgrade("farmhouse"));
        Check("(A) still tier 1 after blocked upgrade", bs.GetTier("farmhouse") == 1);

        // Finish the bundle.
        Check("(A) contribute turnip 25", bs.Contribute("farmhouse", "turnip", 25));
        Check("(A) contribute wood 200", bs.Contribute("farmhouse", "wood", 200));

        // View reports have/need at the completed-but-not-upgraded state.
        var view = bs.BuildView();
        var fh = view.Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(A) view: farmhouse commissioned, tier 1, has upgrade target", fh.Commissioned && fh.Tier == 1 && fh.HasTarget);
        Check("(A) view: wheat line reads 25/25 complete", LineOf(fh, "wheat") is { Contributed: 25, Need: 25, Complete: true });
        Check("(A) view: wood line reads 200/200 complete", LineOf(fh, "wood") is { Contributed: 200, Need: 200, Complete: true });
        Check("(A) view: CanUpgrade true when all lines complete", fh.CanUpgrade);

        // Upgrade now succeeds → tier 2, contributions cleared, next target advanced.
        Check("(A) upgrade accepted when bundle complete", bs.Upgrade("farmhouse"));
        Check("(A) advanced to tier 2", bs.GetTier("farmhouse") == 2);

        var view2 = bs.BuildView();
        var fh2 = view2.Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(A) view: tier 2 now targets tier 3, contributions reset", fh2.Tier == 2 && fh2.HasTarget && LineOf(fh2, "carrot") is { Contributed: 0 });
        Check("(A) view: tier-2 active effects present (declarative)", fh2.ActiveEffects.Count > 0);
    }

    private static BundleLineView? LineOf(BuildingView b, string itemId)
        => b.Bundle.Find(l => l.ItemId == itemId);

    // ─────────────────────────── (E) Trading Post building ───────────────────────────

    /// <summary>The new trading_post building commissions and upgrades through the normal build loop.</summary>
    private void RunTradingPostBuilding()
    {
        GD.Print("-------------------- (E) trading_post building commission + upgrade --------------------");
        var inv = new Inventory(); // unbound flat pool, no Bulk caps
        inv.AddItem("wood", 100);
        inv.AddItem("stone", 70);
        inv.AddItem("hardwood", 30); // the Elderwood line in the shipped construction bundle
        inv.AddItem("forest_root", 20);
        inv.AddItem("tree_sap", 20);
        inv.AddItem("silt_carp", 20);
        inv.AddItem("marsh_clam", 20);

        // trading_post now carries Gold costs too (60 at commission, 250 at tier-2 upgrade).
        var wallet = new Wallet();
        wallet.EarnGold(310);

        var bs = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold);
        Check("(E) trading_post is a defined building", Buildings.IsDefined("trading_post"));

        // Commission (wood 90 + stone 60 + Gold 60) → Built tier 1.
        Check("(E) commission trading_post", bs.Commission("trading_post"));
        Check("(E) trading_post built at tier 1", bs.GetTier("trading_post") == 1 && bs.IsCommissioned("trading_post"));
        Check("(E) construction consumed wood90+stone60", inv.Count("wood") == 10 && inv.Count("stone") == 10);

        // Contribute the tier-2 bundle (forest_root 20 + tree_sap 20 + silt_carp 20 + marsh_clam 20 +
        // Gold 250), then upgrade.
        Check("(E) contribute tier2 forest_root", bs.Contribute("trading_post", "forest_root", 20));
        Check("(E) contribute tier2 tree_sap", bs.Contribute("trading_post", "tree_sap", 20));
        Check("(E) contribute tier2 silt_carp", bs.Contribute("trading_post", "silt_carp", 20));
        Check("(E) contribute tier2 marsh_clam", bs.Contribute("trading_post", "marsh_clam", 20));
        Check("(E) upgrade trading_post to tier 2", bs.Upgrade("trading_post"));
        Check("(E) trading_post now tier 2", bs.GetTier("trading_post") == 2);

        var tp = bs.BuildView().Buildings.Find(b => b.Id == "trading_post")!;
        Check("(E) tier-2 grants its shop CategoryUnlock effect", tp.ActiveEffects.Count > 0);
    }

    // ─────────────────────────── (B) GameState + save/load ───────────────────────────

    private void RunGameStateRoundTrip()
    {
        GD.Print("-------------------- (B) GameState command path + save/load --------------------");
        ClearSlot0();

        var gs1 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs1); // _Ready seeds the starter inventory (10 wood, 10 stone) on the clean slot

        int changed = 0;
        gs1.BuildingChanged += _ => changed++;

        // Rejected: infirmary needs herb; starter holds none → nothing consumed.
        int woodBefore = gs1.Inventory.Count("wood");
        Check("(B) CommissionBuilding rejects unaffordable infirmary", !gs1.CommissionBuilding("infirmary"));
        Check("(B) rejected commission consumed no wood", gs1.Inventory.Count("wood") == woodBefore);
        Check("(B) rejected commission raised no BuildingChanged", changed == 0);

        // Stock the rest of farmhouse's construction bundle (wood 120, stone 90 total; starter already
        // has 10 of each) and earn its Gold cost (90) — every shipped building now carries a Gold cost.
        gs1.AddItem("wood", 110);
        gs1.AddItem("stone", 80);
        gs1.EarnGold(90);

        // Accepted: farmhouse (wood 120, stone 90, Gold 90) now affordable.
        Check("(B) CommissionBuilding(farmhouse) succeeds", gs1.CommissionBuilding("farmhouse"));
        Check("(B) farmhouse now tier 1", gs1.GetBuildingTier("farmhouse") == 1);
        Check("(B) commission raised BuildingChanged", changed == 1);

        // Partial contribution toward tier 2 (wheat is light Bulk — safe to stock; need is 25).
        gs1.AddItem("wheat", 8);
        Check("(B) ContributeBundle(farmhouse, wheat, 5) succeeds", gs1.ContributeBundle("farmhouse", "wheat", 5));

        var v1 = gs1.GetPlanningTableView().Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(B) view before save: wheat 5/25", LineOf(v1, "wheat") is { Contributed: 5, Need: 25 });

        gs1.SaveGame();

        // Fresh GameState reloads the saved slot: tier + partial contributions must round-trip.
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(B) reloaded farmhouse tier 1", gs2.GetBuildingTier("farmhouse") == 1);
        var v2 = gs2.GetPlanningTableView().Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(B) reloaded contribution wheat 5/25 exact round-trip", LineOf(v2, "wheat") is { Contributed: 5, Need: 25 });
        Check("(B) reloaded infirmary still not commissioned", gs2.GetBuildingTier("infirmary") == 0);

        gs1.QueueFree();
        gs2.QueueFree();
    }

    // ─────────────────────────── (C) Loader placement ───────────────────────────

    private void RunLoaderNullSafe()
    {
        GD.Print("-------------------- (C) BuildingLoader placement + null-safety --------------------");

        // No marker present anywhere → PlaceCommissioned skips gracefully, no throw, nothing added.
        var bareHost = new Node3D { Name = "BareHost" };
        AddChild(bareHost);
        var loaderBare = new BuildingLoader(bareHost, id => id == "farmhouse" ? 1 : 0);
        loaderBare.PlaceCommissioned();
        Check("(C) loader null-safe: no marker → nothing placed, no throw", bareHost.GetChildCount() == 0);

        // Marker present → the farmhouse scene is instanced at it with the tier's stage shown.
        var host = new Node3D { Name = "PlaceHost" };
        AddChild(host);
        var marker = new Marker3D { Name = "Building_farmhouse", Position = new Vector3(12f, 0f, 8f) };
        host.AddChild(marker);

        int tier = 1;
        var loader = new BuildingLoader(host, id => id == "farmhouse" ? tier : 0);
        loader.PlaceCommissioned();

        var placed = FindBuildingInstance(host);
        Check("(C) loader instanced the farmhouse at its marker", placed != null && placed.GlobalPosition == marker.GlobalPosition);
        Check("(C) placed building carries a StaticBody3D footprint", placed?.GetNodeOrNull("%Footprint") is StaticBody3D);
        Check("(C) tier 1 shows stage index 1", StageVisible(placed, 1) && !StageVisible(placed, 0));

        // Upgrade → refresh swaps the stage in place, no duplicate instance.
        tier = 2;
        loader.Refresh("farmhouse");
        Check("(C) tier 2 swaps to stage index 2", StageVisible(placed, 2) && !StageVisible(placed, 1));
        Check("(C) refresh did not duplicate the instance", CountBuildingInstances(host) == 1);
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

    private static bool StageVisible(BuildingInstance? inst, int stageIndex)
    {
        var stages = inst?.GetNodeOrNull("%Stages");
        if (stages == null || stageIndex >= stages.GetChildCount())
            return false;
        return stages.GetChild(stageIndex) is Node3D n3 && n3.Visible;
    }

    // ─────────────────────────── (D) UI smoke ───────────────────────────

    private async Task RunUiSmoke()
    {
        GD.Print("-------------------- (D) build_panel UI smoke --------------------");
        var packed = GD.Load<PackedScene>("res://scenes/ui/build_panel.tscn");
        Check("(D) build_panel.tscn loads", packed != null);
        if (packed == null)
            return;

        var panel = packed.Instantiate<BuildPanel>();
        AddChild(panel);
        await Frames(2);
        Check("(D) build_panel: %BuildingList resolves", panel.GetNodeOrNull("%BuildingList") != null);

        // Render a stocked view so a Commission button is ENABLED (affordable) for the intent check.
        var inv = new Inventory();
        inv.AddItem("wood", 30);
        inv.AddItem("stone", 30);
        var bs = new BuildingSystem(inv);
        panel.Render(bs.BuildView());
        await Frames(2);

        var list = panel.GetNode<VBoxContainer>("%BuildingList");
        Check("(D) one row per building (13)", list.GetChildCount() == Buildings.All.Count);

        // Only command_post is affordable from this stock without a wallet wired in (empty construction
        // bundle, GoldCost 0) — every other building now carries a non-zero Gold cost — so its
        // Commission button is the one enabled row.
        string? commissioned = null;
        panel.CommissionRequested += id => commissioned = id;
        var button = FindFirstEnabledButton(list);
        Check("(D) an enabled Commission button was built", button != null);
        button?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("(D) pressing it raised CommissionRequested", commissioned != null);

        panel.QueueFree();
        await Frames(1);
    }

    private static Button? FindFirstEnabledButton(Node root)
    {
        foreach (Node c in root.GetChildren())
        {
            if (c is Button b && !b.Disabled)
                return b;
            var nested = FindFirstEnabledButton(c);
            if (nested != null)
                return nested;
        }
        return null;
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    // ─────────────────────────── (F) Gold seam ───────────────────────────

    /// <summary>
    /// Spike-local building definition (NOT registered in <see cref="Buildings"/> — passed straight to
    /// <see cref="BuildingSystem"/>'s optional catalog parameter) carrying a non-zero
    /// <see cref="BuildingDefinition.GoldCost"/> and tier-2 <see cref="BuildingTier.GoldCost"/>, so this
    /// spike can exercise the gold gate without giving any shipped building a cost.
    /// </summary>
    private static readonly BuildingDefinition GoldGateKeep = new()
    {
        Id = "spike_gold_keep",
        DisplayName = "Spike Gold-Gate Keep",
        GoldCost = 15,
        ConstructionBundle = new BundleRequirement[]
        {
            new() { ItemId = "wood", Quantity = 4 },
        },
        Tiers = new BuildingTier[]
        {
            new() { Tier = 1, StageIndex = 1 },
            new()
            {
                Tier = 2, StageIndex = 2,
                GoldCost = 10,
                UpgradeBundle = new BundleRequirement[]
                {
                    new() { ItemId = "stone", Quantity = 3 },
                },
            },
        },
    };

    private void RunGoldSeam()
    {
        GD.Print("-------------------- (F) Gold seam: commission/upgrade gold gate --------------------");
        var inv = new Inventory(); // unbound flat pool, no Bulk caps
        inv.AddItem("wood", 20);
        inv.AddItem("stone", 20);

        var wallet = new Wallet();
        var bs = new BuildingSystem(inv, () => wallet.Gold, wallet.TrySpendGold, new[] { GoldGateKeep });

        // (a) Bundle is affordable but the wallet is empty — commission rejects, nothing consumed.
        Check("(F) commission rejected when gold insufficient", !bs.Commission("spike_gold_keep"));
        Check("(F) rejected commission consumed no wood", inv.Count("wood") == 20);
        Check("(F) rejected commission spent no gold", wallet.Gold == 0);
        Check("(F) rejected building not commissioned", !bs.IsCommissioned("spike_gold_keep"));

        // (b) Earn exactly the gold cost — commission now succeeds, bundle AND gold both consumed.
        wallet.EarnGold(15);
        Check("(F) commission accepted once gold affordable", bs.Commission("spike_gold_keep"));
        Check("(F) construction bundle consumed (wood 20→16)", inv.Count("wood") == 16);
        Check("(F) gold deducted at commission (15→0)", wallet.Gold == 0);
        Check("(F) building Built at tier 1", bs.GetTier("spike_gold_keep") == 1);

        // Accumulate the tier-2 MATERIAL bundle in full — gold is never contributed piecemeal, so
        // CanUpgrade must still read false on gold alone with the wallet back at 0.
        Check("(F) contribute tier2 stone", bs.Contribute("spike_gold_keep", "stone", 3));
        Check("(F) bundle complete but upgrade still blocked on gold", !bs.CanUpgrade("spike_gold_keep"));

        // (c) Upgrade rejected while gold is short — contributions and tier stay untouched.
        Check("(F) upgrade rejected when gold insufficient", !bs.Upgrade("spike_gold_keep"));
        Check("(F) rejected upgrade spent no gold", wallet.Gold == 0);
        Check("(F) rejected upgrade left tier at 1", bs.GetTier("spike_gold_keep") == 1);

        // Earn the tier's gold cost — upgrade now succeeds, gold deducted, tier advances.
        wallet.EarnGold(10);
        Check("(F) upgrade accepted once gold affordable", bs.Upgrade("spike_gold_keep"));
        Check("(F) gold deducted at upgrade (10→0)", wallet.Gold == 0);
        Check("(F) building advanced to tier 2", bs.GetTier("spike_gold_keep") == 2);

        // View-model surfaces GoldCost + CanAffordGold; a shipped (gold-free) building still reads 0/true.
        var view = bs.BuildView();
        var gk = view.Buildings.Find(b => b.Id == "spike_gold_keep")!;
        Check("(F) view: at max tier after the tier-2 upgrade", gk.AtMaxTier && !gk.HasTarget);

        // command_post is the one shipped building with GoldCost 0 (start-state, empty construction
        // bundle) — every other shipped building now carries a non-zero Gold cost.
        var baseline = new BuildingSystem(new Inventory()).BuildView().Buildings.Find(b => b.Id == "command_post")!;
        Check("(F) shipped building view: command_post GoldCost 0, affordable", baseline.GoldCost == 0 && baseline.CanAffordGold);
    }

    // ─────────────────────────── Save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[BuildingSpike] slot0.json backed up and cleared for the test run.");
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
            GD.Print("[BuildingSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[BuildingSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
