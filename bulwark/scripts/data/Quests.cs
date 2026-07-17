using System.Collections.Generic;
using System.Linq;
using Bulwark.Cozy;

using Bulwark.Quests;
namespace Bulwark.Data;

public static class Quests
{
    // ===================== Deliver / material sets (design/tutorial_quests.md) =====================

    /// <summary>Deliver-objective set key for "Give Fenwick 3 fresh crops" (Fenwick's Table).</summary>
    public const string FreshCropsSet = "fresh_crops";

    /// <summary>Every farm crop's harvested-yield item id — the "fresh crops" the player hands Fenwick,
    /// derived from <see cref="Crops"/> so adding a crop needs no edit here.</summary>
    public static readonly IReadOnlyCollection<string> FreshCrops =
        Crops.All.Select(c => c.YieldItemId).ToHashSet();

    /// <summary>
    /// Elderwood-sourced material ids (Restore the Trading Post's hardwood guidance). No biome tag
    /// exists on <see cref="Items"/>, so this is the minimal explicit set — the yields of the Elderwood
    /// territory's resource nodes (Territories.Elderwood / ResourceNodes): hardwood, coal, wild_mushroom,
    /// forest_root, ward_salt, and the ley-glade arcane_essence. Winning the wolf gate opens the biome,
    /// so the first hardwood banked ticks the guidance objective.
    /// </summary>
    public static readonly IReadOnlyCollection<string> ElderwoodMaterials = new HashSet<string>
    {
        "hardwood", "coal", "wild_mushroom", "forest_root", "ward_salt", "arcane_essence",
    };

    // ===================== Hand-wired opening (design/tutorial.md) =====================
    // RepairLodging + PlanningTable have StartWhen null — GameState's StoryDirector starts/completes them
    // explicitly through the intro → lodging → scripted day-close → Day-2 table beats.

    public static readonly QuestDefinition RepairLodging = new(
        "repair_lodging",
        "Repair the Lodging",
        new QuestObjective[]
        {
            new("Gather timber", "wood", 15),
            new("Gather stone", "stone", 10),
            new("Return to Tharr"),
        });

    public static readonly QuestDefinition PlanningTable = new(
        "planning_table",
        "The Planning Table",
        new QuestObjective[]
        {
            new("Visit the planning table"),
        });

    // ============ The directed opening arc — the data-driven quest chain (design/tutorial_quests.md) ============
    //
    // DATA-DRIVEN family: each carries a StartWhen flag-conjunction (resolved through
    // GameState.HasFlagForConditions — real flags, derived <id>_built / <id>_commissioned, and
    // quest_<id>_complete) and auto-completes when its non-optional objectives are all done. Optional
    // objectives (guidance, e.g. "Speak with Arkus") display + tick but never gate completion, so the
    // arc never stalls on a step outside this wave (dialogue, tracking).

    /// <summary>Directed Farmhouse + Tavern repair. Starts when the Day-2 planning-table tour lands
    /// (planning_table_shown); completes when both hearths' derived *_built flags flip (either order).</summary>
    public static readonly QuestDefinition RaiseTheHearths = new(
        "raise_the_hearths", "Raise the Hearths",
        new[]
        {
            QuestObjective.OnFlag("Raise the Farmhouse", "farmhouse_built"),
            QuestObjective.OnFlag("Raise the Tavern", "tavern_built"),
        },
        StartWhen: new[] { "planning_table_shown" });

    /// <summary>Combat. Starts on the first player commission (Tharr's first build day); its counter
    /// only tallies victories AFTER it starts.</summary>
    public static readonly QuestDefinition FirstBlood = new(
        "first_blood", "First Blood",
        new[]
        {
            QuestObjective.CountEvent("Defeat the goblins near the old quarry (win 2 encounters)", "combat_victory", 2),
        },
        StartWhen: new[] { "first_commission" });

    /// <summary>The farm loop. Starts on farmhouse_built; completes on 6 crops harvested. Starter seeds
    /// now come from Fenwick's dialogue (no store on day one), so there is no buy-seeds step.</summary>
    public static readonly QuestDefinition FirstHarvest = new(
        "first_harvest", "First Harvest",
        new[]
        {
            QuestObjective.CountEvent("Harvest 6 crops", "crop_harvested", 6),
        },
        StartWhen: new[] { "farmhouse_built" });

    /// <summary>Hearth and till. Requires First Harvest done AND the Tavern up. Completes on the
    /// Fenwick hand-off (3 crops) + eating the meal he cooks — farming and meals taught by Fenwick.</summary>
    public static readonly QuestDefinition FenwicksTable = new(
        "fenwicks_table", "Fenwick's Table",
        new[]
        {
            QuestObjective.Deliver("Give Fenwick 3 fresh crops", FreshCropsSet, 3),
            QuestObjective.OnceEvent("Eat the meal he cooks", "meal_eaten"),
        },
        StartWhen: new[] { "quest_first_harvest_complete", "tavern_built" });

    /// <summary>The wolf gate (moved earlier). Starts when Fenwick's Table completes; the lair scene
    /// spawns while active and victory latches dire_wolf_slain, which opens the Elderwood passage.
    /// Tracking is guidance.</summary>
    public static readonly QuestDefinition WolfOfTheFringe = new(
        "wolf_of_the_fringe", "The Wolf of the Fringe",
        new[]
        {
            QuestObjective.OnceEvent("Track the dire wolf to its hunting ground", "wolf_tracked", optional: true),
            QuestObjective.OnFlag("Slay it", "dire_wolf_slain"),
        },
        StartWhen: new[] { "quest_fenwicks_table_complete" });

    /// <summary>The Trading Post needs Elderwood hardwood, and the dire wolf guards the passage. Starts
    /// alongside the wolf hunt (Fenwick's Table complete); completes on trading_post_built. Entering the
    /// Elderwood and banking hardwood are guidance (the Elderwood opens once the wolf is slain).</summary>
    public static readonly QuestDefinition RestoreTradingPost = new(
        "restore_trading_post", "Restore the Trading Post",
        new[]
        {
            QuestObjective.OnceEvent("Travel to the Elderwood", "elderwood_entered", optional: true),
            QuestObjective.OnceEvent("Gather hardwood from the Elderwood", "elderwood_material_banked", optional: true),
            QuestObjective.OnFlag("Raise the Trading Post", "trading_post_built"),
        },
        StartWhen: new[] { "quest_fenwicks_table_complete" });

    /// <summary>Arkus wakes and prompts the Smithy and the Infirmary. Starts when Arkus wakes
    /// (arkus_awake, set by the wake cutscene once the Trading Post is up); completes when both
    /// buildings are raised. Speaking with Arkus and the two commissions are guidance.</summary>
    public static readonly QuestDefinition SmithAndSickbed = new(
        "smith_and_sickbed", "The Smith and the Sickbed",
        new[]
        {
            QuestObjective.OnFlag("Speak with Arkus", "arkus_awake", optional: true),
            QuestObjective.OnFlag("Fund the Smithy", "smithy_commissioned", optional: true),
            QuestObjective.OnFlag("Raise the Smithy", "smithy_built"),
            QuestObjective.OnFlag("Commission the Infirmary", "infirmary_commissioned", optional: true),
            QuestObjective.OnFlag("Raise the Infirmary", "infirmary_built"),
        },
        StartWhen: new[] { "arkus_awake" });

    /// <summary>Smithy crafting. Starts on smithy_built; completes on the first craft/upgrade at the forge.</summary>
    public static readonly QuestDefinition FirstSteel = new(
        "first_steel", "First Steel",
        new[]
        {
            QuestObjective.OnceEvent("Craft or upgrade one piece of gear", "smithy_craft"),
        },
        StartWhen: new[] { "smithy_built" });

    /// <summary>Attrition and recovery. Starts when Josen arrives (a random event 1-3 days after the
    /// Infirmary is built — the Infirmary already exists by then). Completes on the first Treat Wounds.
    /// Meeting Josen is guidance.</summary>
    public static readonly QuestDefinition MendTheWounded = new(
        "mend_the_wounded", "Mend the Wounded",
        new[]
        {
            QuestObjective.OnFlag("Speak with Josen", "josen_arrived", optional: true),
            QuestObjective.OnceEvent("Treat a squad member's wounds", "treat_wounds"),
        },
        StartWhen: new[] { "josen_arrived" });

    private static readonly DefinitionRegistry<QuestDefinition> Registry = new(d => d.Id,
        RepairLodging, PlanningTable,
        RaiseTheHearths, FirstBlood, FirstHarvest, FenwicksTable,
        WolfOfTheFringe, RestoreTradingPost, SmithAndSickbed, FirstSteel,
        MendTheWounded);

    public static IReadOnlyCollection<QuestDefinition> All => Registry.All;
    public static bool TryGet(string id, out QuestDefinition def) => Registry.TryGet(id, out def);
    public static QuestDefinition Get(string id) => Registry.Get(id);
}
