using System;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.Utilities;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the Phase-1 economy loop: combat loot → gold → smithy sink. Drives a
/// REAL GameState node's commands directly (fresh, on a clean save slot — the user's slot0.json is
/// backed up first and restored at the end); no rendered scenes. The Phase-1 forest drop tables are
/// min == max, so victory loot is deterministic without an RNG seam.
///  (1) Loot: defeating gob_1 (goblin_pair) drops exactly 2 goblin fangs + 8 coin; parts land in
///      the shared inventory, the day ledger counts both (verified through the end-of-day summary),
///      and gold rose.
///  (2) Selling: parts sell for qty × SellValue (gold up, inventory down); over-sell and unsellable
///      items reject cleanly.
///  (3) Smithy runes: an insufficient-gold Striking buy spends nothing; with gold the Veteran's
///      longsword gains Striking (a 2nd weapon die — the exact DamageCalculator input) and then a
///      Potency rune (+1 to the previewed attack bonus); a duplicate Striking and an unknown member
///      reject with no gold spent.
///  (4) Weapon shop: an insufficient-gold buy spends nothing; with gold the Scholar's staff is
///      replaced by a bought Greataxe (a strike now rolls the greataxe die); unknown weapon/member
///      reject.
///  (5) Save round-trip: gold balance, the applied runes, and the bought weapon all survive a fresh
///      restore.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class EconomySpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string ForestId = "verdant_fringe";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== ECONOMY SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[EconomySpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            await RunScenario(data);
        }
        catch (Exception e)
        {
            GD.PushError($"[EconomySpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("EconomySpike");
    }

    private async Task RunScenario(DataManager data)
    {
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        var squad = gs.Squad;
        Check("(0) GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null)
            return;

        var veteran = squad.FindMember(SquadRoster.PlayerId)!;
        var scholar = squad.FindMember(SquadRoster.ScholarId)!;

        Check("(0) fresh wallet starts empty", gs.Gold == 0);

        // ── (1) Victory loot: deterministic drop table (2 goblins → 2 fang + 8 coin) ──
        GD.Print("-------------------- (1) Loot drops --------------------");
        Check("(1) travel to the forest", gs.TravelToTerritory(ForestId));
        Check("(1) contact gob_1 (goblin_pair)", gs.BeginTerritoryEncounter("gob_1", new Vector2(1, 1)));
        var pending = gs.Territory.PendingEncounter;
        if (pending == null) { AbortFail("[EconomySpike] no pending encounter."); return; }

        int fangBefore = gs.Inventory.Count(Items.GoblinFang.Id);
        var session = StartSession(pending.Setup);
        try
        {
            foreach (var enemy in pending.Enemies)
                await ReactionEvents.DeliverDamage(veteran, enemy, Physical(999));
        }
        finally { session.Teardown(); }

        var outcome = gs.CompleteTerritoryEncounter(BattleResult.Team1Wins);
        Check("(1) victory outcome", outcome is { Victory: true });
        Check("(1) 2 goblin fangs dropped into the inventory",
            gs.Inventory.Count(Items.GoblinFang.Id) == fangBefore + 2);
        Check("(1) 8 coin awarded (2 goblins × 4)", gs.Gold == 8);

        // The day ledger counts loot through the AddItem/EarnGold choke points: sleep, then read the
        // staged end-of-day summary.
        gs.Sleep();
        var summary = gs.ConsumeDaySummary();
        Check("(1) day summary counted the fangs",
            summary != null && summary.ItemsGained.TryGetValue(Items.GoblinFang.Id, out int f) && f == 2);
        Check("(1) day summary shows the gold earned", summary != null && summary.GoldEarned == 8);
        Check("(1) gold survived the night", gs.Gold == 8);

        // ── (2) Selling parts for gold ──
        GD.Print("-------------------- (2) Selling --------------------");
        Check("(2) unsellable item rejected (turnip seeds have no sell value)",
            !gs.SellItem(Items.TurnipSeed.Id, 1));
        Check("(2) over-selling rejected (only 2 fangs held)", !gs.SellItem(Items.GoblinFang.Id, 3));
        Check("(2) selling both fangs succeeds", gs.SellItem(Items.GoblinFang.Id, 2));
        Check("(2) gold rose by 2 × SellValue(5) = 10", gs.Gold == 18);
        Check("(2) fangs left the inventory", gs.Inventory.Count(Items.GoblinFang.Id) == 0);

        // ── (3) Smithy: fundamental runes on the Veteran's longsword ──
        GD.Print("-------------------- (3) Smithy runes --------------------");
        var target = CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);
        var vetWeapon = veteran.Equipment!.MainHandWeapon!;

        (bool previewOk, int baseBonus, int baseMax) = TryPreview(veteran, target);

        Check("(3) Striking rejected when gold is short (18 < 400)",
            !gs.ApplyWeaponRune(SquadRoster.PlayerId, RuneKind.Striking));
        Check("(3) rejected rune spent no gold", gs.Gold == 18);

        // Insufficient-gold weapon buy (folded weapon-shop check) — 18 < 200, spends nothing.
        Check("(3) insufficient-gold greataxe buy rejected", !gs.BuyWeapon(SquadRoster.ScholarId, "greataxe"));
        Check("(3) rejected buy spent no gold", gs.Gold == 18);

        gs.EarnGold(1000); // bankroll the smithy run
        Check("(3) granted gold banked", gs.Gold == 1018);

        // Refinement 3: runes are a MAGICAL enchantment — they cost gold + arcane_essence (a non-metal
        // reagent). With gold but NO reagent, the apply rejects and spends nothing.
        Check("(3) Striking rejected when reagent short (gold ok, no arcane_essence)",
            !gs.ApplyWeaponRune(SquadRoster.PlayerId, RuneKind.Striking));
        Check("(3) reagent-short rejection spent no gold", gs.Gold == 1018);
        Check("(3) reagent-short rejection consumed no reagent", gs.Inventory.Count(Items.ArcaneEssence.Id) == 0);

        gs.AddItem(Items.ArcaneEssence.Id, 5); // enough for Striking (2) + Potency (1)

        Check("(3) Striking applied (gold + reagent)", gs.ApplyWeaponRune(SquadRoster.PlayerId, RuneKind.Striking));
        Check("(3) Striking cost 400 gold", gs.Gold == 618);
        Check("(3) Striking consumed 2 arcane_essence", gs.Inventory.Count(Items.ArcaneEssence.Id) == 3);
        Check("(3) weapon now carries a Striking rune",
            vetWeapon.Striking == PF2e.Data.StrikingRuneLevel.Striking);
        Check("(3) strike math sees a 2nd weapon die (DamageCalculator input)",
            vetWeapon.GetEffectiveDamageDice().NumberOfDice == 2);

        Check("(3) Potency applied (gold + reagent)", gs.ApplyWeaponRune(SquadRoster.PlayerId, RuneKind.Potency));
        Check("(3) Potency cost 150 gold", gs.Gold == 468);
        Check("(3) Potency consumed 1 arcane_essence", gs.Inventory.Count(Items.ArcaneEssence.Id) == 2);
        Check("(3) weapon now carries a +1 potency rune", vetWeapon.PotencyBonus == 1);

        if (previewOk)
        {
            (bool ok2, int newBonus, int newMax) = TryPreview(veteran, target);
            Check("(3) preview: striking added weapon damage (max damage up)", ok2 && newMax > baseMax);
            Check("(3) preview: potency added +1 to the attack bonus", ok2 && newBonus == baseBonus + 1);
        }
        else
        {
            GD.Print("  [note] combat preview unavailable — relying on instance/dice assertions.");
        }

        Check("(3) duplicate Striking rejected", !gs.ApplyWeaponRune(SquadRoster.PlayerId, RuneKind.Striking));
        Check("(3) duplicate rejection spent no gold", gs.Gold == 468);
        Check("(3) unknown member rejected", !gs.ApplyWeaponRune("nobody", RuneKind.Potency));
        Check("(3) unknown-member rejection spent no gold", gs.Gold == 468);

        // ── (4) Weapon shop: replace the Scholar's staff with a bought greataxe ──
        GD.Print("-------------------- (4) Weapon shop --------------------");
        int staffDie = scholar.Equipment!.MainHandWeapon!.DamageDice.DieSize;
        Check("(4) Scholar starts on the staff (d4)", staffDie == 4);

        Check("(4) unknown weapon slug rejected", !gs.BuyWeapon(SquadRoster.ScholarId, "vorpal-nonsense"));
        Check("(4) unknown member rejected", !gs.BuyWeapon("nobody", "greataxe"));

        Check("(4) buy the greataxe (200g)", gs.BuyWeapon(SquadRoster.ScholarId, "greataxe"));
        Check("(4) greataxe cost 200 gold", gs.Gold == 268);
        var scholarWeapon = scholar.Equipment!.MainHandWeapon!;
        Check("(4) Scholar's main-hand weapon changed to the greataxe (d12)",
            scholarWeapon.DamageDice.DieSize == 12);
        Check("(4) a strike now rolls the greataxe die",
            scholarWeapon.GetEffectiveDamageDice().DieSize == 12);

        // ── (4b) Higher-tier equipment costs METAL (Refinement 3): gold + copper_ingot ──
        // Isolated on a fresh GameState so the smithy-upgrade materials don't fight the shared
        // inventory's Bulk carry cap (this scenario's accumulated hauling).
        GD.Print("-------------------- (4b) Higher-tier weapon (metal-gated) --------------------");
        {
            // Fresh save slot so the isolated GameState below starts from clean starter state (gs re-saves
            // its own state in section 6 before the reload check).
            if (Godot.FileAccess.FileExists(SavePath))
                DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));

            var gm = new GameState { RealSecondsPerGameMinute = 0 };
            AddChild(gm);

            // A higher-tier catalog entry (falchion, Improved tier) is locked until the smithy upgrades.
            Check("(4b) higher-tier falchion locked at base smithy", !gm.BuyWeapon(SquadRoster.TharrId, "falchion"));

            // Upgrade the shipped Smithy to Improved (commission + tier-2 bundle). Fresh inventory seeds
            // wood10+stone10; commission consumes wood6+stone10 first, then the tier-2 bundle is added.
            Check("(4b) commission smithy", gm.CommissionBuilding("smithy"));
            gm.AddItem("stone", 8);
            gm.AddItem("goblin_fang", 6);
            gm.AddItem("rat_pelt", 5);
            Check("(4b) contribute smithy tier2 stone", gm.ContributeBundle("smithy", "stone", 8));
            Check("(4b) contribute smithy tier2 goblin_fang", gm.ContributeBundle("smithy", "goblin_fang", 6));
            Check("(4b) contribute smithy tier2 rat_pelt", gm.ContributeBundle("smithy", "rat_pelt", 5));
            Check("(4b) upgrade smithy to Improved", gm.UpgradeBuilding("smithy"));
            Check("(4b) smithy tier now Improved", gm.SmithyTier == SmithyTier.Improved);

            gm.EarnGold(1000); // bankroll the metal buy
            int goldBeforeFalchion = gm.Gold;

            // Unlocked by tier now, but the higher-tier weapon still needs METAL — with no copper_ingot
            // the buy rejects cleanly (nothing consumed).
            Check("(4b) falchion rejected when metal short (no copper_ingot)",
                !gm.BuyWeapon(SquadRoster.TharrId, "falchion"));
            Check("(4b) metal-short rejection spent no gold", gm.Gold == goldBeforeFalchion);
            Check("(4b) metal-short rejection consumed no metal", gm.Inventory.Count("copper_ingot") == 0);

            gm.AddItem("copper_ingot", 2); // falchion MetalCost = 2
            Check("(4b) falchion buy succeeds with gold + metal", gm.BuyWeapon(SquadRoster.TharrId, "falchion"));
            Check("(4b) falchion cost 300 gold", gm.Gold == goldBeforeFalchion - 300);
            Check("(4b) falchion consumed the 2 copper_ingot", gm.Inventory.Count("copper_ingot") == 0);
            var medicWeapon = gm.Squad!.FindMember(SquadRoster.TharrId)!.Equipment!.MainHandWeapon!;
            Check("(4b) Medic's main-hand is now the falchion (d10)", medicWeapon.DamageDice.DieSize == 10);

            // Base-tier buy is UNAFFECTED by metal (gold-only) even at the upgraded smithy.
            int goldBeforeClub = gm.Gold;
            Check("(4b) base-tier club buy needs no metal (gold-only)", gm.BuyWeapon(SquadRoster.ScoutId, "club"));
            Check("(4b) base club cost only gold (15)", gm.Gold == goldBeforeClub - 15);

            gm.QueueFree();
        }

        // ── (7) Trading Post: buy/sell for gold + smithy-tier stock unlock ──
        // Isolated GameState (own bound inventory) so its buys/sells and the smithy upgrade don't
        // fight the shared scenario's accumulated carry. The store owns buy/sell now (off the smithy).
        GD.Print("-------------------- (7) Trading Post --------------------");
        {
            if (Godot.FileAccess.FileExists(SavePath))
                DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));

            var gp = new GameState { RealSecondsPerGameMinute = 0 };
            AddChild(gp);

            // BUY validates gold BEFORE consuming — a fresh empty wallet can't buy.
            Check("(7) buy rejected when gold short (empty wallet)", !gp.BuyGood("wood", 1));
            gp.EarnGold(1000);

            int woodBefore = gp.Inventory.Count("wood");
            int goldBefore = gp.Gold;
            Check("(7) buy 1 wood succeeds (gold + carry-fit)", gp.BuyGood("wood", 1));
            Check("(7) buy spent the gold (wood 4g)", gp.Gold == goldBefore - 4);
            Check("(7) bought wood landed in the inventory", gp.Inventory.Count("wood") == woodBefore + 1);

            // BUY respects the PF2e Bulk carry cap — 999 wood won't fit the party, nothing consumed.
            int goldBeforeOver = gp.Gold;
            int woodBeforeOver = gp.Inventory.Count("wood");
            Check("(7) buy rejected when it won't fit carry (999 wood)", !gp.BuyGood("wood", 999));
            Check("(7) over-cap buy spent no gold", gp.Gold == goldBeforeOver);
            Check("(7) over-cap buy added no wood", gp.Inventory.Count("wood") == woodBeforeOver);

            // SELL routes through the Trading Post now (GameState.SellItem → StoreSystem.Sell).
            gp.AddItem("goblin_fang", 2);
            int goldBeforeSell = gp.Gold;
            Check("(7) sell via trading post succeeds", gp.SellItem("goblin_fang", 2));
            Check("(7) sale credited gold (2 × 5)", gp.Gold == goldBeforeSell + 10);
            Check("(7) unsellable item still rejects (turnip seeds)", !gp.SellItem("turnip_seed", 1));

            // The sell shelf enumeration lives on the Trading Post view (the SmithyView never had it).
            gp.AddItem("rat_pelt", 3);
            var tpView = gp.GetTradingPostView();
            Check("(7) trading post view exposes the derived sell shelf",
                tpView.SellShelf.Any(s => s.ItemId == "rat_pelt" && s.Quantity == 3));
            Check("(7) smithy view carries NO sell shelf (moved to the trading post)",
                gp.GetSmithyView() is { } sv && sv.GetType().GetProperty("SellShelf") == null);

            // Smithy-tier UNLOCK: copper_ingot is locked at Base, opens once the smithy reaches Improved.
            Check("(7) copper_ingot offer locked at base smithy (buy rejected)", !gp.BuyGood("copper_ingot", 1));
            Check("(7) view: copper_ingot present but flagged locked at base",
                gp.GetTradingPostView().Offers.Any(o => o.ItemId == "copper_ingot" && !o.Unlocked));

            Check("(7) commission smithy", gp.CommissionBuilding("smithy"));
            gp.AddItem("stone", 8);
            gp.AddItem("goblin_fang", 6);
            gp.AddItem("rat_pelt", 5);
            Check("(7) contribute smithy tier2 bundle",
                gp.ContributeBundle("smithy", "stone", 8)
                && gp.ContributeBundle("smithy", "goblin_fang", 6)
                && gp.ContributeBundle("smithy", "rat_pelt", 5));
            Check("(7) upgrade smithy to Improved", gp.UpgradeBuilding("smithy"));
            Check("(7) smithy tier now Improved", gp.SmithyTier == SmithyTier.Improved);

            Check("(7) view: copper_ingot now unlocked after the smithy upgrade",
                gp.GetTradingPostView().Offers.Any(o => o.ItemId == "copper_ingot" && o.Unlocked));
            int goldBeforeIngot = gp.Gold;
            Check("(7) copper_ingot now buyable after the smithy upgrade", gp.BuyGood("copper_ingot", 1));
            Check("(7) copper_ingot buy spent 45g", gp.Gold == goldBeforeIngot - 45);
            Check("(7) bought copper_ingot landed in the inventory", gp.Inventory.Count("copper_ingot") == 1);

            gp.QueueFree();
        }

        // ── (5) Smithy view-model sanity ──
        var smithy = gs.GetSmithyView();
        Check("(5) smithy view-model built (gold + members + weapons)",
            smithy != null && smithy.Gold == gs.Gold && smithy.Members.Count == 4 && smithy.Weapons.Count > 0);

        // ── (6) Save round-trip: gold, runes, bought weapon ──
        GD.Print("-------------------- (6) Save round-trip --------------------");
        gs.SaveGame();
        int savedGold = gs.Gold;
        int vetPotency = vetWeapon.PotencyBonus;

        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(6) reloaded: gold balance round-trips", gs2.Gold == savedGold);

        var vet2 = gs2.Squad!.FindMember(SquadRoster.PlayerId)!;
        var vetWeapon2 = vet2.Equipment!.MainHandWeapon!;
        Check("(6) reloaded: Striking rune round-trips",
            vetWeapon2.Striking == PF2e.Data.StrikingRuneLevel.Striking
            && vetWeapon2.GetEffectiveDamageDice().NumberOfDice == 2);
        Check("(6) reloaded: Potency rune round-trips", vetWeapon2.PotencyBonus == vetPotency);

        var scholar2 = gs2.Squad!.FindMember(SquadRoster.ScholarId)!;
        Check("(6) reloaded: bought greataxe round-trips (d12 main hand)",
            scholar2.Equipment!.MainHandWeapon!.DamageDice.DieSize == 12);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    private static (bool ok, int bonus, int max) TryPreview(ICharacter attacker, ICharacter target)
    {
        try
        {
            var p = CombatPreviewCalculator.CalculateAttackPreview(attacker, target);
            return (true, p.TotalAttackBonus, p.DamageMax);
        }
        catch (Exception e)
        {
            GD.Print($"  [note] preview threw: {e.Message}");
            return (false, 0, 0);
        }
    }

    private static CombatSession StartSession(CombatSetup setup)
    {
        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        foreach (var (c, _) in setup.Party) CombatantRegistry.Instance!.Register(c);
        foreach (var (c, _) in setup.Enemies) CombatantRegistry.Instance!.Register(c);
        return session;
    }

    private static DamageResult Physical(int amount) =>
        new() { TotalDamage = amount, DamageType = DamageType.Slashing };

    // ─────────────────────────── Save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[EconomySpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[EconomySpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[EconomySpike] test slot0.json removed (no prior save existed).");
        }
    }
}
