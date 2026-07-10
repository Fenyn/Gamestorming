using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// Plain serializable snapshot of all persisted cozy-layer state. Flat DTO — no Godot types, no
/// behaviour — so <see cref="SaveSerializer"/> can round-trip it with System.Text.Json and only the
/// GameState adapter ever touches file paths.
/// </summary>
public sealed class SaveData
{
    /// <summary>Save schema version, bumped when the shape changes.</summary>
    public int Version { get; set; } = 1;

    public ClockDto Clock { get; set; } = new();

    /// <summary>Inventory stacks: item id → quantity.</summary>
    public Dictionary<string, int> Inventory { get; set; } = new();

    public List<PlotDto> Plots { get; set; } = new();

    public FlagsDto Flags { get; set; } = new();
}

/// <summary>Calendar + time-of-day snapshot.</summary>
public sealed class ClockDto
{
    public int MinuteOfDay { get; set; } = DayClock.DayStartMinute;
    public int Day { get; set; } = 1;
    public Season Season { get; set; } = Season.Spring;
    public int Year { get; set; } = 1;
}

/// <summary>One farm plot. Vector2I is flattened to X/Y so JSON stays engine-agnostic.</summary>
public sealed class PlotDto
{
    public int X { get; set; }
    public int Y { get; set; }
    public PlotStage Stage { get; set; }
    public string? CropId { get; set; }
    public int DaysGrown { get; set; }
    public bool WateredToday { get; set; }
}

/// <summary>Persistent game flags.</summary>
public sealed class FlagsDto
{
    /// <summary>Set when the player collapsed at 2 AM instead of sleeping voluntarily.</summary>
    public bool CollapsedLastNight { get; set; }
}
