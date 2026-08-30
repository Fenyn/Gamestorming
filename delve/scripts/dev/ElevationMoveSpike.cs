using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Events;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless proof that a cliff stops everyone. Enemies (and AI-toggled PCs) used to walk straight up
/// multi-level faces because the Pathfinder ran its cliff check only on cardinal edges — a diagonal
/// move was never elevation-tested at all — and because Step had no elevation gate on either side of
/// the engine/host seam.
///
/// The unit of truth is one EDGE: <see cref="BattleGrid.GetEdgeStepUp"/> over the two tiles' corner
/// heights. An edge that rises more than one elevation is a cliff, whichever of the eight directions
/// you walk into it from. Every scenario below asks that same question, so the pathfinder, Step
/// highlighting and a live AI turn cannot disagree about what a wall of rock is.
///
///  (a) Pathfinder  — over 50 generated forest maps: no cliff edge is ever a one-step move, and any
///                    longer route the pathfinder does return between those two tiles is made
///                    entirely of legal edges. Non-cliff edges stay reachable (the check is not
///                    vacuously passing by refusing everything).
///  (b) Step        — delve's StepBlockedReason refuses every cliff edge on those same maps, and the
///                    engine's own StepAction refuses them too once the session wiring is in place.
///                    Both directions are covered: no scrambling up, no stepping off a drop.
///  (c) AI turn     — a seeded auto-played encounter on a generated forest map. Every tile-by-tile
///                    move any unit makes is checked against the same edge rule.
/// </summary>
public partial class ElevationMoveSpike : SpikeBase
{
    /// <summary>Biome under test: forest maps go up to six elevations, so cliffs are everywhere.</summary>
    private const string Biome = "forest";

    /// <summary>Seeds swept in scenarios (a) and (b).</summary>
    private const int SeedCount = 50;
    private const int FirstSeed = 1;

    /// <summary>Walking rise every mover in this spike is allowed: one elevation, no climb speed.</summary>
    private const int MaxStepUp = 1;

    /// <summary>Route budget for the "did it find a longer way round?" probe, in tiles.</summary>
    private const int RouteBudget = 12;

    /// <summary>Seeds for the auto-played encounters in scenario (c).</summary>
    private static readonly int[] EncounterSeeds = { 4242, 77, 31337 };

    /// <summary>Rounds the auto-played encounter is given before the spike calls it enough.</summary>
    private const int EncounterRounds = 25;

    protected override string Banner => "==================== ELEVATION MOVE SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        SweepGeneratedMaps();

        GD.Print("-------------------- (c) auto-played AI encounters on forest maps --------------------");
        foreach (int seed in EncounterSeeds)
            await RunEncounter(data, seed);

        Check($"(c) the AI actually moved ({_segmentsChecked} tile transitions)", _segmentsChecked > 0);
        Check($"(c) no AI move crossed a cliff edge ({_illegalSegments} violations)",
            _illegalSegments == 0);
        Check($"(c) every move was tile-by-tile ({_unexplainedJumps} unexplained jumps)",
            _unexplainedJumps == 0);
    }

    // ─────────────────────────── (a) + (b) generated-map sweep ───────────────────────────

    /// <summary>
    /// One pass over the seeds serves both the pathfinder and the Step assertions: generating a map
    /// is the expensive part, and both questions are asked of the same edges.
    /// </summary>
    private void SweepGeneratedMaps()
    {
        GD.Print("-------------------- (a)+(b) 50 generated forest maps --------------------");

        var actor = PresetCharacters.BuildPlayer(level: 1, teamId: 1);
        var step = new StepAction();

        int mapsGenerated = 0;
        int cliffEdges = 0;   // rise > 1: nobody walks up it
        int dropEdges = 0;    // fall-threshold drop the other way: walkable, but not by Stepping
        int openEdges = 0;    // neither

        // (a) Pathfinder.
        int oneStepViolations = 0;
        int openEdgesReachable = 0;
        int routesFound = 0;
        int routeBadEdges = 0;

        // (b) Step.
        int stepAccepted = 0;         // host delegate let a cliff or drop edge through
        int stepFalsePositives = 0;   // host delegate called a legal edge too steep
        int engineStepAccepted = 0;   // engine StepAction let a cliff or drop edge through
        int engineFalsePositives = 0;

        for (int i = 0; i < SeedCount; i++)
        {
            int seed = FirstSeed + i;
            var layout = MapGenerator.GenerateValidated(Biome, seed);
            if (layout == null) { Check($"seed {seed}: GenerateValidated produced a layout", false); continue; }

            var grid = MapLayoutGridBuilder.Build(layout);
            mapsGenerated++;

            var movement = new MovementActions(grid, new BattleEventEmitter(new BattleRunner()));

            // The engine's StepAction reads ForcedMovementExecutor.Grid and the host delegate the
            // session installs. EngineEncounterScope is what claims both in a real encounter, so the
            // engine half of (b) is proved through the same wiring the game runs on.
            using var scope = new EngineEncounterScope(
                grid,
                isPlayerControlled: _ => true,
                reactionPolicy: _ => Task.FromResult(false),
                validateStep: movement.StepBlockedReason);

            foreach (var tile in grid.AllTiles)
            {
                if (tile.IsBlocked) continue;
                var from = tile.GridPosition;

                var reachable = Pathfinder.FindReachableTiles(grid, Request(from, RouteBudget));

                foreach (var to in grid.GetNeighbors(from))
                {
                    if (grid.GetTile(to)!.IsBlocked) continue;

                    bool cliff = grid.GetEdgeStepUp(from, to) > MaxStepUp;
                    // The reverse rise IS the drop across this edge. Walking off it is legal
                    // movement (that is what falling is); Stepping off it is not.
                    bool drop = grid.GetEdgeStepUp(to, from) >= TileCornerHeights.FallDamageThreshold;

                    string? reason = HostStepReason(movement, actor, from, to);
                    string? engineReason = EngineStepReason(step, actor, from, to);

                    if (cliff)
                    {
                        cliffEdges++;

                        // (a) never a one-step move, and any longer route is all legal edges.
                        if (reachable.TryGetValue(to, out _))
                        {
                            var path = Pathfinder.ReconstructPath(reachable, to);
                            if (path.Count <= 2) oneStepViolations++;
                            else
                            {
                                routesFound++;
                                routeBadEdges += CountIllegalEdges(grid, path);
                            }
                        }
                    }
                    else if (drop)
                    {
                        dropEdges++;
                    }
                    else
                    {
                        openEdges++;
                        if (reachable.ContainsKey(to)) openEdgesReachable++;
                    }

                    // (b) Step refuses a rise it cannot climb and a drop it would fall down;
                    // everything else it must allow.
                    if (cliff || drop)
                    {
                        if (reason != "Too steep.") stepAccepted++;
                        if (engineReason == null) engineStepAccepted++;
                    }
                    else
                    {
                        if (reason == "Too steep.") stepFalsePositives++;
                        if (engineReason != null && engineReason.Contains("steep")) engineFalsePositives++;
                    }
                }
            }
        }

        GD.Print($"        · {mapsGenerated} maps, {cliffEdges} cliff edges, {dropEdges} drop edges, "
                 + $"{openEdges} open edges");
        GD.Print($"        · {routesFound} cliff pairs joined by a longer route, "
                 + $"{openEdgesReachable} open edges reachable");

        Check($"(a) {mapsGenerated} forest maps generated", mapsGenerated == SeedCount);
        Check($"(a) the sweep actually found cliffs ({cliffEdges} edges)", cliffEdges > 0);
        Check($"(a) no cliff edge is a one-step move ({oneStepViolations} violations)",
            oneStepViolations == 0);
        Check($"(a) every route the pathfinder returned uses legal edges ({routeBadEdges} bad edges)",
            routeBadEdges == 0);
        Check("(a) open edges are still reachable — the gate is not refusing everything",
            openEdges > 0 && openEdgesReachable > 0);

        Check($"(b) the sweep found drops to Step off ({dropEdges} edges)", dropEdges > 0);
        Check($"(b) StepBlockedReason refuses every cliff and drop edge ({stepAccepted} accepted)",
            stepAccepted == 0);
        Check($"(b) StepBlockedReason allows open edges ({stepFalsePositives} false positives)",
            stepFalsePositives == 0);
        Check($"(b) engine StepAction refuses every cliff and drop edge ({engineStepAccepted} accepted)",
            engineStepAccepted == 0);
        Check($"(b) engine StepAction allows open edges ({engineFalsePositives} false positives)",
            engineFalsePositives == 0);
    }

    /// <summary>Delve's host-side step legality for one edge.</summary>
    private static string? HostStepReason(
        MovementActions movement, ICharacter actor, PF2eVec from, PF2eVec to)
    {
        actor.GridPosition = from;
        return movement.StepBlockedReason(actor, to);
    }

    /// <summary>The engine's own step legality for one edge, or null when it accepts the move.</summary>
    private static string? EngineStepReason(
        StepAction step, ICharacter actor, PF2eVec from, PF2eVec to)
    {
        actor.GridPosition = from;
        step.Destination = to;
        string? message = step.GetValidationErrorMessage(actor);
        step.Destination = null;
        return message;
    }

    /// <summary>Edges along a walked path whose rise exceeds the walking allowance.</summary>
    private static int CountIllegalEdges(BattleGrid grid, List<PF2eVec> path)
    {
        int bad = 0;
        for (int i = 1; i < path.Count; i++)
            if (grid.GetEdgeStepUp(path[i - 1], path[i]) > MaxStepUp) bad++;
        return bad;
    }

    private static PathfindingRequest Request(PF2eVec origin, int maxDistance) => new()
    {
        Origin = origin,
        MaxDistance = maxDistance,
        TileWidth = 1,
        MaxStepUpElevations = MaxStepUp,
        OriginTeamId = 1
    };

    // ─────────────────────────── (c) auto-played AI encounter ───────────────────────────

    private BattleGrid _encounterGrid = null!;
    private readonly List<ICharacter> _units = new();
    private readonly Dictionary<ICharacter, PF2eVec> _lastSeen = new();

    private int _segmentsChecked;
    private int _illegalSegments;
    private int _unexplainedJumps;

    /// <summary>
    /// One seeded encounter on a real generated forest map, played entirely by the AI. Every
    /// tile-to-tile transition is checked: the per-tile MovementStep events a Stride emits, plus a
    /// position sweep after every event, which is what catches a Step (it emits no path).
    /// </summary>
    private async Task RunEncounter(DataManager data, int seed)
    {
        var layout = MapGenerator.GenerateValidated(Biome, seed);
        if (layout == null) { Check($"(c) seed {seed}: encounter map generated", false); return; }

        _encounterGrid = MapLayoutGridBuilder.Build(layout);
        _units.Clear();
        _lastSeen.Clear();
        Check($"(c) seed {seed}: encounter map generated", _encounterGrid.TileCount > 0);

        using var reactions = UsePassthroughReactions();
        using var spatial = SpatialDelegates.Wire(_encounterGrid);

        Rng.Seed(seed);

        var runner = new BattleRunner();
        runner.SetPresenter(OnBattleEvent);
        var simulator = new AIBattleSimulator(_encounterGrid, runner) { MaxRounds = EncounterRounds };

        // Shove and the other forced-movement paths read this global; no other scope owns it here.
        ForcedMovementExecutor.Grid = _encounterGrid;

        try
        {
            var deploy = new DeploymentPicker(_encounterGrid, layout);

            var team1 = new List<ICharacter>
            {
                PresetCharacters.BuildPlayer(level: 2, teamId: 1),
                PresetCharacters.BuildRecruit(level: 2, teamId: 1)
            };
            var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;
            var team2 = new List<ICharacter>
            {
                CreatureFactory.Create(goblinDef, teamId: 2),
                CreatureFactory.Create(goblinDef, teamId: 2),
                CreatureFactory.Create(goblinDef, teamId: 2)
            };

            if (!deploy.Place(simulator, team1, zoneIndex: 0) || !deploy.Place(simulator, team2, zoneIndex: 1))
            {
                Check($"(c) seed {seed}: both teams deployed", false);
                return;
            }
            Check($"(c) seed {seed}: both teams deployed", true);

            _units.AddRange(team1);
            _units.AddRange(team2);
            foreach (var c in _units) _lastSeen[c] = c.GridPosition;

            GD.Print($"[Spike] seed {seed}: {team1.Count} PCs vs {team2.Count} Goblin Warriors on "
                     + $"'{Biome}', {EncounterRounds} rounds max");

            BattleResult result = await simulator.RunEncounter(team1, team2);

            GD.Print($"        · seed {seed}: {result}, {_segmentsChecked} tile transitions so far");
        }
        finally
        {
            if (ReferenceEquals(ForcedMovementExecutor.Grid, _encounterGrid))
                ForcedMovementExecutor.Grid = null;
        }
    }

    private Task OnBattleEvent(BattleEvent evt)
    {
        if (evt.Type == BattleEventType.MovementStep && evt.Path is { Count: 2 })
            CheckSegment(evt.Source, evt.Path[0], evt.Path[1]);

        // Position sweep: a Step moves a unit without emitting a path, so the events alone are not
        // enough. Any transition already counted above simply re-reads as "no change" here.
        foreach (var c in _units)
        {
            var now = c.GridPosition;
            if (!_lastSeen.TryGetValue(c, out var before) || before == now) continue;

            int distance = Math.Max(Math.Abs(now.x - before.x), Math.Abs(now.y - before.y));
            if (distance == 1) CheckSegment(c, before, now);
            else _unexplainedJumps++;

            _lastSeen[c] = now;
        }
        return Task.CompletedTask;
    }

    private void CheckSegment(ICharacter? mover, PF2eVec from, PF2eVec to)
    {
        _segmentsChecked++;
        _lastSeen[mover!] = to;

        int stepUp = _encounterGrid.GetEdgeStepUp(from, to);
        if (stepUp <= MaxStepUp) return;

        _illegalSegments++;
        GD.PushError($"[Spike] CLIFF CLIMB: {mover?.Name ?? "?"} moved ({from.x},{from.y}) -> "
                     + $"({to.x},{to.y}), rise {stepUp} elevations");
    }

    /// <summary>
    /// Hands out start tiles inside a generated map's deployment zones: walkable, unoccupied, and
    /// never handed out twice.
    /// </summary>
    private sealed class DeploymentPicker
    {
        private readonly BattleGrid _grid;
        private readonly MapLayout _layout;
        private readonly HashSet<PF2eVec> _taken = new();

        internal DeploymentPicker(BattleGrid grid, MapLayout layout)
        {
            _grid = grid;
            _layout = layout;
        }

        internal bool Place(BattleSimulator simulator, List<ICharacter> team, int zoneIndex)
        {
            var zones = _layout.DeploymentZones;
            if (zones == null || zoneIndex >= zones.Length) return false;
            var zone = zones[zoneIndex];

            int xMin = Math.Min(zone.CornerA.x, zone.CornerB.x);
            int xMax = Math.Max(zone.CornerA.x, zone.CornerB.x);
            int yMin = Math.Min(zone.CornerA.y, zone.CornerB.y);
            int yMax = Math.Max(zone.CornerA.y, zone.CornerB.y);

            int placed = 0;
            for (int y = yMin; y <= yMax && placed < team.Count; y++)
            {
                for (int x = xMin; x <= xMax && placed < team.Count; x++)
                {
                    var pos = new PF2eVec(x, y);
                    if (_taken.Contains(pos)) continue;
                    var tile = _grid.GetTile(pos);
                    if (tile == null || tile.IsBlocked) continue;
                    if (!_grid.CanCreatureFit(pos, team[placed].TileWidth)) continue;

                    simulator.PlaceCreature(team[placed], pos);
                    _taken.Add(pos);
                    placed++;
                }
            }
            return placed == team.Count;
        }
    }
}
