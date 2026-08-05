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
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using PF2e.TurnManagement;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

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
///  (7) Encounters deploy onto a GENERATED battle map, and the map is a function of (world seed, day,
///      contact) only: the same roamer on the same day reproduces it across a save/load, a new day
///      does not.
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

        var veteran = squad.FindMember(SquadRoster.PlayerId)!;
        var scout = squad.FindMember(SquadRoster.ElaraId)!;
        var medic = squad.FindMember(SquadRoster.TharrId)!;
        var scholar = squad.FindMember(SquadRoster.FenwickId)!;

        // ── (1) Travel command & party selection ──
        GD.Print("-------------------- (1) Travel & party selection --------------------");
        Check("(1) starts at the outpost", gs.Territory.CurrentTerritoryId == null);
        Check("(1) TravelToOutpost from the outpost is refused", !gs.TravelToOutpost());

        Check("(1) >3 companions rejected", !gs.TravelToTerritory(ForestId, new[]
        {
            SquadRoster.ElaraId, SquadRoster.TharrId, SquadRoster.FenwickId, SquadRoster.PlayerId,
        }));
        Check("(1) the Veteran as a companion rejected",
            !gs.TravelToTerritory(ForestId, new[] { SquadRoster.PlayerId }));
        Check("(1) duplicate companion rejected",
            !gs.TravelToTerritory(ForestId, new[] { SquadRoster.ElaraId, SquadRoster.ElaraId }));
        Check("(1) unknown territory rejected",
            !gs.TravelToTerritory("the_moon", Array.Empty<string>()));
        Check("(1) unknown companion id rejected",
            !gs.TravelToTerritory(ForestId, new[] { "nobody" }));

        // The gate contract: the all-hands overload marches the FULL living roster, no selection.
        // Order follows SquadRoster.MemberOrder (marching order): Player, Tharr, Fenwick, Elara.
        Check("(1) all-hands travel (gate contract) accepted", gs.TravelToTerritory(ForestId));
        Check("(1) all-hands selection is every living companion (Medic, Scholar, Scout)",
            gs.Territory.SelectedCompanionIds.SequenceEqual(
                new[] { SquadRoster.TharrId, SquadRoster.FenwickId, SquadRoster.ElaraId }));
        Check("(1) all-hands march home again", gs.TravelToOutpost());

        // The Scholar falls — dead members cannot be taken along (and later must sit out).
        scholar.Health!.ForceDeadState();
        Check("(1) dead companion rejected",
            !gs.TravelToTerritory(ForestId, new[] { SquadRoster.FenwickId }));
        Check("(1) all-hands travel skips the dead (Scholar sits out)",
            gs.TravelToTerritory(ForestId)
            && gs.Territory.SelectedCompanionIds.SequenceEqual(
                new[] { SquadRoster.TharrId, SquadRoster.ElaraId }));
        Check("(1) march home for the explicit-selection checks", gs.TravelToOutpost());

        int minuteBefore = gs.Clock.MinuteOfDay;
        Check("(1) valid travel (Veteran + Scout) accepted",
            gs.TravelToTerritory(ForestId, new[] { SquadRoster.ElaraId }));
        Check("(1) travel spent exactly 30 game-minutes",
            gs.Clock.MinuteOfDay == minuteBefore + 30);
        Check("(1) location is the forest", gs.Territory.CurrentTerritoryId == ForestId);
        Check("(1) selection stored (Scout only)",
            gs.Territory.SelectedCompanionIds.Count == 1
            && gs.Territory.SelectedCompanionIds[0] == SquadRoster.ElaraId);
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
        Check("(2) one-shot fallen wood stayed depleted (RespawnDays=0)",
            gs.Territory.IsNodeDepleted(ForestId, "wood_1"));
        Check("(2) sleeping woke us at the outpost", gs.Territory.CurrentTerritoryId == null);
        Check("(2) harvesting from the outpost rejected", !gs.HarvestResourceNode("rock_1", ToolKind.Pick));
        gs.ResourceHarvested -= onHarvest;
        gs.TerritoryNodeChanged -= onNode;

        // ── (3) Roamer contact → real combat setup → scripted victory ──
        GD.Print("-------------------- (3) Encounter & victory --------------------");
        Check("(3) travel back out (Veteran + Scout)",
            gs.TravelToTerritory(ForestId, new[] { SquadRoster.ElaraId }));

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
            partyIds.SequenceEqual(new[] { SquadRoster.PlayerId, SquadRoster.ElaraId }));
        Check("(3) living sit-out (Medic) absent", !partyIds.Contains(SquadRoster.TharrId));
        Check("(3) dead member (Scholar) absent", !partyIds.Contains(SquadRoster.FenwickId));
        Check("(3) roster units are the LIVE squad instances (attrition)",
            ReferenceEquals(pending.Setup.Party[0].Unit, veteran)
            && ReferenceEquals(pending.Setup.Party[1].Unit, scout));
        Check("(3) enemies match the table entry: 2x Goblin Warrior",
            pending.Enemies.Count == 2
            && pending.Enemies.All(e => e.Name.StartsWith("Goblin Warrior", StringComparison.Ordinal))
            && pending.Setup.Enemies.Count == 2);
        Check("(3) a second contact while one is pending is refused",
            !gs.BeginTerritoryEncounter("gob_2", contactPos));

        int xpBefore = squad.GetXp(SquadRoster.PlayerId);
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
            squad.GetXp(SquadRoster.PlayerId) == xpBefore + 2 * xpPerGoblin
            && squad.GetXp(SquadRoster.TharrId) == xpBefore + 2 * xpPerGoblin);
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
            squad.GetXp(SquadRoster.PlayerId) == xpBefore + 2 * xpPerGoblin);

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
        var medicView = panel?.Members.Find(m => m.Id == SquadRoster.TharrId);
        int dc = medicView != null && medicView.DcOptions.Count > 0 ? medicView.DcOptions[0].Dc : 0;
        minuteBefore = gs.Clock.MinuteOfDay;
        Check("(5) Medic can still Treat Wounds on the battered Veteran",
            dc > 0 && gs.TreatWounds(SquadRoster.TharrId, SquadRoster.PlayerId, dc));
        Check("(5) treatment spent its 10 minutes", gs.Clock.MinuteOfDay == minuteBefore + 10);
        var panelAfter = gs.GetSquadPanelView();
        Check("(5) RAW 1-hour immunity window is running",
            (panelAfter?.Members.Find(m => m.Id == SquadRoster.PlayerId)?.ImmunityMinutesRemaining ?? 0) > 0);

        gs.SaveGame();
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(5) reloaded: one-shot node still depleted", gs2.Territory.IsNodeDepleted(ForestId, "wood_1"));
        Check("(5) reloaded: daily node not depleted", !gs2.Territory.IsNodeDepleted(ForestId, "rock_1"));
        Check("(5) reloaded: player is at the outpost (location never persists)",
            gs2.Territory.CurrentTerritoryId == null);
        Check("(5) reloaded: Veteran still battered (attrition round-trips)",
            gs2.Squad?.FindMember(SquadRoster.PlayerId)?.Health?.CurrentHP
                == veteran.Health.CurrentHP);

        // ── (6) Exploration triggers → story flags / quest events ──
        GD.Print("-------------------- (6) Exploration triggers --------------------");
        await TestExplorationTriggers();

        // ── (7) Generated battle maps: layout-backed setups + rematch reproducibility ──
        GD.Print("-------------------- (7) Generated battle maps --------------------");
        TestGeneratedBattleMaps(gs2, contactPos);
    }

    /// <summary>
    /// The M3 producer contract: a roamer contact deploys onto a GENERATED map, and that map is a
    /// function of (world seed, day, contact) alone — so the same roamer on the same day gives the
    /// same battlefield even across a save/load, and tomorrow's fight is somewhere else.
    ///
    /// Reproducibility is tested the way the game can actually hit it: two fresh GameStates loaded
    /// from the same save are the same world on the same day, which is exactly the "save between
    /// BeginEncounter and the combat scene" case the encounter has to survive. The third loads the
    /// same save and sleeps first, isolating the day as the only difference.
    /// </summary>
    private void TestGeneratedBattleMaps(GameState source, Vector2 contactPos)
    {
        const string Roamer = "expedition_1"; // single-entry table: the enemy roster is deterministic too
        source.SaveGame();

        var first = LoadFixture();
        Check("(7) fixture A marched out", first.TravelToTerritory(ForestId));
        Check($"(7) fixture A contacted {Roamer}", first.BeginTerritoryEncounter(Roamer, contactPos));
        var a = first.Territory.PendingEncounter;
        if (a?.Setup.Layout == null)
        {
            Check("(7) the encounter runs on a generated map", false);
            return;
        }
        var layoutA = a.Setup.Layout;

        Check("(7) the encounter runs on a generated map", true);
        Check("(7) map provenance recorded (forest biome, non-zero seed)",
            a.BiomeId == "forest" && a.MapSeed != 0 && a.Setup.BiomeId == "forest");
        // The board is sized by the BIOME (its size range plus whatever border it asked for), not by
        // the flat CombatBoards constants, and the setup reports the layout's numbers.
        var biome = MapGenRegistry.GetBiome("forest");
        int pad = 2 * layoutA.BorderWidth;
        Check($"(7) the setup's board is the layout's biome-sized own ({layoutA.Width}x{layoutA.Height})",
            a.Setup.GridWidth == layoutA.Width && a.Setup.GridHeight == layoutA.Height
            && layoutA.Width >= biome.MinSize.x + pad && layoutA.Width <= biome.MaxSize.x + pad
            && layoutA.Height >= biome.MinSize.y + pad && layoutA.Height <= biome.MaxSize.y + pad);
        Check("(7) the whole party and every enemy deployed",
            a.Setup.Party.Count == first.Territory.SelectedCompanionIds.Count + 1
            && a.Setup.Enemies.Count == a.Enemies.Count);
        Check("(7) every combatant stands on walkable terrain",
            Anchors(a).TrueForAll(p => layoutA.IsWalkable(p.x, p.y)));
        Check("(7) party deploys in team 0's zone, enemies in team 1's",
            InZone(layoutA, 0, a.Setup.Party) && InZone(layoutA, 1, a.Setup.Enemies));

        // Same world, same day, freshly reloaded: identical ground and identical deployment.
        var rematch = LoadFixture();
        Check("(7) fixture B (same save, same day) marched out", rematch.TravelToTerritory(ForestId));
        Check("(7) fixture B contacted the same roamer", rematch.BeginTerritoryEncounter(Roamer, contactPos));
        var b = rematch.Territory.PendingEncounter;
        Check("(7) same-day rematch derived the same map seed", b != null && b.MapSeed == a.MapSeed);
        Check("(7) same-day rematch generated an identical map",
            b?.Setup.Layout != null && LayoutHash(b.Setup.Layout) == LayoutHash(layoutA));
        Check("(7) same-day rematch deployed both teams identically",
            b != null && Anchors(b).SequenceEqual(Anchors(a)));

        // Planner anchors are legal by construction — the self-heal should find nothing to fix.
        // (Normalize mutates, so it runs after the deployment comparison above.)
        var corrections = a.Setup.Normalize();
        Check($"(7) planner anchors need no deployment corrections ({corrections.Count})",
            corrections.Count == 0);

        // Only the day differs.
        var tomorrow = LoadFixture();
        tomorrow.Sleep();
        Check("(7) fixture C marched out on the next day", tomorrow.TravelToTerritory(ForestId));
        Check("(7) fixture C contacted the same roamer", tomorrow.BeginTerritoryEncounter(Roamer, contactPos));
        var c = tomorrow.Territory.PendingEncounter;
        Check("(7) a new day derives a new map seed", c != null && c.MapSeed != a.MapSeed);
        Check("(7) a new day generates a different map",
            c?.Setup.Layout != null && LayoutHash(c.Setup.Layout) != LayoutHash(layoutA));
    }

    /// <summary>A GameState freshly loaded from the protected slot0 — same world, same day.</summary>
    private GameState LoadFixture()
    {
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        return gs;
    }

    private static List<PF2eVec> Anchors(Bulwark.Territory.TerritoryEncounter e) =>
        e.Setup.Party.Select(p => p.Pos).Concat(e.Setup.Enemies.Select(p => p.Pos)).ToList();

    /// <summary>True when every listed anchor falls inside the layout's zone for that team.</summary>
    private static bool InZone(
        MapLayout layout, int teamId, List<(ICharacter Unit, PF2eVec Pos)> team)
    {
        var zone = DeploymentPlanner.FindZone(layout, teamId);
        if (zone == null)
            return false;

        int xMin = Math.Min(zone.CornerA.x, zone.CornerB.x), xMax = Math.Max(zone.CornerA.x, zone.CornerB.x);
        int yMin = Math.Min(zone.CornerA.y, zone.CornerB.y), yMax = Math.Max(zone.CornerA.y, zone.CornerB.y);
        return team.TrueForAll(t =>
            t.Pos.x >= xMin && t.Pos.x <= xMax && t.Pos.y >= yMin && t.Pos.y <= yMax);
    }

    /// <summary>
    /// FNV-1a over everything that defines the battlefield — dimensions, recorded seed, tile roles,
    /// surfaces, elevations and corner heights. Equal hashes mean the same ground.
    /// </summary>
    private static uint LayoutHash(MapLayout layout)
    {
        unchecked
        {
            uint h = 2166136261u;
            void Mix(int v)
            {
                for (int b = 0; b < 4; b++)
                {
                    h ^= (uint)((v >> (b * 8)) & 0xFF);
                    h *= 16777619u;
                }
            }

            Mix(layout.Width);
            Mix(layout.Height);
            Mix(layout.Seed);
            for (int i = 0; i < layout.Tiles.Length; i++)
            {
                Mix((int)layout.Tiles[i]);
                Mix((int)layout.Surfaces[i]);
                Mix(layout.Elevations[i]);
                var corners = layout.CornerHeights[i];
                Mix(corners.NW);
                Mix(corners.NE);
                Mix(corners.SE);
                Mix(corners.SW);
            }
            return h;
        }
    }

    /// <summary>
    /// The world-side producers for the three story hooks: the ExplorationTrigger instances placed in
    /// the real Elderwood/forest scenes (existence + authored sink ids), and the fire-once → GameState
    /// behaviour (first player-body contact sets the flag; re-entry is idempotent because SetStoryFlag
    /// no-ops an already-set flag). Uses GameState.Instance (the reloaded gs2 on the protected slot0).
    /// </summary>
    private async Task TestExplorationTriggers()
    {
        // (a) Placement/authoring: the triggers are wired into the REAL territory scenes with the
        //     right sink ids, at distinct locations, and the Elderwood campsite carries its marker.
        var elder = GD.Load<PackedScene>("res://scenes/territory/elderwood.tscn").Instantiate<Node2D>();
        var deep = elder.GetNodeOrNull<Bulwark.Territory.ExplorationTrigger>("ExploredTrigger");
        var camp = elder.GetNodeOrNull<Bulwark.Territory.ExplorationTrigger>("FarCampsiteTrigger");
        Check("(6) Elderwood deep-zone trigger present → elderwood_explored",
            deep != null && deep.StoryFlag == "elderwood_explored");
        Check("(6) Elderwood far-corner trigger present → elderwood_far_campsite_discovered",
            camp != null && camp.StoryFlag == "elderwood_far_campsite_discovered");
        Check("(6) the two Elderwood triggers sit at distinct locations (far campsite deeper)",
            deep != null && camp != null && deep.Position.DistanceTo(camp.Position) > 400f);
        Check("(6) far campsite carries a visual marker (Campfire prop)",
            elder.GetNodeOrNull<Node2D>("Campfire") != null);
        elder.QueueFree();

        var forest = GD.Load<PackedScene>("res://scenes/territory/forest.tscn").Instantiate<Node2D>();
        var wolf = forest.GetNodeOrNull<Bulwark.Territory.ExplorationTrigger>("WolfTrackedTrigger");
        Check("(6) forest wolf-lair trigger present → wolf_tracked quest event",
            wolf != null && string.IsNullOrEmpty(wolf.StoryFlag) && wolf.QuestEvent == "wolf_tracked");
        float wolfRadius =
            (wolf?.GetNodeOrNull<CollisionShape2D>("CollisionShape2D")?.Shape as CircleShape2D)?.Radius ?? 0f;
        Check($"(6) wolf trigger radius is generous ({wolfRadius:0} px, trips before lair contact 34)",
            wolfRadius > 100f);
        forest.QueueFree();
        await PhysicsFrames(1);

        // (b) Behaviour: first player-body contact fires exactly once and reaches GameState; a
        //     re-entering fresh instance cannot double the beat (SetStoryFlag idempotent).
        var gs = GameState.Instance;
        const string probe = "spike_exploration_probe";
        Check("(6) probe flag starts unset", !gs.HasStoryFlag(probe));

        var world = new Node2D { Name = "ExplProbeWorld" };
        AddChild(world);
        var player = GD.Load<PackedScene>("res://scenes/cozy/player.tscn").Instantiate<PlayerController>();
        player.Position = new Vector2(500, 500);
        world.AddChild(player);

        world.AddChild(MakeProbeTrigger(probe, new Vector2(500, 500)));
        await PhysicsFrames(3);
        Check("(6) walking into the trigger set its story flag", gs.HasStoryFlag(probe));
        Check("(6) re-set of the already-set flag is a no-op (idempotent)", !gs.SetStoryFlag(probe));

        // Re-entry (fresh instance overlaps the player again): the flag stays set exactly once.
        world.AddChild(MakeProbeTrigger(probe, new Vector2(500, 500)));
        await PhysicsFrames(3);
        Check("(6) re-entry left the flag set exactly once (still true, no crash)", gs.HasStoryFlag(probe));

        world.QueueFree();
        await PhysicsFrames(1);
    }

    /// <summary>A bare ExplorationTrigger (default Area2D layer/mask, like the shipped ones) with a
    /// small circle shape, positioned to overlap the probe player body.</summary>
    private static Bulwark.Territory.ExplorationTrigger MakeProbeTrigger(string flag, Vector2 pos)
    {
        var t = new Bulwark.Territory.ExplorationTrigger { StoryFlag = flag, Position = pos };
        t.AddChild(new CollisionShape2D { Shape = new CircleShape2D { Radius = 40f } });
        return t;
    }

    private async Task PhysicsFrames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
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
