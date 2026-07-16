using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Thin adapter script for a premade building scene (scenes/buildings/&lt;id&gt;.tscn). Holds no game
/// logic — the <see cref="BuildingLoader"/> instances it at the building's <c>%Building_&lt;id&gt;</c>
/// marker and calls <see cref="Apply"/> to show the visual stage/scaffold/overlays for the current
/// state (design/building_visuals.md).
///
/// AUTHORING CONTRACT (the loader relies on these node names — all but %Stages/%Footprint optional):
///  • <c>%Stages</c> — a container whose children are the visual STAGES in order. Child 0 = the
///    ruined/site look; children 1..N = the evolving restored art for tiers 1..N (or a story-override
///    index — story stages are addressed by index like any other). Exactly one is shown at a time;
///    the rest are hidden. Replace the placeholder ColorRects with real Sprite2D art — only the
///    child ORDER matters.
///  • <c>%Scaffold</c> — (optional) shown INSTEAD of any stage while the building is under
///    construction (commission or upgrade); hidden otherwise.
///  • <c>%Overlays</c> — (optional) zero or more children shown by Name, additive on top of the
///    active stage (season/event/story dressing — see <see cref="BuildingVisualState"/>).
///  • <c>%Footprint</c> — a StaticBody2D + CollisionShape2D that blocks the building's tiles. Shared
///    across every stage — always active, never toggled here.
///  • <c>%Interact</c> — a Marker2D anchor for a future diegetic interaction point (unused this phase).
/// A stage/scaffold that changes the building's OUTLINE may carry its own collision shapes
/// (CollisionShape2D/CollisionPolygon2D anywhere under it) — <see cref="Apply"/> disables them under
/// a hidden stage/scaffold (hidden CanvasItems still collide in Godot; this is the explicit fix).
/// Unique collision shapes per node, never shared sub_resources.
/// </summary>
public partial class BuildingInstance : Node2D
{
    /// <summary>
    /// Resolve the full visual state in one call: scaffold-vs-stage, per-stage/scaffold collision,
    /// and overlay visibility. Null-safe on every container — a scene missing %Scaffold/%Overlays
    /// simply never shows one (the user authors that art later).
    /// </summary>
    /// <param name="stageIndex">The %Stages child index to show (ignored while scaffolded).</param>
    /// <param name="underConstruction">True while the building's commission/upgrade construction
    /// window is active. When true AND a %Scaffold node exists, the scaffold shows and every stage
    /// hides; otherwise the stage at <paramref name="stageIndex"/> shows as normal (including when
    /// underConstruction is true but no %Scaffold exists — nothing to swap to).</param>
    /// <param name="overlayKeys">Active overlay keys this frame — an %Overlays child is visible iff
    /// its Name is in this set.</param>
    public void Apply(int stageIndex, bool underConstruction, IReadOnlyCollection<string> overlayKeys)
    {
        var stages = GetNodeOrNull<Node>("%Stages");
        var scaffold = GetNodeOrNull<Node>("%Scaffold");
        bool showScaffold = underConstruction && scaffold != null;

        if (stages != null)
        {
            int i = 0;
            foreach (Node child in stages.GetChildren())
            {
                SetVisibleAndCollision(child, !showScaffold && i == stageIndex);
                i++;
            }
        }

        if (scaffold != null)
            SetVisibleAndCollision(scaffold, showScaffold);

        var overlays = GetNodeOrNull<Node>("%Overlays");
        if (overlays != null)
        {
            foreach (Node child in overlays.GetChildren())
                if (child is CanvasItem ci)
                    ci.Visible = overlayKeys.Contains(child.Name.ToString());
        }
    }

    /// <summary>Compat wrapper for the pre-Apply call shape: shows only the stage at
    /// <paramref name="stageIndex"/>, no scaffold, no overlays. Other code/spikes may still call
    /// this directly.</summary>
    public void SetStage(int stageIndex) => Apply(stageIndex, false, Array.Empty<string>());

    /// <summary>Toggle a stage/scaffold subtree's own visibility AND disable collision under every
    /// CollisionShape2D/CollisionPolygon2D descendant when hidden (hidden CanvasItems still collide
    /// in Godot — this is the explicit fix). The shared %Footprint is never passed here.</summary>
    private static void SetVisibleAndCollision(Node root, bool visible)
    {
        if (root is CanvasItem ci)
            ci.Visible = visible;

        foreach (Node descendant in Descendants(root))
        {
            switch (descendant)
            {
                case CollisionShape2D shape:
                    shape.Disabled = !visible;
                    break;
                case CollisionPolygon2D poly:
                    poly.Disabled = !visible;
                    break;
            }
        }
    }

    private static IEnumerable<Node> Descendants(Node node)
    {
        foreach (Node child in node.GetChildren())
        {
            yield return child;
            foreach (Node grandchild in Descendants(child))
                yield return grandchild;
        }
    }
}
