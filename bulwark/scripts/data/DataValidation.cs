using System.Collections.Generic;
using System.Linq;
using Bulwark.Cozy;
using Bulwark.Data.Dialogues;
using Godot;
// The Characters registry class shares its leaf name with the Bulwark.Data.Characters namespace, which
// shadows it from inside Bulwark.Data — alias it so `CharacterRegistry.IsDefined` resolves to the class.
using CharacterRegistry = Bulwark.Data.Characters.Characters;

using Bulwark.Quests;
namespace Bulwark.Data;

/// <summary>
/// Fail-fast, cross-registry referential-integrity checks over the static content registries. All
/// individual registries are clean <see cref="DefinitionRegistry{T}"/> instances; nothing else
/// cross-checks the string ids that flow BETWEEN them (a recipe's RequiredCategory vs a building's
/// CategoryUnlock detail; a bundle's item id vs Items; an encounter's drop-table key vs DropTables).
/// Those seams are where shipped bugs hid, so this runs at content-load time — loud in dev builds
/// (<see cref="Godot.OS.IsDebugBuild"/>), absent in release (<see cref="RunAll"/> is only invoked from
/// <c>DataManager._Ready</c> behind that gate).
///
/// Deliberately minimal (no rule-engine, no attributes): a flat list of named check methods, each
/// emitting one <c>GD.PushError("[DataValidation] ...")</c> per violation and returning its violation
/// count. <see cref="RunAll"/> sums them and logs a one-line summary. Add a check by writing a method
/// and appending it to the list in <see cref="RunAll"/>.
/// </summary>
public static class DataValidation
{
    private const string Tag = "[DataValidation]";

    /// <summary>Run every check, log a one-line summary, and return the total violation count (0 = clean).
    /// Callers gate this on <see cref="Godot.OS.IsDebugBuild"/>.</summary>
    public static int RunAll()
    {
        var checks = new (string Name, System.Func<int> Run)[]
        {
            ("recipe item ids", CheckRecipeItemIds),
            ("recipe categories", CheckRecipeCategories),
            ("bundle item ids", CheckBundleItemIds),
            ("drop-table item ids", CheckDropTableItemIds),
            ("trading-post item ids", CheckTradingPostItemIds),
            ("meal/consumable/crop item ids", CheckMealConsumableCropItemIds),
            ("territory scenes + encounter keys", CheckTerritories),
            ("quest item ids", CheckQuestItemIds),
            ("prices + quantities", CheckPricesAndQuantities),
            ("dialogue speakers", CheckDialogueSpeakers),
            ("quest flags", CheckQuestFlags),
            ("dialogue flags", CheckDialogueFlags),
            ("villager schedules", CheckSchedules),
        };

        int total = 0;
        foreach (var (_, run) in checks)
            total += run();

        GD.Print($"{Tag} ran {checks.Length} checks — {total} violation(s).");
        return total;
    }

    /// <summary>Emit one violation line and return 1 (folds into the per-check sum).</summary>
    private static int Violation(string message)
    {
        GD.PushError($"{Tag} {message}");
        return 1;
    }

    // ===================== Checks =====================

    /// <summary>Every recipe input/output resolves to an <see cref="Items"/> id. Wildcard inputs
    /// (category, not item) instead require the category to exist on at least one item.</summary>
    private static int CheckRecipeItemIds()
    {
        int v = 0;
        foreach (var r in Recipes.All)
        {
            foreach (var input in r.Inputs)
            {
                if (input.IsWildcard)
                {
                    var cat = input.CategoryWildcard!.Value;
                    if (!Items.All.Any(i => i.Category == cat))
                        v += Violation($"recipe '{r.Id}' wildcard input category '{cat}' matches no item.");
                }
                else if (input.ItemId == null || !Items.IsDefined(input.ItemId))
                {
                    v += Violation($"recipe '{r.Id}' input item '{input.ItemId ?? "<null>"}' is not a defined item.");
                }
            }

            if (!Items.IsDefined(r.OutputItemId))
                v += Violation($"recipe '{r.Id}' output item '{r.OutputItemId}' is not a defined item.");
        }
        return v;
    }

    /// <summary>
    /// Every recipe <see cref="RecipeDefinition.RequiredCategory"/> resolves to a CategoryUnlock a
    /// building tier grants — the exact bug the review found (a recipe requiring "tavern" while the
    /// Tavern granted "meals"). The station categories smelter/tanner/still/loom/apothecary are
    /// DECLARED-PENDING forward references (Recipes.cs: "no station building ships this pass; the
    /// category is data-only until one is authored"), so they are on a documented allowlist rather
    /// than flagged — a genuine typo still matches neither the grants nor the allowlist and fails.
    /// </summary>
    private static int CheckRecipeCategories()
    {
        var granted = new HashSet<string>(
            Buildings.All
                .SelectMany(b => b.Tiers)
                .SelectMany(t => t.Effects)
                .Where(e => e.Type == BuildingEffectType.CategoryUnlock && e.Detail != null)
                .Select(e => e.Detail!));

        // Declared-pending station categories (Recipes constants) — buildings authored later grant
        // these. TavernCategory ("meals") is intentionally absent: the Tavern already grants it, so it
        // is covered by `granted`. This is the one documented allowlist; every other category must be
        // a live building grant.
        var pending = new HashSet<string>
        {
            Recipes.SmelterCategory, Recipes.TannerCategory, Recipes.StillCategory,
            Recipes.LoomCategory, Recipes.ApothecaryCategory,
        };

        int v = 0;
        foreach (var r in Recipes.All)
        {
            if (r.RequiredCategory == null)
                continue;
            if (!granted.Contains(r.RequiredCategory) && !pending.Contains(r.RequiredCategory))
                v += Violation($"recipe '{r.Id}' RequiredCategory '{r.RequiredCategory}' is granted by no building tier.");
        }
        return v;
    }

    /// <summary>Every construction/upgrade bundle item id (all buildings, all tiers) resolves to an item.</summary>
    private static int CheckBundleItemIds()
    {
        int v = 0;
        foreach (var b in Buildings.All)
        {
            foreach (var req in b.ConstructionBundle)
                if (!Items.IsDefined(req.ItemId))
                    v += Violation($"building '{b.Id}' construction bundle item '{req.ItemId}' is not a defined item.");

            foreach (var tier in b.Tiers)
                foreach (var req in tier.UpgradeBundle)
                    if (!Items.IsDefined(req.ItemId))
                        v += Violation($"building '{b.Id}' tier {tier.Tier} upgrade bundle item '{req.ItemId}' is not a defined item.");
        }
        return v;
    }

    /// <summary>Every drop-table entry item id resolves to an item.</summary>
    private static int CheckDropTableItemIds()
    {
        int v = 0;
        foreach (var table in DropTables.All)
            foreach (var entry in table.Entries)
                if (!Items.IsDefined(entry.ItemId))
                    v += Violation($"drop table '{table.Id}' entry item '{entry.ItemId}' is not a defined item.");
        return v;
    }

    /// <summary>Every Trading Post catalog item id resolves to an item.</summary>
    private static int CheckTradingPostItemIds()
    {
        int v = 0;
        foreach (var entry in TradingPost.All)
            if (!Items.IsDefined(entry.ItemId))
                v += Violation($"trading post offer item '{entry.ItemId}' is not a defined item.");
        return v;
    }

    /// <summary>Every meal id, consumable id, and crop seed/yield id resolves to an item.</summary>
    private static int CheckMealConsumableCropItemIds()
    {
        int v = 0;
        foreach (var m in Meals.All)
            if (!Items.IsDefined(m.Id))
                v += Violation($"meal '{m.Id}' is not a defined item.");

        foreach (var c in Consumables.All)
            if (!Items.IsDefined(c.Id))
                v += Violation($"consumable '{c.Id}' is not a defined item.");

        foreach (var crop in Crops.All)
        {
            if (!Items.IsDefined(crop.SeedItemId))
                v += Violation($"crop '{crop.Id}' seed item '{crop.SeedItemId}' is not a defined item.");
            if (!Items.IsDefined(crop.YieldItemId))
                v += Violation($"crop '{crop.Id}' yield item '{crop.YieldItemId}' is not a defined item.");
        }
        return v;
    }

    /// <summary>
    /// For every territory: each roamer's weighted-encounter keys resolve in <see cref="EncounterTables"/>,
    /// and each encounter creature's drop-table key resolves in <see cref="DropTables"/> — hard
    /// referential violations. The <see cref="TerritoryDefinition.ScenePath"/> is only WARNED when
    /// missing, not counted: territory scenes are user-authored blockouts per CLAUDE.md (the Elderwood /
    /// Sunken Reach are documented as authored later), so a missing .tscn is a pending-content gap, not
    /// a data-integrity break.
    /// </summary>
    private static int CheckTerritories()
    {
        int v = 0;
        foreach (var terr in Territories.All)
        {
            if (!ResourceLoader.Exists(terr.ScenePath))
                GD.PushWarning($"{Tag} territory '{terr.Id}' scene '{terr.ScenePath}' does not exist yet (3D greybox pending).");

            foreach (var roamer in terr.Roamers)
            {
                foreach (var we in roamer.Encounters)
                {
                    if (!EncounterTables.TryGet(we.EncounterId, out var enc))
                    {
                        v += Violation($"territory '{terr.Id}' roamer '{roamer.RoamerId}' encounter '{we.EncounterId}' is not a defined encounter.");
                        continue;
                    }

                    foreach (var ec in enc.Creatures)
                    {
                        string? dropId = ec.Creature.DropTableId;
                        if (dropId != null && !DropTables.IsDefined(dropId))
                            v += Violation($"encounter '{enc.Id}' creature '{ec.Creature.DisplayName}' drop table '{dropId}' is not a defined drop table.");
                    }
                }
            }
        }
        return v;
    }

    /// <summary>Every quest objective's tracking item id (the only item-id-bearing quest field —
    /// QuestDefinition carries no reward items) resolves to an item.</summary>
    private static int CheckQuestItemIds()
    {
        int v = 0;
        foreach (var q in Bulwark.Data.Quests.All)
            foreach (var obj in q.Objectives)
                if (obj.TrackingItemId != null && !Items.IsDefined(obj.TrackingItemId))
                    v += Violation($"quest '{q.Id}' objective tracking item '{obj.TrackingItemId}' is not a defined item.");
        return v;
    }

    /// <summary>Gold prices and item quantities are sane: shop prices &gt; 0 (a zero buy price is free
    /// money), bundle quantities &gt; 0, recipe input/output quantities &gt; 0, and gold costs / drop
    /// bands non-negative and ordered.</summary>
    private static int CheckPricesAndQuantities()
    {
        int v = 0;

        foreach (var entry in TradingPost.All)
            if (entry.Price <= 0)
                v += Violation($"trading post offer '{entry.ItemId}' has a non-positive price ({entry.Price}).");

        foreach (var b in Buildings.All)
        {
            if (b.GoldCost < 0)
                v += Violation($"building '{b.Id}' has a negative gold cost ({b.GoldCost}).");
            foreach (var req in b.ConstructionBundle)
                if (req.Quantity <= 0)
                    v += Violation($"building '{b.Id}' construction bundle '{req.ItemId}' has a non-positive quantity ({req.Quantity}).");
            foreach (var tier in b.Tiers)
            {
                if (tier.GoldCost < 0)
                    v += Violation($"building '{b.Id}' tier {tier.Tier} has a negative gold cost ({tier.GoldCost}).");
                foreach (var req in tier.UpgradeBundle)
                    if (req.Quantity <= 0)
                        v += Violation($"building '{b.Id}' tier {tier.Tier} bundle '{req.ItemId}' has a non-positive quantity ({req.Quantity}).");
            }
        }

        foreach (var r in Recipes.All)
        {
            foreach (var input in r.Inputs)
                if (input.Quantity <= 0)
                    v += Violation($"recipe '{r.Id}' input has a non-positive quantity ({input.Quantity}).");
            if (r.OutputQuantity <= 0)
                v += Violation($"recipe '{r.Id}' output quantity is non-positive ({r.OutputQuantity}).");
        }

        foreach (var table in DropTables.All)
        {
            if (table.CoinMin < 0 || table.CoinMax < table.CoinMin)
                v += Violation($"drop table '{table.Id}' has an invalid coin band ({table.CoinMin}..{table.CoinMax}).");
            foreach (var entry in table.Entries)
                if (entry.MinQty < 0 || entry.MaxQty < entry.MinQty)
                    v += Violation($"drop table '{table.Id}' entry '{entry.ItemId}' has an invalid quantity band ({entry.MinQty}..{entry.MaxQty}).");
        }

        return v;
    }

    /// <summary>Every dialogue line/step speaker id resolves via <see cref="CharacterRegistry"/> (the player
    /// id "player" is itself a Characters profile, so no separate case is needed). Loads the dialogue
    /// JSONs the same way GameState does.</summary>
    private static int CheckDialogueSpeakers()
    {
        int v = 0;
        string path = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(path);

        foreach (string id in db.AllIds)
        {
            if (!db.TryGet(id, out var file))
                continue;

            if (file.Steps != null)
                foreach (var step in file.Steps)
                    if (!string.IsNullOrEmpty(step.Speaker) && !CharacterRegistry.IsDefined(step.Speaker))
                        v += Violation($"dialogue '{id}' step speaker '{step.Speaker}' is not a defined character.");

            if (file.Entries != null)
                foreach (var entry in file.Entries)
                    foreach (var line in entry.Lines)
                        if (!string.IsNullOrEmpty(line.Speaker) && !CharacterRegistry.IsDefined(line.Speaker))
                            v += Violation($"dialogue '{id}' talk line speaker '{line.Speaker}' is not a defined character.");
        }
        return v;
    }

    /// <summary>
    /// Membership-only <see cref="DerivedFlags"/> instance for validation: the live-state Funcs are
    /// never invoked by <see cref="DerivedFlags.CanResolve"/> (it only probes the precomputed family
    /// dictionaries), so no-op delegates are safe here. Building/villager/quest id sets default (null)
    /// to the shipped static registries (<see cref="Buildings.All"/>/<see cref="Villagers.All"/>/
    /// <see cref="Bulwark.Data.Quests.All"/>), matching production exactly.
    /// </summary>
    private static readonly DerivedFlags FlagFamilies = new(
        anyUnderConstruction: () => false,
        buildingTier: _ => 0,
        buildingUnderConstruction: _ => false,
        villagerArrived: _ => false,
        questCompleted: _ => false,
        questActive: _ => false);

    /// <summary>
    /// Real (non-derived) story flags actually set somewhere in shipped content — the complement to
    /// the derived families in <see cref="DerivedFlags"/>. Compiled by grepping
    /// <c>SetStoryFlag(...)</c> / <c>_storyFlags.Set(...)</c> literals in scripts/ (excluding
    /// scripts/dev/ — throwaway spikes, not shipped content), <c>"type": "flag"</c> effects in
    /// bulwark/data/dialogues/**/*.json, and roamer <c>ClearsStoryFlag</c> values in Territories.cs.
    /// A quest/dialogue flag id resolving through neither this set nor
    /// <see cref="DerivedFlags.CanResolve"/> is a flag nothing sets.
    /// </summary>
    private static readonly HashSet<string> KnownStoryFlags = new()
    {
        "intro_scene_0",               // RoadScene (SetStoryFlag)
        "intro_scene_1a",               // HomesteadExteriorScene (SetStoryFlag) + scene_1a.json step effect ("type": "flag")
        "intro_scene_1",                // HomesteadInteriorScene (SetStoryFlag)
        "intro_complete",               // data/dialogues/intro/scene_2.json step effect ("type": "flag")
        "lodging_quest_started",        // GameState.RepairLodging + tharr_tutorial.json talk-entry effect
        "lodging_repaired",             // GameState.RepairLodging
        "first_rest",                   // GameState.Sleep (design/tutorial.md Step 5)
        "starter_seeds_granted",        // fenwick_tutorial.json one-shot latch: dialogue item-effect seed grant (First Harvest, no store yet)
        "planning_table_shown",         // CozyWorldScene (planning table first shown)
        "first_commission",             // GameState.OnBuildingChangedForQuests (first player commission)
        "first_combat_victory",         // GameState.BeginTerritoryEncounter (first combat victory)
        "first_expedition_cleared",     // Territories.cs Verdant Fringe roamer ClearsStoryFlag
        "dire_wolf_slain",              // Territories.cs Wolf Lair roamer ClearsStoryFlag
        "arkus_found",                  // OutpostScene Arkus-found cutscene (return after dire_wolf_slain)
        "arkus_awake",                  // OutpostScene Arkus-wake cutscene (gates Smithy + Infirmary)
        "first_casualty",               // GameState.FirstCasualtyFlag (CompleteEncounter)
        "eight_buildings_constructed",  // GameState.EightBuildingsFlag (CheckEightBuildingsMilestone)
        "eight_trophies_collected",     // GameState.EightTrophiesFlag (CheckEightTrophiesMilestone)
    };

    /// <summary>A flag id is valid when it names a derived family or a known real flag.</summary>
    private static bool IsResolvableFlag(string flagId) => FlagFamilies.CanResolve(flagId) || KnownStoryFlags.Contains(flagId);

    /// <summary>
    /// Every flag a quest waits on (<see cref="QuestDefinition.StartWhen"/>) or ticks against
    /// (a <see cref="QuestObjectiveKind.Flag"/> objective's Key) must be <see cref="IsResolvableFlag"/>
    /// — either a derived family or a real flag something actually sets. Catches "quest waits on a
    /// flag nothing sets", which silently stalls the quest forever.
    /// </summary>
    private static int CheckQuestFlags()
    {
        int v = 0;
        foreach (var q in Bulwark.Data.Quests.All)
        {
            if (q.StartWhen != null)
                foreach (var flag in q.StartWhen)
                    if (!IsResolvableFlag(flag))
                        v += Violation($"quest '{q.Id}' StartWhen flag '{flag}' resolves through neither a derived family nor a known real flag.");

            foreach (var obj in q.Objectives)
                if (obj.Kind == QuestObjectiveKind.Flag && obj.Key != null && !IsResolvableFlag(obj.Key))
                    v += Violation($"quest '{q.Id}' objective '{obj.Description}' flag '{obj.Key}' resolves through neither a derived family nor a known real flag.");
        }
        return v;
    }

    /// <summary>
    /// Every <c>flags_required</c>/<c>flags_blocked</c> entry in dialogue JSON (top-level sequence
    /// conditions and talk-pool entry conditions) must be <see cref="IsResolvableFlag"/> — dialogue
    /// gating resolves flags through the same real+derived path quests use
    /// (<see cref="DialogueConditionContext.HasFlag"/>), so an unresolvable flag here is the same
    /// "gate on a flag nothing sets" bug. Loads the dialogue JSONs the same way GameState does.
    /// </summary>
    private static int CheckDialogueFlags()
    {
        int v = 0;
        string path = ProjectSettings.GlobalizePath("res://data/dialogues");
        var db = new DialogueDatabase(path);

        foreach (string id in db.AllIds)
        {
            if (!db.TryGet(id, out var file))
                continue;

            v += CheckDialogueConditionFlags(file.Conditions, $"dialogue '{id}'");

            if (file.Entries != null)
                foreach (var entry in file.Entries)
                    v += CheckDialogueConditionFlags(entry.Conditions, $"dialogue '{id}' entry (priority {entry.Priority})");
        }
        return v;
    }

    /// <summary>
    /// Every villager schedule (design/schedules) is well-formed: its id names a defined villager or a
    /// starting resident, it has at least one entry, entries carry a non-empty marker name and a minute
    /// within the clock's valid range (<see cref="DayClock.DayStartMinute"/>..<see cref="DayClock.DayRolloverMinute"/>,
    /// i.e. 6:00–30:00), and minutes strictly ASCEND (the resolver relies on that order). Marker EXISTENCE
    /// is a scene-side concern (a runtime warning), not validated here.
    /// </summary>
    private static int CheckSchedules()
    {
        int v = 0;
        foreach (var sched in Schedules.All)
        {
            if (!Villagers.IsDefined(sched.VillagerId) && !CharacterRegistry.IsDefined(sched.VillagerId))
                v += Violation($"schedule villager '{sched.VillagerId}' is not a defined villager or resident.");

            if (sched.Entries.Count == 0)
            {
                v += Violation($"schedule '{sched.VillagerId}' has no entries.");
                continue;
            }

            int prev = int.MinValue;
            foreach (var e in sched.Entries)
            {
                if (string.IsNullOrEmpty(e.MarkerName))
                    v += Violation($"schedule '{sched.VillagerId}' has an entry with an empty marker name.");

                if (e.MinuteOfDay < DayClock.DayStartMinute || e.MinuteOfDay > DayClock.DayRolloverMinute)
                    v += Violation($"schedule '{sched.VillagerId}' entry minute {e.MinuteOfDay} is outside the clock range [{DayClock.DayStartMinute}, {DayClock.DayRolloverMinute}].");

                if (e.MinuteOfDay <= prev)
                    v += Violation($"schedule '{sched.VillagerId}' entries are not strictly ascending (minute {e.MinuteOfDay} follows {prev}).");
                prev = e.MinuteOfDay;
            }
        }
        return v;
    }

    private static int CheckDialogueConditionFlags(DialogueCondition? cond, string where)
    {
        int v = 0;
        if (cond?.FlagsRequired != null)
            foreach (var flag in cond.FlagsRequired)
                if (!IsResolvableFlag(flag))
                    v += Violation($"{where} flags_required '{flag}' resolves through neither a derived family nor a known real flag.");

        if (cond?.FlagsBlocked != null)
            foreach (var flag in cond.FlagsBlocked)
                if (!IsResolvableFlag(flag))
                    v += Violation($"{where} flags_blocked '{flag}' resolves through neither a derived family nor a known real flag.");

        return v;
    }
}
