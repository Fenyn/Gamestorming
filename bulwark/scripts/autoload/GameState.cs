using System;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.Autoload;

/// <summary>
/// The single authoritative mutable state root. Thin Node adapter per CLAUDE.md: it hosts the plain
/// C# game systems (<see cref="DayClock"/>, <see cref="Inventory"/>, <see cref="FarmSystem"/>),
/// ticks the clock each frame, wires their events up as a single subscription hub for UI/world
/// scenes, and owns the file-path side of save/load. All mutation goes through intent-named command
/// methods that validate and let the systems raise change events — UI never mutates directly.
/// </summary>
public partial class GameState : Node
{
    public static GameState Instance { get; private set; } = null!;

    private const string SaveDir = "user://save";
    private const string SavePath = "user://save/slot0.json";

    /// <summary>Real seconds per in-game minute (fed to <see cref="DayClock"/>). ~15 real min/day at 0.75.</summary>
    [Export] public double RealSecondsPerGameMinute { get; set; } = 0.75;

    // --- Owned systems ---
    public DayClock Clock { get; private set; } = null!;
    public Inventory Inventory { get; private set; } = null!;
    public FarmSystem Farm { get; private set; } = null!;

    /// <summary>Set when the player collapsed at 2 AM instead of sleeping voluntarily (see M3 TODO in DoSleep).</summary>
    public bool CollapsedLastNight { get; private set; }

    // --- Event hub (UI/world subscribe here; systems remain the source of truth) ---
    public event Action? MinuteChanged;
    public event Action? HourChanged;
    public event Action? DayStarted;
    public event Action<Vector2I>? PlotChanged;
    public event Action<string>? InventoryChanged;

    /// <summary>Raised after a save file is loaded (initial autoload or explicit LoadGame).</summary>
    public event Action? GameLoaded;

    public override void _Ready()
    {
        Instance = this;

        Clock = new DayClock { RealSecondsPerGameMinute = RealSecondsPerGameMinute };
        Inventory = new Inventory();
        Farm = new FarmSystem(Inventory, () => Clock.Season);

        // Re-expose system events through the hub.
        Clock.MinuteChanged += () => MinuteChanged?.Invoke();
        Clock.HourChanged += () => HourChanged?.Invoke();
        Clock.DayStarted += () => DayStarted?.Invoke();
        Clock.DayEnded += OnClockDayEnded;
        Farm.PlotChanged += tile => PlotChanged?.Invoke(tile);
        Inventory.InventoryChanged += id => InventoryChanged?.Invoke(id);

        if (SaveExists())
            LoadGame();
        else
            SeedStarterInventory();
    }

    public override void _Process(double delta)
    {
        Clock.Tick(delta); // no-op while paused (SceneRouter pauses during combat)
    }

    // ===================== Commands (validate → delegate → systems raise events) =====================

    public bool TillPlot(Vector2I tile) => Farm.TillPlot(tile);
    public bool PlantCrop(Vector2I tile, string cropId) => Farm.PlantCrop(tile, cropId);
    public bool WaterPlot(Vector2I tile) => Farm.WaterPlot(tile);
    public bool HarvestPlot(Vector2I tile) => Farm.HarvestPlot(tile);

    public void AddItem(string itemId, int qty) => Inventory.AddItem(itemId, qty);
    public bool RemoveItem(string itemId, int qty) => Inventory.RemoveItem(itemId, qty);

    /// <summary>Voluntary sleep at the outpost: resolve overnight growth, advance the day, save.</summary>
    public void Sleep() => DoSleep(collapsed: false);

    // ===================== Save / load =====================

    public bool SaveExists() => Godot.FileAccess.FileExists(SavePath);

    /// <summary>Serialize all persisted state to <c>user://save/slot0.json</c>.</summary>
    public void SaveGame()
    {
        var data = SaveState.Capture(Clock, Inventory, Farm, CollapsedLastNight);
        string json = SaveSerializer.Serialize(data);

        DirAccess.MakeDirRecursiveAbsolute(SaveDir);
        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
        if (file == null)
        {
            GD.PushError($"[GameState] Could not open save file: {Godot.FileAccess.GetOpenError()}");
            return;
        }
        file.StoreString(json);
    }

    /// <summary>Load persisted state from disk. No-op if no save exists.</summary>
    public void LoadGame()
    {
        if (!SaveExists())
            return;

        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError($"[GameState] Could not read save file: {Godot.FileAccess.GetOpenError()}");
            return;
        }

        var data = SaveSerializer.Deserialize(file.GetAsText());
        if (data == null)
        {
            GD.PushError("[GameState] Save file could not be parsed.");
            return;
        }

        CollapsedLastNight = SaveState.Restore(data, Clock, Inventory, Farm);
        GameLoaded?.Invoke();
    }

    // ===================== Internals =====================

    private void OnClockDayEnded()
    {
        // Player was still out when the day ended at 2 AM — force a collapse-sleep.
        DoSleep(collapsed: true);
    }

    private void DoSleep(bool collapsed)
    {
        CollapsedLastNight = collapsed;

        // Order matters: overnight growth resolves for the day just played BEFORE the calendar
        // advances, so watered crops "grow overnight". Then start the new day, then persist it.
        Farm.OnDayEnded();
        Clock.StartNextDay();
        SaveGame();

        // TODO (M3): when the squad exists outside combat, a collapse should apply the engine
        // Fatigued condition to each squad member for tomorrow's fights. CollapsedLastNight is the
        // flag that will drive it; nothing consumes it yet.
    }

    private void SeedStarterInventory()
    {
        Inventory.AddItem(Items.TurnipSeed.Id, 5);
        Inventory.AddItem(Items.PotatoSeed.Id, 3);
        Inventory.AddItem(Items.Wood.Id, 10);
        Inventory.AddItem(Items.Stone.Id, 10);
    }
}
