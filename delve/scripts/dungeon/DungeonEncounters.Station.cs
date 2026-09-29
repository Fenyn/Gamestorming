using System.Linq;
using Delve.Run.Events;

namespace Delve.Dungeon;

public static partial class DungeonEncounters
{
    /// <summary>Authored event DCs are level-1 DCs. This moves each onto the party's level along the
    /// GM Core "DCs by level" table, keeping its offset from the standard DC.</summary>
    public static EventDefinition AtLevel(EventDefinition definition, int level)
    {
        int shift = PF2e.Core.PF2eRules.GetDCByLevel(level) - PF2e.Core.PF2eRules.GetDCByLevel(1);
        if (shift == 0) return definition;
        return definition with
        {
            Options = definition.Options.Select(o => o.Check is { FixedDc: false } check ? o with { Check = check with { Dc = check.Dc + shift } } : o).ToArray()
        };
    }

    /// <summary>The scene a quiet room offers, in its floor's words.</summary>
    public static EventDefinition RoomEvent(DungeonRoom room, StationHistory history, CrawlWords words) => new()
    {
        Id = $"station-{room.Id}",
        Title = words.Name(room.Purpose),
        Body = words.Body(room.Purpose, history),
        Options = words.Scenes(room.Purpose, history),
    };

    public static string StationBody(RoomPurpose purpose, StationHistory history) => purpose switch
    {
        RoomPurpose.Shrine => Event(RoomFamily.Shrine).Body,
        RoomPurpose.Stores => Event(RoomFamily.Cache).Body,
        _ => $"The {StationPlan.Name(purpose).ToLowerInvariant()} is quiet. {Observation(purpose, history)}",
    };
    private static string Observation(RoomPurpose purpose, StationHistory history) => purpose switch
    {
        RoomPurpose.Barracks => "Beds and lockers mark the sleeping bays. Someone has since made a rough sleeping place among them.",
        RoomPurpose.MessHall or RoomPurpose.Kitchen => "Tables and serving equipment remain from the station's communal meals. Scavengers have begun using the room again.",
        RoomPurpose.Cistern => "The reservoir dominates the chamber. Walkways provide access to the pumps and pipework.",
        RoomPurpose.Checkpoint => "The guards once inspected arrivals here. Their desk and equipment remain.",
        _ => history == StationHistory.WardFailure ? "Discarded components record the keepers' attempts to repair the ward." :
            history == StationHistory.Flooded ? "Mud has spread through the service areas since the station was abandoned." : "The workers left their equipment behind during the evacuation."
    };
}
