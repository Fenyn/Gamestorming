using System.Collections.Generic;

namespace Delve.Dungeon;

/// <summary>The crawl's words for each floor, keyed by the floor's id (FloorThemes).</summary>
public static class CrawlWordsTable
{
    public static CrawlWords For(string floorId) => Rows.TryGetValue(floorId, out var words) ? words : Station;

    private static readonly CrawlWords Station = new()
    {
        Names = new Dictionary<RoomPurpose, string>
        {
            [RoomPurpose.Receiving] = "Receiving hall", [RoomPurpose.Checkpoint] = "Guard checkpoint", [RoomPurpose.Barracks] = "Barracks",
            [RoomPurpose.MessHall] = "Mess hall", [RoomPurpose.Stores] = "Stores", [RoomPurpose.Kitchen] = "Kitchen",
            [RoomPurpose.Cistern] = "Cistern", [RoomPurpose.Workshop] = "Workshop", [RoomPurpose.Shrine] = "Shrine",
            [RoomPurpose.Maintenance] = "Maintenance gallery", [RoomPurpose.Refuge] = "Emergency refuge", [RoomPurpose.WardChamber] = "Ward chamber",
        },
        Accounts = new Dictionary<StationHistory, string>
        {
            [StationHistory.Flooded] = StationPlan.Account(StationHistory.Flooded),
            [StationHistory.Evacuated] = StationPlan.Account(StationHistory.Evacuated),
            [StationHistory.WardFailure] = StationPlan.Account(StationHistory.WardFailure),
        },
        Body = DungeonEncounters.StationBody,
        Scenes = StationScenes.For,
        NewRoomKicker = "New room",
        UnexploredTitle = "Unexplored room",
        ProgressLabel = "Rooms cleared",
        CrossingNoun = "doorway",
        GoalFind = "Goal: find the ward chamber",
        GoalDefeat = "Goal: defeat the guardian",
        GoalLeave = "Goal: take the stairs down",
        ExitAction = "Descend to floor {0}",
        ExitTip = "Leave this floor by the guardian's stairs.",
        ExitBlockedTip = "Unavailable: defeat the guardian in the ward chamber first.",
        FloorComplete = "Floor complete. The stairs lead onward.",
        ArrivalCaption = "The root stair leads down into the ward station.\nFind the ward chamber.",
        RevealProp = "ward_engine",
        ExitProp = "stairs",
        ArrivalProp = "stair_rise",
    };

    private static readonly CrawlWords Fringe = new()
    {
        Names = new Dictionary<RoomPurpose, string>
        {
            [RoomPurpose.Receiving] = "Old road", [RoomPurpose.Checkpoint] = "Woodward's lookout", [RoomPurpose.Barracks] = "Woodcutters' camp",
            [RoomPurpose.MessHall] = "Hazel thicket", [RoomPurpose.Stores] = "Poachers' cache", [RoomPurpose.Kitchen] = "Charcoal kiln",
            [RoomPurpose.Cistern] = "Woodland spring", [RoomPurpose.Workshop] = "Woodwright's shed", [RoomPurpose.Shrine] = "Wayside shrine",
            [RoomPurpose.Maintenance] = "Dark waystone", [RoomPurpose.Refuge] = "Hunters' lodge", [RoomPurpose.WardChamber] = "Wolf den",
        },
        Accounts = new Dictionary<StationHistory, string>
        {
            [StationHistory.Flooded] = "The river rose in the thaw and drowned the low glades. Goblins hold the dry camps.",
            [StationHistory.Evacuated] = "The camps emptied in one night when the fog came. Raiders have opened the caches.",
            [StationHistory.WardFailure] = "The waystones went dark one by one. Wolves den where the light was.",
        },
        Body = (purpose, _) => Prompt(deep: false, purpose),
        Scenes = GladeScenes.For,
        NewRoomKicker = "New glade",
        UnexploredTitle = "Unexplored glade",
        ProgressLabel = "Glades cleared",
        CrossingNoun = "trail",
        GoalFind = "Goal: find the wolf den",
        GoalDefeat = "Goal: defeat the Dire Wolf's pack",
        GoalLeave = "Goal: take the holloway",
        ExitAction = "Enter the Deep Wood",
        ExitTip = "Leave the Fringe by the holloway.",
        ExitBlockedTip = "Unavailable: break the wolf pack at the den first.",
        FloorComplete = "The pack is broken, and the holloway leads on.",
        ArrivalCaption = "You take the old road into the Fringe.\nFind the wolf den.",
        RevealProp = "beacon",
        ExitProp = "holloway",
        ArrivalProp = "old_road",
    };

    private static readonly CrawlWords DeepWood = Fringe with
    {
        Names = new Dictionary<RoomPurpose, string>
        {
            [RoomPurpose.Receiving] = "Holloway foot", [RoomPurpose.Checkpoint] = "High seat", [RoomPurpose.Barracks] = "Trappers' camp",
            [RoomPurpose.MessHall] = "Fungus hollow", [RoomPurpose.Stores] = "Smugglers' cache", [RoomPurpose.Kitchen] = "Pitch kiln",
            [RoomPurpose.Cistern] = "Black pool", [RoomPurpose.Workshop] = "Bowyer's lean-to", [RoomPurpose.Shrine] = "Standing stones",
            [RoomPurpose.Maintenance] = "Sunken waystone", [RoomPurpose.Refuge] = "Hollow oak", [RoomPurpose.WardChamber] = "Regent's grove",
        },
        Accounts = new Dictionary<StationHistory, string>
        {
            [StationHistory.Flooded] = "Black water has crept up from the hollows below. Things from the water hunt the dry glades.",
            [StationHistory.Evacuated] = "The order's foresters fled and left their dead under the stones. Without light, the dead do not rest.",
            [StationHistory.WardFailure] = "The waystone ring has failed. The Regent's roots have split the old road.",
        },
        Body = (purpose, _) => Prompt(deep: true, purpose),
        GoalFind = "Goal: find the Regent's grove",
        GoalDefeat = "Goal: defeat the Arboreal Regent",
        GoalLeave = "Goal: take the root stair down",
        ExitAction = "Descend to the ward station",
        ExitTip = "Go down the root stair to the ward station.",
        ExitBlockedTip = "Unavailable: defeat the Regent in its grove first.",
        FloorComplete = "The Regent has fallen, and the root stair leads down.",
        ArrivalCaption = "You follow the holloway down into the Deep Wood.\nFind the Regent's grove.",
        ExitProp = "root_stair",
        ArrivalProp = "holloway_rise",
    };

    // A method, so the rows above can name prompt tables declared below them.
    private static string Prompt(bool deep, RoomPurpose purpose) =>
        (deep ? DeepPrompts : FringePrompts).TryGetValue(purpose, out var prompt) ? prompt : "The glade is quiet.";

    private static readonly Dictionary<RoomPurpose, string> FringePrompts = new()
    {
        [RoomPurpose.Checkpoint] = "A platform sits high in an oak. Blazes on the ladder mark the old trails.",
        [RoomPurpose.Barracks] = "Cots stand under a torn tarp.",
        [RoomPurpose.MessHall] = "Hazel and berries grow thick here.",
        [RoomPurpose.Stores] = "A chest lies under a deadfall. Its lid is wired shut.",
        [RoomPurpose.Kitchen] = "A turf kiln still holds its heat.",
        [RoomPurpose.Cistern] = "A spring fills a stone basin.",
        [RoomPurpose.Workshop] = "Tools hang over a bench under a bark roof.",
        [RoomPurpose.Shrine] = "A dawn sun is carved on a wayside post.",
        [RoomPurpose.Maintenance] = "The lamp on the waystone cairn is cold.",
    };

    private static readonly Dictionary<RoomPurpose, string> DeepPrompts = new()
    {
        [RoomPurpose.Checkpoint] = "A hunting seat is lashed high in a dead pine. Old blazes mark the trails below.",
        [RoomPurpose.Barracks] = "Snare lines and cold bedrolls lie under the roots.",
        [RoomPurpose.MessHall] = "Pale mushrooms crowd the hollow.",
        [RoomPurpose.Stores] = "A strongbox is sunk in the bank. A tripwire runs to its lid.",
        [RoomPurpose.Kitchen] = "Pitch pots cool beside a banked fire.",
        [RoomPurpose.Cistern] = "Black water fills a sinkhole to the brim.",
        [RoomPurpose.Workshop] = "Bowstaves season on pegs under a bark roof.",
        [RoomPurpose.Shrine] = "The standing stones hum faintly.",
        [RoomPurpose.Maintenance] = "The waystone lies half sunk in moss, and its lamp is cold.",
    };

    private static readonly Dictionary<string, CrawlWords> Rows = new()
    {
        ["grassland"] = Fringe,
        ["deepforest"] = DeepWood,
        ["station"] = Station,
    };
}
