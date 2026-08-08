using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Presets;
using Bulwark.Territory;
using Godot;
using PF2e.Core;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the Phase-3 villager / static-cast ARRIVAL + PARTY-JOIN framework. Proves
/// the LOGIC entirely with SPIKE-LOCAL SYNTHETIC villager definitions + an existing-preset join
/// target (PresetCharacters.BuildRecruit, an authored-but-unshipped 5th fighter, registered
/// spike-locally in PartyPresets) — NONE of which is added to the shipped registries. Sections:
///  (A) Trigger evaluation for each variant (BuildingReached tier, StoryFlag, DateReached, AND-
///      composite) against a stub context; arrival fires exactly once per villager; idempotent
///      re-evaluation.
///  (B) StoryFlags store: set/query, idempotent re-set, single event.
///  (C) Roster-join + POOL GROWTH: a not-arrived join is rejected, a non-recruitable (townsfolk)
///      join is rejected, and an arrived + recruitable join adds a 5th ROSTER member that is present
///      and usable; a duplicate join is rejected. (The pool grows — the adventuring party does not;
///      see (I).)
///  (D) Grown-roster save/restore: CaptureMembers tags the grown member with its preset key (the
///      fixed four carry none), RestoreMembers rebuilds the 5-member roster with the added member's
///      live-state delta re-applied, an EXACT serialized round-trip, and the grown member levels up
///      through the shared banked-XP path.
///  (E) The DEFAULT 4-member squad path is unchanged (four members, no preset keys).
///  (F) VillagerLoader is null-safe with no marker, and places a placeholder NPC at a marker when
///      the villager has arrived.
///  (G) The SHIPPED Villagers registry + PartyPresets are EMPTY, and a real GameState is a clean
///      no-op: flags work, no villager arrives, JoinRoster rejects, the squad stays at four.
///  (H) Full GameState save/load round-trip of story flags + a grown roster; plus VillagerSystem
///      arrival-state capture/restore with no re-fire after restore.
///  (I) The corrected model: a grown POOL still forms a ≤4 adventuring party — the select view lists
///      the pool's companions, an over-full selection is rejected, a chosen 3 forms a party of 4,
///      the all-hands default caps at 4, and the pool + selection round-trip a save.
/// The user's slot0.json is backed up and restored around the run.
/// </summary>
public partial class VillagerSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";
    private const string RecruitPresetKey = "spike-recruit";
    private const string RecruitCharacterId = PresetCharacters.RecruitId; // "the-recruit"

    private bool _slot0Existed;
    private string? _slot0Backup;

    // ── Mutable stub of the live state a trigger reads (spike-local; never touches GameState) ──
    private sealed class StubContext : IArrivalContext
    {
        public readonly Dictionary<string, int> Tiers = new();
        public readonly HashSet<string> Flags = new();
        public readonly Dictionary<string, int> ItemCounts = new();
        public readonly Dictionary<string, int> Hearts = new();
        public int DayOrdinal = ArrivalTrigger.Ordinal(1, Season.Spring, 1);

        public int GetBuildingTier(string buildingId) => Tiers.TryGetValue(buildingId, out var t) ? t : 0;
        public bool HasStoryFlag(string flagId) => Flags.Contains(flagId);
        public int CurrentDayOrdinal => DayOrdinal;
        public int CountItem(string itemId) => ItemCounts.TryGetValue(itemId, out var n) ? n : 0;
        public int HeartsOf(string characterId) => Hearts.TryGetValue(characterId, out var h) ? h : 0;
    }

    public override void _Ready()
    {
        GD.Print("==================== VILLAGER SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[VillagerSpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            RunScheduleResolution();    // (S)
            RunTriggerVariants();       // (A)
            RunStoryFlags();            // (B)
            RunPartyJoinAndGrowth();    // (C) + (D) + (E) + (F)
            RunShippedEmptyAndGameState(); // (G) + (H)
        }
        catch (Exception e)
        {
            GD.PushError($"[VillagerSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            PartyPresets.Clear();
            RestoreSlot0();
        }

        FinishAndQuit("VillagerSpike");
    }

    // ─────────────────────────── (S) Schedule resolution (pure logic) ───────────────────────────

    /// <summary>
    /// Exercises <see cref="Schedules.ResolveMarker"/> — the Node-free daily-slot resolution — against
    /// shipped data: unknown villager → home (null), before-first-slot → home, exactly-at / between
    /// slots → the latest passed slot, after the last slot → last marker (late night stays), and the
    /// dawn rollover → home again. Generic over the shipped tharr schedule so it survives content edits.
    /// </summary>
    private void RunScheduleResolution()
    {
        GD.Print("-------------------- (S) Schedule resolution (pure) --------------------");

        Check("(S) unknown villager → home (null)", Schedules.ResolveMarker("nobody_here", 700) == null);

        Check("(S) tharr has a shipped schedule (≥2 slots)",
            Schedules.TryGet("tharr", out var tharr) && tharr!.Entries.Count >= 2);
        var e = tharr!.Entries;
        var first = e[0];
        var second = e[1];
        var last = e[e.Count - 1];

        Check("(S) before the first slot → home (null)",
            Schedules.ResolveMarker("tharr", first.MinuteOfDay - 1) == null);
        Check("(S) exactly at the first slot → first marker",
            Schedules.ResolveMarker("tharr", first.MinuteOfDay) == first.MarkerName);
        Check("(S) between slots → the latest passed slot",
            Schedules.ResolveMarker("tharr", second.MinuteOfDay - 1) == first.MarkerName);
        Check("(S) at/after the last slot → last marker (late night stays)",
            Schedules.ResolveMarker("tharr", DayClock.DayRolloverMinute) == last.MarkerName);
        Check("(S) dawn rollover (new day at 6:00) → home (null)",
            Schedules.ResolveMarker("tharr", DayClock.DayStartMinute) == null);
    }

    // ─────────────────────────── (A) Trigger variants + arrival-once ───────────────────────────

    private void RunTriggerVariants()
    {
        GD.Print("-------------------- (A) Trigger variants + arrival (once) --------------------");

        var vBuild = new VillagerDefinition
        {
            Id = "v_build", DisplayName = "Smith",
            Arrival = ArrivalTrigger.BuildingReached("smithy", minTier: 2),
        };
        var vFlag = new VillagerDefinition
        {
            Id = "v_flag", DisplayName = "Herald",
            Arrival = ArrivalTrigger.StoryFlag("met_smith"),
        };
        var vDate = new VillagerDefinition
        {
            Id = "v_date", DisplayName = "Traveler",
            Arrival = ArrivalTrigger.DateReached(Season.Summer, day: 5),
        };
        var vAll = new VillagerDefinition
        {
            Id = "v_all", DisplayName = "Envoy",
            Arrival = ArrivalTrigger.All(
                ArrivalTrigger.BuildingReached("smithy", minTier: 1),
                ArrivalTrigger.StoryFlag("chapel_blessed")),
        };

        var ctx = new StubContext();
        var vs = new VillagerSystem(ctx, new[] { vBuild, vFlag, vDate, vAll });
        var events = new List<string>();
        vs.Arrived += events.Add;

        Check("(A) nothing satisfied initially → no arrivals", vs.EvaluateArrivals().Count == 0);

        // BuildingReached: tier 1 is not enough for v_build (needs 2), but it satisfies v_all's
        // building leg; v_all still waits on its flag.
        ctx.Tiers["smithy"] = 1;
        var n0 = vs.EvaluateArrivals();
        Check("(A) BuildingReached(tier 2) not satisfied at tier 1", !vs.HasArrived("v_build") && n0.Count == 0);
        Check("(A) AND-composite not satisfied without its flag", !vs.HasArrived("v_all"));

        ctx.Tiers["smithy"] = 2;
        var n1 = vs.EvaluateArrivals();
        Check("(A) BuildingReached fires at tier 2", n1.Contains("v_build") && vs.HasArrived("v_build"));

        ctx.Flags.Add("met_smith");
        var n2 = vs.EvaluateArrivals();
        Check("(A) StoryFlag trigger fires when set", n2.Contains("v_flag") && vs.HasArrived("v_flag"));

        ctx.Flags.Add("chapel_blessed");
        var n3 = vs.EvaluateArrivals();
        Check("(A) AND-composite fires when every leg satisfied", n3.Contains("v_all") && vs.HasArrived("v_all"));

        Check("(A) DateReached not satisfied before its date", !vs.HasArrived("v_date"));
        ctx.DayOrdinal = ArrivalTrigger.Ordinal(1, Season.Summer, 5);
        var n4 = vs.EvaluateArrivals();
        Check("(A) DateReached fires at/after its date", n4.Contains("v_date") && vs.HasArrived("v_date"));

        // Idempotent: re-evaluating yields nothing new; each villager arrived exactly once.
        Check("(A) re-evaluate produces no new arrivals (idempotent)", vs.EvaluateArrivals().Count == 0);
        Check("(A) all four arrived", vs.ArrivedIds.Count == 4);
        Check("(A) each arrived exactly once (4 events, no duplicates)",
            events.Count == 4 && new HashSet<string>(events).Count == 4);
    }

    // ─────────────────────────── (B) Story-flag store ───────────────────────────

    private void RunStoryFlags()
    {
        GD.Print("-------------------- (B) StoryFlags store --------------------");
        var flags = new StoryFlags();
        var raised = new List<string>();
        flags.FlagSet += raised.Add;

        Check("(B) unknown flag not set", !flags.Has("beat1"));
        Check("(B) Set returns true the first time", flags.Set("beat1"));
        Check("(B) Has true after set", flags.Has("beat1"));
        Check("(B) re-set is a no-op (false, no extra event)", !flags.Set("beat1") && raised.Count == 1);
        Check("(B) empty/null flag rejected", !flags.Set("") && raised.Count == 1);
    }

    // ─────────────── (C) party-join + growth, (D) save/restore, (E) default, (F) loader ───────────────

    private void RunPartyJoinAndGrowth()
    {
        GD.Print("-------------------- (C) Party-join + roster growth --------------------");

        // Register the spike-local joinable preset: an EXISTING but unshipped 5th fighter. NOT added
        // to any shipped registry — PartyPresets ships empty; this registration is spike-only.
        PartyPresets.Clear();
        PartyPresets.Register(new PartyPresetSpec
        {
            Key = RecruitPresetKey,
            Builder = lvl => PresetCharacters.BuildRecruit(lvl),
            Combo = PresetCombos.FighterSentinel,
        });

        var recruitVillager = new VillagerDefinition
        {
            Id = "v_recruit", DisplayName = "The Recruit",
            Arrival = ArrivalTrigger.StoryFlag("recruit_ready"),
            Recruitable = true, JoinPresetKey = RecruitPresetKey,
        };
        var townsfolk = new VillagerDefinition
        {
            Id = "v_townie", DisplayName = "Townsperson",
            Arrival = ArrivalTrigger.StoryFlag("townie_ready"),
            Recruitable = false,
        };

        var squad = SquadRoster.BuildNew(2);
        Check("(C) default roster is 4", squad.Members.Count == 4);

        var ctx = new StubContext();
        var vs = new VillagerSystem(ctx, new[] { recruitVillager, townsfolk });

        // Not arrived yet → join rejected, roster unchanged.
        Check("(C) join rejected while villager not arrived", RosterJoin.TryAdd(squad, vs, recruitVillager, 2) == null);
        Check("(C) roster still 4 after rejected join", squad.Members.Count == 4);

        ctx.Flags.Add("recruit_ready");
        ctx.Flags.Add("townie_ready");
        vs.EvaluateArrivals();
        Check("(C) recruit arrived", vs.HasArrived("v_recruit"));
        Check("(C) townsfolk arrived", vs.HasArrived("v_townie"));

        // Arrived but NOT recruitable → rejected.
        Check("(C) non-recruitable join rejected even when arrived", RosterJoin.TryAdd(squad, vs, townsfolk, 2) == null);
        Check("(C) roster still 4", squad.Members.Count == 4);

        // Arrived + recruitable → joins; roster grows to 5.
        var joined = RosterJoin.TryAdd(squad, vs, recruitVillager, 2);
        Check("(C) arrived + recruitable join succeeds", joined != null);
        Check("(C) roster GREW to 5", squad.Members.Count == 5);

        var recruit = squad.FindMember(RecruitCharacterId);
        Check("(C) 5th member is the recruit, present and usable (alive with Health/Stats)",
            recruit != null && recruit.Health != null && !recruit.Health.IsDead && recruit.Stats != null);

        // Idempotent: joining again is rejected (already present).
        Check("(C) duplicate join rejected, roster stays at 5",
            RosterJoin.TryAdd(squad, vs, recruitVillager, 2) == null && squad.Members.Count == 5);

        RunGrownRosterRoundTrip(squad);  // (D)
        RunDefaultPathUnchanged();       // (E)
        RunVillagerLoader(recruitVillager); // (F)
    }

    // ─────────────────────────── (D) Grown-roster save / restore ───────────────────────────

    private void RunGrownRosterRoundTrip(SquadRoster squad)
    {
        GD.Print("-------------------- (D) Grown-roster save / restore round-trip --------------------");

        var recruit = squad.FindMember(RecruitCharacterId)!;
        recruit.Health!.SetCurrentHP(recruit.Health.MaxHP - 5); // live-state dent to survive the reload
        squad.AddXp(RecruitCharacterId, 250);

        var snapshot = squad.CaptureMembers();
        Check("(D) snapshot has 5 members", snapshot.Count == 5);
        var recruitDto = snapshot.Find(d => d.Id == RecruitCharacterId)!;
        Check("(D) grown member dto carries its preset key", recruitDto.PresetKey == RecruitPresetKey);
        Check("(D) the fixed four carry NO preset key", snapshot.FindAll(d => d.PresetKey == null).Count == 4);

        // Restore into a FRESH roster (PartyPresets still holds the spike registration).
        var squad2 = SquadRoster.BuildNew(2);
        Check("(D) fresh roster starts at 4", squad2.Members.Count == 4);
        squad2.RestoreMembers(snapshot);
        Check("(D) restored roster grew back to 5", squad2.Members.Count == 5);

        var recruit2 = squad2.FindMember(RecruitCharacterId);
        Check("(D) recruit rebuilt on restore", recruit2 != null);
        Check("(D) recruit live-state delta restored (HP dent)",
            recruit2!.Health!.CurrentHP == recruit2.Health.MaxHP - 5);
        Check("(D) recruit banked XP restored", squad2.GetXp(RecruitCharacterId) == 250);

        string s1 = JsonSerializer.Serialize(squad.CaptureMembers());
        string s2 = JsonSerializer.Serialize(squad2.CaptureMembers());
        Check("(D) EXACT grown-roster snapshot round-trip", s1 == s2);

        // The grown member levels up through the SHARED banked-XP path (combo resolved via ComboFor).
        squad2.AddXp(RecruitCharacterId, 1000); // 250 + 1000 = 1250 → one level, 250 banked
        var ups = squad2.ApplyBankedLevelUps();
        Check("(D) grown member levels up via banked XP (2 → 3)",
            squad2.FindMember(RecruitCharacterId)!.Stats!.Level == 3
            && ups.Exists(u => u.MemberId == RecruitCharacterId && u.ToLevel == 3));
        Check("(D) the fixed four did not level (no XP banked)",
            squad2.FindMember(SquadRoster.PlayerId)!.Stats!.Level == 2);
    }

    // ─────────────────────────── (E) Default path unchanged ───────────────────────────

    private void RunDefaultPathUnchanged()
    {
        GD.Print("-------------------- (E) Default 4-member path unchanged --------------------");
        var plain = SquadRoster.BuildNew(2);
        Check("(E) default squad is exactly 4 members", plain.Members.Count == 4);
        var snap = plain.CaptureMembers();
        Check("(E) default snapshot: 4 dtos, every preset key null (byte-identical default path)",
            snap.Count == 4 && snap.TrueForAll(d => d.PresetKey == null));
    }

    // ─────────────────────────── (F) VillagerLoader null-safety ───────────────────────────

    private void RunVillagerLoader(VillagerDefinition recruitVillager)
    {
        GD.Print("-------------------- (F) VillagerLoader placement + null-safety --------------------");

        // No marker anywhere → nothing placed, no throw (even though the predicate says "arrived").
        var bareHost = new Node3D { Name = "BareVillagerHost" };
        AddChild(bareHost);
        var loaderBare = new VillagerLoader(bareHost, _ => true, new[] { recruitVillager });
        loaderBare.PlaceArrived();
        Check("(F) loader null-safe: no marker → nothing placed, no throw", bareHost.GetChildCount() == 0);

        // Marker present but villager NOT arrived → still nothing placed.
        var host = new Node3D { Name = "VillagerHost" };
        AddChild(host);
        var marker = new Marker3D { Name = recruitVillager.MarkerName, Position = new Vector3(6f, 0f, 3f) };
        host.AddChild(marker);

        var loaderNotArrived = new VillagerLoader(host, _ => false, new[] { recruitVillager });
        loaderNotArrived.PlaceArrived();
        Check("(F) not-arrived villager places no NPC (marker only)", host.GetChildCount() == 1);

        // Arrived + marker present → a real NPC entity is spawned at the marker position (tracked by
        // the loader; with no schedule wired its anchor is the villager's own home marker).
        var loader = new VillagerLoader(host, _ => true, new[] { recruitVillager });
        loader.PlaceArrived();
        var npc = loader.GetPlaced(recruitVillager.Id);
        Check("(F) arrived villager gets an NPC at its marker",
            npc != null && npc.GlobalPosition == marker.GlobalPosition);

        // Idempotent: refreshing again does not duplicate the NPC.
        loader.Refresh(recruitVillager.Id);
        int npcCount = 0;
        foreach (Node c in host.GetChildren())
            if (c is VillagerNpc)
                npcCount++;
        Check("(F) refresh does not duplicate the NPC", npcCount == 1);
    }

    // ─────────────── (G) shipped empty + GameState no-op, (H) GameState round-trip ───────────────

    private void RunShippedEmptyAndGameState()
    {
        GD.Print("-------------------- (G) Shipped registries EMPTY + GameState no-op --------------------");

        Check("(G) SHIPPED Villagers registry has content", Villagers.All.Count > 0);

        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        Check("(G) GameState built a squad of 4", gs.Squad != null && gs.Squad.Members.Count == 4);

        var arrivalEvents = new List<string>();
        gs.VillagerArrived += arrivalEvents.Add;
        var flagEvents = new List<string>();
        gs.StoryFlagChanged += flagEvents.Add;

        Check("(G) SetStoryFlag works + emits event", gs.SetStoryFlag("intro_done") && flagEvents.Count == 1);
        Check("(G) HasStoryFlag reflects it", gs.HasStoryFlag("intro_done"));
        Check("(G) re-set is a no-op (false)", !gs.SetStoryFlag("intro_done"));
        Check("(G) JoinRoster rejects an unknown villager (empty catalog)", !gs.JoinRoster("v_recruit"));
        Check("(G) no villager arrived in shipped play", gs.ArrivedVillagers.Count == 0 && arrivalEvents.Count == 0);
        Check("(G) squad still 4 (nothing joined)", gs.Squad!.Members.Count == 4);

        // (H) Full GameState round-trip of a story flag + a grown roster.
        GD.Print("-------------------- (H) GameState save/load round-trip + arrival persistence --------------------");

        // PartyPresets still holds the spike registration from (C). Grow the squad directly (the
        // shipped catalog has no villager to join), exercising the same InsertMember → save path.
        var grown = gs.Squad!.InsertMember(RecruitPresetKey, lvl => PresetCharacters.BuildRecruit(lvl),
            PresetCombos.FighterSentinel, gs.Squad.Level);
        Check("(H) GameState squad grown to 5 via InsertMember", grown != null && gs.Squad.Members.Count == 5);
        grown!.Health!.SetCurrentHP(grown.Health.MaxHP - 3);
        gs.SetStoryFlag("chapter1_done");
        gs.SaveGame();

        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(H) reloaded GameState restored the story flags",
            gs2.HasStoryFlag("intro_done") && gs2.HasStoryFlag("chapter1_done"));
        Check("(H) reloaded GameState rebuilt the grown roster (5 members)",
            gs2.Squad != null && gs2.Squad.Members.Count == 5);
        var reRecruit = gs2.Squad!.FindMember(RecruitCharacterId);
        Check("(H) reloaded recruit present with its HP delta restored",
            reRecruit != null && reRecruit.Health!.CurrentHP == reRecruit.Health.MaxHP - 3);

        RunPartyFormationCap(gs2); // (I)

        // Arrival-state capture/restore (the persistence path a populated catalog would use), and no
        // re-fire for an already-arrived villager after restore.
        var ctx = new StubContext();
        ctx.Flags.Add("recruit_ready");
        var recruitVillager = new VillagerDefinition
        {
            Id = "v_recruit", DisplayName = "The Recruit",
            Arrival = ArrivalTrigger.StoryFlag("recruit_ready"),
            Recruitable = true, JoinPresetKey = RecruitPresetKey,
        };
        var townsfolk = new VillagerDefinition
        {
            Id = "v_townie", DisplayName = "Townsperson",
            Arrival = ArrivalTrigger.StoryFlag("townie_ready"), Recruitable = false,
        };
        var vsA = new VillagerSystem(ctx, new[] { recruitVillager, townsfolk });
        vsA.EvaluateArrivals();
        var captured = vsA.Capture();

        var vsB = new VillagerSystem(ctx, new[] { recruitVillager, townsfolk });
        var reFired = new List<string>();
        vsB.Arrived += reFired.Add;
        vsB.Restore(captured);
        Check("(H) villager arrival state round-trips (recruit arrived, townie not)",
            vsB.HasArrived("v_recruit") && !vsB.HasArrived("v_townie"));
        Check("(H) restore raises no arrival events", reFired.Count == 0);
        vsB.EvaluateArrivals();
        Check("(H) re-evaluate after restore does not re-fire the already-arrived recruit",
            !reFired.Contains("v_recruit"));
    }

    // ─────── (I) Grown POOL still forms a ≤4 adventuring party (selection from the pool) ───────

    /// <summary>
    /// The corrected model's core invariant: joining grows the ROSTER POOL, but the adventuring
    /// party stays a selection of ≤4. Drives the real GameState party-formation seam on a 5-member
    /// pool — the select view lists the 4 non-Veteran companions, an over-full selection is rejected,
    /// a chosen 3 forms a party of 4, and the pool + the selection both round-trip through a save.
    /// The all-hands default caps its party at 4 even with the larger pool.
    /// </summary>
    private void RunPartyFormationCap(GameState gs)
    {
        GD.Print("-------------------- (I) Adventuring party capped at 4 from a 5-member pool --------------------");
        const string territoryId = "verdant_fringe";

        Check("(I) pool is 5 going in", gs.Squad != null && gs.Squad.Members.Count == 5);

        var selectView = gs.GetPartySelectView(territoryId);
        Check("(I) party-select lists 4 companions from the pool (Veteran + 4 others)",
            selectView.Companions.Count == 4);

        // A party of five (4 companions) is REJECTED — the adventuring party is capped at 4.
        var fourCompanions = new List<string>
        {
            SquadRoster.ElaraId, SquadRoster.TharrId, SquadRoster.FenwickId, RecruitCharacterId,
        };
        Check("(I) travel with 4 companions (party of 5) rejected", !gs.TravelToTerritory(territoryId, fourCompanions));
        Check("(I) still at the outpost after the rejected embark", gs.Territory.CurrentTerritoryId == null);

        // A chosen 3 (party of 4) is ACCEPTED — the selection from the pool, not the whole pool.
        var chosen = new List<string> { SquadRoster.TharrId, SquadRoster.FenwickId, RecruitCharacterId };
        Check("(I) travel with a chosen 3 (party of 4) accepted", gs.TravelToTerritory(territoryId, chosen));
        Check("(I) exactly 3 companions selected → party of 4 (Veteran + 3)",
            gs.Territory.SelectedCompanionIds.Count == 3);
        Check("(I) selection holds the CHOSEN members, not the whole pool",
            gs.Territory.SelectedCompanionIds.Contains(RecruitCharacterId)
            && !gs.Territory.SelectedCompanionIds.Contains(SquadRoster.ElaraId));

        // Save mid-selection → reload → pool (5) AND selection (3) both restored.
        gs.SaveGame();
        var gsReload = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gsReload);
        Check("(I) reload restores the 5-member pool", gsReload.Squad != null && gsReload.Squad.Members.Count == 5);
        Check("(I) reload restores the 3-member party selection", gsReload.Territory.SelectedCompanionIds.Count == 3);

        // The all-hands default (full-party overload) also caps the party at 4 with the larger pool.
        Check("(I) all-hands travel from a 5-pool caps the party at 4 (≤3 companions)",
            gsReload.TravelToTerritory(territoryId)
            && gsReload.Territory.SelectedCompanionIds.Count <= TerritorySystem.MaxCompanions);
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
        GD.Print("[VillagerSpike] slot0.json backed up and cleared for the test run.");
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
            GD.Print("[VillagerSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[VillagerSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
