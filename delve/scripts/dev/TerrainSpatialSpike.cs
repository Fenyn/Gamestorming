using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e.Actions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless proof for M6: real cover, line of sight and line of effect traced off terrain geometry
/// (<see cref="TerrainSpatial"/>), and the gate in <see cref="SpatialDelegates.Wire"/> that decides
/// whether an encounter gets them.
///
/// This spike exists because wiring <c>CoverHelper.HasLineOfEffect</c> switches on
/// <c>AreaCalculator.FilterByLineOfEffect</c>, which until now no-opped: EVERY area spell in the game
/// starts respecting walls the moment that delegate is non-null. So the area cases here go through the
/// real spell path (<see cref="PlayerActionExecutor.GetAreaTemplateTiles"/> and a live
/// <see cref="PlayerActionExecutor.ExecuteCast"/>), not through the delegate in isolation.
///
/// Boards are HAND-ROLLED <see cref="MapLayout"/>s — arrays painted directly — so no biome tuning can
/// move a wall out from under an assertion. One real generated SEWER map (pinned seeds; sewer weights
/// are not in flight) backs the hand-rolled cases with a sanity sweep.
///
///  (a) Wall barrier      — a wall between two combatants kills LOS and LOE and grants standard cover;
///                          a clear shot on the same side grants none; an intervening creature grants
///                          lesser cover; adjacent and same-tile pairs never block themselves.
///  (b) Area spells       — a Fireball template aimed past a wall drops exactly the tiles behind it,
///                          and a live Breathe Fire cone resolves against the goblin in front of the
///                          wall and not the one behind it.
///  (c) Cover pillar      — a standable ProvidesCover tile grants standard cover but blocks neither
///                          sight nor effect, does not cover the creature standing ON it, and is what
///                          Take Cover's terrain check keys off.
///  (d) Elevation         — a low wall blocks a shot fired from the ground and not the same shot fired
///                          from a plateau four elevations up. Same wall, same target, different eye
///                          height.
///  (e) Flat equivalence  — CreateFlat boards report no spatial features, keep the open stubs, and lose
///                          nothing to LOE filtering. Includes the evidence for WHY the gate exists:
///                          TerrainSpatial over that same flat grid would hand out creature cover.
///  (f) Generated sewer   — pinned seeds: spatial features present, some walkable pair has blocked LOE,
///                          and no pair of ADJACENT walkable tiles ever does.
/// </summary>
public partial class TerrainSpatialSpike : SpikeBase
{
    /// <summary>Corner height of a full wall — the forest biome's WallHeight (2 elevations).</summary>
    private const int TallWall = 8;

    /// <summary>Corner height of a low wall and of a cover pillar — the biomes' CoverHeight (1 elevation).</summary>
    private const int LowWall = 4;

    /// <summary>Elevation the plateau in scenario (d) stands at, in elevations.</summary>
    private const int PlateauElevation = 4;

    /// <summary>Sewer seeds for the generated-map sweep. Sewer macro-shape weights are not in flight.</summary>
    private static readonly int[] SewerSeeds = { 7, 2026, 84105 };

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== TERRAIN SPATIAL SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[TerrainSpatialSpike] DataManager not loaded — aborting.");
            return;
        }
        PresetSpells.EnsureRegistered();

        try
        {
            Scenario_A_WallBarrier(data);
            await Scenario_B_AreaSpells(data);
            Scenario_C_CoverPillar(data);
            Scenario_D_Elevation(data);
            Scenario_E_FlatEquivalence(data);
            Scenario_F_GeneratedSewer();
        }
        catch (Exception e)
        {
            GD.PushError($"[TerrainSpatialSpike] Unhandled exception: {e}");
            Fail();
        }

        FinishAndQuit("TerrainSpatialSpike");
    }

    // ─────────────────────────── (a) Wall barrier ───────────────────────────

    /// <summary>
    /// 15x9 board, ground at elevation 0, one full-height wall column at x=6. Everything about a solid
    /// barrier: it stops sight, it stops effects, and it is standard cover.
    /// </summary>
    private void Scenario_A_WallBarrier(DataManager data)
    {
        GD.Print("-------------------- (a) wall barrier --------------------");
        var layout = BarrierLayout();

        // Across the wall.
        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var target = MakeGoblin(data);
        // Same side, clear line.
        var scout = PresetCharacters.BuildScout(level: 2, teamId: 1);
        var clearTarget = MakeGoblin(data);
        // Same side, a creature in the way.
        var blocker = MakeGoblin(data);

        var session = StartSession(layout, "(a)",
            party: new() { (hero, new PF2eVec(2, 4)), (scout, new PF2eVec(8, 7)) },
            enemies: new()
            {
                (target, new PF2eVec(12, 4)),
                (clearTarget, new PF2eVec(12, 7)),
                (blocker, new PF2eVec(10, 7)),
            },
            seed: 1);
        try
        {
            Check("(a) wall grid wires the real spatial delegates",
                TerrainSpatial.HasSpatialFeatures(session.Grid));

            Check("(a) wall between combatants blocks line of sight",
                CoverHelper.HasLineOfSight!(hero, target) == false);
            Check("(a) wall between combatants blocks line of effect",
                CoverHelper.HasLineOfEffect!(hero.GridPosition, target.GridPosition) == false);
            Check("(a) wall between combatants grants standard cover",
                CoverHelper.GetPositionalCover!(hero, target) == CoverLevel.Standard);

            Check("(a) clear line on one side has sight and effect",
                CoverHelper.HasLineOfSight(scout, clearTarget)
                && CoverHelper.HasLineOfEffect(scout.GridPosition, clearTarget.GridPosition));
            Check("(a) intervening creature grants lesser cover",
                CoverHelper.GetPositionalCover(scout, clearTarget) == CoverLevel.Lesser);
            Check("(a) intervening creature does NOT block line of sight",
                CoverHelper.HasLineOfSight(scout, clearTarget));

            // Nothing blocks itself, and nothing at Chebyshev distance <= 1 can be blocked at all.
            var beside = new PF2eVec(5, 4);   // ground tile hard against the wall's west face
            var wallTile = new PF2eVec(6, 4);
            Check("(a) same tile always has line of effect",
                CoverHelper.HasLineOfEffect(beside, beside));
            Check("(a) a tile adjacent to the wall has line of effect INTO the wall's own square",
                CoverHelper.HasLineOfEffect(beside, wallTile));
            Check("(a) two tiles adjacent along the wall face have line of effect",
                CoverHelper.HasLineOfEffect(beside, new PF2eVec(5, 5)));

            // A creature pressed against the wall must not shadow itself.
            session.Grid.MoveCreature(hero, beside);
            session.Grid.MoveCreature(target, new PF2eVec(5, 8));
            Check("(a) hugging the wall grants no cover along a clear parallel line",
                CoverHelper.GetPositionalCover(hero, target) == CoverLevel.None
                && CoverHelper.HasLineOfSight(hero, target));
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (b) Area spells ───────────────────────────

    /// <summary>
    /// The engine-wide behaviour this milestone switches on. Same barrier board; the checks run through
    /// the two places spell targeting actually reaches <c>AreaCalculator.GetAreaTiles</c>:
    /// <see cref="PlayerActionExecutor.GetAreaTemplateTiles"/> (the hover preview) and
    /// <see cref="PlayerActionExecutor.ExecuteCast"/> → <c>BuildAreaResult</c> (the resolved cast).
    /// </summary>
    private async Task Scenario_B_AreaSpells(DataManager data)
    {
        GD.Print("-------------------- (b) area spells across a wall --------------------");
        var layout = BarrierLayout();

        var scholar = PresetCharacters.BuildScholar(level: 2, teamId: 1);
        var nearGoblin = MakeGoblin(data);  // in front of the wall
        var farGoblin = MakeGoblin(data);   // behind the wall

        var session = StartSession(layout, "(b)",
            party: new() { (scholar, new PF2eVec(8, 4)) },
            enemies: new() { (nearGoblin, new PF2eVec(7, 4)), (farGoblin, new PF2eVec(5, 4)) },
            seed: 11);
        try
        {
            var exec = session.PlayerActions;

            // ── Burst template: aimed east of the wall, it must lose exactly the tiles west of it.
            var burstOrigin = new PF2eVec(9, 4);
            var spell = PresetSpells.Get(PresetSpells.FireballId);
            int radius = spell.Area!.SizeInTiles;
            var unfiltered = AreaCalculator.GetBurstTiles(burstOrigin, radius);
            var filtered = exec.GetAreaTemplateTiles(scholar, PresetSpells.FireballId, burstOrigin);
            var kept = new HashSet<PF2eVec>(filtered);

            int removed = 0;
            bool removedAllBehind = true;
            bool keptOnlyInFront = true;
            foreach (var tile in unfiltered)
            {
                bool behindWall = tile.x < WallColumn;
                if (kept.Contains(tile))
                {
                    if (behindWall) keptOnlyInFront = false;
                }
                else
                {
                    removed++;
                    if (!behindWall) removedAllBehind = false;
                }
            }

            Check("(b) burst template loses tiles to the wall", removed > 0);
            Check("(b) every tile the burst kept is in front of the wall", keptOnlyInFront);
            Check("(b) every tile the burst dropped is behind the wall", removedAllBehind);
            GD.Print($"        · burst r={radius} at ({burstOrigin.x},{burstOrigin.y}): "
                     + $"{unfiltered.Count} template tiles, {filtered.Count} kept, {removed} dropped");

            // ── Cone template: the shape reaches both goblins, LOE keeps only the near one.
            var coneAim = farGoblin.GridPosition;
            var coneShape = AreaCalculator.GetConeTiles(
                scholar.GridPosition, coneAim - scholar.GridPosition,
                PresetSpells.Get(PresetSpells.BreatheFireId).Area!.SizeInTiles);
            var coneShapeSet = new HashSet<PF2eVec>(coneShape);
            Check("(b) the unfiltered cone covers both goblins",
                coneShapeSet.Contains(nearGoblin.GridPosition) && coneShapeSet.Contains(farGoblin.GridPosition));

            var coneTiles = new HashSet<PF2eVec>(
                exec.GetAreaTemplateTiles(scholar, PresetSpells.BreatheFireId, coneAim));
            Check("(b) cone template keeps the goblin in front of the wall",
                coneTiles.Contains(nearGoblin.GridPosition));
            Check("(b) cone template drops the goblin behind the wall",
                !coneTiles.Contains(farGoblin.GridPosition));

            // ── Live cast: the resolved spell must only touch the reachable goblin.
            scholar.Actions.RefillActions();
            var resolved = await CaptureCast(() =>
                exec.ExecuteCast(scholar, PresetSpells.BreatheFireId, -1, coneAim));

            var hit = new HashSet<ICharacter>();
            if (resolved?.TargetResults != null)
                foreach (var tr in resolved.TargetResults)
                    if (tr.Target != null) hit.Add(tr.Target);

            Check("(b) live cone cast resolved", resolved != null);
            Check("(b) live cone cast hits the goblin in front of the wall", hit.Contains(nearGoblin));
            Check("(b) live cone cast does NOT hit the goblin behind the wall", !hit.Contains(farGoblin));
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (c) Cover pillar ───────────────────────────

    /// <summary>
    /// 11x5 board with one standable Cover tile at (5,2). A pillar is not a barrier: standard cover,
    /// full sight, full effect.
    /// </summary>
    private void Scenario_C_CoverPillar(DataManager data)
    {
        GD.Print("-------------------- (c) cover pillar --------------------");
        var layout = Blank(11, 5);
        PaintCover(layout, 5, 2, LowWall);

        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var beside = PresetCharacters.BuildScout(level: 2, teamId: 1);
        var target = MakeGoblin(data);

        var session = StartSession(layout, "(c)",
            party: new() { (hero, new PF2eVec(2, 2)), (beside, new PF2eVec(4, 2)) },
            enemies: new() { (target, new PF2eVec(8, 2)) },
            seed: 21);
        try
        {
            Check("(c) cover tile between combatants grants standard cover",
                CoverHelper.GetPositionalCover!(hero, target) == CoverLevel.Standard);
            Check("(c) cover tile does not block line of sight",
                CoverHelper.HasLineOfSight!(hero, target));
            Check("(c) cover tile does not block line of effect",
                CoverHelper.HasLineOfEffect!(hero.GridPosition, target.GridPosition));

            Check("(c) creature beside the pillar counts as adjacent to terrain cover",
                CoverHelper.IsAdjacentToTerrainCover!(beside));
            Check("(c) creature away from the pillar does not",
                !CoverHelper.IsAdjacentToTerrainCover(hero));

            // Standing on the pillar must not cover the creature standing on it.
            session.Grid.MoveCreature(hero, new PF2eVec(5, 2));
            Check("(c) standing ON the cover tile grants no cover to its occupant",
                CoverHelper.GetPositionalCover(hero, target) == CoverLevel.None);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (d) Elevation ───────────────────────────

    /// <summary>
    /// 13x9 board: a plateau four elevations up on the west edge, a LOW wall (one elevation) at x=6,
    /// open ground between. The same target, the same wall, two shooters at different heights.
    /// </summary>
    private void Scenario_D_Elevation(DataManager data)
    {
        GD.Print("-------------------- (d) elevation over a low wall --------------------");
        var layout = Blank(13, 9);
        for (int y = 0; y < 9; y++)
        {
            for (int x = 0; x <= 3; x++) PaintGround(layout, x, y, PlateauElevation);
            PaintWall(layout, 6, y, LowWall);
        }

        var lowShooter = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var highShooter = PresetCharacters.BuildScout(level: 2, teamId: 1);
        var target = MakeGoblin(data);

        var session = StartSession(layout, "(d)",
            party: new() { (lowShooter, new PF2eVec(4, 4)), (highShooter, new PF2eVec(3, 4)) },
            enemies: new() { (target, new PF2eVec(10, 4)) },
            seed: 31);
        try
        {
            var grid = session.Grid;
            Check("(d) plateau tile really is four elevations up",
                grid.GetTile(new PF2eVec(3, 4))!.EffectiveHeight
                == PlateauElevation * TileCornerHeights.UnitsPerElevation);
            Check("(d) the wall really is one elevation tall",
                grid.GetTile(new PF2eVec(6, 4))!.CornerHeights.MaxHeight == LowWall);

            Check("(d) shot from ground level is blocked by the low wall",
                !CoverHelper.HasLineOfSight!(lowShooter, target));
            Check("(d) shot from ground level takes standard cover from it",
                CoverHelper.GetPositionalCover!(lowShooter, target) == CoverLevel.Standard);
            Check("(d) area effect from ground level cannot cross the low wall",
                !CoverHelper.HasLineOfEffect!(lowShooter.GridPosition, target.GridPosition));

            Check("(d) shot from the plateau clears the low wall (line of sight restored)",
                CoverHelper.HasLineOfSight(highShooter, target));
            Check("(d) shot from the plateau takes no cover from it",
                CoverHelper.GetPositionalCover(highShooter, target) == CoverLevel.None);
            Check("(d) area effect from the plateau clears the low wall",
                CoverHelper.HasLineOfEffect(highShooter.GridPosition, target.GridPosition));
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (e) Flat equivalence ───────────────────────────

    /// <summary>
    /// The stub-equivalence proof, plus the evidence for why the gate in
    /// <see cref="SpatialDelegates.Wire"/> is not redundant.
    /// </summary>
    private void Scenario_E_FlatEquivalence(DataManager data)
    {
        GD.Print("-------------------- (e) flat board equivalence --------------------");

        var hero = PresetCharacters.BuildPlayer(level: 2, teamId: 1);
        var blocker = MakeGoblin(data);
        var target = MakeGoblin(data);

        var session = StartSession(null, "(e)",
            party: new() { (hero, new PF2eVec(2, 2)) },
            enemies: new() { (blocker, new PF2eVec(4, 2)), (target, new PF2eVec(6, 2)) },
            seed: 41);
        try
        {
            Check("(e) CreateFlat grid reports no spatial features",
                !TerrainSpatial.HasSpatialFeatures(session.Grid));

            Check("(e) flat board keeps the open cover stub",
                CoverHelper.GetPositionalCover!(hero, target) == CoverLevel.None);
            Check("(e) flat board keeps the open line-of-sight stub",
                CoverHelper.HasLineOfSight!(hero, target));
            Check("(e) flat board keeps the open line-of-effect stub",
                CoverHelper.HasLineOfEffect!(hero.GridPosition, target.GridPosition));
            Check("(e) flat board reports no adjacent terrain cover",
                !CoverHelper.IsAdjacentToTerrainCover!(hero));

            // The whole point: with the stub in place, no area template loses a tile.
            var origin = new PF2eVec(6, 5);
            var spell = PresetSpells.Get(PresetSpells.FireballId);
            int unfiltered = AreaCalculator.GetBurstTiles(origin, spell.Area!.SizeInTiles).Count;
            int filtered = session.PlayerActions
                .GetAreaTemplateTiles(hero, PresetSpells.FireballId, origin).Count;
            Check("(e) flat board loses no area-template tiles to LOE filtering",
                filtered == unfiltered);

            // Why the gate exists: the real implementation over this same flat grid is NOT a no-op —
            // it hands out creature cover, which is a live balance change and belongs in its own change.
            var real = new TerrainSpatial(session.Grid);
            Check("(e) terrain queries over a flat grid are provably open (sight)",
                real.HasLineOfSight(hero, target));
            Check("(e) terrain queries over a flat grid are provably open (effect)",
                real.HasLineOfEffect(hero.GridPosition, target.GridPosition));
            Check("(e) but the real implementation WOULD grant creature cover on a flat board "
                  + "— the gate is load-bearing",
                real.GetPositionalCover(hero, target) == CoverLevel.Lesser);
        }
        finally { session.Teardown(); }
    }

    // ─────────────────────────── (f) Generated sewer ───────────────────────────

    /// <summary>
    /// Real generated maps, pinned seeds. Two invariants that must hold on any board: walls actually
    /// stop something, and adjacency never does (Bresenham has no intervening tiles between neighbours,
    /// so a creature can always be hit by the effect in the square next to it).
    /// </summary>
    private void Scenario_F_GeneratedSewer()
    {
        GD.Print("-------------------- (f) generated sewer maps --------------------");

        foreach (int seed in SewerSeeds)
        {
            var (layout, grid) = MapGenerator.GenerateBattle("sewer", seed);
            if (layout == null || grid == null)
            {
                Check($"(f) seed {seed}: GenerateBattle produced a map", false);
                continue;
            }

            SpatialDelegates.Wire(grid);
            try
            {
                Check($"(f) seed {seed}: generated grid wires the real delegates",
                    TerrainSpatial.HasSpatialFeatures(grid));

                var walkable = new List<PF2eVec>();
                foreach (var tile in grid.AllTiles)
                    if (!tile.Inaccessible) walkable.Add(tile.GridPosition);

                var loe = CoverHelper.HasLineOfEffect!;

                int blocked = 0;
                foreach (var from in walkable)
                    foreach (var to in walkable)
                        if (!loe(from, to)) blocked++;

                int adjacentBlocked = 0;
                PF2eVec worstAdjacentFrom = default;
                PF2eVec worstAdjacentTo = default;
                foreach (var from in walkable)
                {
                    foreach (var to in grid.GetNeighbors(from))
                    {
                        if (grid.GetTile(to)!.Inaccessible) continue;
                        if (loe(from, to)) continue;
                        adjacentBlocked++;
                        worstAdjacentFrom = from;
                        worstAdjacentTo = to;
                    }
                }

                Check($"(f) seed {seed}: some pair of walkable tiles has blocked line of effect",
                    blocked > 0);
                Check($"(f) seed {seed}: no pair of ADJACENT walkable tiles has blocked line of effect",
                    adjacentBlocked == 0);
                if (adjacentBlocked > 0)
                    GD.Print($"        · e.g. ({worstAdjacentFrom.x},{worstAdjacentFrom.y}) -> "
                             + $"({worstAdjacentTo.x},{worstAdjacentTo.y})");

                GD.Print($"        · {layout.Width}x{layout.Height}, {walkable.Count} walkable tiles, "
                         + $"{blocked} of {walkable.Count * walkable.Count} ordered pairs blocked");
            }
            finally { SpatialDelegates.Unwire(); }
        }
    }

    // ─────────────────────────── Layout painting ───────────────────────────

    /// <summary>Column the barrier board's wall stands in.</summary>
    private const int WallColumn = 6;

    /// <summary>15x9 open ground with one full-height wall column at <see cref="WallColumn"/>.</summary>
    private static MapLayout BarrierLayout()
    {
        var layout = Blank(15, 9);
        for (int y = 0; y < 9; y++)
            PaintWall(layout, WallColumn, y, TallWall);
        return layout;
    }

    /// <summary>
    /// A flat sheet of Ground at elevation 0. Arrays are set directly rather than generated, so no
    /// biome tuning can move a feature out from under an assertion.
    /// </summary>
    private static MapLayout Blank(int width, int height)
    {
        var layout = new MapLayout { Name = $"spike_{width}x{height}", Seed = 0 };
        layout.Initialize(width, height);
        for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++)
                PaintGround(layout, x, y, 0);
        return layout;
    }

    private static void PaintGround(MapLayout layout, int x, int y, int elevation)
        => Paint(layout, x, y, TileRole.Ground, SurfaceType.Stone,
            elevation, elevation * TileCornerHeights.UnitsPerElevation);

    private static void PaintWall(MapLayout layout, int x, int y, int cornerHeight)
        => Paint(layout, x, y, TileRole.Wall, SurfaceType.Stone,
            TileCornerHeights.ToElevationsFloor(cornerHeight), cornerHeight);

    private static void PaintCover(MapLayout layout, int x, int y, int cornerHeight)
        => Paint(layout, x, y, TileRole.Cover, SurfaceType.Stone,
            TileCornerHeights.ToElevationsFloor(cornerHeight), cornerHeight);

    private static void Paint(
        MapLayout layout, int x, int y, TileRole role, SurfaceType surface, int elevation, int cornerHeight)
    {
        layout.SetTile(x, y, role);
        layout.SetSurface(x, y, surface);
        layout.SetElevation(x, y, elevation);
        layout.SetSlope(x, y, SlopeType.Flat, 0);
        layout.SetCornerHeights(x, y, TileCornerHeights.Flat(cornerHeight));
    }

    // ─────────────────────────── Harness helpers ───────────────────────────

    /// <summary>
    /// Start a real <see cref="CombatSession"/> — the whole point being that it runs
    /// <see cref="SpatialDelegates.Wire"/> for us. A null layout means the legacy flat board.
    /// Any deployment correction is a bug in the hand-rolled board, so it is reported as a failure
    /// rather than silently relocating a probe.
    /// </summary>
    private CombatSession StartSession(
        MapLayout? layout, string tag,
        List<(ICharacter, PF2eVec)> party, List<(ICharacter, PF2eVec)> enemies, int seed)
    {
        var setup = layout != null
            ? new CombatSetup { Layout = layout, BiomeId = "forest", RngSeed = seed }
            : new CombatSetup { GridWidth = 12, GridHeight = 10, RngSeed = seed };

        setup.Party.AddRange(party);
        setup.Enemies.AddRange(enemies);

        var session = new CombatSession();
        session.Setup(setup);
        session.SetPresenter(_ => Task.CompletedTask);

        foreach (var (c, _) in party) CombatantRegistry.Instance.Register(c);
        foreach (var (c, _) in enemies) CombatantRegistry.Instance.Register(c);

        Check($"{tag} deployment needed no correction", session.SetupCorrections.Count == 0);
        foreach (string correction in session.SetupCorrections) GD.Print($"        · {correction}");

        return session;
    }

    private static ICharacter MakeGoblin(DataManager data)
        => CreatureFactory.Create(data.ResolveCreature(EncounterTables.GoblinWarrior)!, teamId: 2);

    /// <summary>Capture the resolved SpellContext of a single cast (mirrors SpellCastSpike).</summary>
    private static async Task<SpellContext?> CaptureCast(Func<Task<bool>> cast)
    {
        SpellContext? captured = null;
        void Capture(SpellCompletionEvent e) => captured = e.Context;
        SpellCastAction.OnSpellResolved += Capture;
        try { await cast(); }
        finally { SpellCastAction.OnSpellResolved -= Capture; }
        return captured;
    }
}
