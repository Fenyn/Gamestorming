using System.Collections.Generic;
using System.Linq;
using Bulwark.Territory;
using Godot;

using Bulwark.Cozy;
using Bulwark.Quests;
using Bulwark.Dialogue;
namespace Bulwark.Save;

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
        TerritorySystem? territory = null, Wallet? wallet = null,
        BuildingSystem? buildings = null,
        StoryFlags? storyFlags = null, VillagerSystem? villagers = null,
        MealSystem? meals = null,
        string? playerName = null,
        FriendshipSystem? friendship = null,
        DialogueSession? dialogue = null,
        QuestLog? questLog = null,
        ForageSystem? forage = null,
        int worldSeed = 0)
    {
        return new SaveData
        {
            PlayerName = playerName,
            WorldSeed = worldSeed,
            Clock = new ClockDto
            {
                MinuteOfDay = clock.MinuteOfDay,
                Day = clock.Day,
                Season = clock.Season,
                Year = clock.Year,
            },
            MemberInventories = inventory.CaptureMemberInventories(),
            Warehouse = inventory.CaptureWarehouse(),
            Gold = wallet?.Gold ?? 0,
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
            Buildings = buildings?.Capture(),
            StoryFlags = storyFlags?.Capture(),
            ArrivedVillagers = villagers?.Capture(),
            ActiveMeal = meals?.Capture(),
            Friendship = friendship?.Capture(),
            SeenDialogueIds = dialogue != null ? new List<string>(dialogue.Seen) : null,
            Quests = questLog?.Capture(),
            Forage = forage?.Capture(),
        };
    }

    /// <summary>Overwrite the live systems from a DTO.</summary>
    public static void Restore(
        SaveData data, DayClock clock, Inventory inventory, FarmSystem farm,
        SquadRoster? squad = null, TreatWoundsSystem? treatWounds = null,
        TerritorySystem? territory = null, Wallet? wallet = null,
        BuildingSystem? buildings = null,
        StoryFlags? storyFlags = null, VillagerSystem? villagers = null,
        MealSystem? meals = null,
        FriendshipSystem? friendship = null,
        DialogueSession? dialogue = null,
        QuestLog? questLog = null,
        ForageSystem? forage = null)
    {
        clock.RestoreState(data.Clock.MinuteOfDay, data.Clock.Day, data.Clock.Season, data.Clock.Year);

        // v3+ persists per-member carry + warehouse; pre-v3 saves carry only the flat pool, which
        // is distributed across members (bound) or dropped into the warehouse (unbound) on migration.
        if (data.MemberInventories != null || data.Warehouse != null)
            inventory.LoadState(data.MemberInventories, data.Warehouse);
        else
            inventory.LoadFrom(data.Inventory);

        // Additive field: 0 in pre-economy saves — restore sets the balance to 0 cleanly.
        wallet?.LoadFrom(data.Gold);

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
            squad.RestoreMembers(data.Squad, data.PlayerName);

        // Additive field: null in pre-Treat-Wounds saves — restore clears to "no one immune".
        treatWounds?.RestoreImmunities(data.TreatWoundsImmunities);

        // Additive field: null in pre-M3 saves — restore clears to fresh territory state.
        territory?.RestoreState(data.Territory);

        // Additive field: null in pre-v4 saves — restore resets buildings to not-commissioned.
        buildings?.Restore(data.Buildings);

        // Additive fields: null in pre-v5 saves — restore clears flags and arrivals. GameState
        // re-runs villager EvaluateArrivals after this so any now-satisfied trigger catches up.
        storyFlags?.Restore(data.StoryFlags);
        villagers?.Restore(data.ArrivedVillagers);

        // Additive field: null in pre-v6 saves / no active meal — restore clears the buff. Re-applies
        // to the roster's live instances (rebuilt fresh by RestoreMembers above), so the buff is live.
        meals?.Restore(data.ActiveMeal);

        // Additive field: null in pre-v8 saves — restore clears to zero friendship. Silent (no
        // threshold re-fires); GameState recomputes the effect aggregator after this so earned
        // heart perks/unlocks re-derive from the restored fired set. Runs after the clock restore
        // above so the daily/weekly counters reconcile against the loaded calendar.
        friendship?.Restore(data.Friendship);

        // Additive field: null in pre-v9 saves — DialogueSession.Restore clears to "nothing seen".
        dialogue?.Restore(data.SeenDialogueIds);

        // Additive field: null in pre-v11 saves — restore clears to "no quests started".
        questLog?.Restore(data.Quests);

        // Additive field: null in pre-v12 saves — restore clears to "no forage yet"; the first
        // territory visit then catches up deterministically from day 1. The caller (GameState)
        // sets the world seed on the system BEFORE this restore.
        forage?.Restore(data.Forage);
    }
}
