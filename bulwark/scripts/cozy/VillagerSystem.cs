using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// Tracks which hand-authored villagers have ARRIVED at the outpost (Phase 3 keystone). Plain C#:
/// it holds the arrived-id set and, on <see cref="EvaluateArrivals"/>, checks every not-yet-arrived
/// villager's <see cref="ArrivalTrigger"/> against the current <see cref="IArrivalContext"/>, marking
/// newly-satisfied ones arrived (idempotent — each fires <see cref="Arrived"/> exactly once, ever).
///
/// GameState owns one instance built over the SHIPPED (empty) <see cref="Villagers"/> catalog and
/// re-drives <see cref="EvaluateArrivals"/> from every trigger source (BuildingChanged, DayStarted,
/// StoryFlagChanged, and on load) — a no-op while the catalog is empty. The catalog is injectable so
/// the spike can exercise the logic with spike-local synthetic definitions.
/// </summary>
public sealed class VillagerSystem
{
    private readonly IArrivalContext _context;
    private readonly List<VillagerDefinition> _catalog;
    private readonly HashSet<string> _arrived = new();

    /// <summary>Raised once per villager the moment its trigger is first satisfied, with the id.</summary>
    public event Action<string>? Arrived;

    /// <param name="context">Live state the triggers read.</param>
    /// <param name="catalog">Villager set to evaluate; defaults to the shipped <see cref="Villagers.All"/>.</param>
    public VillagerSystem(IArrivalContext context, IEnumerable<VillagerDefinition>? catalog = null)
    {
        _context = context ?? throw new ArgumentNullException(nameof(context));
        _catalog = catalog != null ? new List<VillagerDefinition>(catalog) : new List<VillagerDefinition>(Villagers.All);
    }

    /// <summary>True once <paramref name="id"/>'s villager has arrived.</summary>
    public bool HasArrived(string id) => _arrived.Contains(id);

    /// <summary>Every arrived villager id.</summary>
    public IReadOnlyCollection<string> ArrivedIds => _arrived;

    /// <summary>The villagers this system evaluates (for id-scoped refreshes and join resolution).</summary>
    public IReadOnlyList<VillagerDefinition> Catalog => _catalog;

    /// <summary>Non-throwing lookup within this system's catalog.</summary>
    public bool TryGet(string id, out VillagerDefinition def)
    {
        foreach (var d in _catalog)
            if (d.Id == id)
            {
                def = d;
                return true;
            }
        def = null!;
        return false;
    }

    /// <summary>
    /// Check every not-yet-arrived villager's trigger against the current state; mark the newly
    /// satisfied ones arrived and raise <see cref="Arrived"/> for each (once, in catalog order).
    /// Idempotent and safe to call from any trigger source. Returns the ids that newly arrived
    /// (empty on a no-op, and always empty while the catalog is empty).
    /// </summary>
    public List<string> EvaluateArrivals()
    {
        var newly = new List<string>();
        foreach (var def in _catalog)
        {
            if (_arrived.Contains(def.Id))
                continue;
            if (def.Arrival != null && def.Arrival.IsSatisfied(_context))
            {
                _arrived.Add(def.Id);
                newly.Add(def.Id);
            }
        }
        foreach (var id in newly)
            Arrived?.Invoke(id);
        return newly;
    }

    /// <summary>Snapshot the arrived-id set for the save file.</summary>
    public List<string> Capture() => new(_arrived);

    /// <summary>
    /// Overwrite the arrived set from a save. Version-tolerant: null (pre-v5 save) clears to "none
    /// arrived"; ids not in this catalog are dropped. Silent — no <see cref="Arrived"/> events
    /// (GameState re-runs <see cref="EvaluateArrivals"/> after restore to catch up any trigger that
    /// is now satisfied, e.g. when loading a pre-v5 save whose state already meets a condition).
    /// </summary>
    public void Restore(IEnumerable<string>? ids)
    {
        _arrived.Clear();
        if (ids == null)
            return;
        foreach (var id in ids)
            if (!string.IsNullOrEmpty(id) && TryGet(id, out _))
                _arrived.Add(id);
    }
}
