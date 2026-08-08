using System;
using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data;

using Bulwark.Save;
namespace Bulwark.Territory;

/// <summary>
/// What a territory scene must expose for the forage daily pass to place spawns. Implemented by an
/// engine-aware adapter (<see cref="RegionForageCellProvider"/> over the scene's authored ground
/// region); the system itself stays plain C# — no Godot types cross this seam (cells are ints, not
/// Vector2I).
/// </summary>
public interface IForageCellProvider
{
    /// <summary>Inclusive cell bounds forage may spawn inside (the playable field, band excluded).</summary>
    (int X0, int Y0, int X1, int Y1) PlayableRect { get; }

    /// <summary>True when the cell is open spawnable ground: inside the territory's authored
    /// walkable region and clear of the cells its world objects occupy (trigger footprints, obstacle
    /// bodies such as water, plus their margin — all supplied by the adapter).</summary>
    bool IsOpenGround(int x, int y);

    /// <summary>Cells forage must keep its distance from: authored node positions (markers and
    /// placed prefabs) and roamer markers.</summary>
    IReadOnlyCollection<(int X, int Y)> ReservedCells { get; }

    /// <summary>Cells anchoring the trail (the exit trigger and the entry spawn). Clearance is
    /// pass-specific: forage keeps <see cref="ForageSystem.MinSpacingCells"/> away, debris only
    /// <see cref="ForageSystem.DebrisTrailClearanceCells"/> — clutter belongs underfoot.</summary>
    IReadOnlyCollection<(int X, int Y)> TrailCells { get; }
}

/// <summary>One live forage spawn in a territory (persisted per design/forage.md).</summary>
public sealed class ForageSpawn
{
    /// <summary>Territory-unique node id ("forage_d&lt;day&gt;_&lt;n&gt;") — the harvest contract
    /// with <see cref="TerritorySystem"/> and the scene's node views.</summary>
    public required string NodeId { get; init; }

    /// <summary>The <see cref="ResourceNodeDefinition.Id"/> this spawn instantiates.</summary>
    public required string ResourceId { get; init; }

    public int CellX { get; init; }
    public int CellY { get; init; }

    /// <summary>Absolute day ordinal the spawn appeared on.</summary>
    public int SpawnDay { get; init; }

    /// <summary>Set on harvest; pruned by the next daily pass (the cell stays occupied today).</summary>
    public bool Harvested { get; set; }
}

/// <summary>
/// The Stardew-style forage spawner (design/forage.md). Plain C# (game-systems layer, not a Node):
/// per unlocked territory it runs a deterministic daily pass — soft cap 6 live spawns, 1–4 weighted
/// attempts against the territory's <see cref="TerritoryDefinition.ForageTable"/>, valid-cell rules
/// via <see cref="IForageCellProvider"/> — plus a sweep of uncollected forage every 7th day, BEFORE
/// that day's pass. RNG is seeded by (world seed, day, territory id), so a reload replays the same
/// spawn set. Because cell validity needs the loaded scene, passes run as a catch-up when the
/// territory scene is entered (and again on day change while inside); <see cref="LastPassDay"/>
/// persists so processed days never re-roll.
///
/// A SECOND pass each day spawns debris (the third category in design/forage.md — stones, branches,
/// weeds): its own table (<see cref="TerritoryDefinition.DebrisTable"/>), own cap
/// (<see cref="DebrisLiveCap"/>), own 2–4 attempts, NO weekly sweep (debris accumulates to cap until
/// the player clears it), a one-time 8–12 piece sprinkle on the territory's first-ever pass, and a
/// relaxed 1-cell trail clearance. Same determinism (own RNG stream per day) and persistence.
/// </summary>
public sealed class ForageSystem
{
    /// <summary>Soft cap: a territory stops spawning at this many uncollected forage nodes.</summary>
    public const int LiveCap = 6;

    public const int MinAttemptsPerDay = 1;
    public const int MaxAttemptsPerDay = 4;

    /// <summary>Minimum Chebyshev distance (cells) from other nodes/markers/exits and other spawns.</summary>
    public const int MinSpacingCells = 2;

    /// <summary>Uncollected forage sweeps every Nth absolute day (before that day's pass).</summary>
    public const int SweepIntervalDays = 7;

    /// <summary>Debris cap: the territory stops sprinkling clutter at this many uncleared pieces.
    /// There is no sweep — only clearing (or the map's own crowding) makes room.</summary>
    public const int DebrisLiveCap = 12;

    public const int DebrisMinAttemptsPerDay = 2;
    public const int DebrisMaxAttemptsPerDay = 4;

    /// <summary>First-ever pass pre-sprinkles this many debris pieces so the map starts lived-in.</summary>
    public const int DebrisSeedMin = 8;
    public const int DebrisSeedMax = 12;

    /// <summary>Debris may hug the trail: only this Chebyshev clearance from
    /// <see cref="IForageCellProvider.TrailCells"/> (forage keeps <see cref="MinSpacingCells"/>).</summary>
    public const int DebrisTrailClearanceCells = 1;

    /// <summary>Random cells tried per spawn attempt before the attempt gives up.</summary>
    private const int CellTriesPerAttempt = 24;

    private sealed class TerritoryForage
    {
        public int LastPassDay;
        public readonly List<ForageSpawn> Spawns = new();

        /// <summary>Live + cleared-today debris (the second, non-swept pass).</summary>
        public readonly List<ForageSpawn> Debris = new();

        /// <summary>True once the one-time initial debris sprinkle has run for this territory.</summary>
        public bool DebrisSeeded;
    }

    private readonly Dictionary<string, TerritoryForage> _territories = new();
    private int _worldSeed;

    /// <summary>Raised after a catch-up changed a territory's spawn set, with the territory id.</summary>
    public event Action<string>? ForageChanged;

    /// <summary>Set the per-save world seed (persisted in SaveData; the determinism anchor).</summary>
    public void SetWorldSeed(int seed) => _worldSeed = seed;

    // ===================== Queries =====================

    /// <summary>Live (uncollected) spawns in a territory, in spawn order.</summary>
    public IReadOnlyList<ForageSpawn> GetLive(string territoryId)
    {
        var live = new List<ForageSpawn>();
        if (_territories.TryGetValue(territoryId, out var state))
        {
            foreach (var spawn in state.Spawns)
                if (!spawn.Harvested)
                    live.Add(spawn);
        }
        return live;
    }

    /// <summary>Live (uncleared) debris pieces in a territory, in spawn order.</summary>
    public IReadOnlyList<ForageSpawn> GetLiveDebris(string territoryId)
    {
        var live = new List<ForageSpawn>();
        if (_territories.TryGetValue(territoryId, out var state))
        {
            foreach (var spawn in state.Debris)
                if (!spawn.Harvested)
                    live.Add(spawn);
        }
        return live;
    }

    /// <summary>True when the node id names a forage or debris spawn (live or harvested-today)
    /// here — i.e. anything this system placed, as opposed to an authored/placed node.</summary>
    public bool IsForageNode(string territoryId, string nodeId) => Find(territoryId, nodeId) != null;

    /// <summary>The spawn's resource id, or null when the node id is not a forage spawn.</summary>
    public string? ResolveResourceId(string territoryId, string nodeId)
        => Find(territoryId, nodeId)?.ResourceId;

    public bool IsHarvested(string territoryId, string nodeId)
        => Find(territoryId, nodeId)?.Harvested ?? false;

    // ===================== Commands =====================

    /// <summary>Mark a spawn collected (called by <see cref="TerritorySystem.Harvest"/> on success).
    /// The entry stays, flagged, until the next daily pass prunes it — its cell reads occupied for
    /// the rest of the day.</summary>
    public bool MarkHarvested(string territoryId, string nodeId)
    {
        var spawn = Find(territoryId, nodeId);
        if (spawn == null || spawn.Harvested)
            return false;
        spawn.Harvested = true;
        return true;
    }

    /// <summary>
    /// Run every owed daily pass for a territory up to <paramref name="currentDay"/> (absolute day
    /// ordinal). Each day runs the forage pass (prune yesterday's harvested entries → 7th-day sweep
    /// → 1–4 weighted spawn attempts under the live cap) and then the debris pass (prune cleared
    /// pieces → one-time initial sprinkle OR 2–4 top-up attempts under the debris cap; never swept).
    /// Deterministic per (world seed, day, territory id) regardless of when the catch-up runs.
    /// Raises <see cref="ForageChanged"/> once if anything changed.
    /// </summary>
    public void CatchUp(string territoryId, int currentDay, IForageCellProvider cells)
    {
        if (!Territories.TryGet(territoryId, out var territory))
            return;

        var state = GetOrCreate(territoryId);
        bool changed = false;

        for (int day = state.LastPassDay + 1; day <= currentDay; day++)
        {
            changed |= RunForageDay(territory, state, day, cells);
            changed |= RunDebrisDay(territory, state, day, cells);
            state.LastPassDay = day;
        }

        if (changed)
            ForageChanged?.Invoke(territoryId);
    }

    /// <summary>One forage day: prune → 7th-day sweep → capped weighted attempts.</summary>
    private bool RunForageDay(
        TerritoryDefinition territory, TerritoryForage state, int day, IForageCellProvider cells)
    {
        var rng = new Random(DeterministicRng.StableSeed(_worldSeed, day, territory.Id));
        bool changed = state.Spawns.RemoveAll(s => s.Harvested) > 0;

        if (day % SweepIntervalDays == 0 && state.Spawns.Count > 0)
        {
            state.Spawns.Clear();
            changed = true;
        }

        int attempts = rng.Next(MinAttemptsPerDay, MaxAttemptsPerDay + 1);
        for (int attempt = 0; attempt < attempts; attempt++)
        {
            if (state.Spawns.Count >= LiveCap)
                break;

            string? resourceId = PickWeighted(territory.ForageTable, rng);
            if (resourceId == null)
                break; // empty/invalid table — nothing this territory can spawn

            if (!TryPickCell(rng, cells, state, MinSpacingCells, out int x, out int y))
                continue; // no valid cell found this attempt (map crowded)

            state.Spawns.Add(new ForageSpawn
            {
                NodeId = $"forage_d{day}_{attempt}",
                ResourceId = resourceId,
                CellX = x,
                CellY = y,
                SpawnDay = day,
            });
            changed = true;
        }
        return changed;
    }

    /// <summary>
    /// One debris day (design/forage.md third category): prune cleared pieces (cleared debris is
    /// gone for good — new clutter only ever comes from this pass), then either the one-time
    /// 8–12 piece initial sprinkle (the territory's first-ever debris pass, so the map starts
    /// lived-in) or the 2–4 attempt daily top-up under <see cref="DebrisLiveCap"/>. Debris is
    /// deliberately NEVER swept — it accumulates to cap until the player clears it. Own RNG stream
    /// (world seed, day, "territoryId:debris") so the forage rolls stay byte-identical.
    /// </summary>
    private bool RunDebrisDay(
        TerritoryDefinition territory, TerritoryForage state, int day, IForageCellProvider cells)
    {
        bool changed = state.Debris.RemoveAll(s => s.Harvested) > 0;
        if (territory.DebrisTable.Count == 0)
            return changed; // no clutter here (yet) — the sprinkle stays owed until a table exists

        var rng = new Random(DeterministicRng.StableSeed(_worldSeed, day, territory.Id + ":debris"));

        if (!state.DebrisSeeded)
        {
            int seeds = rng.Next(DebrisSeedMin, DebrisSeedMax + 1);
            for (int i = 0; i < seeds; i++)
            {
                if (state.Debris.Count >= DebrisLiveCap)
                    break;
                string? resourceId = PickWeighted(territory.DebrisTable, rng);
                if (resourceId == null)
                    break;
                if (!TryPickCell(rng, cells, state, DebrisTrailClearanceCells, out int x, out int y))
                    continue;
                state.Debris.Add(new ForageSpawn
                {
                    NodeId = $"debris_d{day}_s{i}",
                    ResourceId = resourceId,
                    CellX = x,
                    CellY = y,
                    SpawnDay = day,
                });
                changed = true;
            }
            state.DebrisSeeded = true;
            return changed; // the sprinkle IS this day's debris pass
        }

        int attempts = rng.Next(DebrisMinAttemptsPerDay, DebrisMaxAttemptsPerDay + 1);
        for (int attempt = 0; attempt < attempts; attempt++)
        {
            if (state.Debris.Count >= DebrisLiveCap)
                break;

            string? resourceId = PickWeighted(territory.DebrisTable, rng);
            if (resourceId == null)
                break;

            if (!TryPickCell(rng, cells, state, DebrisTrailClearanceCells, out int x, out int y))
                continue;

            state.Debris.Add(new ForageSpawn
            {
                NodeId = $"debris_d{day}_{attempt}",
                ResourceId = resourceId,
                CellX = x,
                CellY = y,
                SpawnDay = day,
            });
            changed = true;
        }
        return changed;
    }

    // ===================== Save bridge =====================

    /// <summary>Snapshot all per-territory forage + debris state.</summary>
    public List<TerritoryForageDto> Capture()
    {
        var dtos = new List<TerritoryForageDto>();
        foreach (var (territoryId, state) in _territories)
        {
            var dto = new TerritoryForageDto
            {
                TerritoryId = territoryId,
                LastPassDay = state.LastPassDay,
                DebrisSeeded = state.DebrisSeeded,
            };
            foreach (var spawn in state.Spawns)
                dto.Spawns.Add(ToDto(spawn));
            foreach (var spawn in state.Debris)
                dto.Debris.Add(ToDto(spawn));
            dtos.Add(dto);
        }
        return dtos;
    }

    /// <summary>Overwrite forage state from a save. Null = pre-forage save = everything fresh
    /// (the first catch-up then seeds from day 1, deterministically). Pre-debris saves carry no
    /// debris section — DebrisSeeded stays false, so the next pass runs the initial sprinkle.</summary>
    public void Restore(List<TerritoryForageDto>? dtos)
    {
        _territories.Clear();
        if (dtos == null)
            return;

        foreach (var dto in dtos)
        {
            if (string.IsNullOrEmpty(dto.TerritoryId))
                continue;
            var state = GetOrCreate(dto.TerritoryId);
            state.LastPassDay = dto.LastPassDay;
            state.DebrisSeeded = dto.DebrisSeeded;
            RestoreSpawns(dto.Spawns, state.Spawns);
            RestoreSpawns(dto.Debris, state.Debris);
        }
    }

    private static ForageSpawnDto ToDto(ForageSpawn spawn) => new()
    {
        NodeId = spawn.NodeId,
        ResourceId = spawn.ResourceId,
        X = spawn.CellX,
        Y = spawn.CellY,
        SpawnDay = spawn.SpawnDay,
        Harvested = spawn.Harvested,
    };

    private static void RestoreSpawns(List<ForageSpawnDto>? dtos, List<ForageSpawn> target)
    {
        if (dtos == null)
            return;
        foreach (var s in dtos)
        {
            if (string.IsNullOrEmpty(s.NodeId) || !ResourceNodes.IsDefined(s.ResourceId))
                continue;
            target.Add(new ForageSpawn
            {
                NodeId = s.NodeId,
                ResourceId = s.ResourceId,
                CellX = s.X,
                CellY = s.Y,
                SpawnDay = s.SpawnDay,
                Harvested = s.Harvested,
            });
        }
    }

    // ===================== Internals =====================

    private TerritoryForage GetOrCreate(string territoryId)
    {
        if (!_territories.TryGetValue(territoryId, out var state))
            _territories[territoryId] = state = new TerritoryForage();
        return state;
    }

    private ForageSpawn? Find(string territoryId, string nodeId)
    {
        if (!_territories.TryGetValue(territoryId, out var state))
            return null;
        foreach (var spawn in state.Spawns)
            if (spawn.NodeId == nodeId)
                return spawn;
        foreach (var spawn in state.Debris)
            if (spawn.NodeId == nodeId)
                return spawn;
        return null;
    }

    /// <summary>Weighted table roll; entries with unknown resource ids or (future) off-season
    /// filters are skipped. Null when nothing is eligible.</summary>
    private static string? PickWeighted(IReadOnlyList<ForageEntry> table, Random rng)
    {
        int total = 0;
        foreach (var entry in table)
        {
            if (!ResourceNodes.IsDefined(entry.NodeId))
                continue;
            total += Math.Max(1, entry.Weight);
        }
        if (total <= 0)
            return null;

        int roll = rng.Next(total);
        foreach (var entry in table)
        {
            if (!ResourceNodes.IsDefined(entry.NodeId))
                continue;
            roll -= Math.Max(1, entry.Weight);
            if (roll < 0)
                return entry.NodeId;
        }
        return null;
    }

    /// <summary>Roll random cells inside the playable rect until one passes the valid-cell rules:
    /// open spawnable ground, ≥ <see cref="MinSpacingCells"/> (Chebyshev) from every reserved cell
    /// and existing spawn (forage AND debris), and ≥ <paramref name="trailClearance"/> from every
    /// trail cell (the pass-specific rule: forage 2, debris 1). False when
    /// <see cref="CellTriesPerAttempt"/> rolls all fail.</summary>
    private static bool TryPickCell(
        Random rng, IForageCellProvider cells, TerritoryForage state, int trailClearance,
        out int x, out int y)
    {
        var (x0, y0, x1, y1) = cells.PlayableRect;
        for (int i = 0; i < CellTriesPerAttempt; i++)
        {
            x = rng.Next(x0, x1 + 1);
            y = rng.Next(y0, y1 + 1);

            if (!cells.IsOpenGround(x, y))
                continue;
            if (TooClose(cells.ReservedCells, x, y, MinSpacingCells)
                || TooClose(cells.TrailCells, x, y, trailClearance)
                || TooCloseToSpawns(state.Spawns, x, y)
                || TooCloseToSpawns(state.Debris, x, y))
            {
                continue;
            }
            return true;
        }
        x = y = 0;
        return false;
    }

    private static bool TooClose(
        IReadOnlyCollection<(int X, int Y)> anchors, int x, int y, int clearance)
    {
        foreach (var (ax, ay) in anchors)
            if (Math.Max(Math.Abs(ax - x), Math.Abs(ay - y)) < clearance)
                return true;
        return false;
    }

    private static bool TooCloseToSpawns(List<ForageSpawn> spawns, int x, int y)
    {
        foreach (var spawn in spawns)
            if (Math.Max(Math.Abs(spawn.CellX - x), Math.Abs(spawn.CellY - y)) < MinSpacingCells)
                return true;
        return false;
    }
}
