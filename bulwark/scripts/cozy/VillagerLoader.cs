using System;
using System.Collections.Generic;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Places an NPC node into a walkable world scene (the outpost) for each ARRIVED villager — the
/// framework mirror of <see cref="BuildingLoader"/>. For each arrived villager it spawns a node at
/// the user-placed <c>%Villager_&lt;id&gt;</c> marker (falling back to the associated building's
/// <c>%Building_&lt;id&gt;</c> marker); if a premade <c>scenes/villagers/&lt;id&gt;.tscn</c> exists it
/// instances that, otherwise it drops a bare placeholder Node2D so the arrival is visible while art
/// is authored later.
///
/// Fully null-safe: a villager with no marker (and no associated building marker) is skipped with a
/// log line. DIALOGUE / schedules / interaction are OUT OF SCOPE this phase — a later system. With
/// the shipped villager catalog empty, this places nothing. Placement re-runs per villager on
/// VillagerArrived (idempotent — an already-placed NPC is not duplicated).
/// </summary>
public sealed class VillagerLoader
{
    private readonly Node2D _host;
    private readonly Func<string, bool> _hasArrived;
    private readonly IReadOnlyList<VillagerDefinition> _catalog;
    private readonly Dictionary<string, Node2D> _placed = new();

    /// <param name="host">Scene the villager markers live under (the outpost Node2D).</param>
    /// <param name="hasArrived">Whether a villager id has arrived (GameState.IsVillagerArrived).</param>
    /// <param name="catalog">Villager set to place; defaults to the shipped <see cref="Villagers.All"/>.</param>
    public VillagerLoader(Node2D host, Func<string, bool> hasArrived, IEnumerable<VillagerDefinition>? catalog = null)
    {
        _host = host ?? throw new ArgumentNullException(nameof(host));
        _hasArrived = hasArrived ?? throw new ArgumentNullException(nameof(hasArrived));
        _catalog = catalog != null ? new List<VillagerDefinition>(catalog) : new List<VillagerDefinition>(Villagers.All);
    }

    /// <summary>Place an NPC for every arrived villager (call once on scene ready).</summary>
    public void PlaceArrived()
    {
        foreach (var def in _catalog)
            Refresh(def.Id);
    }

    /// <summary>
    /// Ensure one villager's NPC exists if it has arrived: spawn it at its marker (once). A
    /// not-yet-arrived villager is left unplaced. Safe to call repeatedly (idempotent) and safe when
    /// the marker or scene is absent.
    /// </summary>
    public void Refresh(string id)
    {
        VillagerDefinition? def = null;
        foreach (var d in _catalog)
            if (d.Id == id) { def = d; break; }
        if (def == null || !_hasArrived(id))
            return;

        if (_placed.TryGetValue(id, out var existing) && GodotObject.IsInstanceValid(existing))
            return; // already placed

        var inst = InstanceVillager(def);
        if (inst != null)
            _placed[id] = inst;
    }

    private Node2D? InstanceVillager(VillagerDefinition def)
    {
        Marker2D? marker = FindMarker(def);
        if (marker == null)
        {
            GD.Print($"[VillagerLoader] No %{def.MarkerName} marker (or associated building) — skipping {def.Id} NPC.");
            return null;
        }

        Node2D inst;
        if (ResourceLoader.Exists(def.ScenePath)
            && GD.Load<PackedScene>(def.ScenePath)?.InstantiateOrNull<Node2D>() is { } scene)
        {
            inst = scene;
        }
        else
        {
            // Placeholder NPC — real villager art + dialogue arrive in a later system.
            inst = new Node2D();
        }

        inst.Name = $"{def.MarkerName}Instance";
        _host.AddChild(inst);
        inst.GlobalPosition = marker.GlobalPosition;
        return inst;
    }

    /// <summary>
    /// The placed villager NPC nearest to <paramref name="worldPos"/> within
    /// <paramref name="maxDistance"/> pixels, or null when none is in range — the proximity query
    /// the talk/gift interactions use ("E on/near the villager"). Only ARRIVED, actually-placed
    /// NPCs are considered.
    /// </summary>
    public string? NearestVillagerId(Vector2 worldPos, float maxDistance)
    {
        string? best = null;
        float bestDistance = maxDistance;
        foreach (var (id, node) in _placed)
        {
            if (!GodotObject.IsInstanceValid(node) || !_hasArrived(id))
                continue;
            float distance = node.GlobalPosition.DistanceTo(worldPos);
            if (distance <= bestDistance)
            {
                bestDistance = distance;
                best = id;
            }
        }
        return best;
    }

    /// <summary>The villager's own marker, or — failing that — its associated building's marker.</summary>
    private Marker2D? FindMarker(VillagerDefinition def)
    {
        Marker2D? marker = _host.GetNodeOrNull<Marker2D>($"%{def.MarkerName}")
                           ?? _host.GetNodeOrNull<Marker2D>(def.MarkerName);
        if (marker != null || string.IsNullOrEmpty(def.AssociatedBuildingId))
            return marker;

        string buildingMarker = $"Building_{def.AssociatedBuildingId}";
        return _host.GetNodeOrNull<Marker2D>($"%{buildingMarker}")
               ?? _host.GetNodeOrNull<Marker2D>(buildingMarker);
    }
}
