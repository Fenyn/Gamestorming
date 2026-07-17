using System;
using System.Linq;
using Bulwark.Data;

using Bulwark.Cozy;
namespace Bulwark.Quests;

/// <summary>
/// The hand-wired STORY / QUEST-TRIGGER orchestrator (design/tutorial.md, design/tutorial_quests.md).
/// Plain C# and unit-testable: it owns the content knowledge that used to live in the GameState
/// autoload — the tutorial quest chain, the per-item and per-building quest hooks, the milestone
/// latches (eight buildings, eight trophies, first casualty), the repair-lodging rules, the
/// deliver-set resolution, and the single home of every quest-event key a command records
/// (crop_harvested, smithy_craft, meal_eaten, combat_victory, …). GameState keeps thin forwarders and
/// wires the system events to the handler methods here; every string literal that names story content
/// lives in THIS class, never in the autoload.
///
/// The story systems it reacts to are injected as narrow delegates (flag get/set, building/trophy
/// queries, the saving <c>SetStoryFlag</c> command, the "any member is a casualty" predicate) plus the
/// two sibling systems it drives directly (<see cref="QuestLog"/> for quest state,
/// <see cref="Inventory"/> for material checks/consumption) — never GameState itself. Two flag-write
/// seams are distinguished on purpose: <paramref name="setFlagRaw"/> sets the store WITHOUT a save
/// (latches whose caller saves right after, mirroring the pre-refactor "call the flag store directly to
/// avoid a redundant extra save" note), while <paramref name="setStoryFlag"/> is the saving command
/// (RepairLodging's beats and the designated-encounter ClearsStoryFlag, which must persist immediately).
/// </summary>
public sealed class StoryDirector
{
    /// <summary>
    /// Bulwark story flag latched the first time any party member ends a combat encounter dead or
    /// Wounded (see the injected casualty predicate for the exact query + its known limitation). A
    /// framework seam only — no shipped villager/quest reads it in shipped play; authored content can
    /// gate on it via <see cref="ArrivalTrigger.StoryFlag"/>.
    /// </summary>
    private const string FirstCasualtyFlag = "first_casualty";

    /// <summary>
    /// Bulwark story flag latched the first time the outpost has 8 or more buildings commissioned
    /// (tier ≥ 1), EXCLUDING the "command_post" start-state building (present from day one, so it never
    /// counts toward this milestone). One-shot, idempotent.
    /// </summary>
    private const string EightBuildingsFlag = "eight_buildings_constructed";

    /// <summary>
    /// Bulwark story flag latched the first time the party's combined trophy count (every
    /// <see cref="ItemCategory.Trophy"/> item, summed across carry + warehouse) reaches 8 — checked
    /// after every inventory gain and again after a load. One-shot, idempotent.
    /// </summary>
    private const string EightTrophiesFlag = "eight_trophies_collected";

    /// <summary>Named day-clock pause reason for the Day-1 tutorial time freeze (design/tutorial.md):
    /// set when intro_complete lands, cleared when the scripted day close sets first_rest.</summary>
    private const string Day1FreezeSource = "tutorial_day1";

    /// <summary>Per-day chance Josen shows up once the Infirmary is built (design/tutorial_quests.md,
    /// Mend the Wounded). The deterministic latest-arrival day is the real guarantee (see
    /// <see cref="JosenLatestDaysAfterInfirmary"/>); the roll only paces the average earlier.</summary>
    private const double JosenArrivalChancePerDay = 0.35;

    /// <summary>Josen arrives no later than this many days after the Infirmary is built, so a run of
    /// unlucky rolls can never lock him (and Mend the Wounded) out.</summary>
    private const int JosenLatestDaysAfterInfirmary = 3;

    private readonly QuestLog _questLog;
    private readonly Inventory _inventory;
    private readonly Func<string, bool> _hasFlagForConditions;
    private readonly Func<string, bool> _hasFlagRaw;
    private readonly Func<string, bool> _setFlagRaw;
    private readonly Func<string, bool> _setStoryFlag;
    private readonly Func<string, int> _buildingTier;
    private readonly Func<int> _commissionedCount;
    private readonly Func<bool> _anyCasualty;
    private readonly Action<string, bool> _setClockPaused;

    private readonly Random _random = new();

    /// <summary>Absolute day ordinal the Infirmary was first observed built (the Josen arrival-window
    /// anchor). -1 = not yet built/observed. Transient by design (not persisted) — a load re-anchors it
    /// to the load day (prototype-grade; the deterministic latest-day guarantee still holds).</summary>
    private int _infirmaryFirstSeenDay = -1;

    /// <param name="questLog">The quest log this director starts/completes/ticks.</param>
    /// <param name="inventory">Party inventory (repair-lodging + deliver material checks/consumption).</param>
    /// <param name="hasFlagForConditions">Derived + real flag resolver (quest evaluation / event recording).</param>
    /// <param name="hasFlagRaw">Real story-flag store read (the one-shot milestone/latch guards).</param>
    /// <param name="setFlagRaw">Real story-flag store set WITHOUT a save — latches whose caller saves next.</param>
    /// <param name="setStoryFlag">The saving <c>SetStoryFlag</c> command (beats that must persist at once).</param>
    /// <param name="buildingTier">Live building tier query (0 = not commissioned).</param>
    /// <param name="commissionedCount">Count of buildings at tier ≥ 1 (the eight-buildings milestone).</param>
    /// <param name="anyCasualty">Predicate: any member currently dead or Wounded (the first-casualty latch).</param>
    public StoryDirector(
        QuestLog questLog,
        Inventory inventory,
        Func<string, bool> hasFlagForConditions,
        Func<string, bool> hasFlagRaw,
        Func<string, bool> setFlagRaw,
        Func<string, bool> setStoryFlag,
        Func<string, int> buildingTier,
        Func<int> commissionedCount,
        Func<bool> anyCasualty,
        Action<string, bool> setClockPaused)
    {
        _questLog = questLog ?? throw new ArgumentNullException(nameof(questLog));
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _hasFlagForConditions = hasFlagForConditions ?? throw new ArgumentNullException(nameof(hasFlagForConditions));
        _hasFlagRaw = hasFlagRaw ?? throw new ArgumentNullException(nameof(hasFlagRaw));
        _setFlagRaw = setFlagRaw ?? throw new ArgumentNullException(nameof(setFlagRaw));
        _setStoryFlag = setStoryFlag ?? throw new ArgumentNullException(nameof(setStoryFlag));
        _buildingTier = buildingTier ?? throw new ArgumentNullException(nameof(buildingTier));
        _commissionedCount = commissionedCount ?? throw new ArgumentNullException(nameof(commissionedCount));
        _anyCasualty = anyCasualty ?? throw new ArgumentNullException(nameof(anyCasualty));
        _setClockPaused = setClockPaused ?? throw new ArgumentNullException(nameof(setClockPaused));
    }

    // ===================== Quest-trigger handlers (wired to system events by GameState) =====================

    /// <summary>Quest trigger: story flags drive the hand-wired opening quest starts/completions and
    /// the Day-1 tutorial time freeze (design/tutorial.md). The rest of the arc is data-driven.</summary>
    public void OnStoryFlag(string flagId)
    {
        switch (flagId)
        {
            case "intro_complete":
                _questLog.StartQuest("repair_lodging");
                // Freeze the day clock for the directed Day-1 tutorial — the day only advances via the
                // scripted close below (first_rest lifts it).
                _setClockPaused(Day1FreezeSource, true);
                break;
            case "lodging_repaired":
                _questLog.CompleteQuest("repair_lodging");
                // The scripted Day-1 close (day1_close cutscene → auto-sleep → first_rest) is sequenced
                // by the outpost scene when it observes lodging_repaired; it reuses the sleep/day-advance
                // path, so nothing else to do here.
                break;
            case "first_rest":
                // The scripted close reached Day 2: lift the tutorial freeze and open The Planning Table.
                _setClockPaused(Day1FreezeSource, false);
                _questLog.StartQuest("planning_table");
                break;
            case "planning_table_shown":
                _questLog.CompleteQuest("planning_table");
                // Raise the Hearths auto-starts (data-driven StartWhen planning_table_shown).
                break;
        }
    }

    /// <summary>
    /// Day-start story beats. Josen's arrival (design/tutorial_quests.md, Mend the Wounded): a random
    /// event 1-<see cref="JosenLatestDaysAfterInfirmary"/> days after the Infirmary is built —
    /// <see cref="JosenArrivalChancePerDay"/> per day, with a deterministic latest-day guarantee so an
    /// unlucky run never locks him out. Setting the (real) josen_arrived flag drives his villager
    /// arrival and starts Mend the Wounded through the normal FlagSet path.
    /// </summary>
    public void OnDayStarted(int today)
    {
        if (_hasFlagRaw("josen_arrived") || !_hasFlagForConditions("infirmary_built"))
            return;

        if (_infirmaryFirstSeenDay < 0)
            _infirmaryFirstSeenDay = today;

        int daysSince = today - _infirmaryFirstSeenDay;
        if (daysSince >= JosenLatestDaysAfterInfirmary || _random.NextDouble() < JosenArrivalChancePerDay)
            _setStoryFlag("josen_arrived");
    }

    /// <summary>
    /// Post-load catch-up: re-apply the Day-1 tutorial freeze when a save was taken mid-Day-1
    /// (intro_complete set but the scripted close's first_rest not yet reached), and re-anchor Josen's
    /// arrival window to the load day (the anchor is transient — prototype-grade — but the latest-day
    /// guarantee still holds from the load day forward).
    /// </summary>
    public void OnLoaded(int today)
    {
        if (_hasFlagRaw("intro_complete") && !_hasFlagRaw("first_rest"))
            _setClockPaused(Day1FreezeSource, true);

        if (_infirmaryFirstSeenDay < 0 && !_hasFlagRaw("josen_arrived") && _hasFlagForConditions("infirmary_built"))
            _infirmaryFirstSeenDay = today;
    }

    /// <summary>Quest trigger: inventory gains drive repair_lodging progress AND Restore the Trading
    /// Post's "gather hardwood" guidance one-shot — the item-gain choke point covers both.</summary>
    public void OnItemAdded(string itemId, int qty)
    {
        if (_questLog.IsActive("repair_lodging"))
        {
            if (itemId == "wood")
                _questLog.UpdateProgress("repair_lodging", 0, qty);
            else if (itemId == "stone")
                _questLog.UpdateProgress("repair_lodging", 1, qty);
        }

        // Restore the Trading Post's hardwood guidance ticks on the first Elderwood-sourced material
        // banked. No biome tag exists on Items, so membership is the explicit ElderwoodMaterials set.
        if (Bulwark.Data.Quests.ElderwoodMaterials.Contains(itemId))
            RecordQuestEvent("elderwood_material_banked");
    }

    /// <summary>
    /// Quest trigger on any building state change (commission/contribute/upgrade/construction-complete):
    /// raises the arc's derived-ish first_commission flag and re-evaluates the whole data-driven chain
    /// (derived *_built / *_commissioned flags may have just flipped). Runs AFTER the main handler's
    /// effect-recompute + BuildingChanged event (subscription order).
    /// </summary>
    public void OnBuildingChanged(string buildingId)
    {
        int tier = _buildingTier(buildingId);

        // First Blood starts on the first PLAYER commission — exclude the start-state command_post
        // (present at tier 1 from day one). Set is idempotent; FlagSet re-runs EvaluateQuests.
        if (buildingId != "command_post" && tier >= 1)
            _setFlagRaw("first_commission");

        EvaluateQuests();
    }

    /// <summary>Quest trigger on construction completion: every completion re-derives *_built flags, so
    /// re-evaluate the data-driven chain.</summary>
    public void OnConstructionCompleted(string buildingId) => EvaluateQuests();

    // ===================== Milestone latches =====================

    /// <summary>
    /// Framework seam (<c>eight_buildings_constructed</c>): latch the flag the first time the outpost has
    /// 8+ buildings at tier ≥ 1, excluding the "command_post" start-state building (present from day one,
    /// narratively not a constructed building). One-shot — Set is idempotent past the first call. Uses
    /// the raw flag store (not the saving command) to avoid a redundant extra save: the commission path
    /// saves right after this call. Also re-checked after a load restore (a save may already be past the
    /// threshold), mirroring <see cref="CheckEightTrophiesMilestone"/>.
    /// </summary>
    public void CheckEightBuildingsMilestone()
    {
        if (_hasFlagRaw(EightBuildingsFlag))
            return;
        int count = _commissionedCount();
        if (_buildingTier("command_post") >= 1)
            count--;
        if (count >= 8)
            _setFlagRaw(EightBuildingsFlag);
    }

    /// <summary>
    /// Framework seam (<c>eight_trophies_collected</c>): latch the flag the first time the party's
    /// combined trophy count (every <see cref="ItemCategory.Trophy"/> item, summed via
    /// <see cref="Inventory.CountEverywhere"/> — carry + warehouse, regardless of scene mode) reaches 8.
    /// Called after every inventory gain AND after a load (a restored save may already be past the
    /// threshold — <see cref="Inventory.ItemAdded"/> never fires during restore). One-shot — Set is
    /// idempotent past the first call.
    /// </summary>
    public void CheckEightTrophiesMilestone()
    {
        if (_hasFlagRaw(EightTrophiesFlag))
            return;
        int total = 0;
        foreach (var def in Items.All)
            if (def.Category == ItemCategory.Trophy)
                total += _inventory.CountEverywhere(def.Id);
        if (total >= 8)
            _setFlagRaw(EightTrophiesFlag);
    }

    /// <summary>
    /// Framework seam (<c>first_casualty</c>): latch the flag the FIRST time any member ends an
    /// encounter dead or Wounded (read through the injected casualty predicate AFTER the roster's own
    /// post-combat cleanup ran). One-shot latch — the raw store Set is idempotent past the first set;
    /// uses the raw store (not the saving command) because the encounter-completion path saves right
    /// after this call. See the predicate's known limitation (an already-Wounded arrival reads as a
    /// casualty too), acceptable for a one-shot latch.
    /// </summary>
    public void OnEncounterCompleted()
    {
        if (!_hasFlagRaw(FirstCasualtyFlag) && _anyCasualty())
            _setFlagRaw(FirstCasualtyFlag);
    }

    // ===================== Command-driven story beats =====================

    /// <summary>
    /// First night's rest (design/tutorial.md): latch <c>first_rest</c>. Consumed by OnStoryFlag
    /// (lifts the Day-1 freeze, starts The Planning Table) and Tharr's Day-2 tour gating.
    /// Uses the raw store (idempotent past the first night, mirroring the first-casualty latch)
    /// so it rides the sleep command's AdvanceDay save rather than triggering a second one — FlagSet
    /// still runs the quest/arrival re-evaluation.
    /// </summary>
    public void OnFirstRest() => _setFlagRaw("first_rest");

    /// <summary>
    /// A victorious territory encounter: latch the one-shot <c>first_combat_victory</c> flag the
    /// tutorial dialogue debrief references, count the First Blood victory (quest event combat_victory —
    /// its counter only advances while the quest is active, so pre-quest wins never count), and apply the
    /// designated-encounter latch (design/tutorial_quests.md): some roamers flip a one-way story flag on
    /// victory — the deeper expedition (first_expedition_cleared → completes quest 5 AND triggers Arkus's
    /// arrival) and the wolf-lair boss (dire_wolf_slain → completes quest 9). Data-driven off the roamer;
    /// the saving SetStoryFlag drives villager arrivals and quest completion through the normal FlagSet path.
    /// </summary>
    public void OnCombatVictory(string territoryId, string roamerId)
    {
        _setFlagRaw("first_combat_victory");
        RecordQuestEvent("combat_victory");

        if (Territories.TryGet(territoryId, out var territoryDef))
        {
            var roamer = territoryDef.Roamers.FirstOrDefault(r => r.RoamerId == roamerId);
            if (!string.IsNullOrEmpty(roamer?.ClearsStoryFlag))
                _setStoryFlag(roamer!.ClearsStoryFlag!);
        }
    }

    /// <summary>Harvesting a mature farm plot ticks First Harvest's counter (one tick per harvested plot).</summary>
    public void OnCropHarvested() => RecordQuestEvent("crop_harvested");

    /// <summary>Upgrading/buying gear at the forge completes First Steel (quest event smithy_craft).</summary>
    public void OnSmithyCraft() => RecordQuestEvent("smithy_craft");

    /// <summary>Eating a meal ticks Share the Harvest's "Eat the meal he cooks" objective.</summary>
    public void OnMealEaten() => RecordQuestEvent("meal_eaten");

    /// <summary>A sale ticks Share the Harvest's "Sell 3 goods to Elara" counter (quest event item_sold).</summary>
    public void OnItemSold(int qty) => RecordQuestEvent("item_sold", qty);

    /// <summary>A bought SEED ticks First Harvest's guidance "Buy seeds" objective (quest event seed_bought).</summary>
    public void OnGoodBought(string itemId)
    {
        if (Items.TryGet(itemId, out var d) && d.Category == ItemCategory.Seed)
            RecordQuestEvent("seed_bought");
    }

    /// <summary>
    /// The first Treat Wounds AT THE INFIRMARY completes Mend the Wounded (quest event treat_wounds).
    /// design/tutorial_quests.md's "Completes when" column names the Infirmary specifically — Treat
    /// Wounds has no per-location variant in the sim (it is a squad-panel action usable anywhere), so
    /// "at the Infirmary" is approximated pragmatically as "the Infirmary exists" (derived
    /// infirmary_built: tier ≥ 1 and its tier-1 construction window has closed) rather than a true
    /// location check. A Treat Wounds resolved before the Infirmary is built still heals — it simply
    /// does not advance this quest.
    /// </summary>
    public void OnTreatWounds()
    {
        if (_hasFlagForConditions("infirmary_built"))
            RecordQuestEvent("treat_wounds");
    }

    // ===================== Repair lodging (rules; the command stays a GameState forwarder) =====================

    /// <summary>
    /// The simple "bring materials to Tharr" task before the full building system: requires 15 wood +
    /// 10 stone in the party inventory, consumes them, and sets the lodging_quest_started + lodging_repaired
    /// story beats (through the saving SetStoryFlag command, so they persist at once). Returns false (clean
    /// reject, nothing consumed) when the materials are insufficient or the lodging is already repaired.
    /// </summary>
    public bool TryRepairLodging()
    {
        if (_hasFlagRaw("lodging_repaired"))
            return false;
        if (!_inventory.Has("wood", 15) || !_inventory.Has("stone", 10))
            return false;
        _inventory.RemoveItem("wood", 15);
        _inventory.RemoveItem("stone", 10);
        _setStoryFlag("lodging_quest_started");
        _setStoryFlag("lodging_repaired");
        return true;
    }

    // ===================== Quest log seams (choke point + deliver + evaluation) =====================

    /// <summary>
    /// Choke point: record one quest-relevant event (combat_victory, item_sold, crop_harvested,
    /// meal_eaten, smithy_craft, treat_wounds, …). Advances matching event-count and one-shot objectives
    /// on the active data-driven quests and re-evaluates start/complete conditions. Wired from the
    /// systems' own events; GameState exposes a forwarder so a later dialogue/scene layer can raise
    /// events too.
    /// </summary>
    public void RecordQuestEvent(string eventKey, int amount = 1)
        => _questLog.RecordEvent(eventKey, amount, _hasFlagForConditions);

    /// <summary>
    /// Deliver items from a named set toward an active quest's Deliver objective (the Give-Fenwick-3-crops
    /// interaction). Validates an active quest has an unmet Deliver objective for <paramref name="setKey"/>
    /// AND the party holds enough items from the resolved set, then CONSUMES that many (greedy across the
    /// set) and advances the objective. Rejects cleanly (false, nothing consumed) otherwise. Currently
    /// only <c>Bulwark.Data.Quests.FreshCropsSet</c> resolves.
    /// </summary>
    public bool DeliverQuestItems(string setKey)
    {
        if (_questLog.FindDeliverObjective(setKey) is not { } target)
            return false;
        var set = ResolveDeliverSet(setKey);
        if (set == null)
            return false;

        int have = 0;
        foreach (var id in set)
            have += _inventory.Count(id);
        if (have < target.Need)
            return false;

        // Consume the required count greedily across the set (validated available above).
        int remaining = target.Need;
        foreach (var id in set)
        {
            if (remaining <= 0)
                break;
            int take = Math.Min(remaining, _inventory.Count(id));
            if (take > 0 && _inventory.RemoveItem(id, take))
                remaining -= take;
        }

        _questLog.RecordDelivery(setKey, target.Need, _hasFlagForConditions);
        return true;
    }

    /// <summary>Resolve a Deliver set key to its item-id set (null = unknown key).</summary>
    private static System.Collections.Generic.IReadOnlyCollection<string>? ResolveDeliverSet(string setKey)
        => setKey == Bulwark.Data.Quests.FreshCropsSet ? Bulwark.Data.Quests.FreshCrops : null;

    /// <summary>Re-evaluate every data-driven arc quest's start/complete conditions against current
    /// state (real + derived flags). The single seam called from every relevant change + on load.</summary>
    public void EvaluateQuests() => _questLog.EvaluateConditions(_hasFlagForConditions);
}
