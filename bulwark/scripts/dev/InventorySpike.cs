using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Conditions;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the PF2e Bulk-driven, per-member carry system + outpost warehouse.
/// Drives a REAL GameState node's commands directly on a clean save slot (slot0.json backed up and
/// restored around the run), no rendered scenes. Proves:
///  (1) Light default squad: starter inventory distributes across members and NOBODY is encumbered;
///      per-member carried Bulk sums correctly and auto-distribution spreads a gain over members.
///  (2) The party ItemAdded choke point still fires for gains, so the DayLedger counts loot/harvest.
///  (3) Encumbrance teeth: a member crossing 5 + Str mod Bulk gains the engine Encumbered condition
///      (−10 ft Speed — the combat bite) and loses it when offloaded; the 10 + Str mod hard cap
///      rejects further carry.
///  (4) Warehouse deposit/withdraw moves items between a member and shared storage and updates
///      encumbrance; a withdrawal that would break the hard cap is rejected.
///  (5) Party-level hard cap: with every member full, AddItem places nothing and rejects the lot
///      (no phantom ItemAdded).
///  (6) Full save/load round-trip of per-member carry + warehouse; encumbrance recomputes on load.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class InventorySpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== INVENTORY SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[InventorySpike] DataManager not loaded — aborting.");
            return;
        }
        if (ConditionDatabase.Instance?.GetCondition(Condition.Encumbered) == null)
        {
            AbortFail("[InventorySpike] Encumbered condition not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            await Task.CompletedTask;
            RunScenario();
        }
        catch (Exception e)
        {
            GD.PushError($"[InventorySpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("InventorySpike");
    }

    private void RunScenario()
    {
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        var squad = gs.Squad;
        Check("(0) GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null)
            return;

        // ── (1) Light default squad: starter inventory distributed, nobody encumbered ──
        GD.Print("-------------------- (1) Light default squad --------------------");
        Check("(1) starter wood present (10)", gs.Inventory.Count(Items.Wood.Id) == 10);
        Check("(1) starter stone present (10)", gs.Inventory.Count(Items.Stone.Id) == 10);
        Check("(1) starter turnip seeds present (5)", gs.Inventory.Count(Items.TurnipSeed.Id) == 5);

        var view0 = gs.GetInventoryView();
        Check("(1) view exposes all 4 members", view0.Members.Count == 4);

        // Carried Bulk sums to the starter total: 8 seeds ×0.1 + 20 wood/stone ×0.1 = 2.8 Bulk.
        double totalCarried = view0.Members.Sum(m => m.CarriedBulk);
        Check($"(1) per-member Bulk sums to 2.8 (got {totalCarried:0.###})",
            Math.Abs(totalCarried - 2.8) < 0.001);

        bool anyEncumbered = squad.Members.Any(m => m.Conditions!.HasCondition(Condition.Encumbered));
        Check("(1) light default squad is NOT encumbered", !anyEncumbered);
        Check("(1) view agrees: no member flagged encumbered", view0.Members.All(m => !m.Encumbered));

        // Light wood (Bulk 0.1) consolidates on one carrier — no need to spread.
        int woodCarriers = view0.Members.Count(m => m.Stacks.ContainsKey(Items.Wood.Id));
        Check($"(1) light wood stays consolidated on ≥1 carrier (got {woodCarriers})", woodCarriers >= 1);

        // ── (2) Party ItemAdded choke point → DayLedger counts a harvest gain ──
        GD.Print("-------------------- (2) ItemAdded choke point --------------------");
        (string Id, int Qty)? added = null;
        Action<string, int> probe = (id, qty) => added = (id, qty);
        gs.Inventory.ItemAdded += probe;
        gs.AddItem(Items.Herb.Id, 3);
        gs.Inventory.ItemAdded -= probe;
        Check("(2) party ItemAdded fired for the gain (herb ×3)",
            added is { Id: "herb", Qty: 3 });

        gs.Sleep();
        var summary = gs.ConsumeDaySummary();
        Check("(2) DayLedger counted the herb through the choke point",
            summary != null && summary.ItemsGained.TryGetValue(Items.Herb.Id, out int h) && h == 3);

        // ── (3) Encumbrance crossing + hard cap + combat bite (Scholar: Str +0 → thr 5, cap 10) ──
        // Uses plank (Bulk 1.0) so the arithmetic matches PF2e Bulk thresholds exactly.
        GD.Print("-------------------- (3) Encumbrance teeth --------------------");
        var scholar = squad.FindMember(SquadRoster.FenwickId)!;

        // Empty the Scholar into the warehouse so the crossing is deterministic.
        foreach (var (id, qty) in ScholarStacks(gs).ToList())
            gs.DepositToWarehouse(SquadRoster.FenwickId, id, qty);
        Check("(3) Scholar emptied to the warehouse", ScholarCarriedBulk(gs) == 0);
        int baseSpeed = scholar.Stats!.SpeedInFeet;

        Check("(3) give 5 plank → carried 5.0, at threshold, NOT encumbered",
            gs.Inventory.TryGiveToMember(SquadRoster.FenwickId, Items.Plank.Id, 5)
            && Math.Abs(ScholarCarriedBulk(gs) - 5.0) < 0.001
            && !scholar.Conditions!.HasCondition(Condition.Encumbered));

        Check("(3) give 1 more plank → carried 6.0 > 5, ENCUMBERED",
            gs.Inventory.TryGiveToMember(SquadRoster.FenwickId, Items.Plank.Id, 1)
            && scholar.Conditions!.HasCondition(Condition.Encumbered));

        Check($"(3) Encumbered bites combat: Speed dropped 10 ft ({baseSpeed} → {scholar.Stats.SpeedInFeet})",
            scholar.Stats.SpeedInFeet == Math.Max(5, baseSpeed - 10));
        // The engine's ConditionImporter does not cascade the Clumsy child of Encumbered (no "clumsy"
        // UUID mapping), so the modeled teeth are the −10 ft Speed penalty; note it, don't fail on it.
        GD.Print($"  [note] engine models Encumbered's Speed penalty; Clumsy child not applied "
            + $"(HasClumsy={scholar.Conditions!.HasCondition(Condition.Clumsy)}).");

        Check("(3) fill to the cap: give 4 plank → carried 10.0 (== 10+Str, allowed)",
            gs.Inventory.TryGiveToMember(SquadRoster.FenwickId, Items.Plank.Id, 4)
            && Math.Abs(ScholarCarriedBulk(gs) - 10.0) < 0.001);

        Check("(3) hard cap: one more plank REJECTED (would exceed 10), no mutation",
            !gs.Inventory.TryGiveToMember(SquadRoster.FenwickId, Items.Plank.Id, 1)
            && Math.Abs(ScholarCarriedBulk(gs) - 10.0) < 0.001);

        // ── (4) Deposit/withdraw move items and update encumbrance ──
        GD.Print("-------------------- (4) Deposit / withdraw --------------------");
        int whPlankBefore = gs.GetInventoryView().Warehouse.GetValueOrDefault(Items.Plank.Id, 0);
        Check("(4) deposit 6 plank → carried 4.0, encumbrance CLEARED, Speed restored",
            gs.DepositToWarehouse(SquadRoster.FenwickId, Items.Plank.Id, 6)
            && Math.Abs(ScholarCarriedBulk(gs) - 4.0) < 0.001
            && !scholar.Conditions!.HasCondition(Condition.Encumbered)
            && scholar.Stats.SpeedInFeet == baseSpeed);
        Check("(4) deposited plank landed in the warehouse (+6)",
            gs.GetInventoryView().Warehouse.GetValueOrDefault(Items.Plank.Id, 0) == whPlankBefore + 6);

        Check("(4) withdraw 6 plank → carried 10.0, RE-ENCUMBERED",
            gs.WithdrawFromWarehouse(SquadRoster.FenwickId, Items.Plank.Id, 6)
            && Math.Abs(ScholarCarriedBulk(gs) - 10.0) < 0.001
            && scholar.Conditions!.HasCondition(Condition.Encumbered));
        Check("(4) withdraw past the hard cap REJECTED",
            !gs.WithdrawFromWarehouse(SquadRoster.FenwickId, Items.Plank.Id, 1)
            && Math.Abs(ScholarCarriedBulk(gs) - 10.0) < 0.001);

        // ── (5) Party-level hard cap: fill everyone, then AddItem rejects the lot ──
        GD.Print("-------------------- (5) Party hard cap --------------------");
        foreach (var mv in gs.GetInventoryView().Members)
        {
            int room = (int)Math.Floor(mv.MaxBulk - mv.CarriedBulk); // whole plank (Bulk 1) units
            if (room > 0)
                gs.Inventory.TryGiveToMember(mv.MemberId, Items.Plank.Id, room);
        }
        bool anyRoomLeft = gs.GetInventoryView().Members.Any(m => m.MaxBulk - m.CarriedBulk >= 1.0);
        Check("(5) every member topped to <1 Bulk of free capacity", !anyRoomLeft);

        (string Id, int Qty)? phantom = null;
        Action<string, int> phantomProbe = (id, qty) => phantom = (id, qty);
        gs.Inventory.ItemAdded += phantomProbe;
        var addResult = gs.Inventory.AddItem(Items.Plank.Id, 5);
        gs.Inventory.ItemAdded -= phantomProbe;
        Check("(5) AddItem placed 0 and rejected all 5 at the party hard cap",
            addResult.Placed == 0 && addResult.Rejected == 5 && !addResult.FullyPlaced);
        Check("(5) no phantom ItemAdded fired when nothing was placed", phantom == null);

        // ── (6) Save / load round-trip: per-member carry + warehouse + recomputed encumbrance ──
        GD.Print("-------------------- (6) Save / load round-trip --------------------");
        gs.SaveGame();
        var before = gs.GetInventoryView();
        int scholarPlankBefore = ScholarStacks(gs).GetValueOrDefault(Items.Plank.Id, 0);
        bool scholarEncumberedBefore = scholar.Conditions!.HasCondition(Condition.Encumbered);

        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        var after = gs2.GetInventoryView();

        Check("(6) reloaded: warehouse round-trips",
            DictEqual(before.Warehouse, after.Warehouse));

        bool membersMatch = before.Members.Count == after.Members.Count
            && before.Members.All(bm =>
            {
                var am = after.Members.FirstOrDefault(x => x.MemberId == bm.MemberId);
                return am != null
                    && DictEqual(bm.Stacks, am.Stacks)
                    && Math.Abs(bm.CarriedBulk - am.CarriedBulk) < 0.001
                    && bm.Encumbered == am.Encumbered;
            });
        Check("(6) reloaded: every member's carried stacks + Bulk + encumbered flag round-trip",
            membersMatch);

        var scholar2 = gs2.Squad!.FindMember(SquadRoster.FenwickId)!;
        Check("(6) reloaded: Scholar plank count round-trips",
            ScholarStacks(gs2).GetValueOrDefault(Items.Plank.Id, 0) == scholarPlankBefore);
        Check("(6) reloaded: encumbrance RECOMPUTED on load (condition reapplied + Speed reduced)",
            scholarEncumberedBefore
            && scholar2.Conditions!.HasCondition(Condition.Encumbered)
            && scholar2.Stats!.SpeedInFeet == Math.Max(5, baseSpeed - 10));

        // ── (7) Refinement 1: warehouse is OUTPOST-ONLY physical storage ──
        // Fresh facade bound to the live squad so the reachability semantics are isolated from the
        // heavily-loaded scenario above. Wood (Bulk 1) split between member carry and the warehouse.
        GD.Print("-------------------- (7) Warehouse accessibility --------------------");
        Check("(7) default WarehouseAccessible is TRUE (baseline access)",
            new Inventory().WarehouseAccessible);

        var inv = new Inventory();
        inv.BindSquad(squad);
        string yId = squad.Members.First(m => m.Id != SquadRoster.FenwickId).Id;
        inv.TryGiveToMember(SquadRoster.FenwickId, Items.Wood.Id, 3); // member carry: 3
        inv.TryGiveToMember(yId, Items.Wood.Id, 4);
        inv.DepositToWarehouse(yId, Items.Wood.Id, 4);                // warehouse: 4, member carry: 3

        Check("(7) accessible: Count sees members + warehouse (3+4=7)",
            inv.Count(Items.Wood.Id) == 7 && inv.Has(Items.Wood.Id, 7));
        Check("(7) accessible: merged view includes the warehouse (4)",
            inv.BuildView(0).Warehouse.GetValueOrDefault(Items.Wood.Id, 0) == 4
            && inv.Stacks.GetValueOrDefault(Items.Wood.Id, 0) == 7);

        inv.WarehouseAccessible = false;
        Check("(7) field: Count EXCLUDES the warehouse (member carry 3 only)",
            inv.Count(Items.Wood.Id) == 3 && !inv.Has(Items.Wood.Id, 7) && inv.Has(Items.Wood.Id, 3));
        Check("(7) field: RemoveItem can't pull warehouse stock (remove 4 rejected)",
            !inv.RemoveItem(Items.Wood.Id, 4) && inv.Count(Items.Wood.Id) == 3);
        Check("(7) field: deposit & withdraw both REFUSE (outpost-only actions)",
            !inv.DepositToWarehouse(SquadRoster.FenwickId, Items.Wood.Id, 1)
            && !inv.WithdrawFromWarehouse(SquadRoster.FenwickId, Items.Wood.Id, 1));
        Check("(7) field: member carry untouched by the refused actions (still 3)",
            inv.BuildView(0).Members.First(m => m.MemberId == SquadRoster.FenwickId)
               .Stacks.GetValueOrDefault(Items.Wood.Id, 0) == 3);
        Check("(7) field: merged view EXCLUDES the warehouse (empty / carry-only)",
            inv.BuildView(0).Warehouse.GetValueOrDefault(Items.Wood.Id, 0) == 0
            && inv.Stacks.GetValueOrDefault(Items.Wood.Id, 0) == 3);

        inv.WarehouseAccessible = true;
        Check("(7) back at the outpost: warehouse access RESTORED (Count 7 again, warehouse stock intact)",
            inv.Count(Items.Wood.Id) == 7
            && inv.DepositToWarehouse(SquadRoster.FenwickId, Items.Wood.Id, 1)); // deposit works again

        var unbound = new Inventory { WarehouseAccessible = false };
        Check("(7) unbound field: WouldFit is false (no reachable storage)",
            !unbound.WouldFit(Items.Wood.Id, 1));
        unbound.WarehouseAccessible = true;
        Check("(7) unbound outpost: WouldFit is true (warehouse unbounded)",
            unbound.WouldFit(Items.Wood.Id, 1));

        // ── (8) Refinement 2: a gain consolidates onto an existing holder before spreading ──
        // Scholar (Str +0 → threshold 5) is the deterministic holder. Uses plank (Bulk 1.0).
        GD.Print("-------------------- (8) Stack-consolidation distribution --------------------");
        var inv2 = new Inventory();
        inv2.BindSquad(squad);
        inv2.TryGiveToMember(SquadRoster.FenwickId, Items.Plank.Id, 2); // Scholar already holds a stack

        (string Id, int Qty)? gain = null;
        Action<string, int> gainProbe = (id, qty) => gain = (id, qty);
        inv2.ItemAdded += gainProbe;
        var consolidate = inv2.AddItem(Items.Plank.Id, 3); // 2 + 3 = 5, all fits under the Scholar's threshold
        inv2.ItemAdded -= gainProbe;

        var vc = inv2.BuildView(0);
        int scholarPlank = vc.Members.First(m => m.MemberId == SquadRoster.FenwickId)
                            .Stacks.GetValueOrDefault(Items.Plank.Id, 0);
        int otherCarriers = vc.Members.Count(m => m.MemberId != SquadRoster.FenwickId
                            && m.Stacks.ContainsKey(Items.Plank.Id));
        Check("(8) gain CONSOLIDATED onto the existing holder (Scholar 2→5, not spread)",
            scholarPlank == 5 && otherCarriers == 0);
        Check("(8) consolidation: Placed 3 / Rejected 0, ItemAdded fired once for (plank, 3)",
            consolidate.Placed == 3 && consolidate.Rejected == 0 && gain is { Id: "plank", Qty: 3 });
        Check("(8) holder at threshold (5 == 5+Str) is NOT encumbered",
            !squad.FindMember(SquadRoster.FenwickId)!.Conditions!.HasCondition(Condition.Encumbered));

        // Holder now full to threshold → the next gain must overflow to another member.
        gain = null;
        inv2.ItemAdded += gainProbe;
        var overflow = inv2.AddItem(Items.Plank.Id, 2);
        inv2.ItemAdded -= gainProbe;

        var vo = inv2.BuildView(0);
        int scholarPlank2 = vo.Members.First(m => m.MemberId == SquadRoster.FenwickId)
                             .Stacks.GetValueOrDefault(Items.Plank.Id, 0);
        int overflowHeld = vo.Members.Where(m => m.MemberId != SquadRoster.FenwickId)
                             .Sum(m => m.Stacks.GetValueOrDefault(Items.Plank.Id, 0));
        Check("(8) holder full → gain OVERFLOWED to another member (Scholar stays 5, other +2)",
            scholarPlank2 == 5 && overflowHeld == 2);
        Check("(8) overflow: Placed 2 / Rejected 0, ItemAdded fired once for (plank, 2)",
            overflow.Placed == 2 && overflow.Rejected == 0 && gain is { Id: "plank", Qty: 2 });
    }

    // ─────────────────────────── Scholar helpers ───────────────────────────

    private static IReadOnlyDictionary<string, int> ScholarStacks(GameState gs)
        => gs.GetInventoryView().Members.First(m => m.MemberId == SquadRoster.FenwickId).Stacks;

    private static double ScholarCarriedBulk(GameState gs)
        => gs.GetInventoryView().Members.First(m => m.MemberId == SquadRoster.FenwickId).CarriedBulk;

    private static bool DictEqual(IReadOnlyDictionary<string, int> a, IReadOnlyDictionary<string, int> b)
        => a.Count == b.Count && a.All(kv => b.TryGetValue(kv.Key, out int v) && v == kv.Value);

    // ─────────────────────────── Save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[InventorySpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[InventorySpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[InventorySpike] test slot0.json removed (no prior save existed).");
        }
    }
}
