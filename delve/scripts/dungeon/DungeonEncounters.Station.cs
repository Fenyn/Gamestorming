using Delve.Run.Events;

namespace Delve.Dungeon;

public static partial class DungeonEncounters
{
    public static EventDefinition StationEvent(DungeonRoom room, StationHistory history)
    {
        if (room.Purpose == RoomPurpose.Shrine) return Event(RoomFamily.Shrine);
        if (room.Purpose == RoomPurpose.Stores) return Event(RoomFamily.Cache);
        return new EventDefinition
        {
            Id = $"station-{room.Id}", Title = StationPlan.Name(room.Purpose),
            Body = room.Purpose == RoomPurpose.Receiving ? StationPlan.Account(history)
                + " Find the guardian in the ward chamber. Defeating it restores the Wardstone and opens the stairs. Clear the final floor to complete the expedition." :
                $"The {StationPlan.Name(room.Purpose).ToLowerInvariant()} is quiet. {Observation(room.Purpose, history)} You can look for useful supplies among what remains.",
            Options = room.Purpose == RoomPurpose.Receiving
                ? new[] { new EventOption { Label = "Raise the Wardstone and enter", Success = EventOutcome.Nothing("The station opens before you. Follow its doors deeper inside.") } }
                : new[]
                {
                    new EventOption { Label = "Gather the abandoned supplies", Success = new EventOutcome("You recover a handful of useful salvage.", new[] { new EventEffect(EventEffectKind.GoldDelta, 10) }) },
                    new EventOption { Label = "Leave the room undisturbed", Success = EventOutcome.Nothing("You leave the remnants of the station where they lie.") }
                }
        };
    }
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
