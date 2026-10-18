using System.Collections.Generic;
using Delve.Run;
using static Delve.Data.VillageActivities;

namespace Delve.Data;

/// <summary>Where a resident spends one part of the day, and doing what. The area names a cluster of ResidentSpot markers.</summary>
public sealed record VillageTask(string Area, string Activity);

/// <summary>
/// Each resident's day in the village: morning, afternoon and evening. Work happens by day; in the
/// evening the village gathers at the hearth, the tavern and the shrine. A resident whose area is not
/// built yet, or is full, takes the first of <see cref="Fallbacks"/> with room.
/// </summary>
public static class VillageSchedule
{
    public const string Commons = "commons";

    public static readonly VillageTask[] Fallbacks = { new(Commons, Wander), new("hearth", Sit), new(Commons, Chat) };

    private static readonly VillageTask Fallback = Fallbacks[0];

    private static readonly Dictionary<string, VillageTask[]> ByResident = new()
    {
        ["player"] = new VillageTask[] { new("woodyard", Chop), new("woodyard", Chop), new("hearth", Sit) },
        ["elara"] = new VillageTask[] { new("store", Harvest), new("well", Chat), new("tavern", Sit) },
        ["tharr"] = new VillageTask[] { new("waypost", Watch), new("waypost", Watch), new("hearth", Sit) },
        ["fenwick"] = new VillageTask[] { new("bestiary", Watch), new("bestiary", Watch), new("cook", Cook) },
        ["raven"] = new VillageTask[] { new("yard", Train), new("yard", Train), new("tavern", Chat) },
        ["thistle"] = new VillageTask[] { new("garden", Garden), new("garden", Garden), new("tavern", Sit) },
        ["arkus"] = new VillageTask[] { new("smithy", Smith), new("smithy", Smith), new("tavern", Sit) },
        ["aldric"] = new VillageTask[] { new("yard", Watch), new("bunkhouse", Watch), new("bunkhouse", Watch) },
        ["spore"] = new VillageTask[] { new("garden", Garden), new("garden", Garden), new("well", Chat) },
        ["josen"] = new VillageTask[] { new("shrine", Sit), new("shrine", Sit), new("shrine", Sit) },
        ["grub"] = new VillageTask[] { new("garden", Garden), new("fields", Garden), new("hearth", Sit) },
        ["sera"] = new VillageTask[] { new("waypost", Watch), new("waypost", Watch), new(Commons, Wander) },
        ["oskar"] = new VillageTask[] { new("infirmary", Watch), new("infirmary", Watch), new("infirmary", Watch) },
        ["hazel"] = new VillageTask[] { new("waypost", Chat), new("bestiary", Chat), new("tavern", Chat) },
        ["wynn"] = new VillageTask[] { new("hearth", Sit), new(Commons, Wander), new("tavern", Chat) },
        ["vasska"] = new VillageTask[] { new("shrine", Sit), new("shrine", Sit), new("shrine", Sit) },
        ["hilde"] = new VillageTask[] { new("forge", Smith), new("forge", Smith), new("tavern", Sit) },
        ["flick"] = new VillageTask[] { new("junk", Haul), new("junk", Haul), new("tavern", Sit) },
    };

    public static VillageTask For(string residentId, CampTimeOfDay time) =>
        ByResident.TryGetValue(residentId, out var day) ? day[(int)time] : Fallback;
}
