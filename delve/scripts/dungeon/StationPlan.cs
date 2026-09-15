using System;
using Delve.Run;

namespace Delve.Dungeon;

public enum RoomPurpose { Receiving, Checkpoint, Barracks, MessHall, Stores, Kitchen, Cistern, Workshop, Shrine, Maintenance, Refuge, WardChamber }
public enum StationHistory { Flooded, Evacuated, WardFailure }

/// <summary>Physical facility functions are independent of the encounters occupying them.</summary>
public static class StationPlan
{
    public static readonly RoomPurpose[] Functions = { RoomPurpose.Receiving, RoomPurpose.Checkpoint, RoomPurpose.Barracks, RoomPurpose.MessHall,
        RoomPurpose.Stores, RoomPurpose.Workshop, RoomPurpose.Cistern, RoomPurpose.Kitchen, RoomPurpose.Shrine, RoomPurpose.Maintenance, RoomPurpose.Refuge, RoomPurpose.WardChamber };
    public static StationHistory History(int seed) => (StationHistory)new Random(RunRng.StableSeed(seed, 0, "station-history")).Next(3);
    public static string Account(StationHistory history) => history switch
    {
        StationHistory.Flooded => "Water broke into the service wing. The keepers carried supplies toward the entrance before abandoning the station. Scavengers now occupy the dry rooms.",
        StationHistory.Evacuated => "The keepers packed in haste. Sleeping places became casualty beds and the guards screened the evacuation. Scavengers have reopened the stores.",
        _ => "The ward failed despite repeated repairs. Spare components remain on the benches and disconnected conduits lead toward the sealed chamber. Scavengers have moved into the living wing."
    };
    public static string Name(RoomPurpose purpose) => purpose switch
    {
        RoomPurpose.Receiving => "Receiving hall", RoomPurpose.Checkpoint => "Guard checkpoint", RoomPurpose.MessHall => "Mess hall",
        RoomPurpose.WardChamber => "Ward chamber", RoomPurpose.Refuge => "Emergency refuge", RoomPurpose.Maintenance => "Maintenance gallery",
        _ => purpose.ToString()
    };
    public static RoomPurpose Default(RoomFamily family) => family switch
    {
        RoomFamily.Entrance => RoomPurpose.Receiving, RoomFamily.GuardHall => RoomPurpose.Checkpoint,
        RoomFamily.Barracks => RoomPurpose.Barracks, RoomFamily.Cistern => RoomPurpose.Cistern,
        RoomFamily.Guardian => RoomPurpose.WardChamber, RoomFamily.Elite => RoomPurpose.MessHall,
        RoomFamily.Cache => RoomPurpose.Stores, RoomFamily.Camp => RoomPurpose.Refuge,
        RoomFamily.Shrine => RoomPurpose.Shrine, _ => RoomPurpose.Workshop
    };
    public static RoomFamily Prefab(RoomPurpose purpose) => purpose switch
    {
        RoomPurpose.Receiving => RoomFamily.Entrance, RoomPurpose.Checkpoint => RoomFamily.GuardHall,
        RoomPurpose.Barracks => RoomFamily.Barracks, RoomPurpose.Cistern => RoomFamily.Cistern,
        RoomPurpose.WardChamber => RoomFamily.Guardian, RoomPurpose.Refuge => RoomFamily.Camp,
        RoomPurpose.Shrine => RoomFamily.Shrine, RoomPurpose.Stores => RoomFamily.Cache,
        RoomPurpose.Workshop or RoomPurpose.Maintenance => RoomFamily.Collapse, _ => RoomFamily.Elite
    };
}
