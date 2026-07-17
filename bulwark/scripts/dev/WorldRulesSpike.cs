using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Territory;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless verification of the world-rules safety pass ("the map is the law", Stardew semantics):
///  (1) FarmSystem predicate injection, pure C#: tilling rejected where the world says no
///      (non-farmable / occupied), permissive default without a world, staging chain intact
///      (water needs a crop, plant needs Tilled — and Tilled is unreachable on rejected cells).
///  (2) Placeable collision in a minimal physics world: a resource node body blocks a
///      CharacterBody2D, a depleted node stops blocking, the transition sign / lever carry solid
///      bodies, a roamer is stopped by a wall, and roamer→player contact still fires the
///      encounter event (the ContactTrigger Area2D senses the player body, so a blocking wall
///      cannot eat it).
///  (3) The REAL outpost scene: the farm-world predicate is bound (tilling off the map / on
///      non-farmable ground / under a placed prop fails through GameState), the wall baker
///      covered every Walls cell without physics (counts match, no double bake), and the player
///      body is physically stopped by the perimeter barrier and a painted wall cell.
///  (4) The REAL forest scene: baker + barrier built there too (shared base), counts reported.
/// Runs headless — physics steps via awaited physics frames. Prints [PASS]/[FAIL] per check and a
/// final SPIKE RESULT line.
/// </summary>
public partial class WorldRulesSpike : SpikeBase
{
    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== WORLD RULES SPIKE ====================");

        var gs = GetNodeOrNull<GameState>("/root/GameState");
        bool clockWasPaused = gs?.Clock.IsPaused ?? false;
        if (gs != null)
            gs.Clock.SetPaused("spike", true); // freeze the loaded save's clock (no mid-spike fatigue latch / dawn rollover)

        try
        {
            TestFarmPredicateInjection();
            await TestPlaceableCollision();
            if (gs != null)
            {
                await TestRealOutpost(gs);
                await TestRealForest();
                Check("farm predicate cleared after the outpost scene exited (permissive again)",
                    gs.TillPlot(new Vector2I(9999, 9999)));
            }
            else
            {
                Check("GameState autoload present", false);
            }
        }
        catch (Exception e)
        {
            GD.PushError($"[WorldRulesSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            if (gs != null)
                gs.Clock.SetPaused("spike", clockWasPaused);
        }

        FinishAndQuit("WorldRulesSpike");
    }

    // ─────────────────────── (1) Pure C# — predicate injection ───────────────────────

    private void TestFarmPredicateInjection()
    {
        GD.Print("-------------------- (1) FarmSystem predicate --------------------");
        var inv = new Inventory();
        var clock = new DayClock(); // Spring day 1
        var farm = new FarmSystem(inv, () => clock.Season);

        // World truth stand-in: only (1,1) and (2,2) are farmable, (2,2) is occupied.
        var farmable = new[] { new Vector2I(1, 1), new Vector2I(2, 2) };
        var occupied = new[] { new Vector2I(2, 2) };
        farm.SetTillable(c => farmable.Contains(c) && !occupied.Contains(c));

        Check("till rejected on non-farmable cell", !farm.TillPlot(new Vector2I(5, 5)));
        Check("till rejected on occupied cell", !farm.TillPlot(new Vector2I(2, 2)));
        Check("till accepted on free farmable cell", farm.TillPlot(new Vector2I(1, 1)));
        Check("rejected cells stay untouched (no plot created)", farm.GetPlot(new Vector2I(5, 5)) == null);

        // Staging chain: nothing bypasses it, and Tilled is unreachable on rejected cells.
        inv.AddItem("turnip_seed", 2);
        Check("water rejected on untilled ground", !farm.WaterPlot(new Vector2I(3, 3)));
        Check("plant rejected on non-farmable cell (no Tilled stage by construction)",
            !farm.PlantCrop(new Vector2I(5, 5), "turnip"));
        Check("plant rejected on tilled-less farmable cell", !farm.PlantCrop(new Vector2I(2, 2), "turnip"));
        Check("water rejected on tilled-but-empty plot", !farm.WaterPlot(new Vector2I(1, 1)));
        Check("plant accepted on tilled unwatered soil (Stardew-legal)",
            farm.PlantCrop(new Vector2I(1, 1), "turnip"));

        // Back-compat contract: no injected world = permissive (pure tests, headless tooling).
        var bare = new FarmSystem(new Inventory(), () => clock.Season);
        Check("no predicate → tilling anywhere (permissive default)", bare.TillPlot(new Vector2I(7, 7)));
        farm.SetTillable(null);
        Check("cleared predicate → permissive again", farm.TillPlot(new Vector2I(8, 8)));
    }

    // ─────────────────────── (2) Placeable collision (mini physics world) ───────────────────────

    private async Task TestPlaceableCollision()
    {
        GD.Print("-------------------- (2) Placeable collision --------------------");

        // (2a) Resource node body blocks a moving CharacterBody2D (the roamer doubles as probe).
        var world = new Node2D { Name = "ProbeWorld" };
        AddChild(world);

        var nodeScene = GD.Load<PackedScene>("res://scenes/territory/resource_node.tscn");
        var view = nodeScene.Instantiate<ResourceNodeView>();
        view.Position = new Vector2(60, 0);
        world.AddChild(view);

        var bait = new Node2D { Name = "Bait", Position = new Vector2(160, 0) };
        world.AddChild(bait);

        var roamerScene = GD.Load<PackedScene>("res://scenes/territory/roaming_enemy.tscn");
        var roamer = roamerScene.Instantiate<RoamingEnemy>();
        roamer.Position = Vector2.Zero;
        world.AddChild(roamer);
        roamer.Setup("probe", bait);

        bool contact = false;
        roamer.PlayerContacted += _ => contact = true;

        await PhysicsFrames(60); // 1s chase at 95 px/s would reach x≈95 unblocked
        Check($"body chasing past a resource node is blocked by it (x={roamer.Position.X:0.0})",
            roamer.Position.X < 50f);
        Check("blocked body never came within contact range (no encounter)", !contact);

        // (2b) Depleted node stops blocking (collision disabled with the visual).
        view.SetDepleted(true);
        await PhysicsFrames(1);
        var bodyShape = view.GetNodeOrNull<CollisionShape2D>("%BodyShape");
        Check("depleted node disables its collision shape", bodyShape is { Disabled: true });
        view.SetDepleted(false);
        await PhysicsFrames(1);
        Check("respawned node re-enables its collision shape", bodyShape is { Disabled: false });

        // (2c) Transition sign and lever carry solid bodies now.
        var sign = GD.Load<PackedScene>("res://scenes/territory/transition_sign.tscn").Instantiate<TransitionSign>();
        world.AddChild(sign);
        Check("transition sign has a solid post body", sign.GetNodeOrNull<StaticBody2D>("PostBody") != null);
        var lever = GD.Load<PackedScene>("res://scenes/props/lever.tscn").Instantiate<Node2D>();
        world.AddChild(lever);
        Check("lever prop has a solid base body", lever.GetNodeOrNull<StaticBody2D>("Base") != null);
        world.QueueFree();
        await PhysicsFrames(1);

        // (2d) Roamer vs wall: wander/chase movement is MoveAndSlide, so a StaticBody2D stops it.
        var world2 = new Node2D { Name = "ProbeWorld2" };
        AddChild(world2);
        var wall = new StaticBody2D { Name = "Wall", Position = new Vector2(60, 0) };
        wall.AddChild(new CollisionShape2D { Shape = new RectangleShape2D { Size = new Vector2(12, 96) } });
        world2.AddChild(wall);
        var bait2 = new Node2D { Position = new Vector2(160, 0) };
        world2.AddChild(bait2);
        var roamer2 = roamerScene.Instantiate<RoamingEnemy>();
        roamer2.Position = Vector2.Zero;
        world2.AddChild(roamer2);
        roamer2.Setup("wall_probe", bait2);
        bool contact2 = false;
        roamer2.PlayerContacted += _ => contact2 = true;

        await PhysicsFrames(60);
        Check($"roamer stepping toward a wall is blocked (x={roamer2.Position.X:0.0})",
            roamer2.Position.X < 52f);
        Check("wall-blocked roamer fired no contact", !contact2);

        // (2e) Contact seam intact: the ContactTrigger Area2D fires on the player BODY entering (not a
        // bare marker), so the probe needs a real avatar — a roamer whose trigger overlaps it raises
        // the encounter even when a wall would block the body's approach.
        string? contactId = null;
        var playerBody = GD.Load<PackedScene>("res://scenes/cozy/player.tscn").Instantiate<PlayerController>();
        playerBody.Position = new Vector2(160, 0);
        world2.AddChild(playerBody);
        var roamer3 = roamerScene.Instantiate<RoamingEnemy>();
        roamer3.Position = new Vector2(135, 0); // 25 px from the player — inside the contact trigger radius (30)
        world2.AddChild(roamer3);
        roamer3.Setup("contact_probe", playerBody);
        roamer3.PlayerContacted += id => contactId = id;

        await PhysicsFrames(3);
        Check("roamer contact with the player body fires the encounter event", contactId == "contact_probe");

        world2.QueueFree();
        await PhysicsFrames(1);
    }

    // ─────────────────────── (3) Real outpost — binding, baker, physics ───────────────────────

    private async Task TestRealOutpost(GameState gs)
    {
        GD.Print("-------------------- (3) Real outpost scene --------------------");
        var outpost = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn").Instantiate<OutpostScene>();

        // Runtime-only water paint, BEFORE the instance enters the tree (so _Ready's bake sees it;
        // nothing is written to disk — this instance is freed at the end): one open water cell
        // (must bake + physically block) and one overlay-bridged water cell (must NOT bake — the
        // bridge contract: a tile painted on GroundDecor/Props over water = passable crossing).
        var groundPre = outpost.GetNodeOrNull<TileMapLayer>("%Ground");
        var decorPre = outpost.GetNodeOrNull<TileMapLayer>("%GroundDecor");
        Vector2I? waterCell = null, bridgeCell = null;
        if (groundPre?.TileSet != null && decorPre != null
            && FindWaterTile(outpost, groundPre.TileSet, out int waterSrc, out Vector2I waterAtlas))
        {
            var picked = PickQuietCells(groundPre, decorPre,
                outpost.GetNodeOrNull<TileMapLayer>("%Walls"),
                outpost.GetNodeOrNull<TileMapLayer>("%Props"), waterSrc, 2);
            if (picked.Count == 2)
            {
                waterCell = picked[0];
                bridgeCell = picked[1];
                groundPre.SetCell(picked[0], waterSrc, waterAtlas);
                groundPre.SetCell(picked[1], waterSrc, waterAtlas);
                decorPre.SetCell(picked[1], waterSrc, waterAtlas); // any overlay tile = a bridge
            }
        }
        Check("staged runtime water cells for the bake (open + bridged)",
            waterCell != null && bridgeCell != null);

        AddChild(outpost);
        await PhysicsFrames(2);

        // --- Farm-world binding through GameState ---
        Check("tilling off the painted map rejected (predicate bound)",
            !gs.TillPlot(new Vector2I(-999, -999)));

        var ground = outpost.Ground;
        Vector2I? nonFarmable = null;
        if (ground != null)
        {
            foreach (Vector2I c in ground.GetUsedCells())
            {
                if (outpost.IsFarmable(c))
                    continue;
                nonFarmable = c;
                break;
            }
        }
        Check("found a painted non-farmable cell to test against", nonFarmable != null);
        if (nonFarmable is { } bad)
            Check("till rejected on painted non-farmable ground", !gs.TillPlot(bad));

        var tillable = outpost.FarmableCells()
            .Where(c => outpost.IsTillable(c) && gs.Farm.GetPlot(c) == null)
            .Take(2).ToList();
        Check($"found free tillable soil cells ({tillable.Count})", tillable.Count == 2);
        if (tillable.Count == 2)
        {
            Check("plant rejected on farmable-but-untilled soil (staging intact)",
                !gs.PlantCrop(tillable[0], "turnip"));
            Check("till accepted on free farmable soil", gs.TillPlot(tillable[0]));

            // Occupancy: a placed prop claims its cell even though the soil is farmable.
            var chest = GD.Load<PackedScene>("res://scenes/props/chest.tscn").Instantiate<Node2D>();
            outpost.AddChild(chest);
            chest.GlobalPosition = outpost.CellToWorld(tillable[1]);
            Check("prop-occupied farmable cell is not tillable", !outpost.IsTillable(tillable[1]));
            Check("till rejected on the occupied cell through GameState", !gs.TillPlot(tillable[1]));
            chest.QueueFree();
            await PhysicsFrames(1);
            Check("cell tillable again once the prop is gone", gs.TillPlot(tillable[1]));
        }

        // --- Wall baker coverage ---
        var walls = outpost.Walls;
        Check("bake report covers the Walls layer", outpost.BakeReport.ContainsKey("Walls"));
        if (walls != null && outpost.BakeReport.TryGetValue("Walls", out var report))
        {
            int expectNative = 0, expectBaked = 0;
            foreach (Vector2I cell in walls.GetUsedCells())
            {
                if (walls.GetCellTileData(cell) is not { } td) continue;
                if (td.GetCollisionPolygonsCount(0) > 0) expectNative++;
                else expectBaked++;
            }
            GD.Print($"  [info] outpost Walls: {report.Native} tile-physics, {report.Baked} baked "
                     + $"(recount {expectNative}/{expectBaked})");
            Check("baked exactly the physics-less cells (no double bake)",
                report.Native == expectNative && report.Baked == expectBaked);
            var bakedBody = walls.GetNodeOrNull<StaticBody2D>("BakedWallCollision");
            Check("one runtime body holds the baked rects (count matches)",
                bakedBody != null && bakedBody.GetChildCount() == report.Baked);
        }
        Check("perimeter barrier spawned with 4 walls",
            outpost.GetNodeOrNull<Node2D>("PerimeterBarrier")?.GetChildCount() == 4);

        // --- Water baker coverage (water blocks movement; overlay = bridge) ---
        Check("bake report covers the Water pass", outpost.BakeReport.ContainsKey("Water"));
        var waterBody = ground?.GetNodeOrNull<StaticBody2D>("BakedWaterCollision");
        Check("BakedWaterCollision body exists under Ground", waterBody != null);
        if (ground != null && waterBody != null && outpost.BakeReport.TryGetValue("Water", out var wReport))
        {
            var (expNative, expBaked, expBridged) = RecountWater(outpost, ground,
                outpost.GetNodeOrNull<TileMapLayer>("%GroundDecor"), outpost.Props);
            GD.Print($"  [info] outpost Water: {wReport.Native} tile-physics, {wReport.Baked} baked, "
                     + $"{outpost.WaterBridgedCells} bridged (recount {expNative}/{expBaked}/{expBridged})");
            Check("water bake counts match an independent recount",
                wReport.Native == expNative && wReport.Baked == expBaked
                && outpost.WaterBridgedCells == expBridged);
            Check("one runtime body holds the water rects (count matches)",
                waterBody.GetChildCount() == wReport.Baked);

            if (waterCell is { } wcell)
                Check("runtime-painted open water cell got a baked rect",
                    HasShapeAt(waterBody, ground.MapToLocal(wcell)));
            if (bridgeCell is { } bcell)
                Check("overlay-bridged water cell was NOT baked (bridge contract)",
                    !HasShapeAt(waterBody, ground.MapToLocal(bcell)));
            Check("the staged bridge cell counted as bridged", outpost.WaterBridgedCells >= 1);
        }

        // --- Player physics: input sanity, perimeter stop, painted-wall stop ---
        var player = outpost.GetNodeOrNull<PlayerController>("Player");
        Check("outpost spawned the player", player != null);
        if (player != null && ground != null)
        {
            var tillableList = tillable.Count > 0 ? tillable : outpost.FarmableCells().Take(1).ToList();
            if (tillableList.Count > 0)
            {
                // Sanity: synthesized input moves the body at all (guards the two stop-asserts).
                player.GlobalPosition = outpost.CellToWorld(tillableList[0]);
                Vector2 start = player.GlobalPosition;
                Input.ActionPress("move_left");
                await PhysicsFrames(20);
                Input.ActionRelease("move_left");
                Check($"synthesized input moves the player ({start.DistanceTo(player.GlobalPosition):0.0} px)",
                    start.DistanceTo(player.GlobalPosition) > 10f);
            }

            // Perimeter: teleport to the westmost painted column and push off the map.
            Rect2I used = ground.GetUsedRect();
            Vector2I? edgeCell = null;
            for (int y = used.Position.Y; y < used.End.Y && edgeCell == null; y++)
            {
                var c = new Vector2I(used.Position.X, y);
                if (ground.GetCellSourceId(c) != -1 && CellIsPhysicallyFree(outpost, c))
                    edgeCell = c;
            }
            Check("found a free west-edge cell for the perimeter test", edgeCell != null);
            if (edgeCell is { } edge)
            {
                player.GlobalPosition = outpost.CellToWorld(edge);
                float edgeX = outpost.CellToWorld(edge).X;
                Input.ActionPress("move_left");
                await PhysicsFrames(60);
                Input.ActionRelease("move_left");
                await PhysicsFrames(2);
                Check($"perimeter barrier stops the player at the map edge (x={player.GlobalPosition.X:0.0}, edge {edgeX:0.0})",
                    player.GlobalPosition.X >= edgeX - 20f);
            }

            // Painted wall: approach a Walls cell from a free cell below it, push up, never enter it.
            Vector2I? wallCell = null;
            if (walls != null)
            {
                foreach (Vector2I w in walls.GetUsedCells())
                {
                    var approach = w + new Vector2I(0, 1);
                    if (ground.GetCellSourceId(approach) != -1 && CellIsPhysicallyFree(outpost, approach))
                    {
                        wallCell = w;
                        break;
                    }
                }
            }
            Check("found a painted wall cell with a free approach", wallCell != null);
            if (wallCell is { } wc)
            {
                player.GlobalPosition = outpost.CellToWorld(wc + new Vector2I(0, 1));
                Input.ActionPress("move_up");
                await PhysicsFrames(60);
                Input.ActionRelease("move_up");
                await PhysicsFrames(2);
                Check($"painted wall stops the player (ended in cell {outpost.WorldToCell(player.GlobalPosition)}, wall {wc})",
                    outpost.WorldToCell(player.GlobalPosition) != wc);
            }

            // Baked water: approach the runtime-painted water cell from below, push up, never enter.
            if (waterCell is { } wtr)
            {
                player.GlobalPosition = outpost.CellToWorld(wtr + new Vector2I(0, 1));
                Input.ActionPress("move_up");
                await PhysicsFrames(60);
                Input.ActionRelease("move_up");
                await PhysicsFrames(2);
                Check($"baked water stops the player (ended in cell {outpost.WorldToCell(player.GlobalPosition)}, water {wtr})",
                    outpost.WorldToCell(player.GlobalPosition) != wtr);
            }
        }

        outpost.QueueFree();
        await PhysicsFrames(2);
    }

    /// <summary>No Walls/Props tile on the cell — safe to stand a body on for a physics probe.</summary>
    private static bool CellIsPhysicallyFree(OutpostScene outpost, Vector2I cell)
        => (outpost.Walls == null || outpost.Walls.GetCellSourceId(cell) == -1)
           && (outpost.Props == null || outpost.Props.GetCellSourceId(cell) == -1);

    // ─────────────────────── Water helpers ───────────────────────

    /// <summary>Locate a paintable water tile in the tileset by the same identity the baker uses:
    /// the atlas source's texture file name contains "water_a1" (the generated water autotile
    /// atlas convention — sources carry no runtime name, terrain names vary per pack).</summary>
    /// <summary>Find any tile from a water atlas source, using the SCENE's own water identity
    /// (WaterSourceKeywords — covers both the legacy "water_a1" atlas and the pre-expanded
    /// "a1_liquids" sheet the current maps paint with).</summary>
    private static bool FindWaterTile(
        CozyWorldScene scene, TileSet tileSet, out int sourceId, out Vector2I atlasCoords)
    {
        for (int i = 0; i < tileSet.GetSourceCount(); i++)
        {
            int id = tileSet.GetSourceId(i);
            if (tileSet.GetSource(id) is not TileSetAtlasSource atlas || atlas.Texture == null
                || atlas.GetTilesCount() == 0)
                continue;
            if (!scene.IsWaterSource(tileSet, id))
                continue;
            sourceId = id;
            atlasCoords = atlas.GetTileId(0);
            return true;
        }
        sourceId = -1;
        atlasCoords = default;
        return false;
    }

    /// <summary>Pick painted ground cells that are quiet for a physics probe: away from the west
    /// perimeter-probe column and the map's south edge, whole 3x4 neighbourhood (the cell, its
    /// approach below, and their surroundings) painted, water-free, and clear of Walls / Props /
    /// GroundDecor — so the staged water cells never interfere with the other probes, and vice
    /// versa. Picked cells keep 4+ cells of separation from each other.</summary>
    private static List<Vector2I> PickQuietCells(TileMapLayer ground, TileMapLayer decor,
        TileMapLayer? walls, TileMapLayer? props, int waterSrc, int count)
    {
        var picked = new List<Vector2I>();
        Rect2I used = ground.GetUsedRect();
        foreach (Vector2I c in ground.GetUsedCells())
        {
            if (c.X <= used.Position.X + 1 || c.Y >= used.End.Y - 2)
                continue;

            bool ok = true;
            for (int dx = -1; dx <= 1 && ok; dx++)
            {
                for (int dy = -1; dy <= 2 && ok; dy++)
                {
                    Vector2I n = c + new Vector2I(dx, dy);
                    int src = ground.GetCellSourceId(n);
                    if (src == -1 || src == waterSrc
                        || decor.GetCellSourceId(n) != -1
                        || (walls != null && walls.GetCellSourceId(n) != -1)
                        || (props != null && props.GetCellSourceId(n) != -1))
                        ok = false;
                }
            }
            if (!ok)
                continue;

            foreach (Vector2I p in picked)
            {
                if (Math.Abs(p.X - c.X) < 4 && Math.Abs(p.Y - c.Y) < 4)
                {
                    ok = false;
                    break;
                }
            }
            if (!ok)
                continue;

            picked.Add(c);
            if (picked.Count == count)
                break;
        }
        return picked;
    }

    /// <summary>Independent recount of what the water baker should have done: per painted ground
    /// cell whose source texture is a water_a1 atlas — bridged (overlay tile on GroundDecor/Props),
    /// native (tile ships physics), or baked.</summary>
    /// <summary>Independent water recount using the SCENE's own water identity (same
    /// WaterSourceKeywords the baker consults), so the check can never drift from the baker's
    /// source list.</summary>
    private static (int Native, int Baked, int Bridged) RecountWater(CozyWorldScene scene,
        TileMapLayer ground, TileMapLayer? decor, TileMapLayer? props)
    {
        if (ground.TileSet == null)
            return (0, 0, 0);

        int native = 0, baked = 0, bridged = 0;
        foreach (Vector2I cell in ground.GetUsedCells())
        {
            int src = ground.GetCellSourceId(cell);
            if (!scene.IsWaterSource(ground.TileSet, src))
                continue;

            if ((decor != null && decor.GetCellSourceId(cell) != -1)
                || (props != null && props.GetCellSourceId(cell) != -1))
                bridged++;
            else if (ground.GetCellTileData(cell) is { } td && td.GetCollisionPolygonsCount(0) > 0)
                native++;
            else
                baked++;
        }
        return (native, baked, bridged);
    }

    /// <summary>A CollisionShape2D sits (within a pixel) at the given layer-local position.</summary>
    private static bool HasShapeAt(StaticBody2D body, Vector2 localPos)
    {
        foreach (Node child in body.GetChildren())
        {
            if (child is CollisionShape2D shape && shape.Position.DistanceTo(localPos) < 1f)
                return true;
        }
        return false;
    }

    // ─────────────────────── (4) Real forest — shared base built it too ───────────────────────

    private async Task TestRealForest()
    {
        GD.Print("-------------------- (4) Real forest scene --------------------");
        var forest = GD.Load<PackedScene>("res://scenes/territory/forest.tscn").Instantiate<TerritoryScene>();
        AddChild(forest);
        await PhysicsFrames(2);

        Check("forest bake report covers the Walls layer", forest.BakeReport.ContainsKey("Walls"));
        if (forest.BakeReport.TryGetValue("Walls", out var report))
            GD.Print($"  [info] forest Walls: {report.Native} tile-physics, {report.Baked} baked");
        Check("forest perimeter barrier spawned with 4 walls",
            forest.GetNodeOrNull<Node2D>("PerimeterBarrier")?.GetChildCount() == 4);

        // Water pass built by the shared base here too, counts verified against a recount.
        Check("forest bake report covers the Water pass", forest.BakeReport.ContainsKey("Water"));
        var fGround = forest.GetNodeOrNull<TileMapLayer>("%Ground");
        var fWaterBody = fGround?.GetNodeOrNull<StaticBody2D>("BakedWaterCollision");
        Check("forest BakedWaterCollision body exists under Ground", fWaterBody != null);
        if (fGround != null && fWaterBody != null && forest.BakeReport.TryGetValue("Water", out var fWater))
        {
            var (expNative, expBaked, expBridged) = RecountWater(forest, fGround,
                forest.GetNodeOrNull<TileMapLayer>("%GroundDecor"),
                forest.GetNodeOrNull<TileMapLayer>("%Props"));
            GD.Print($"  [info] forest Water: {fWater.Native} tile-physics, {fWater.Baked} baked, "
                     + $"{forest.WaterBridgedCells} bridged (recount {expNative}/{expBaked}/{expBridged})");
            Check("forest water counts match an independent recount (body count too)",
                fWater.Native == expNative && fWater.Baked == expBaked
                && forest.WaterBridgedCells == expBridged
                && fWaterBody.GetChildCount() == fWater.Baked);
        }

        forest.QueueFree();
        await PhysicsFrames(2);
    }

    // ─────────────────────── Harness ───────────────────────

    private async Task PhysicsFrames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
    }
}
