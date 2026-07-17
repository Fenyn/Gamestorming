using System;
using System.Collections.Generic;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Places every building that has either a PRE-PLACED instance or a marker + scene into a walkable
/// world scene (the outpost) — commissioned or not. Two placement strategies, tried in order per
/// building (design/building_authoring_guide.md):
///  1. PRE-PLACED (primary, per CLAUDE.md's "objects placed in .tscn via editor" convention): the
///     user instances <c>scenes/buildings/&lt;id&gt;.tscn</c> directly as a child of the outpost scene
///     and hand-positions it in the editor. The loader finds it by matching a child
///     <see cref="BuildingInstance"/>'s <see cref="Node.SceneFilePath"/> against
///     <see cref="BuildingDefinition.ScenePath"/> (robust to node renames — never matched by node
///     name) and ADOPTS it: tracks it, drives it via <see cref="BuildingInstance.Apply"/> exactly like
///     a spawned one, but NEVER repositions it (the user's placement is authoritative).
///  2. MARKER + INSTANTIATE (legacy fallback): if no pre-placed instance is found, the loader falls
///     back to instancing the premade scene at the user-placed <c>%Building_&lt;id&gt;</c> marker, as
///     before.
/// Either way it drives the placed instance's visible stage/scaffold/overlays from the building's
/// current state (design/building_visuals.md), and lets the scene's own StaticBody2D footprint block
/// the tiles (buildings bring their own collision — consistent with CozyWorldScene's baked collision).
/// A tier-0 (not-commissioned) building is placed too, showing its Stage0 ruined/site look — the
/// design intent is that a ruin is visible in the world from day one (the intro has Elara spotting the
/// collapsed trading post), not that the building appears only once commissioned.
///
/// Fully null-safe: a missing pre-placed instance AND a missing marker/scene is skipped with a log
/// line (the build STATE still works; the art arrives later). Placement re-runs per building on
/// BuildingChanged, so a just-commissioned building swaps off its ruin and an upgrade swaps its stage
/// in place. A driver-boundary event (day start, story-flag set) calls <see cref="RefreshAll"/> so
/// every building re-evaluates, not just the one whose tier/construction actually changed.
///
/// Decoupled from GameState (takes tier/construction/calendar/flag-lookup delegates) so it is
/// exercisable in a headless, no-outpost spike context. The three visual-state delegates are
/// OPTIONAL (default null): when any is absent, <see cref="Refresh"/> falls back to the original
/// plain tier→SetStage behavior — byte-identical to the pre-visual-stages system.
/// </summary>
public sealed class BuildingLoader
{
    private readonly Node2D _host;
    private readonly Func<string, int> _tierOf;
    private readonly Func<string, bool>? _isUnderConstruction;
    private readonly Func<(Season Season, int Day)>? _calendar;
    private readonly Func<string, bool>? _hasFlag;
    private readonly Dictionary<string, BuildingDefinition> _catalog;
    private readonly Dictionary<string, BuildingInstance> _placed = new();

    /// <param name="host">Scene the buildings + markers live under (the outpost Node2D).</param>
    /// <param name="tierOf">Current tier of a building id (0 = not commissioned).</param>
    /// <param name="isUnderConstruction">Optional: true while a building's construction window
    /// (commission or upgrade) is active. Null → back-compat fallback (see class remarks).</param>
    /// <param name="calendar">Optional: the current (season, dayOfSeason) — drives Window/Season
    /// overlay rules and the auto season key. Null → back-compat fallback.</param>
    /// <param name="hasFlag">Optional: story-flag query — drives Flag overlay/stage-override rules.
    /// Null → back-compat fallback.</param>
    /// <param name="catalog">The building set this loader places from. Null → the shipped
    /// <see cref="Buildings.All"/> registry (every production caller). A spike/test may pass its own
    /// definitions (mirrors <see cref="BuildingSystem"/>'s catalog seam) without touching the shared
    /// registry.</param>
    public BuildingLoader(
        Node2D host,
        Func<string, int> tierOf,
        Func<string, bool>? isUnderConstruction = null,
        Func<(Season Season, int Day)>? calendar = null,
        Func<string, bool>? hasFlag = null,
        IEnumerable<BuildingDefinition>? catalog = null)
    {
        _host = host ?? throw new ArgumentNullException(nameof(host));
        _tierOf = tierOf ?? throw new ArgumentNullException(nameof(tierOf));
        _isUnderConstruction = isUnderConstruction;
        _calendar = calendar;
        _hasFlag = hasFlag;
        _catalog = new Dictionary<string, BuildingDefinition>();
        foreach (var def in catalog ?? Buildings.All)
            _catalog[def.Id] = def;
    }

    /// <summary>Place/refresh every building with a marker + scene, commissioned or not (call once on
    /// scene ready). Tier-0 buildings place their ruined Stage0 look (design/building_visuals.md: a
    /// ruin is visible in the world from day one, not just after commission).</summary>
    public void PlaceAll() => RefreshAll();

    /// <summary>Back-compat alias for <see cref="PlaceAll"/> — same body, kept for existing callers
    /// written when only commissioned buildings were placed.</summary>
    public void PlaceCommissioned() => PlaceAll();

    /// <summary>
    /// Refresh every building's visual — call on any driver-boundary event (day start: season/window
    /// boundaries; story-flag set: override/overlay changes) so every building re-evaluates, not just
    /// the one whose own tier/construction state changed. Identical body to <see cref="PlaceAll"/>;
    /// named separately so a boundary-event handler reads as "refresh everything" rather than "place".
    /// </summary>
    public void RefreshAll()
    {
        foreach (var def in _catalog.Values)
            Refresh(def.Id);
    }

    /// <summary>
    /// Ensure one building's visual matches its state: instance it (at its marker) if not yet placed,
    /// then select the stage/scaffold/overlays for its current state. A tier-0 (not-commissioned)
    /// building is STILL placed and shown at Stage0 — the ruined/site look
    /// (design/building_visuals.md's authoring contract) — its %Footprint still blocks the tiles.
    /// Safe to call repeatedly (idempotent) and safe when the marker or scene is absent. An
    /// under-construction building (commission or upgrade) is placed and shows its scaffold, not
    /// skipped.
    /// </summary>
    public void Refresh(string id)
    {
        if (!_catalog.TryGetValue(id, out var def))
            return;

        int tier = _tierOf(id);

        if (!_placed.TryGetValue(id, out var inst) || !GodotObject.IsInstanceValid(inst))
        {
            inst = FindPrePlaced(def) ?? InstanceBuilding(def);
            if (inst == null)
                return; // no pre-placed instance and no marker/scene — state still works, art arrives later
            _placed[id] = inst;
        }

        if (_isUnderConstruction == null || _calendar == null || _hasFlag == null)
        {
            // Back-compat: visual-state delegates not wired (spike/back-compat caller) — plain
            // tier→SetStage, byte-identical to the pre-visual-stages behavior.
            inst.SetStage(def.StageIndexForTier(tier));
            return;
        }

        bool underConstruction = _isUnderConstruction(id);
        var (season, day) = _calendar();
        var (stageIndex, overlayKeys) = BuildingVisualState.Evaluate(def, tier, underConstruction, season, day, _hasFlag);
        inst.Apply(stageIndex, underConstruction, overlayKeys);
    }

    /// <summary>
    /// Primary placement strategy: find a <see cref="BuildingInstance"/> the user already instanced as
    /// a direct child of <see cref="_host"/> in the editor (outpost.tscn) whose
    /// <see cref="Node.SceneFilePath"/> matches <paramref name="def"/>'s <see cref="BuildingDefinition.ScenePath"/>.
    /// Matched by SCENE PATH, never by node name — the user is free to rename the instance (e.g. the
    /// outpost.tscn node is named "Tavern", not "Building_tavern"). Its position is never touched: the
    /// user's hand-placement in the editor is authoritative.
    /// </summary>
    private BuildingInstance? FindPrePlaced(BuildingDefinition def)
    {
        foreach (Node child in _host.GetChildren())
        {
            if (child is BuildingInstance bi && bi.SceneFilePath == def.ScenePath)
            {
                GD.Print($"[BuildingLoader] Adopted pre-placed instance \"{bi.Name}\" for {def.Id} " +
                         $"(scene {def.ScenePath}) — position left as authored.");
                return bi;
            }
        }
        return null;
    }

    /// <summary>Legacy fallback: instance the premade scene at the user-placed %Building_&lt;id&gt;
    /// marker. Only reached when <see cref="FindPrePlaced"/> found nothing.</summary>
    private BuildingInstance? InstanceBuilding(BuildingDefinition def)
    {
        Marker2D? marker = _host.GetNodeOrNull<Marker2D>($"%{def.MarkerName}")
                           ?? _host.GetNodeOrNull<Marker2D>(def.MarkerName);
        if (marker == null)
        {
            GD.PushWarning($"[BuildingLoader] No pre-placed instance and no %{def.MarkerName} marker in the " +
                     $"scene — skipping {def.Id} visual.");
            return null;
        }

        if (!ResourceLoader.Exists(def.ScenePath))
        {
            GD.PushWarning($"[BuildingLoader] Building scene {def.ScenePath} not found — skipping {def.Id} visual.");
            return null;
        }

        var packed = GD.Load<PackedScene>(def.ScenePath);
        var inst = packed?.InstantiateOrNull<BuildingInstance>();
        if (inst == null)
        {
            GD.PushError($"[BuildingLoader] {def.ScenePath} root is not a BuildingInstance — skipping {def.Id}.");
            return null;
        }

        // Distinct from the marker's own name (they share a parent) to avoid a Godot auto-rename.
        inst.Name = $"{def.MarkerName}Instance";
        _host.AddChild(inst);
        inst.GlobalPosition = marker.GlobalPosition;
        GD.Print($"[BuildingLoader] Spawned {def.Id} at its %{def.MarkerName} marker (scene {def.ScenePath}).");
        return inst;
    }
}
