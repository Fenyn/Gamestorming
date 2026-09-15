using System;
using System.Linq;
using Delve.Dungeon;
using PF2e.MapGen;
namespace Delve.Dev;
public partial class DungeonSpike
{
    private void CheckLayoutVariants()
    {
        int errors = 0, count = 0;
        foreach (var purpose in Enum.GetValues<RoomPurpose>())
        foreach (var history in Enum.GetValues<StationHistory>())
        foreach (int size in new[] { 12, 16 })
        for (int variant = 0; variant < 3; variant++)
        for (int mask = 1; mask < 16; mask++)
        {
            var doors = Enum.GetValues<DoorSide>().Where(d => (mask & (1 << (int)d)) != 0).ToArray();
            var room = StationRooms.Generate(purpose, mask * 71, size, doors, new RoomVariation(LayoutVariant: variant), history);
            count++;
            bool signature = purpose switch
            {
                RoomPurpose.Receiving or RoomPurpose.Checkpoint => room.Props.Any(p => p.Kind == "reception"),
                RoomPurpose.Barracks => room.Props.Count(p => p.Kind is "bed" or "bunkbed") >= 2,
                RoomPurpose.MessHall => room.Props.Any(p => p.Kind == "dining"),
                RoomPurpose.Cistern => room.Layout.Tiles.Count(t => t == TileRole.Water) >= 6,
                RoomPurpose.WardChamber => room.Props.Any(p => p.Kind == "ward_engine") && room.Props.Any(p => p.Kind == "stairs"),
                _ => room.Props.Count > 0
            };
            if (!RoomGeneration.Validate(room) || !signature)
            {
                if (errors < 8) Godot.GD.Print($"Station signature missing: {purpose}/{size}/{variant}/{mask}/{history}");
                errors++;
            }
            foreach (var side in doors) RoomGeneration.Route(room.Layout, new(room.Layout.Width / 2, room.Layout.Width / 2), RoomGeneration.Inside(room.Layout.Width, side));
        }
        Check($"{count} station rooms retain their defining furnishings and legal routes", errors == 0);
        int planErrors = 0;
        foreach (int seed in Enumerable.Range(1, 100))
        {
            var floor = DungeonFloor.Generate(seed);
            foreach (var (a,b) in new[] { (0,1), (2,3), (3,7), (6,7), (9,10), (10,11) })
                if (!floor.Rooms[a].Doors.Any(d => d.Other(a) == b)) planErrors++;
            if (floor.Rooms.Select(r => r.Purpose).Distinct().Count() != 12) planErrors++;
            var elite = floor.Rooms.Single(r => r.Family == RoomFamily.Elite);
            if (floor.Rooms[0].Doors.Any(d => d.Other(0) == elite.Id)) planErrors++;
        }
        Check("station floors retain connected public, living, service and ward functions", planErrors == 0);
    }
}
