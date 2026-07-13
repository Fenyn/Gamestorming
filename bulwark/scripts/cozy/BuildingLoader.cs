using System;
using System.Collections.Generic;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Places commissioned buildings into a walkable world scene (the outpost). For each COMMISSIONED
/// building it instances the premade <c>scenes/buildings/&lt;id&gt;.tscn</c> at the user-placed
/// <c>%Building_&lt;id&gt;</c> marker, drives its visible stage from the building's current tier, and
/// lets the scene's own StaticBody2D footprint block the tiles (buildings are instanced, not
/// painted, so they bring their own collision — consistent with CozyWorldScene's baked collision).
///
/// Fully null-safe: a missing marker or a missing/incompatible building scene is skipped with a log
/// line (the build STATE still works; the art arrives later). Placement re-runs per building on
/// BuildingChanged, so a just-commissioned building appears and an upgrade swaps its stage in place.
///
/// Decoupled from GameState (takes a tier-lookup delegate) so it is exercisable in a headless,
/// no-outpost spike context.
/// </summary>
public sealed class BuildingLoader
{
    private readonly Node2D _host;
    private readonly Func<string, int> _tierOf;
    private readonly Dictionary<string, BuildingInstance> _placed = new();

    /// <param name="host">Scene the buildings + markers live under (the outpost Node2D).</param>
    /// <param name="tierOf">Current tier of a building id (0 = not commissioned).</param>
    public BuildingLoader(Node2D host, Func<string, int> tierOf)
    {
        _host = host ?? throw new ArgumentNullException(nameof(host));
        _tierOf = tierOf ?? throw new ArgumentNullException(nameof(tierOf));
    }

    /// <summary>Place/refresh every commissioned building (call once on scene ready).</summary>
    public void PlaceCommissioned()
    {
        foreach (var def in Buildings.All)
            Refresh(def.Id);
    }

    /// <summary>
    /// Ensure one building's visual matches its state: instance it if newly commissioned, then select
    /// the stage for its current tier. A not-commissioned building is left unplaced. Safe to call
    /// repeatedly (idempotent) and safe when the marker or scene is absent.
    /// </summary>
    public void Refresh(string id)
    {
        if (!Buildings.TryGet(id, out var def))
            return;

        int tier = _tierOf(id);
        if (tier <= 0)
            return; // not commissioned yet — nothing to show

        if (!_placed.TryGetValue(id, out var inst) || !GodotObject.IsInstanceValid(inst))
        {
            inst = InstanceBuilding(def);
            if (inst == null)
                return; // missing marker/scene — state still works, art arrives later
            _placed[id] = inst;
        }

        inst.SetStage(def.StageIndexForTier(tier));
    }

    private BuildingInstance? InstanceBuilding(BuildingDefinition def)
    {
        Marker2D? marker = _host.GetNodeOrNull<Marker2D>($"%{def.MarkerName}")
                           ?? _host.GetNodeOrNull<Marker2D>(def.MarkerName);
        if (marker == null)
        {
            GD.Print($"[BuildingLoader] No %{def.MarkerName} marker in the scene — skipping {def.Id} visual.");
            return null;
        }

        if (!ResourceLoader.Exists(def.ScenePath))
        {
            GD.Print($"[BuildingLoader] Building scene {def.ScenePath} not found — skipping {def.Id} visual.");
            return null;
        }

        var packed = GD.Load<PackedScene>(def.ScenePath);
        var inst = packed?.InstantiateOrNull<BuildingInstance>();
        if (inst == null)
        {
            GD.Print($"[BuildingLoader] {def.ScenePath} root is not a BuildingInstance — skipping {def.Id}.");
            return null;
        }

        // Distinct from the marker's own name (they share a parent) to avoid a Godot auto-rename.
        inst.Name = $"{def.MarkerName}Instance";
        _host.AddChild(inst);
        inst.GlobalPosition = marker.GlobalPosition;
        return inst;
    }
}
