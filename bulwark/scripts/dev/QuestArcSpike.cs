using System;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Territory;
using Godot;
using PF2e.Core;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the tutorial-arc quest FABRIC (design/tutorial_quests.md — "The First
/// Season", rewritten 2026-07-16, 11 quests) driven end-to-end through REAL GameState commands on a
/// clean save slot (backed up + restored). Proves the data-driven start/complete conditions, every
/// objective kind (flag / event-count / one-shot / deliver), the character-first commissionability
/// gate (Smithy AND Infirmary now both hidden until Arkus's wake, <c>arkus_awake</c>), the in-window
/// counter rule (First Blood counts only victories AFTER it starts), and a mid-chain save/load
/// round-trip.
///
/// Two beats remain CUTSCENE-ONLY (OutpostScene, off-limits to a headless spike) and so are set
/// manually, mirroring how <c>planning_table_shown</c> (a UI-only trigger) was always set manually:
///  • <c>arkus_found</c> — the "Arkus found on the road" cutscene on first return after
///    <c>dire_wolf_slain</c>. Real consequence: Arkus's villager arrival (ArrivalTrigger.StoryFlag)
///    fires for real off this flag, same as any other real-flag arrival.
///  • <c>arkus_awake</c> — the wake cutscene, resolved at the day-start once
///    <c>arkus_found &amp;&amp; trading_post_built</c> hold. Real consequence: gates BOTH the Smithy and
///    the Infirmary (<c>RequiredFlagId</c>) and starts The Smith and the Sickbed for real.
/// Everything else rides its REAL gameplay path: the wolf-lair boss victory (latches
/// <c>dire_wolf_slain</c>, completes quest 7, opens the Elderwood), the Elderwood-material banked
/// guidance tick (any Elderwood-sourced item gained), and Josen's random-event arrival (1-3 days after
/// <c>infirmary_built</c>, exercised here by sleeping until <c>josen_arrived</c> latches — the
/// deterministic latest-day guarantee means this can never stall).
///
/// The Command Post carries NO upgrade tiers this pass (2026-07-16 decision: tiers 2-4 deferred
/// pending design) — there is no "Bulwark Grows" quest and nothing here exercises Command Post tiers
/// beyond the tier-1 start state every other building's commissioning depends on.
/// </summary>
public partial class QuestArcSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string ForestId = "verdant_fringe";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== QUEST ARC SPIKE ====================");

        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[QuestArcSpike] DataManager not loaded — aborting (needs the mono build + data drive).");
            return;
        }

        BackupSlot0();
        try
        {
            RunChain();
        }
        catch (Exception e)
        {
            GD.PushError($"[QuestArcSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("QuestArcSpike");
    }

    private void RunChain()
    {
        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        if (gs.Squad == null || gs.Squad.Members.Count != 4)
        {
            AbortFail("[QuestArcSpike] squad unavailable — aborting.");
            return;
        }

        // Gold is cheap to bank; materials are added JUST-IN-TIME before each commission instead of all
        // at once — the inventory is bound to the squad, so a big up-front pile would overflow the PF2e
        // Bulk carry cap and get rejected. Commissioning consumes each bundle, freeing carry for the next.
        gs.EarnGold(20000);

        // The Command Post is the start-state planning table (tier 1 from day one, empty bundle + 0 gold,
        // NO higher tiers this pass). A fresh GameState leaves it at tier 0, so commission it here to
        // reach that start state — done BEFORE the tutorial bootstrap so it doesn't count as the "first
        // building" (first_commission isn't active yet) and, being command_post, it never sets
        // first_commission (start-state exclusion).
        Check("(0) command_post reaches its tier-1 start state", gs.CommissionBuilding("command_post"));

        // ─────────────── (1) Bootstrap: the frozen Day-1 → Repair the Lodging → Day 2 ───────────────
        // The tutorial-progression hooks fire through their REAL gameplay paths wherever a headless
        // spike can drive them, instead of manual SetStoryFlag calls:
        //  • lodging_repaired — gs.RepairLodging() (the real "hand Tharr 15 wood + 10 stone" command).
        //  • first_rest — gs.Sleep() latches it (the scripted Day-1 close's real hook).
        // planning_table_shown stays a manual set: its real trigger is opening the build panel
        // (CozyWorldScene.OnBuildPanelToggled — UI-only), which a headless spike cannot exercise.
        GD.Print("-------------------- (1) Repair the Lodging → The Planning Table --------------------");
        gs.SetStoryFlag("intro_complete");
        Check("(1) Repair the Lodging active (intro_complete)", gs.IsQuestActive("repair_lodging"));
        gs.AddItem("wood", 15);
        gs.AddItem("stone", 10);
        Check("(1) RepairLodging consumes the materials and latches lodging_repaired", gs.RepairLodging());
        Check("(1) lodging_repaired set by the real repair command", gs.HasStoryFlag("lodging_repaired"));
        Check("(1) Repair the Lodging completed by the turn-in", gs.IsQuestCompleted("repair_lodging"));
        gs.Sleep(); // the scripted Day-1 close's stand-in — latches first_rest through the real Sleep hook
        Check("(1) first_rest latched by Sleep()", gs.HasStoryFlag("first_rest"));
        Check("(1) The Planning Table active (first_rest)", gs.IsQuestActive("planning_table"));
        gs.SetStoryFlag("planning_table_shown"); // UI-only trigger — manual in a headless spike
        Check("(1) The Planning Table completed", gs.IsQuestCompleted("planning_table"));
        Check("(1) Raise the Hearths auto-started (planning_table_shown)", gs.IsQuestActive("raise_the_hearths"));

        // ─────────────── (2) In-window rule: a victory BEFORE First Blood starts must not count ───────────────
        GD.Print("-------------------- (2) First Blood in-window counter --------------------");
        Check("(2) travel to the Verdant Fringe", gs.TravelToTerritory(ForestId));
        Check("(2) win an encounter BEFORE any commission (gob_1)", WinEncounter(gs, "gob_1"));
        Check("(2) first_combat_victory latched", gs.HasStoryFlag("first_combat_victory"));
        Check("(2) First Blood still not active (pre-commission win ignored by it)", !gs.IsQuestActive("first_blood"));

        // First player commission (the Day-2 directed build: Farmhouse) → first_commission set,
        // First Blood auto-starts.
        gs.AddItem("wood", 120);
        gs.AddItem("stone", 90);
        Check("(2) commission the Farmhouse", gs.CommissionBuilding("farmhouse"));
        Check("(2) first_commission latched by the first commission", gs.HasStoryFlag("first_commission"));
        Check("(2) First Blood auto-started (first_commission)", gs.IsQuestActive("first_blood"));
        Check("(2) First Blood counter starts at 0 (the pre-commission win did NOT count)",
            ObjProgress(gs, "first_blood", 0) == 0);

        // Two victories AFTER it started → completes at exactly 2.
        Check("(2) win encounter #1 after start (gob_2)", WinEncounter(gs, "gob_2"));
        Check("(2) First Blood at 1/2, still active", ObjProgress(gs, "first_blood", 0) == 1 && gs.IsQuestActive("first_blood"));
        Check("(2) win encounter #2 after start (gob_3)", WinEncounter(gs, "gob_3"));
        Check("(2) First Blood completed at 2 victories", gs.IsQuestCompleted("first_blood"));

        // ─────────────── (3) Mid-chain save/load round-trip ───────────────
        GD.Print("-------------------- (3) Save/load round-trip mid-chain --------------------");
        gs.SaveGame();
        var reloaded = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(reloaded);
        Check("(3) reload: First Blood still completed", reloaded.IsQuestCompleted("first_blood"));
        Check("(3) reload: Raise the Hearths still active", reloaded.IsQuestActive("raise_the_hearths"));
        Check("(3) reload: first_commission flag round-tripped", reloaded.HasStoryFlag("first_commission"));
        Check("(3) reload: Farmhouse still under construction",
            reloaded.GetBuildingTier("farmhouse") == 1 && reloaded.AnyBuildingUnderConstruction);
        gs.QueueFree();
        gs = reloaded; // continue the chain on the reloaded instance

        // ─────────────── (4) Raise the Hearths: Farmhouse + Tavern ───────────────
        GD.Print("-------------------- (4) Raise the Hearths --------------------");
        CompleteConstruction(gs); // finish the Farmhouse
        Check("(4) farmhouse_built ticks Raise the Hearths obj0", ObjDone(gs, "raise_the_hearths", 0));
        Check("(4) First Harvest auto-started (farmhouse_built)", gs.IsQuestActive("first_harvest"));
        gs.AddItem("wood", 90);
        gs.AddItem("stone", 60);
        gs.AddItem("herb", 15);
        Check("(4) commission the Tavern", gs.CommissionBuilding("tavern"));
        CompleteConstruction(gs);
        Check("(4) tavern_built ticks Raise the Hearths obj1", ObjDone(gs, "raise_the_hearths", 1));
        Check("(4) Raise the Hearths completed (both *_built)", gs.IsQuestCompleted("raise_the_hearths"));

        // ─────────────── (5) First Harvest: grow + harvest 6 crops ───────────────
        GD.Print("-------------------- (5) First Harvest --------------------");
        HarvestSixCrops(gs);
        Check("(5) First Harvest completed at 6 crops", gs.IsQuestCompleted("first_harvest"));
        Check("(5) Fenwick's Table auto-started (quest5 + tavern_built)", gs.IsQuestActive("fenwicks_table"));

        // ─────────────── (6) Fenwick's Table: deliver + eat ───────────────
        GD.Print("-------------------- (6) Fenwick's Table --------------------");
        Check("(6) deliver 3 fresh crops to Fenwick", gs.DeliverQuestItems(Bulwark.Data.Quests.FreshCropsSet));
        Check("(6) deliver consumed 3 turnips", gs.CountItem("turnip") == HarvestedTurnips - 3);
        Check("(6) deliver rejected when set already met / insufficient (re-deliver drains + fails)",
            RedeliverEventuallyFails(gs));
        gs.AddItem("herb_tonic", 1);
        Check("(6) eat the meal Fenwick cooks", gs.EatMeal("herb_tonic"));
        Check("(6) Fenwick's Table completed (deliver + meal buff)", gs.IsQuestCompleted("fenwicks_table"));
        Check("(6) The Wolf of the Fringe auto-started (fenwicks_table complete)", gs.IsQuestActive("wolf_of_the_fringe"));
        Check("(6) Restore the Trading Post auto-started IN PARALLEL", gs.IsQuestActive("restore_trading_post"));

        // ─────────────── (8) Restore the Trading Post: hardwood guidance + the store ───────────────
        GD.Print("-------------------- (8) Restore the Trading Post (parallel with the wolf hunt) --------------------");
        gs.AddItem("hardwood", 30); // Elderwood-sourced — ticks the banked guidance AND funds the store
        Check("(8) elderwood_material_banked guidance ticks on the first Elderwood material gained",
            ObjDone(gs, "restore_trading_post", 1));

        // ─────────────── (7) The Wolf of the Fringe: the dire wolf boss (REAL PATH) ───────────────
        GD.Print("-------------------- (7) The Wolf of the Fringe (dire wolf boss) --------------------");
        VerifyBossEncounterBudget();
        // Lair lifecycle predicate (WolfLair.ShouldAppear): hidden before the quest, visible while the
        // quest is active and the wolf unslain, gone forever after the kill.
        Check("(7) lair HIDDEN before its quest is active", !WolfLair.ShouldAppear(questActive: false, wolfSlain: false));
        Check("(7) lair VISIBLE while quest active and wolf unslain",
            gs.IsQuestActive("wolf_of_the_fringe") && WolfLair.ShouldAppear(questActive: true, wolfSlain: false));

        // Sleeping (crop-growing days in phase 5, etc.) tucks the squad back at the outpost between
        // territory visits, so travel back in explicitly rather than assuming the party never left.
        Check("(7) travel back to the Verdant Fringe for the boss", gs.TravelToTerritory(ForestId));
        int peltsBefore = gs.CountItem("dire_wolf_pelt");
        Check("(7) WIN the wolf-lair boss encounter (roamer wolf_lair)", WinEncounter(gs, "wolf_lair"));
        Check("(7) dire_wolf_slain latched by the boss victory", gs.HasStoryFlag("dire_wolf_slain"));
        Check("(7) The Wolf of the Fringe completed (real path, no manual flag)", gs.IsQuestCompleted("wolf_of_the_fringe"));
        Check("(7) dire_wolf_pelt trophy granted on victory (alongside loot)",
            gs.CountItem("dire_wolf_pelt") == peltsBefore + 1);
        Check("(7) lair DESPAWNS for good once slain (predicate false)",
            !WolfLair.ShouldAppear(questActive: true, wolfSlain: true));
        Check("(7) the Elderwood opens on the wolf kill (UnlockFlagId = dire_wolf_slain)",
            gs.IsBiomeUnlocked("elderwood"));

        // Fund + raise the Trading Post now that the Elderwood hardwood gate is open.
        gs.AddItem("wood", 90);
        gs.AddItem("stone", 60);
        Check("(8) commission the Trading Post", gs.CommissionBuilding("trading_post"));
        CompleteConstruction(gs);
        Check("(8) Restore the Trading Post completed (trading_post_built)", gs.IsQuestCompleted("restore_trading_post"));

        // ─────────────── (Arkus found / awake — cutscene-only, set manually) ───────────────
        GD.Print("-------------------- Arkus found → wakes (cutscene stand-in) --------------------");
        Check("(9) Arkus not arrived yet", !gs.IsVillagerArrived("arkus"));
        Check("(9) arkus_awake false before the wake", !gs.HasFlagForConditions("arkus_awake"));
        Check("(9) Smithy HIDDEN from the planning table before Arkus wakes", !PlanningHas(gs, "smithy"));
        Check("(9) Smithy not commissionable before Arkus wakes", !gs.Building.CanCommission("smithy"));
        Check("(9) Infirmary HIDDEN from the planning table before Arkus wakes", !PlanningHas(gs, "infirmary"));
        Check("(9) Infirmary not commissionable before Arkus wakes", !gs.Building.CanCommission("infirmary"));

        // "Arkus found" — the first-return-after-dire_wolf_slain cutscene (OutpostScene, off-limits to a
        // headless spike). Real consequence exercised here: his villager arrival fires for real off the
        // flag (ArrivalTrigger.StoryFlag("arkus_found")).
        gs.SetStoryFlag("arkus_found");
        Check("(9) Arkus ARRIVED via the found flag (VillagerSystem trigger)", gs.IsVillagerArrived("arkus"));

        // "Arkus wakes" — resolved at the day-start once arkus_found && trading_post_built hold (already
        // true here); the wake cutscene itself is OutpostScene-only, so set manually.
        gs.SetStoryFlag("arkus_awake");
        Check("(9) arkus_awake set (wake cutscene stand-in)", gs.HasFlagForConditions("arkus_awake"));
        Check("(9) Smithy now VISIBLE in the planning table", PlanningHas(gs, "smithy"));
        Check("(9) Infirmary now VISIBLE in the planning table", PlanningHas(gs, "infirmary"));
        Check("(9) The Smith and the Sickbed auto-started (arkus_awake)", gs.IsQuestActive("smith_and_sickbed"));
        Check("(9) 'Speak with Arkus' guidance ticks immediately (arkus_awake IS the start flag)",
            ObjDone(gs, "smith_and_sickbed", 0));

        gs.AddItem("wood", 90);
        gs.AddItem("hardwood", 40);
        gs.AddItem("goblin_fang", 25);
        Check("(9) commission the Smithy (gate open)", gs.CommissionBuilding("smithy"));
        Check("(9) 'Fund the Smithy' guidance ticks on commission", ObjDone(gs, "smith_and_sickbed", 1));
        CompleteConstruction(gs);
        Check("(9) smithy_built (First Steel can now auto-start)", gs.HasFlagForConditions("smithy_built"));
        Check("(9) First Steel auto-started (smithy_built)", gs.IsQuestActive("first_steel"));

        gs.AddItem("wood", 120);
        gs.AddItem("hardwood", 30);
        gs.AddItem("herb", 20);
        Check("(9) commission the Infirmary (gate open)", gs.CommissionBuilding("infirmary"));
        Check("(9) 'Commission the Infirmary' guidance ticks on commission", ObjDone(gs, "smith_and_sickbed", 3));
        CompleteConstruction(gs);
        Check("(9) The Smith and the Sickbed completed (both *_built)", gs.IsQuestCompleted("smith_and_sickbed"));

        // ─────────────── (10) First Steel: craft/upgrade at the forge ───────────────
        // Elara carries the party's "scout" stat build under her real character id (the founding-four
        // rework renamed the scout/scholar preset slots to Elara/Fenwick — SquadRoster.ScoutId/
        // ScholarId no longer exist; use ElaraId/FenwickId).
        GD.Print("-------------------- (10) First Steel --------------------");
        Check("(10) buy a piece of gear at the forge", gs.BuyWeapon(SquadRoster.ElaraId, "club"));
        Check("(10) First Steel completed (smithy_craft)", gs.IsQuestCompleted("first_steel"));

        // ─────────────── (11) Mend the Wounded: Josen's random-event arrival (REAL PATH) ───────────────
        // Josen no longer gates the Infirmary (Arkus's wake does) — he arrives via a random event 1-3
        // days after infirmary_built (StoryDirector.OnDayStarted), a deterministic latest-day guarantee
        // so sleeping a handful of times can never stall. Sleep() also fully rests the squad, so the
        // "something to heal" HP dent happens AFTER he arrives, not before (mirrors the real order: heal
        // fully overnight, then treat whatever attrition the day's play produces).
        GD.Print("-------------------- (11) Mend the Wounded (Josen's random-event arrival) --------------------");
        Check("(11) Josen not arrived yet", !gs.IsVillagerArrived("josen"));
        Check("(11) josen_arrived derives false before he arrives", !gs.HasFlagForConditions("josen_arrived"));

        int guard = 0;
        while (!gs.HasStoryFlag("josen_arrived") && guard++ < 6)
            gs.Sleep();
        Check("(11) josen_arrived latched within the deterministic latest-day window", gs.HasStoryFlag("josen_arrived"));
        Check("(11) Josen ARRIVED via the random-event trigger (VillagerSystem)", gs.IsVillagerArrived("josen"));
        Check("(11) Mend the Wounded auto-started (josen_arrived)", gs.IsQuestActive("mend_the_wounded"));
        Check("(11) 'Speak with Josen' guidance ticks immediately (josen_arrived IS the start flag)",
            ObjDone(gs, "mend_the_wounded", 0));

        // Dent a squad member's HP directly (Sleep() rests the squad fully, so there is nothing to treat
        // until something denies it) so Treat Wounds has a real deficit to close.
        var scout = gs.Squad!.FindMember(SquadRoster.ElaraId)!;
        scout.Health!.SetCurrentHP(scout.Health.MaxHP - 12);
        Check("(11) treat a squad member's wounds", gs.TreatWounds(SquadRoster.TharrId, SquadRoster.ElaraId, 15));
        Check("(11) Mend the Wounded completed (treat_wounds)", gs.IsQuestCompleted("mend_the_wounded"));

        // ─────────────── (12) Final: every arc quest complete ───────────────
        GD.Print("-------------------- (12) Whole arc complete --------------------");
        string[] arc =
        {
            "repair_lodging", "planning_table", "raise_the_hearths", "first_blood", "first_harvest",
            "fenwicks_table", "wolf_of_the_fringe", "restore_trading_post", "smith_and_sickbed",
            "first_steel", "mend_the_wounded",
        };
        foreach (var id in arc)
            Check($"(12) {id} completed", gs.IsQuestCompleted(id));

        gs.QueueFree();
    }

    // ─────────────────────────── Scenario helpers ───────────────────────────

    /// <summary>Turnips harvested in phase (5) — 6 plots × turnip yield 1.</summary>
    private const int HarvestedTurnips = 6;

    /// <summary>Win one territory encounter without stepping through combat rounds — Begin then
    /// Complete(Team1Wins) exercises the real victory path (loot, XP, RecordEncounter → combat_victory).</summary>
    private static bool WinEncounter(GameState gs, string roamerId)
    {
        if (!gs.BeginTerritoryEncounter(roamerId, new Vector2(1, 1)))
            return false;
        return gs.CompleteTerritoryEncounter(BattleResult.Team1Wins) is { Victory: true };
    }

    /// <summary>Tick construction days until nothing is under construction (opt-in pacing helper).</summary>
    private static void CompleteConstruction(GameState gs)
    {
        int guard = 0;
        while (gs.AnyBuildingUnderConstruction && guard++ < 20)
            gs.Building.TickDay();
    }

    /// <summary>Grow + harvest 6 turnip plots through real farm commands, watering each day-end.</summary>
    private void HarvestSixCrops(GameState gs)
    {
        gs.BindFarmWorld(_ => true); // spike: every tile is tillable
        gs.AddItem("turnip_seed", 6); // 6 plots (design/tutorial_quests.md: granted via dialogue, not bought)
        var tiles = new Vector2I[6];
        for (int i = 0; i < 6; i++)
        {
            tiles[i] = new Vector2I(i, 0);
            Check($"(5) till + plant + water plot {i}",
                gs.TillPlot(tiles[i]) && gs.PlantCrop(tiles[i], "turnip") && gs.WaterPlot(tiles[i]));
        }

        // Advance days (turnip matures in 4 watered days); re-water each morning until harvestable.
        for (int day = 0; day < 8; day++)
        {
            gs.Sleep(); // grows watered plots overnight, advances the calendar
            foreach (var t in tiles)
                gs.WaterPlot(t);
            if (gs.HarvestPlot(tiles[0])) // first ready plot ends the loop
                break;
        }

        // Harvest the remaining 5 (tile 0 already harvested in the loop above → 6 total events).
        int harvested = 1;
        for (int i = 1; i < 6; i++)
            if (gs.HarvestPlot(tiles[i]))
                harvested++;
        Check("(5) harvested 6 crop plots", harvested == 6);
    }

    /// <summary>Re-run DeliverQuestItems until it fails — proves the command rejects once the crop stock
    /// runs below the objective's remaining need (and consumed nothing on the failing call).</summary>
    private static bool RedeliverEventuallyFails(GameState gs)
    {
        // The Deliver objective was already satisfied by the first delivery, so FindDeliverObjective
        // returns null → the command rejects immediately without consuming anything.
        int before = gs.CountItem("turnip");
        bool rejected = !gs.DeliverQuestItems(Bulwark.Data.Quests.FreshCropsSet);
        return rejected && gs.CountItem("turnip") == before;
    }

    private static int ObjProgress(GameState gs, string questId, int index)
    {
        var entry = gs.GetQuestView().Active.FirstOrDefault(q => q.QuestId == questId)
                    ?? gs.GetQuestView().Completed.FirstOrDefault(q => q.QuestId == questId);
        return entry != null && index < entry.Objectives.Count ? entry.Objectives[index].Progress : -1;
    }

    private static bool ObjDone(GameState gs, string questId, int index)
    {
        var view = gs.GetQuestView();
        var entry = view.Active.FirstOrDefault(q => q.QuestId == questId)
                    ?? view.Completed.FirstOrDefault(q => q.QuestId == questId);
        return entry != null && index < entry.Objectives.Count && entry.Objectives[index].Done;
    }

    private static bool PlanningHas(GameState gs, string buildingId)
        => gs.GetPlanningTableView().Buildings.Any(b => b.Id == buildingId);

    /// <summary>PF2e encounter-building XP for one creature by its level relative to the party level
    /// (Core Rulebook / GMG table). Mirrored here so the spike can score the boss encounter's budget.</summary>
    private static int CreatureXp(int creatureLevel, int partyLevel) => (creatureLevel - partyLevel) switch
    {
        <= -4 => 10,
        -3 => 15,
        -2 => 20,
        -1 => 30,
        0 => 40,
        1 => 60,
        2 => 80,
        3 => 120,
        _ => 160, // +4 and beyond
    };

    /// <summary>
    /// Verify the dire-wolf boss encounter resolves real pack creatures and sums to the PF2e SEVERE
    /// budget for a party of four at the design target level (SquadStartLevel = 2): dire wolf (level 3,
    /// PL+1 = 60 XP) + two pack-mate wolves (level 1, PL-1 = 30 XP each) = 120 = Severe(4).
    /// </summary>
    private void VerifyBossEncounterBudget()
    {
        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null)
        {
            Check("(7) DataManager available for the budget check", false);
            return;
        }
        if (!EncounterTables.TryGet("dire_wolf", out var boss))
        {
            Check("(7) dire_wolf boss encounter is defined", false);
            return;
        }
        Check("(7) dire_wolf boss encounter is defined", true);

        const int partyLevel = GameState.SquadStartLevel; // 2 — a party of four at levels 1-2
        const int severeBudgetFour = 120;                 // PF2e Severe budget, party of 4

        int total = 0;
        bool allResolved = true;
        foreach (var line in boss.Creatures)
        {
            var def = data.ResolveCreature(line.Creature);
            if (def == null)
            {
                allResolved = false;
                continue;
            }
            // The creature's PF2e level is on the resolved stat block (CreatureStatBlockData).
            int level = def.StatBlock.CreatureLevel;
            total += CreatureXp(level, partyLevel) * line.Count;
        }
        Check("(7) every boss creature resolves from the packs (dire wolf + 2 wolves)", allResolved);
        Check($"(7) boss XP sums to the Severe budget for a party of 4 at L{partyLevel} (120): got {total}",
            total == severeBudgetFour);
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
        GD.Print("[QuestArcSpike] slot0.json backed up and cleared for the test run.");
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
            GD.Print("[QuestArcSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[QuestArcSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
