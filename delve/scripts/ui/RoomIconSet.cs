using Godot;

namespace Delve.UI;

/// <summary>The crawl's room icons by key ("fight", "refuge", "unknown"...), shared by the floor plan
/// and the doorway signs so the two always agree.</summary>
[GlobalClass]
public partial class RoomIconSet : Resource
{
    [Export] public Texture2D Entrance { get; set; } = null!;
    [Export] public Texture2D Fight { get; set; } = null!;
    [Export] public Texture2D Event { get; set; } = null!;
    [Export] public Texture2D Lair { get; set; } = null!;
    [Export] public Texture2D Wayfarer { get; set; } = null!;
    [Export] public Texture2D Refuge { get; set; } = null!;
    [Export] public Texture2D Guardian { get; set; } = null!;
    [Export] public Texture2D Unknown { get; set; } = null!;

    /// <summary>The icon for a key from <c>FloorPlan.IconKey</c>; anything else reads as unknown.</summary>
    public Texture2D For(string key) => key switch
    {
        "entrance" => Entrance,
        "fight" => Fight,
        "lair" => Lair,
        "wayfarer" => Wayfarer,
        "refuge" => Refuge,
        "guardian" => Guardian,
        "event" => Event,
        _ => Unknown,
    };
}
