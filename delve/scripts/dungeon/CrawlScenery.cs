using System;
using Godot;

namespace Delve.Dungeon;

/// <summary>How one floor's crawl is dressed: its room prefabs, lighting setup, what joins the rooms,
/// the ground under the gaps, and how the rooms around the party are lit. One .tres per floor in
/// scenes/dungeon/crawls/, picked by the floor's id.</summary>
[GlobalClass]
public partial class CrawlScenery : Resource
{
    /// <summary>One prefab per <see cref="RoomPurpose"/>, in enum order.</summary>
    [Export] public PackedScene[] PurposePrefabs { get; set; } = Array.Empty<PackedScene>();

    [Export] public PackedScene? Look { get; set; }

    /// <summary>Scene whose root implements <see cref="IPassage"/>; one joins each pair of doors.</summary>
    [Export] public PackedScene? Passage { get; set; }

    /// <summary>Ground plane drawn under the gaps between rooms.</summary>
    [Export] public Material? VoidMaterial { get; set; }

    /// <summary>Brightness of the room the party stands in, of rooms already visited, and of unvisited
    /// neighbours.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float CurrentLight { get; set; } = 1f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float ExploredLight { get; set; } = 1f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float UnexploredLight { get; set; } = 1f;

    /// <summary>Draw every visited room, not only the current room's neighbours.</summary>
    [Export] public bool ShowExplored { get; set; }

    /// <summary>Draw unvisited neighbours of the current room, at <see cref="UnexploredLight"/>.</summary>
    [Export] public bool ShowUnexplored { get; set; }

    /// <summary>Seconds a room takes to brighten or dim when the party moves.</summary>
    [Export] public double LightSeconds { get; set; } = 0.5;

    /// <summary>Passage scene that carries the arrival trail off the floor from the entrance's outer
    /// mouth, <see cref="ArrivalTrailLength"/> tiles past the room's margin. Unset, nothing is drawn
    /// past the arrival prop.</summary>
    [Export] public PackedScene? ArrivalTrail { get; set; }
    [Export] public int ArrivalTrailLength { get; set; } = 6;

    /// <summary>Where the party starts its walk in: metres out from the entrance's outer mouth, and
    /// metres above the floor there (the top of a stair).</summary>
    [Export] public float ArrivalReach { get; set; } = 5f;
    [Export] public float ArrivalRise { get; set; }
}
