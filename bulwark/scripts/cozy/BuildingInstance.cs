using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Thin adapter script for a premade building scene (scenes/buildings/&lt;id&gt;.tscn). Holds no game
/// logic — the <see cref="BuildingLoader"/> instances it at the building's <c>%Building_&lt;id&gt;</c>
/// marker and calls <see cref="SetStage"/> to show the visual for the current tier.
///
/// AUTHORING CONTRACT (the loader relies on these node names):
///  • <c>%Stages</c> — a container whose children are the visual STAGES in order. Child 0 = the
///    ruined/site look; children 1..N = the evolving restored art for tiers 1..N. Exactly one is
///    shown at a time (see <see cref="SetStage"/>); the rest are hidden. Replace the placeholder
///    ColorRects with real Sprite2D art — only the child ORDER matters.
///  • <c>%Footprint</c> — a StaticBody2D + CollisionShape2D that blocks the building's tiles. It is
///    a real physics body, so it blocks the player exactly like the outpost's baked wall/water
///    collision (no tilemap painting needed — the building brings its own blocking).
///  • <c>%Interact</c> — a Marker2D anchor for a future diegetic interaction point (unused this phase).
/// </summary>
public partial class BuildingInstance : Node2D
{
    /// <summary>
    /// Show only the stage at <paramref name="stageIndex"/> under <c>%Stages</c> (all siblings
    /// hidden). Null-safe: a scene without the container simply renders whatever it has. The footprint
    /// stays active at every built stage.
    /// </summary>
    public void SetStage(int stageIndex)
    {
        var stages = GetNodeOrNull<Node>("%Stages");
        if (stages == null)
            return;

        int i = 0;
        foreach (Node child in stages.GetChildren())
        {
            if (child is CanvasItem ci)
                ci.Visible = i == stageIndex;
            i++;
        }
    }
}
