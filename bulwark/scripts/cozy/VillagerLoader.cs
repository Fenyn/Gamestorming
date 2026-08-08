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
/// instances that, otherwise it drops a bare placeholder Node3D so the arrival is still tracked and
/// positioned while art is authored later.
///
/// Fully null-safe: a villager with no marker (and no associated building marker) is skipped with a
/// log line. DIALOGUE / schedules / interaction are OUT OF SCOPE this phase — a later system. With
/// the shipped villager catalog empty, this places nothing. Placement re-runs per villager on
/// VillagerArrived (idempotent — an already-placed NPC is not duplicated).
/// </summary>
public sealed class VillagerLoader
{
    /// <summary>The generic, data-driven NPC scene every villager is instanced from (appearance and
    /// identity come from <see cref="VillagerNpc.Setup"/>, not per-character scenes).</summary>
    private const string NpcScenePath = "res://scenes/cozy/npc.tscn";

    private readonly Node3D _host;
    private readonly Func<string, bool> _hasArrived;
    private readonly List<VillagerDefinition> _catalog;
    private readonly HashSet<string> _residentIds = new();
    private readonly Dictionary<string, Node3D> _placed = new();
    private readonly Func<string, bool>? _isWanderSuppressed;
    private readonly Func<int>? _currentMinuteOfDay;

    /// <summary>The schedule marker name each placed NPC is currently anchored at (its own
    /// <c>Villager_&lt;id&gt;</c> home marker when no schedule slot applies). Drives change detection in
    /// <see cref="ApplySchedules"/> so a re-anchor (and its commute) only fires when the slot flips.</summary>
    private readonly Dictionary<string, string> _anchoredMarker = new();

    /// <summary>Schedule markers already warned-about (missing at runtime) so the warning fires once.</summary>
    private readonly HashSet<string> _warnedMissingMarker = new();

    /// <param name="host">Scene the villager markers live under (the outpost Node3D).</param>
    /// <param name="hasArrived">Whether a villager id has arrived (GameState.IsVillagerArrived).</param>
    /// <param name="catalog">Arrival-gated villager set to place; defaults to the shipped
    /// <see cref="Villagers.All"/>.</param>
    /// <param name="residents">Always-present villagers (the non-player starting party — Tharr, Elara,
    /// Fenwick) placed unconditionally from day one, OUTSIDE the arrival flow. Added to the catalog and
    /// treated as permanently present so <see cref="Refresh"/> and <see cref="NearestVillagerId"/> pick
    /// them up without ever consulting <paramref name="hasArrived"/>.</param>
    /// <param name="isWanderSuppressed">Per-villager-id predicate the host scene supplies to gate
    /// <see cref="VillagerNpc"/> wander (dialogue/modal open, a cutscene playing, or that id being the
    /// active talk target) — forwarded read-only to each spawned NPC via
    /// <see cref="VillagerNpc.SetWanderSuppression"/>; this loader has no opinion on WHAT suppresses
    /// wander, only that it can. Null (default) means wander is never suppressed (F6/spike runs).</param>
    /// <param name="currentMinuteOfDay">Reads the day clock's current minute-of-day, used to resolve
    /// each villager's schedule anchor (see <see cref="Schedules"/>). NPCs spawn DIRECTLY on the current
    /// slot's anchor (no cross-map walk on scene entry / save load), and the host calls
    /// <see cref="ApplySchedules"/> on each minute change to re-anchor them. Null (default) disables
    /// schedules entirely — every NPC just spawns and wanders at its home marker (F6/spike runs).</param>
    public VillagerLoader(
        Node3D host,
        Func<string, bool> hasArrived,
        IEnumerable<VillagerDefinition>? catalog = null,
        IEnumerable<VillagerDefinition>? residents = null,
        Func<string, bool>? isWanderSuppressed = null,
        Func<int>? currentMinuteOfDay = null)
    {
        _host = host ?? throw new ArgumentNullException(nameof(host));
        _hasArrived = hasArrived ?? throw new ArgumentNullException(nameof(hasArrived));
        _catalog = catalog != null ? new List<VillagerDefinition>(catalog) : new List<VillagerDefinition>(Villagers.All);
        _isWanderSuppressed = isWanderSuppressed;
        _currentMinuteOfDay = currentMinuteOfDay;
        if (residents != null)
            foreach (var r in residents)
            {
                _catalog.Add(r);
                _residentIds.Add(r.Id);
            }
    }

    /// <summary>Place an NPC for every villager that is currently present — every arrived villager AND
    /// every always-present resident (call once on scene ready).</summary>
    public void PlaceArrived()
    {
        foreach (var def in _catalog)
            Refresh(def.Id);
    }

    /// <summary>A villager is present (and thus placeable/talkable) when it is an always-present
    /// resident, or its arrival trigger has fired.</summary>
    private bool IsPresent(string id) => _residentIds.Contains(id) || _hasArrived(id);

    /// <summary>
    /// Ensure one villager's NPC exists if it is present: spawn it at its marker (once). A
    /// not-yet-present villager is left unplaced. Safe to call repeatedly (idempotent) and safe when
    /// the marker or scene is absent.
    /// </summary>
    public void Refresh(string id)
    {
        VillagerDefinition? def = null;
        foreach (var d in _catalog)
            if (d.Id == id) { def = d; break; }
        if (def == null || !IsPresent(id))
            return;

        if (_placed.TryGetValue(id, out var existing) && GodotObject.IsInstanceValid(existing))
            return; // already placed

        var inst = InstanceVillager(def);
        if (inst != null)
            _placed[id] = inst;
    }

    private Node3D? InstanceVillager(VillagerDefinition def)
    {
        Marker3D? marker = FindMarker(def);
        if (marker == null)
        {
            GD.Print($"[VillagerLoader] No %{def.MarkerName} marker (or associated building) — skipping {def.Id} NPC.");
            return null;
        }

        // Preferred override: a hand-authored per-villager scene, self-configured (none ship today).
        if (ResourceLoader.Exists(def.ScenePath)
            && GD.Load<PackedScene>(def.ScenePath)?.InstantiateOrNull<Node3D>() is { } premade)
        {
            premade.Name = $"{def.MarkerName}Instance";
            _host.AddChild(premade);
            premade.GlobalPosition = marker.GlobalPosition;
            return premade;
        }

        // Default: the generic data-driven NPC scene — each villager is its own entity, configured
        // from villager data via VillagerNpc.Setup (dynamic child per the project's instancing convention).
        if (GD.Load<PackedScene>(NpcScenePath)?.InstantiateOrNull<VillagerNpc>() is { } npc)
        {
            _host.AddChild(npc);

            // Schedule-aware spawn: place DIRECTLY at the current slot's anchor (no walk on scene entry
            // / save load). With no schedule (or before the first slot, or a missing spot marker) this
            // falls back to the villager's own home marker — byte-identical to the pre-schedule behavior.
            string anchorName = CurrentAnchorName(def);
            Node3D? anchorNode = ResolveSpot(anchorName);
            npc.Setup(def.Id, def.SpriteId, (anchorNode ?? marker).GlobalPosition);
            _anchoredMarker[def.Id] = anchorNode != null ? anchorName : def.MarkerName;

            if (_isWanderSuppressed != null)
                npc.SetWanderSuppression(() => _isWanderSuppressed(def.Id));
            return npc;
        }

        // Last resort: a bare node so the villager is still tracked/positioned if the scene is missing.
        var bare = new Node3D { Name = $"{def.MarkerName}Instance" };
        _host.AddChild(bare);
        bare.GlobalPosition = marker.GlobalPosition;
        GD.Print($"[VillagerLoader] {NpcScenePath} missing/invalid — placed a bare node for {def.Id}.");
        return bare;
    }

    /// <summary>The spawned world node for a present villager, or null when it isn't placed (not
    /// present, or its marker/scene was missing). The cutscene director uses this to stage a resident
    /// actor (hide/reveal/walk-in) against its real instance during the arrival cutscene.</summary>
    public Node3D? GetPlaced(string id)
        => _placed.TryGetValue(id, out var node) && GodotObject.IsInstanceValid(node) ? node : null;

    /// <summary>
    /// The placed villager NPC nearest to <paramref name="worldPos"/> within
    /// <paramref name="maxDistance"/> METRES, or null when none is in range — the proximity query
    /// the talk/gift interactions use ("E on/near the villager"). Only PRESENT (arrived or
    /// always-present resident), actually-placed NPCs are considered.
    /// </summary>
    public string? NearestVillagerId(Vector3 worldPos, float maxDistance)
    {
        string? best = null;
        float bestDistance = maxDistance;
        foreach (var (id, node) in _placed)
        {
            if (!GodotObject.IsInstanceValid(node) || !IsPresent(id))
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

    // ------------------------------------------------------------------ Schedules (time-slot routines)

    /// <summary>
    /// Re-anchor every placed NPC to its schedule slot for <paramref name="minuteOfDay"/> — call on each
    /// game-minute change (and day start). When a villager's resolved anchor marker CHANGES, resolves the
    /// marker node and hands its world position to <see cref="VillagerNpc.SetAnchor"/> (which commutes the
    /// NPC there); unchanged anchors are skipped, so this is cheap per minute. A villager with no schedule
    /// resolves to its home marker and, once anchored there, never moves — no behavior change. A missing
    /// marker warns once and keeps the previous anchor (never crashes). No-op when schedules are disabled
    /// (no clock reader wired, e.g. F6/spike runs).
    /// </summary>
    public void ApplySchedules(int minuteOfDay)
    {
        if (_currentMinuteOfDay == null)
            return;

        foreach (var (id, node) in _placed)
        {
            if (node is not VillagerNpc npc || !GodotObject.IsInstanceValid(npc))
                continue;

            string target = Schedules.ResolveMarker(id, minuteOfDay) ?? $"Villager_{id}";
            if (_anchoredMarker.TryGetValue(id, out var current) && current == target)
                continue;

            Node3D? spot = ResolveSpot(target);
            if (spot == null)
            {
                if (_warnedMissingMarker.Add(target))
                    GD.PushWarning($"[VillagerLoader] schedule marker %{target} for '{id}' not found — keeping previous anchor.");
                continue; // keep the previous anchor; retried next slot change if the marker later appears
            }

            npc.SetAnchor(spot.GlobalPosition);
            _anchoredMarker[id] = target;
        }
    }

    /// <summary>The schedule marker name that anchors <paramref name="def"/> right now — the current
    /// slot's marker, or the villager's home marker (no schedule / before the first slot / no clock).</summary>
    private string CurrentAnchorName(VillagerDefinition def)
    {
        int? minute = _currentMinuteOfDay?.Invoke();
        string? slot = minute.HasValue ? Schedules.ResolveMarker(def.Id, minute.Value) : null;
        return slot ?? def.MarkerName;
    }

    /// <summary>Resolve a schedule marker by name (%UniqueName, then a direct child name) — mirrors
    /// <see cref="FindMarker"/>'s lookup but returns any Node3D so a building instance could anchor too.</summary>
    private Node3D? ResolveSpot(string markerName)
        => _host.GetNodeOrNull<Node3D>($"%{markerName}") ?? _host.GetNodeOrNull<Node3D>(markerName);

    /// <summary>The villager's own marker, or — failing that — its associated building's marker.</summary>
    private Marker3D? FindMarker(VillagerDefinition def)
    {
        Marker3D? marker = _host.GetNodeOrNull<Marker3D>($"%{def.MarkerName}")
                           ?? _host.GetNodeOrNull<Marker3D>(def.MarkerName);
        if (marker != null || string.IsNullOrEmpty(def.AssociatedBuildingId))
            return marker;

        string buildingMarker = $"Building_{def.AssociatedBuildingId}";
        return _host.GetNodeOrNull<Marker3D>($"%{buildingMarker}")
               ?? _host.GetNodeOrNull<Marker3D>(buildingMarker);
    }
}
