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
        inv.AddItem("wood", 20);
        inv.AddItem("stone", 20);
        inv.AddItem("wheat", 20);
        inv.AddItem("berries", 20);

        var bs = new BuildingSystem(inv);
        int changed = 0;
        string? lastChanged = null;
        bs.Changed += id => { changed++; lastChanged = id; };

        // Commission REJECTED when unaffordable (infirmary needs herb; none held) — nothing consumed.
        bool rejected = bs.Commission("infirmary");
        Check("(A) commission rejected when construction bundle unaffordable", !rejected);
        Check("(A) rejected commission consumed nothing (wood still 20)", inv.Count("wood") == 20);
        Check("(A) rejected building not commissioned", !bs.IsCommissioned("infirmary") && bs.GetTier("infirmary") == 0);
        Check("(A) rejected commission raised no event", changed == 0);

        // Commission ACCEPTED: farmhouse needs 8 wood + 6 stone → consumed, Built tier 1.
        bool ok = bs.Commission("farmhouse");
        Check("(A) commission accepted when affordable", ok);
        Check("(A) construction bundle consumed (wood 20→12, stone 20→14)",
            inv.Count("wood") == 12 && inv.Count("stone") == 14);
        Check("(A) building Built at tier 1", bs.GetTier("farmhouse") == 1 && bs.IsCommissioned("farmhouse"));
        Check("(A) commission raised Changed(farmhouse)", changed == 1 && lastChanged == "farmhouse");

        // Contribute toward tier 2 (needs wood 6, wheat 8, berries 6). Partials allowed.
        Check("(A) partial contribute accepted (wheat 3)", bs.Contribute("farmhouse", "wheat", 3));
        Check("(A) partial consumed from inventory (wheat 20→17)", inv.Count("wheat") == 17);
        Check("(A) overshoot rejected (wheat 8 > remaining 5)", !bs.Contribute("farmhouse", "wheat", 8));
        Check("(A) overshoot consumed nothing (wheat still 17)", inv.Count("wheat") == 17);
        Check("(A) off-bundle item rejected (stone not in this bundle)", !bs.Contribute("farmhouse", "stone", 1));
        Check("(A) completing a line accepted (wheat +5 = 8)", bs.Contribute("farmhouse", "wheat", 5));
        Check("(A) already-satisfied line rejected (wheat +1)", !bs.Contribute("farmhouse", "wheat", 1));

        // Upgrade blocked while the bundle is incomplete.
        Check("(A) upgrade rejected while bundle incomplete", !bs.CanUpgrade("farmhouse") && !bs.Upgrade("farmhouse"));
        Check("(A) still tier 1 after blocked upgrade", bs.GetTier("farmhouse") == 1);

        // Finish the bundle.
        Check("(A) contribute berries 6", bs.Contribute("farmhouse", "berries", 6));
        Check("(A) contribute wood 6", bs.Contribute("farmhouse", "wood", 6));

        // View reports have/need at the completed-but-not-upgraded state.
        var view = bs.BuildView();
        var fh = view.Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(A) view: farmhouse commissioned, tier 1, has upgrade target", fh.Commissioned && fh.Tier == 1 && fh.HasTarget);
        Check("(A) view: wheat line reads 8/8 complete", LineOf(fh, "wheat") is { Contributed: 8, Need: 8, Complete: true });
        Check("(A) view: wood line reads 6/6 complete", LineOf(fh, "wood") is { Contributed: 6, Need: 6, Complete: true });
        Check("(A) view: CanUpgrade true when all lines complete", fh.CanUpgrade);

        // Upgrade now succeeds → tier 2, contributions cleared, next target advanced.
        Check("(A) upgrade accepted when bundle complete", bs.Upgrade("farmhouse"));
        Check("(A) advanced to tier 2", bs.GetTier("farmhouse") == 2);

        var view2 = bs.BuildView();
        var fh2 = view2.Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(A) view: tier 2 now targets tier 3, contributions reset", fh2.Tier == 2 && fh2.HasTarget && LineOf(fh2, "stone") is { Contributed: 0 });
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
        inv.AddItem("wood", 20);
        inv.AddItem("stone", 20);
        inv.AddItem("wheat", 20);
        inv.AddItem("berries", 20);

        var bs = new BuildingSystem(inv);
        Check("(E) trading_post is a defined building", Buildings.IsDefined("trading_post"));

        // Commission (wood 6 + stone 4) → Built tier 1.
        Check("(E) commission trading_post", bs.Commission("trading_post"));
        Check("(E) trading_post built at tier 1", bs.GetTier("trading_post") == 1 && bs.IsCommissioned("trading_post"));
        Check("(E) construction consumed wood6+stone4", inv.Count("wood") == 14 && inv.Count("stone") == 16);

        // Contribute the tier-2 bundle (wood 6 + wheat 6 + berries 4), then upgrade.
        Check("(E) contribute tier2 wood", bs.Contribute("trading_post", "wood", 6));
        Check("(E) contribute tier2 wheat", bs.Contribute("trading_post", "wheat", 6));
        Check("(E) contribute tier2 berries", bs.Contribute("trading_post", "berries", 4));
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

        // Rejected: infirmary needs 8 herb; starter holds none → nothing consumed.
        int woodBefore = gs1.Inventory.Count("wood");
        Check("(B) CommissionBuilding rejects unaffordable infirmary", !gs1.CommissionBuilding("infirmary"));
        Check("(B) rejected commission consumed no wood", gs1.Inventory.Count("wood") == woodBefore);
        Check("(B) rejected commission raised no BuildingChanged", changed == 0);

        // Accepted: farmhouse (8 wood, 6 stone) affordable from the starter stock.
        Check("(B) CommissionBuilding(farmhouse) succeeds", gs1.CommissionBuilding("farmhouse"));
        Check("(B) farmhouse now tier 1", gs1.GetBuildingTier("farmhouse") == 1);
        Check("(B) commission raised BuildingChanged", changed == 1);

        // Partial contribution toward tier 2 (wheat is light Bulk — safe to stock).
        gs1.AddItem("wheat", 8);
        Check("(B) ContributeBundle(farmhouse, wheat, 5) succeeds", gs1.ContributeBundle("farmhouse", "wheat", 5));

        var v1 = gs1.GetPlanningTableView().Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(B) view before save: wheat 5/8", LineOf(v1, "wheat") is { Contributed: 5, Need: 8 });

        gs1.SaveGame();

        // Fresh GameState reloads the saved slot: tier + partial contributions must round-trip.
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(B) reloaded farmhouse tier 1", gs2.GetBuildingTier("farmhouse") == 1);
        var v2 = gs2.GetPlanningTableView().Buildings.Find(b => b.Id == "farmhouse")!;
        Check("(B) reloaded contribution wheat 5/8 exact round-trip", LineOf(v2, "wheat") is { Contributed: 5, Need: 8 });
        Check("(B) reloaded infirmary still not commissioned", gs2.GetBuildingTier("infirmary") == 0);

        gs1.QueueFree();
        gs2.QueueFree();
    }

    // ─────────────────────────── (C) Loader placement ───────────────────────────

    private void RunLoaderNullSafe()
    {
        GD.Print("-------------------- (C) BuildingLoader placement + null-safety --------------------");

        // No marker present anywhere → PlaceCommissioned skips gracefully, no throw, nothing added.
        var bareHost = new Node2D { Name = "BareHost" };
        AddChild(bareHost);
        var loaderBare = new BuildingLoader(bareHost, id => id == "farmhouse" ? 1 : 0);
        loaderBare.PlaceCommissioned();
        Check("(C) loader null-safe: no marker → nothing placed, no throw", bareHost.GetChildCount() == 0);

        // Marker present → the farmhouse scene is instanced at it with the tier's stage shown.
        var host = new Node2D { Name = "PlaceHost" };
        AddChild(host);
        var marker = new Marker2D { Name = "Building_farmhouse", Position = new Vector2(120, 80) };
        host.AddChild(marker);

        int tier = 1;
        var loader = new BuildingLoader(host, id => id == "farmhouse" ? tier : 0);
        loader.PlaceCommissioned();

        var placed = FindBuildingInstance(host);
        Check("(C) loader instanced the farmhouse at its marker", placed != null && placed.GlobalPosition == marker.GlobalPosition);
        Check("(C) placed building carries a StaticBody2D footprint", placed?.GetNodeOrNull("%Footprint") is StaticBody2D);
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
        return stages.GetChild(stageIndex) is CanvasItem ci && ci.Visible;
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
        Check("(D) one row per building (3)", list.GetChildCount() == Buildings.All.Count);

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
