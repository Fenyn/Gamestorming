using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Events;
using PF2e.TurnManagement;
using PF2e.Utilities;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the M3 territory loop (travel / party selection, resource nodes,
/// roaming encounters into real combat, victory/defeat flows). Drives a REAL GameState node's
/// commands directly (fresh, on a clean save slot — the user's slot0.json is backed up first and
/// restored at the end); no rendered scenes.
///  (1) TravelToTerritory: the all-hands overload (the gate contract) takes every living companion
///      and skips the dead; the explicit-selection path still rejects >3 companions, duplicates,
///      the Veteran-as-companion, unknown territories and dead companions; a valid travel spends
///      exactly 30 game-minutes and stores the selection.
///  (2) HarvestResourceNode: tool gate (no time spent on refusal), yield lands in the shared
///      inventory, node depletes, daily nodes respawn on day change while one-shot nodes stay gone.
///  (3) BeginTerritoryEncounter: pending setup's team-1 roster is EXACTLY Veteran + selection
///      (living sit-outs and the dead absent), enemies match the roamer's (single-entry) table;
///      scripted victory → CompleteEncounter ran (XP banked, save written), return context intact,
///      roamer despawned for the day.
///  (4) Scripted defeat → day advanced WITHOUT full rest, 25% resource penalty applied (floor),
///      party back at the outpost, defeat summary staged.
///  (5) Treat Wounds + immunity/clock interactions unaffected; territory state round-trips the save.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class TerritorySpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string ForestId = "verdant_fringe";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== TERRITORY SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[TerritorySpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            await RunScenario();
        }
        catch (Exception e)
        {
            GD.PushError($"[TerritorySpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("TerritorySpike");
    }

    private async Task RunScenario()
    {
        // Fresh GameState on the clean slot. Real-time ticking disabled so every clock assertion
        // below is exact — commands spend time via SpendTime, which ignores the tick pause.
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        var squad = gs.Squad;
        Check("(0) GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null)
            return;

        var veteran = squad.FindMember(SquadRoster.VeteranId)!;
        var scout = squad.FindMember(SquadRoster.ScoutId)!;
        var medic = squad.FindMember(SquadRoster.MedicId)!;
        var scholar = squad.FindMember(SquadRoster.ScholarId)!;

        // ── (1) Travel command & party selection ──
        GD.Print("-------------------- (1) Travel & party selection --------------------");
        Check("(1) starts at the outpost", gs.Territory.CurrentTerritoryId == null);
        Check("(1) TravelToOutpost from the outpost is refused", !gs.TravelToOutpost());

        Check("(1) >3 companions rejected", !gs.TravelToTerritory(ForestId, new[]
        {
            SquadRoster.ScoutId, SquadRoster.MedicId, SquadRoster.ScholarId, SquadRoster.VeteranId,
        }));
        Check("(1) the Veteran as a companion rejected",
            !gs.TravelToTerritory(ForestId, new[] { SquadRoster.VeteranId }));
        Check("(1) duplicate companion rejected",
            !gs.TravelToTerritory(ForestId, new[] { SquadRoster.ScoutId, SquadRoster.ScoutId }));
        Check("(1) unknown territory rejected",
            !gs.TravelToTerritory("the_moon", Array.Empty<string>()));
        Check("(1) unknown companion id rejected",
            !gs.TravelToTerritory(ForestId, new[] { "nobody" }));

        // The gate contract: the all-hands overload marches the FULL living roster, no selection.
        Check("(1) all-hands travel (gate contract) accepted", gs.TravelToTerritory(ForestId));
        Check("(1) all-hands selection is every living companion (Scout, Medic, Scholar)",
            gs.Territory.SelectedCompanionIds.SequenceEqual(
                new[] { SquadRoster.ScoutId, SquadRoster.MedicId, SquadRoster.ScholarId }));
        Check("(1) all-hands march home again", gs.TravelToOutpost());

        // The Scholar falls — dead members cannot be taken along (and later must sit out).
        scholar.Health!.ForceDeadState();
        Check("(1) dead companion rejected",
            !gs.TravelToTerritory(ForestId, new[] { SquadRoster.ScholarId }));
        Check("(1) all-hands travel skips the dead (Scholar sits out)",
            gs.TravelToTerritory(ForestId)
            && gs.Territory.SelectedCompanionIds.SequenceEqual(
                new[] { SquadRoster.ScoutId, SquadRoster.MedicId }));
        Check("(1) march home for the explicit-selection checks", gs.TravelToOutpost());

        int minuteBefore = gs.Clock.MinuteOfDay;
        Check("(1) valid travel (Veteran + Scout) accepted",
            gs.TravelToTerritory(ForestId, new[] { SquadRoster.ScoutId }));
        Check("(1) travel spent exactly 30 game-minutes",
            gs.Clock.MinuteOfDay == minuteBefore + 30);
        Check("(1) location is the forest", gs.Territory.CurrentTerritoryId == ForestId);
        Check("(1) selection stored (Scout only)",
            gs.Territory.SelectedCompanionIds.Count == 1
            && gs.Territory.SelectedCompanionIds[0] == SquadRoster.ScoutId);
        Check("(1) traveling again while in territory rejected",
            !gs.TravelToTerritory(ForestId, Array.Empty<string>()));

        // ── (2) Harvest: tool gate, yield, depletion, respawn ──
        GD.Print("-------------------- (2) Resource nodes --------------------");
        int harvestEvents = 0, nodeEvents = 0;
        Action<Bulwark.Territory.HarvestResultView> onHarvest = _ => harvestEvents++;
        Action<string> onNode = _ => nodeEvents++;
        gs.ResourceHarvested += onHarvest;
        gs.TerritoryNodeChanged += onNode;

        int stoneBefore = gs.Inventory.Count(Items.Stone.Id);
        minuteBefore = gs.Clock.MinuteOfDay;
        Check("(2) wrong tool (Hand on rock) rejected", !gs.HarvestResourceNode("rock_1", ToolKind.Hand));
        Check("(2) refusal spent no time", gs.Clock.MinuteOfDay == minuteBefore);
        Check("(2) unknown node rejected", !gs.HarvestResourceNode("rock_99", ToolKind.Pick));

        Check("(2) Pick harvests the rock", gs.HarvestResourceNode("rock_1", ToolKind.Pick));
        Check("(2) +2 stone in the shared inventory",
            gs.Inventory.Count(Items.Stone.Id) == stoneBefore + 2);
        Check("(2) harvest spent the node's 15 minutes",
            gs.Clock.MinuteOfDay == minuteBefore + ResourceNodes.Rock.HarvestMinutes);
        Check("(2) node depleted", gs.Territory.IsNodeDepleted(ForestId, "rock_1"));
        Check("(2) depleted node cannot be harvested again",
            !gs.HarvestResourceNode("rock_1", ToolKind.Pick));

        int woodBefore = gs.Inventory.Count(Items.Wood.Id);
        Check("(2) Axe harvests the fallen wood", gs.HarvestResourceNode("wood_1", ToolKind.Axe));
        Check("(2) +2 wood", gs.Inventory.Count(Items.Wood.Id) == woodBefore + 2);
        Check("(2) harvest + node events fired", harvestEvents == 2 && nodeEvents == 2);

        gs.Sleep(); // day change: daily nodes respawn, one-shot nodes stay gone
        Check("(2) rock respawned on day change", !gs.Territory.IsNodeDepleted(ForestId, "rock_1"));
        Check("(2) one-shot fallen wood stayed depleted (RespawnsDaily=false)",
            gs.Territory.IsNodeDepleted(ForestId, "wood_1"));
        Check("(2) sleeping woke us at the outpost", gs.Territory.CurrentTerritoryId == null);
        Check("(2) harvesting from the outpost rejected", !gs.HarvestResourceNode("rock_1", ToolKind.Pick));
        gs.ResourceHarvested -= onHarvest;
        gs.TerritoryNodeChanged -= onNode;

        // ── (3) Roamer contact → real combat setup → scripted victory ──
        GD.Print("-------------------- (3) Encounter & victory --------------------");
        Check("(3) travel back out (Veteran + Scout)",
            gs.TravelToTerritory(ForestId, new[] { SquadRoster.ScoutId }));

        var contactPos = new Vector2(123f, 456f);
        Check("(3) encounter refused for an unknown roamer", !gs.BeginTerritoryEncounter("gob_99", contactPos));
        Check("(3) BeginTerritoryEncounter succeeds (gob_1)", gs.BeginTerritoryEncounter("gob_1", contactPos));

        var pending = gs.Territory.PendingEncounter;
        Check("(3) pending encounter staged", pending != null);
        if (pending == null)
            return;

        Check("(3) rolled gob_1's single-entry table (goblin_pair)", pending.EncounterId == "goblin_pair");
        var partyIds = pending.Setup.Party.Select(p => p.Unit.Id).ToList();
        Check("(3) player roster is EXACTLY Veteran + Scout (in order)",
            partyIds.SequenceEqual(new[] { SquadRoster.VeteranId, SquadRoster.ScoutId }));
        Check("(3) living sit-out (Medic) absent", !partyIds.Contains(SquadRoster.MedicId));
        Check("(3) dead member (Scholar) absent", !partyIds.Contains(SquadRoster.ScholarId));
        Check("(3) roster units are the LIVE squad instances (attrition)",
            ReferenceEquals(pending.Setup.Party[0].Unit, veteran)
            && ReferenceEquals(pending.Setup.Party[1].Unit, scout));
        Check("(3) enemies match the table entry: 2x Goblin Warrior",
            pending.Enemies.Count == 2
            && pending.Enemies.All(e => e.Name.StartsWith("Goblin Warrior", StringComparison.Ordinal))
            && pending.Setup.Enemies.Count == 2);
        Check("(3) a second contact while one is pending is refused",
            !gs.BeginTerritoryEncounter("gob_2", contactPos));

        int xpBefore = squad.GetXp(SquadRoster.VeteranId);
        int goblinLevel = pending.Enemies[0].CreatureStats!.Data.CreatureLevel;
        int xpPerGoblin = EncounterXPCalculator.GetCreatureXP(goblinLevel, squad.Level);

        var session = StartSession(pending.Setup);
        try
        {
            foreach (var enemy in pending.Enemies)
                await ReactionEvents.DeliverDamage(veteran, enemy, Physical(999));
            Check("(3) both goblins slain", pending.Enemies.All(e => e.Health!.IsDead));
        }
        finally { session.Teardown(); }

        RemoveSaveFile(); // prove CompleteTerritoryEncounter writes it back
        var outcome = gs.CompleteTerritoryEncounter(BattleResult.Team1Wins);
        Check("(3) outcome: victory, returning to the forest",
            outcome is { Victory: true } && outcome.TerritoryId == ForestId);
        Check("(3) encounter XP banked on every member",
            squad.GetXp(SquadRoster.VeteranId) == xpBefore + 2 * xpPerGoblin
            && squad.GetXp(SquadRoster.MedicId) == xpBefore + 2 * xpPerGoblin);
        Check("(3) post-encounter save written", Godot.FileAccess.FileExists(SavePath));
        Check("(3) roamer despawned for the day", gs.Territory.IsRoamerDefeated(ForestId, "gob_1"));
        Check("(3) beaten roamer cannot re-trigger", !gs.BeginTerritoryEncounter("gob_1", contactPos));
        Check("(3) pending encounter cleared", gs.Territory.PendingEncounter == null);
        Check("(3) still in the territory after victory", gs.Territory.CurrentTerritoryId == ForestId);
        Vector2? ret = gs.ConsumeTerritoryReturn(ForestId);
        Check("(3) return context intact (player position)", ret == contactPos);
        Check("(3) return context is one-shot", gs.ConsumeTerritoryReturn(ForestId) == null);

        // ── (4) Scripted defeat → wake at the outpost with the resource penalty ──
        GD.Print("-------------------- (4) Defeat --------------------");
        Check("(4) rat-pack contact succeeds (gob_4)", gs.BeginTerritoryEncounter("gob_4", contactPos));
        pending = gs.Territory.PendingEncounter;
        Check("(4) enemies match the table entry: 3x Giant Rat",
            pending != null && pending.Enemies.Count == 3
            && pending.Enemies.All(e => e.Name.StartsWith("Giant Rat", StringComparison.Ordinal)));
        if (pending == null)
            return;

        // Known resource stacks for the penalty math (floor of a quarter).
        var resourceBefore = gs.Inventory.Stacks
            .Where(kv => Items.TryGet(kv.Key, out var d) && d.Category == ItemCategory.Resource)
            .ToDictionary(kv => kv.Key, kv => kv.Value);
        int seedsBefore = gs.Inventory.Count(Items.TurnipSeed.Id);
        int dayBefore = gs.Clock.Day;

        session = StartSession(pending.Setup);
        try
        {
            var rat = pending.Enemies[0];
            await ReactionEvents.DeliverDamage(rat, veteran, Physical(veteran.Health!.MaxHP));
            await ReactionEvents.DeliverDamage(rat, scout, Physical(scout.Health!.MaxHP));
            Check("(4) whole party down (dying, not dead)",
                veteran.Health.CurrentHP == 0 && scout.Health.CurrentHP == 0
                && !veteran.Health.IsDead && !scout.Health.IsDead);
        }
        finally { session.Teardown(); }

        outcome = gs.CompleteTerritoryEncounter(BattleResult.Team2Wins);
        Check("(4) outcome: defeat, wake at the outpost", outcome is { Victory: false });
        Check("(4) day advanced to next morning",
            gs.Clock.Day == dayBefore + 1 && gs.Clock.MinuteOfDay == DayClock.DayStartMinute);
        Check("(4) party is back at the outpost", gs.Territory.CurrentTerritoryId == null);
        Check("(4) gate selection cleared", gs.Territory.SelectedCompanionIds.Count == 0);
        Check("(4) NOT full-rested: Veteran woke stabilized at 1 HP with Wounded",
            veteran.Health.CurrentHP == 1
            && veteran.Conditions!.HasCondition(Condition.Wounded));
        Check("(4) XP survived the defeat (none awarded, none lost)",
            squad.GetXp(SquadRoster.VeteranId) == xpBefore + 2 * xpPerGoblin);

        bool penaltyOk = true;
        foreach (var (itemId, before) in resourceBefore)
        {
            int expected = before - before / Bulwark.Territory.TerritorySystem.DefeatPenaltyDivisor;
            if (gs.Inventory.Count(itemId) != expected)
            {
                penaltyOk = false;
                GD.Print($"    penalty mismatch: {itemId} had {before}, " +
                         $"expected {expected}, got {gs.Inventory.Count(itemId)}");
            }
        }
        Check("(4) 25% resource penalty applied to every Resource stack (floor)", penaltyOk);
        Check("(4) non-resource items untouched (seeds intact)",
            gs.Inventory.Count(Items.TurnipSeed.Id) == seedsBefore);

        var summary = gs.ConsumeDefeatSummary();
        int expectedLossLines = resourceBefore.Count(kv =>
            kv.Value / Bulwark.Territory.TerritorySystem.DefeatPenaltyDivisor > 0);
        Check("(4) defeat summary staged for the wake toast (one line per docked stack)",
            summary != null && summary.Losses.Count == expectedLossLines);
        Check("(4) defeat summary is one-shot", gs.ConsumeDefeatSummary() == null);

        // ── (5) Treat Wounds / clock interactions unaffected; territory save round-trip ──
        GD.Print("-------------------- (5) Treat Wounds & save round-trip --------------------");
        var panel = gs.GetSquadPanelView();
        var medicView = panel?.Members.Find(m => m.Id == SquadRoster.MedicId);
        int dc = medicView != null && medicView.DcOptions.Count > 0 ? medicView.DcOptions[0].Dc : 0;
        minuteBefore = gs.Clock.MinuteOfDay;
        Check("(5) Medic can still Treat Wounds on the battered Veteran",
            dc > 0 && gs.TreatWounds(SquadRoster.MedicId, SquadRoster.VeteranId, dc));
        Check("(5) treatment spent its 10 minutes", gs.Clock.MinuteOfDay == minuteBefore + 10);
        var panelAfter = gs.GetSquadPanelView();
        Check("(5) RAW 1-hour immunity window is running",
            (panelAfter?.Members.Find(m => m.Id == SquadRoster.VeteranId)?.ImmunityMinutesRemaining ?? 0) > 0);

        gs.SaveGame();
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(5) reloaded: one-shot node still depleted", gs2.Territory.IsNodeDepleted(ForestId, "wood_1"));
        Check("(5) reloaded: daily node not depleted", !gs2.Territory.IsNodeDepleted(ForestId, "rock_1"));
        Check("(5) reloaded: player is at the outpost (location never persists)",
            gs2.Territory.CurrentTerritoryId == null);
        Check("(5) reloaded: Veteran still battered (attrition round-trips)",
            gs2.Squad?.FindMember(SquadRoster.VeteranId)?.Health?.CurrentHP
                == veteran.Health.CurrentHP);
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    /// <summary>Real CombatSession over the pending setup, combatants registered (scripted damage
    /// path — the turn loop is not run, mirroring the attrition spike's harness).</summary>
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

    private static void RemoveSaveFile()
    {
        if (Godot.FileAccess.FileExists(SavePath))
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
    }

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[TerritorySpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[TerritorySpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[TerritorySpike] test slot0.json removed (no prior save existed).");
        }
    }
}
