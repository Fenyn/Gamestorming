using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Conditions;
using PF2e.Core;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the Phase-5 PROVISIONS layer: the crafting/recipe system (raw→refined
/// artisan chains) and the meal → day-long-buff system. Sections:
///  (A) CraftingSystem in isolation, over an Inventory bound to a real squad + a SYNTHETIC unlock
///      delegate (a HashSet under our control — no station-building content baked in):
///        - a BASELINE recipe (wood→plank) crafts: inputs consumed, output added, DayClock time spent;
///        - a STATION-GATED recipe (copper_ore→copper_ingot) is REJECTED until its "smelter" category
///          is unlocked (synthetic), then succeeds;
///        - a missing-input craft rejects and consumes NOTHING;
///        - a carry-cap-overflow craft rejects and consumes NOTHING (WouldFit gate).
///  (B) Real GameState wiring: a baseline plank craft advances the clock + moves inventory; a gated
///      recipe rejects at BASELINE (no station category unlocked in shipped play).
///  (C) Meals via GameState: eating applies the buff to the ROSTER and it AFFECTS COMBAT STATS
///      (Fortitude status modifier / Speed modifier / temp HP are live on every member); SINGLE-ACTIVE
///      (re-eating replaces); the buff CLEARS on sleep/day; BASELINE (no meal) leaves stats untouched.
///  (D) Save/load: the active meal id persists (v6) and RE-APPLIES to the rebuilt roster on load.
/// The user's slot0.json is backed up and restored around the run.
/// </summary>
public partial class ProvisionsSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string ForestId = "verdant_fringe";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== PROVISIONS SPIKE ====================");

        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[ProvisionsSpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            RunCraftingIsolation();  // (A)
            RunCraftingWiring();     // (B)
            RunMeals();              // (C)
            RunMealCombatRefresh();  // (C2)
            RunMealPersistence();    // (D)
        }
        catch (Exception e)
        {
            GD.PushError($"[ProvisionsSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("ProvisionsSpike");
    }

    // ─────────────────────────── (A) CraftingSystem isolation ───────────────────────────

    private void RunCraftingIsolation()
    {
        GD.Print("-------------------- (A) CraftingSystem (bound inventory + synthetic unlock) --------------------");

        var squad = SquadRoster.BuildNew(2);
        var inv = new Inventory();
        inv.BindSquad(squad);
        var clock = new DayClock();

        var unlocked = new HashSet<string>();
        var crafting = new CraftingSystem(inv, clock, id => unlocked.Contains(id));
        int craftedEvents = 0;
        crafting.Crafted += _ => craftedEvents++;

        // ---- Baseline recipe: wood → plank (no station required) ----
        inv.AddItem("wood", 4);
        int woodBefore = inv.Count("wood");
        int minuteBefore = clock.MinuteOfDay;
        Check("(A) baseline recipe reports unlocked", crafting.CanCraft("craft_plank"));
        bool plankOk = crafting.Craft("craft_plank");
        Check("(A) baseline plank craft succeeds", plankOk);
        Check("(A) plank inputs consumed (wood -2)", inv.Count("wood") == woodBefore - 2);
        Check("(A) plank output added (+1 plank)", inv.Count("plank") == 1);
        Check("(A) craft spent DayClock time (+10 min)", clock.MinuteOfDay == minuteBefore + 10);
        Check("(A) Crafted event fired once", craftedEvents == 1);

        // ---- Station-gated recipe: copper_ore → copper_ingot, gated on "smelter" ----
        inv.AddItem("copper_ore", 4);
        Check("(A) gated recipe LOCKED before unlock (CanCraft false)", !crafting.CanCraft("craft_copper_ingot"));
        int oreBefore = inv.Count("copper_ore");
        Check("(A) gated craft rejected while locked", !crafting.Craft("craft_copper_ingot"));
        Check("(A) locked reject consumed nothing", inv.Count("copper_ore") == oreBefore && inv.Count("copper_ingot") == 0);

        unlocked.Add(Recipes.SmelterCategory); // synthetic station unlock
        Check("(A) gated recipe UNLOCKED after category added", crafting.CanCraft("craft_copper_ingot"));
        Check("(A) gated ingot craft succeeds once unlocked", crafting.Craft("craft_copper_ingot"));
        Check("(A) ingot inputs consumed + output added",
            inv.Count("copper_ore") == oreBefore - 2 && inv.Count("copper_ingot") == 1);

        // ---- Missing-input reject: no herb present + still locked → nothing consumed ----
        unlocked.Add(Recipes.StillCategory);
        Check("(A) tincture recipe unlocked but no herb → CanCraft false", !crafting.CanCraft("craft_tincture"));
        Check("(A) missing-input craft rejected", !crafting.Craft("craft_tincture"));
        Check("(A) missing-input reject added no tincture", inv.Count("tincture") == 0);

        // ---- Carry-cap reject: fill every member to their Bulk cap with wood, then a plank craft
        //      can't place its (Bulk-1) output → WouldFit false → reject, consume nothing. ----
        var capInv = new Inventory();
        capInv.BindSquad(SquadRoster.BuildNew(2));
        var capClock = new DayClock();
        var capCraft = new CraftingSystem(capInv, capClock, _ => true);
        capInv.AddItem("wood", 500); // overshoots every member's hard cap; surplus rejected at the cap
        Check("(A) members saturated → plank output would not fit", !capInv.WouldFit("plank", 1));
        int capWoodBefore = capInv.Count("wood");
        int capMinuteBefore = capClock.MinuteOfDay;
        Check("(A) carry-cap craft rejected", !capCraft.Craft("craft_plank"));
        Check("(A) carry-cap reject consumed nothing (wood unchanged, no plank)",
            capInv.Count("wood") == capWoodBefore && capInv.Count("plank") == 0);
        Check("(A) carry-cap reject spent no time", capClock.MinuteOfDay == capMinuteBefore);
    }

    // ─────────────────────────── (B) Crafting via GameState ───────────────────────────

    private void RunCraftingWiring()
    {
        GD.Print("-------------------- (B) GameState crafting wiring --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        int recipeEvents = 0;
        gs.RecipeCrafted += _ => recipeEvents++;

        // Baseline plank craft through the command: clock advances, inventory moves.
        gs.AddItem("wood", 6);
        int woodBefore = gs.Inventory.Count("wood");
        int minuteBefore = gs.Clock.MinuteOfDay;
        Check("(B) GameState baseline plank craft succeeds", gs.Craft("craft_plank"));
        Check("(B) command consumed inputs + added output",
            gs.Inventory.Count("wood") == woodBefore - 2 && gs.Inventory.Count("plank") == 1);
        Check("(B) command spent clock time (+10 min)", gs.Clock.MinuteOfDay == minuteBefore + 10);
        Check("(B) RecipeCrafted event re-exposed", recipeEvents == 1);

        // Station-gated recipe rejects at baseline (no station category unlocked in shipped play).
        gs.AddItem("copper_ore", 4);
        Check("(B) baseline: no station categories unlocked", gs.UnlockedCategories.Count == 0);
        Check("(B) gated recipe rejected at baseline", !gs.Craft("craft_copper_ingot"));
        Check("(B) gated reject consumed nothing", gs.Inventory.Count("copper_ore") == 4 && gs.Inventory.Count("copper_ingot") == 0);

        // View-model reflects gate + have/need.
        var view = gs.GetCraftingView();
        var plankView = view.Recipes.First(r => r.RecipeId == "craft_plank");
        var ingotView = view.Recipes.First(r => r.RecipeId == "craft_copper_ingot");
        Check("(B) view: baseline recipe unlocked", plankView.Unlocked);
        Check("(B) view: gated recipe locked at baseline", !ingotView.Unlocked);

        gs.QueueFree();
    }

    // ─────────────────────────── (C) Meals: apply / replace / clear / baseline ───────────────────────────

    private void RunMeals()
    {
        GD.Print("-------------------- (C) Meal buffs (apply to roster, affect stats, clear on rest) --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        if (gs.Squad == null)
        {
            Fail();
            GD.PushError("[ProvisionsSpike] squad unavailable — cannot test meals.");
            gs.QueueFree();
            return;
        }
        var members = gs.Squad.Members;

        int mealEvents = 0;
        gs.MealChanged += () => mealEvents++;

        // BASELINE: no meal → no buff modifiers, no temp HP.
        Check("(C) baseline: no active meal", gs.ActiveMealId == null);
        Check("(C) baseline: no Fortitude/Speed meal modifier, no temp HP",
            members.All(m => m.Modifiers!.GetModifierTotal(StatType.Fortitude) == 0
                             && m.Modifiers!.GetModifierTotal(StatType.Speed) == 0
                             && m.Health!.TempHP == 0));

        // Eat the Fortitude-save meal (herb_tonic, +1 status Fortitude) — buff lands on EVERY member.
        gs.AddItem("herb_tonic", 1);
        Check("(C) eat herb_tonic succeeds", gs.EatMeal("herb_tonic"));
        Check("(C) active meal is herb_tonic", gs.ActiveMealId == "herb_tonic");
        Check("(C) herb_tonic consumed from inventory", gs.Inventory.Count("herb_tonic") == 0);
        Check("(C) +1 Fortitude status modifier live on every roster member (affects saves)",
            members.All(m => m.Modifiers!.GetModifierTotal(StatType.Fortitude) == 1));
        Check("(C) MealChanged event fired", mealEvents == 1);

        // SINGLE-ACTIVE: eat the Speed meal (travel_ration, +5 ft) — replaces the Fortitude buff.
        gs.AddItem("travel_ration", 1);
        Check("(C) eat travel_ration succeeds", gs.EatMeal("travel_ration"));
        Check("(C) active meal replaced → travel_ration", gs.ActiveMealId == "travel_ration");
        Check("(C) prior Fortitude buff cleared (single-active)",
            members.All(m => m.Modifiers!.GetModifierTotal(StatType.Fortitude) == 0));
        Check("(C) +5 Speed modifier live on every member",
            members.All(m => m.Modifiers!.GetModifierTotal(StatType.Speed) == 5));

        // Temp-HP meal (hearty_stew, +5 temp HP) — replaces Speed; temp HP shows on Health (combat).
        gs.AddItem("hearty_stew", 1);
        Check("(C) eat hearty_stew succeeds", gs.EatMeal("hearty_stew"));
        Check("(C) active meal replaced → hearty_stew", gs.ActiveMealId == "hearty_stew");
        Check("(C) prior Speed buff cleared", members.All(m => m.Modifiers!.GetModifierTotal(StatType.Speed) == 0));
        Check("(C) +5 temp HP live on every member (absorbs combat damage)",
            members.All(m => m.Health!.TempHP == 5));

        // CLEAR on rest/day: sleeping advances the day → the meal buff expires.
        gs.Sleep();
        Check("(C) sleep cleared the active meal", gs.ActiveMealId == null);
        Check("(C) sleep cleared the temp HP buff off the roster",
            members.All(m => m.Health!.TempHP == 0));

        // Unknown / absent-item eats reject cleanly.
        Check("(C) eating an undefined meal rejects", !gs.EatMeal("nope"));
        Check("(C) eating a meal you don't hold rejects", !gs.EatMeal("herb_tonic"));

        gs.QueueFree();
    }

    // ────────────── (C2) Day-long meal: per-combat temp HP refresh + persistent all-day modifiers ──────────────

    /// <summary>
    /// Refinement 1: a meal is a DAY-LONG benefit. Its PER-COMBAT component (temp HP) is wiped by
    /// post-combat cleanup but RE-GRANTED at the start of every encounter within the day (well-fed =
    /// fresh temp HP each fight); its PERSISTENT components (stat/attack/AC modifiers) are applied once
    /// on eat and survive every fight, cleared only on the next day rollover. Proven end-to-end through
    /// GameState: eat → fight cleanup wipes temp HP but the meal stays active → BeginTerritoryEncounter
    /// (the encounter-start seam) re-applies it; the new ATTACK-bonus kind lands on attack rolls and
    /// persists across a fight; sleep (day rollover) clears everything.
    /// </summary>
    private void RunMealCombatRefresh()
    {
        GD.Print("-------------------- (C2) Per-combat temp-HP refresh + persistent all-day modifiers --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        if (gs.Squad == null) { Fail(); gs.QueueFree(); return; }
        var members = gs.Squad.Members;

        // ---- Per-combat component (temp HP) refreshes at each encounter start ----
        gs.AddItem("hearty_stew", 1);
        Check("(C2) eat hearty_stew (per-combat temp-HP meal)", gs.EatMeal("hearty_stew"));
        Check("(C2) +5 temp HP present after eating", members.All(m => m.Health!.TempHP == 5));

        // A fight's post-combat cleanup wipes temp HP — but the meal stays active (day-long).
        gs.CompleteEncounter(BattleResult.Team1Wins, null);
        Check("(C2) post-combat cleanup wiped the temp HP", members.All(m => m.Health!.TempHP == 0));
        Check("(C2) meal still active after the fight (day-long)", gs.ActiveMealId == "hearty_stew");

        // Starting the NEXT encounter re-grants the per-combat temp HP (fresh cushion, present in-fight).
        Check("(C2) travel to the forest", gs.TravelToTerritory(ForestId));
        Check("(C2) begin encounter (roamer contact seam)", gs.BeginTerritoryEncounter("gob_1", new Vector2(1, 1)));
        Check("(C2) temp HP re-applied at encounter start (present in-fight)",
            members.All(m => m.Health!.TempHP == 5));

        gs.QueueFree();

        // ---- Persistent all-day component (ATTACK bonus) survives a fight; cleared on day rollover ----
        ClearSlot0();
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        var m2 = gs2.Squad!.Members;

        gs2.AddItem("battle_draught", 1);
        Check("(C2) eat battle_draught (new attack-bonus meal)", gs2.EatMeal("battle_draught"));
        Check("(C2) +1 status ATTACK-roll modifier live on every member (lands on attack rolls)",
            m2.All(m => m.Modifiers!.GetModifierTotal(StatType.AttackRoll) == 1));

        // A fight's cleanup must NOT strip the persistent modifier (all-day benefit).
        gs2.CompleteEncounter(BattleResult.Team1Wins, null);
        Check("(C2) attack-bonus persists across the fight (all-day, not per-combat)",
            m2.All(m => m.Modifiers!.GetModifierTotal(StatType.AttackRoll) == 1));

        // Day rollover (sleep) clears ALL meal components.
        gs2.Sleep();
        Check("(C2) day rollover cleared the active meal", gs2.ActiveMealId == null);
        Check("(C2) attack-bonus cleared on day rollover",
            m2.All(m => m.Modifiers!.GetModifierTotal(StatType.AttackRoll) == 0));

        gs2.QueueFree();
    }

    // ─────────────────────────── (D) Active-meal save/load persistence ───────────────────────────

    private void RunMealPersistence()
    {
        GD.Print("-------------------- (D) Active meal persists + re-applies across save/load --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        if (gs.Squad == null) { Fail(); gs.QueueFree(); return; }

        // Eat a save-buff meal and let EatMeal persist it.
        gs.AddItem("herb_tonic", 1);
        Check("(D) eat herb_tonic (persisted by command)", gs.EatMeal("herb_tonic"));
        Check("(D) active meal live before reload", gs.ActiveMealId == "herb_tonic");

        // Fresh GameState reloads slot0: the active meal id restores AND re-applies to the rebuilt roster.
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(D) reload restored the active meal id", gs2.ActiveMealId == "herb_tonic");
        Check("(D) reload re-applied the buff to the rebuilt roster (Fortitude +1 live)",
            gs2.Squad != null && gs2.Squad.Members.All(m => m.Modifiers!.GetModifierTotal(StatType.Fortitude) == 1));

        // A pristine slot recomputes back to baseline (no meal, byte-identical).
        ClearSlot0();
        var gs3 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs3);
        Check("(D) fresh slot → no active meal, no buff (baseline)",
            gs3.ActiveMealId == null
            && gs3.Squad != null && gs3.Squad.Members.All(m => m.Modifiers!.GetModifierTotal(StatType.Fortitude) == 0));

        gs.QueueFree();
        gs2.QueueFree();
        gs3.QueueFree();
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
        GD.Print("[ProvisionsSpike] slot0.json backed up and cleared for the test run.");
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
            GD.Print("[ProvisionsSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[ProvisionsSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
