using System.Linq;
using Bulwark.Territory;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Bridges the live cozy systems (<see cref="DayClock"/>, <see cref="Inventory"/>,
/// <see cref="FarmSystem"/>) to and from a flat <see cref="SaveData"/> DTO. Pure C# and shared by
/// the GameState adapter and the verification spike, so both exercise the identical capture/restore
/// path.
/// </summary>
public static class SaveState
{
    /// <summary>Snapshot the current state of all cozy systems into a serializable DTO.</summary>
    public static SaveData Capture(
        DayClock clock, Inventory inventory, FarmSystem farm,
        SquadRoster? squad = null, TreatWoundsSystem? treatWounds = null,
        TerritorySystem? territory = null)
    {
        return new SaveData
        {
            Clock = new ClockDto
            {
                MinuteOfDay = clock.MinuteOfDay,
                Day = clock.Day,
                Season = clock.Season,
                Year = clock.Year,
            },
            Inventory = inventory.Stacks.ToDictionary(kv => kv.Key, kv => kv.Value),
            Plots = farm.AllPlots.Select(p => new PlotDto
            {
                X = p.Tile.X,
                Y = p.Tile.Y,
                Stage = p.Stage,
                CropId = p.CropId,
                DaysGrown = p.DaysGrown,
                WateredToday = p.WateredToday,
            }).ToList(),
            Squad = squad?.CaptureMembers(),
            TreatWoundsImmunities = treatWounds?.CaptureImmunities(),
            Territory = territory?.CaptureState(),
        };
    }

    /// <summary>Overwrite the live systems from a DTO.</summary>
    public static void Restore(
        SaveData data, DayClock clock, Inventory inventory, FarmSystem farm,
        SquadRoster? squad = null, TreatWoundsSystem? treatWounds = null,
        TerritorySystem? territory = null)
    {
        clock.RestoreState(data.Clock.MinuteOfDay, data.Clock.Day, data.Clock.Season, data.Clock.Year);

        inventory.LoadFrom(data.Inventory);

        farm.LoadPlots(data.Plots.Select(p => new Plot
        {
            Tile = new Vector2I(p.X, p.Y),
            Stage = p.Stage,
            CropId = p.CropId,
            DaysGrown = p.DaysGrown,
            WateredToday = p.WateredToday,
        }));

        // v1 saves carry no squad section — the freshly built presets stand as-is.
        if (squad != null && data.Squad != null)
            squad.RestoreMembers(data.Squad);

        // Additive field: null in pre-Treat-Wounds saves — restore clears to "no one immune".
        treatWounds?.RestoreImmunities(data.TreatWoundsImmunities);

        // Additive field: null in pre-M3 saves — restore clears to fresh territory state.
        territory?.RestoreState(data.Territory);
    }
}
