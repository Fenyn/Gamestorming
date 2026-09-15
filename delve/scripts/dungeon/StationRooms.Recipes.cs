using System;
using PF2e.MapGen;

namespace Delve.Dungeon;

public static partial class StationRooms
{
    private static void Furnish(Builder b, RoomPurpose purpose, int variant)
    {
        int n = b.N, m = b.Mid;
        switch (purpose)
        {
            case RoomPurpose.Receiving:
                b.Main("reception", 2, 2, Math.Max(2, m - 3), 2);
                if (variant != 0) b.Place("screen", 1, m - 2, Math.Max(2, m - 3), 1, 1.6f);
                b.Place("bench", n - 3, 2, 1, Math.Max(2, m - 3), 0.55f);
                b.Place("notice_board", 1, 2, 1, 2, 1.8f);
                b.Place("luggage", 2, n - 4, 2, 2, 0.8f);
                break;
            case RoomPurpose.Checkpoint:
                // A duty bay and inspection rail, with an opening toward the entrance.
                b.Main("reception", 2, 2, Math.Max(2, m - 3), 2);
                b.Place("screen", 1, m - 3, Math.Max(2, m - 3), 1, 1.6f);
                b.Place("weapon_cabinet", n - 3, 2, 1, Math.Max(2, m - 3), 1.7f);
                b.Place("bench", 2, n - 3, Math.Max(2, m - 3), 1, 0.55f);
                b.Place("stove", n - 3, n - 3, 1, 1, 1.4f);
                break;
            case RoomPurpose.Barracks:
                for (int y = 2; y < n - 3; y += 3)
                {
                    if (b.Place(variant == 1 ? "bunkbed" : "bed", 1, y, 2, 1, 0.6f)) b.Place("footlocker", 3, y, 1, 1, 0.5f);
                    if (b.Place(variant == 1 ? "bunkbed" : "bed", n - 3, y, 2, 1, 0.6f)) b.Place("footlocker", n - 4, y, 1, 1, 0.5f);
                }
                b.Place("stove", 2, n - 3, 1, 1, 1.4f);
                b.Place("washstand", n - 5, 1, 2, 1, 0.9f);
                if (variant != 0) b.Place("screen", 4, 2, 1, Math.Max(2, m - 4), 1.6f);
                break;
            case RoomPurpose.MessHall:
            case RoomPurpose.Kitchen:
                if (!b.Place("dining", 2, 2, 2, n - 4, 0.9f))
                {
                    b.Place("dining", 2, 2, 2, Math.Max(2, m - 3), 0.9f);
                    b.Place("dining", 2, m + 3, 2, n - m - 5, 0.9f);
                }
                if (!b.Place("dining", n - 4, 2, 2, n - 4, 0.9f))
                {
                    b.Place("dining", n - 4, 2, 2, Math.Max(2, m - 3), 0.9f);
                    b.Place("dining", n - 4, m + 3, 2, n - m - 5, 0.9f);
                }
                b.Place("hearth", 1, 1, 2, 1, 1.8f);
                b.Place("pantry", n - 4, 1, 3, 1, 1.6f);
                if (purpose == RoomPurpose.Kitchen) b.Place("prep_counter", 2, n - 3, Math.Max(2, m - 3), 1, 1);
                b.Surface(1, 1, n - 2, n - 2, SurfaceType.Wood);
                break;
            case RoomPurpose.Cistern:
                b.Reservoir(2, 2, Math.Max(2, Math.Min(m - 3, (int)((n - 2) * (n - 2) * 0.28f / (n - 4)))), n - 4);
                b.Place("pump", n - 4, 2, 2, Math.Max(2, m - 3), 1.5f);
                b.Place("pipe", n - 3, n - 3, 1, 1, 1.4f);
                b.Place("tool_bench", n - 5, n - 3, 2, 1, 1);
                break;
            case RoomPurpose.WardChamber:
                if (!b.Main("ward_engine", m - Math.Max(2, m - 3) / 2, 1, Math.Max(2, m - 3), Math.Max(2, m - 3), 2.5f))
                    b.Place("ward_engine", 1, 1, Math.Max(2, m - 3), 2, 2.5f);
                b.Place("control_desk", 1, 2, 1, Math.Max(2, m - 3), 1.2f);
                b.Place("control_desk", n - 2, 2, 1, Math.Max(2, m - 3), 1.2f);
                b.Main("stairs", 2, n - 4, 2, 2, 1);
                b.Place("tool_bench", n - 5, n - 3, 2, 1);
                break;
            case RoomPurpose.Stores:
                for (int y = 2; y < n - 2; y += 3)
                {
                    b.Place("pantry", 1, y, 1, 2, 1.7f);
                    b.Place("luggage", n - 3, y, 2, 2, 1);
                }
                b.Place("cache", 2, n - 4, 2, 2);
                break;
            case RoomPurpose.Workshop:
            case RoomPurpose.Maintenance:
                b.Place("tool_bench", 1, 2, 2, Math.Max(2, m - 3));
                b.Place("pump", n - 3, 2, 2, 2, 1.5f);
                b.Place("pantry", 2, n - 2, Math.Max(2, m - 3), 1, 1.7f);
                b.Place("pipe", n - 3, n - 3, 1, 1, 1.4f);
                break;
            case RoomPurpose.Shrine:
                b.Place("shrine", 2, 2, 2, 2, 1.8f);
                b.Place("bench", n - 3, 2, 1, Math.Max(2, m - 3), 0.5f);
                b.Place("votive", 1, 1, 1, 1, 1.3f);
                b.Place("urn", n - 2, n - 2, 1, 1);
                break;
            case RoomPurpose.Refuge:
                b.Place("camp", 1, 1, 2, 2);
                b.Place("pantry", n - 3, 2, 2, 1, 1.6f);
                b.Place("bed", 1, n - 3, 2, 1, 0.6f);
                b.Place("bed", 1, n - 5, 2, 1, 0.6f);
                break;
        }
        b.Place("torch", 1, 1, 1, 1, 1.6f, false);
        b.Place("torch", n - 2, n - 2, 1, 1, 1.6f, false);
    }

    private static void TellHistory(Builder b, RoomPurpose purpose, StationHistory history)
    {
        int n = b.N;
        if (history == StationHistory.Flooded && purpose is RoomPurpose.Cistern or RoomPurpose.Workshop or RoomPurpose.Kitchen or RoomPurpose.Maintenance)
        {
            b.Surface(1, 1, n - 2, 2, SurfaceType.Mud);
            b.Surface(1, 1, 2, n - 2, SurfaceType.Mud);
            b.Place("leak", n - 2, 1, 1, 1, 0.1f, false);
        }
        else if (history == StationHistory.Evacuated && purpose is RoomPurpose.Receiving or RoomPurpose.Barracks or RoomPurpose.Refuge)
            b.Place("packed_supplies", n - 3, n - 3, 2, 2, 1);
        else if (history == StationHistory.WardFailure && purpose is RoomPurpose.Workshop or RoomPurpose.Maintenance or RoomPurpose.WardChamber)
            b.Place("broken_component", 1, n - 3, 2, 2, 0.6f);
        if (purpose is RoomPurpose.Stores or RoomPurpose.MessHall or RoomPurpose.Barracks)
            b.Place("scavenger_bed", n - 4, n - 3, 2, 2, 0.5f);
    }
}
