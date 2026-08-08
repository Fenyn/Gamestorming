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
///  (2) Placeable collision in a minimal 3D physics world: a resource node body blocks a
///      CharacterBody3D, a depleted node stops blocking, the transition sign exposes its %Label,
///      a roamer is stopped by a wall, and the roamer→player ContactTrigger seam fires exactly once
///      against the 3D avatar.
///  (3) The REAL 3D outpost scene: the farm-world predicate is bound (tilling outside the farm
///      region / on a cell claimed by a sign or a building footprint / beyond the unlocked farm
///      zone fails through GameState), and the player body is physically stopped by the scene's
///      AUTHORED perimeter wall and by a building's %Footprint. There is no runtime collision
///      baking any more — the world .tscn is the law.
///  (4) The REAL 3D forest territory: authored %Ground perimeter and pond bodies stop the avatar,
///      the marker/trigger contract resolves, world content spawned, and the region-based forage
///      provider reports the authored ground minus the cells the scene's objects occupy.
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

        // (2a) Resource node body blocks a moving CharacterBody3D (the roamer doubles as probe).
        // Distances are METRES now — the roamer chases at 2 m/s and its sight range is 3.8 m.
        var world = NewProbeWorld("ProbeWorld");

        var nodeScene = GD.Load<PackedScene>("res://scenes/territory/resource_node.tscn");
        var view = nodeScene.Instantiate<ResourceNodeView>();
        world.AddChild(view);
        view.Position = new Vector3(1.5f, 0f, 0f);

        var bait = new Node3D { Name = "Bait" };
        world.AddChild(bait);
        bait.Position = new Vector3(3.4f, 0f, 0f);

        var roamerScene = GD.Load<PackedScene>("res://scenes/territory/roaming_enemy.tscn");
        var roamer = roamerScene.Instantiate<RoamingEnemy>();
        world.AddChild(roamer);
        roamer.Position = Vector3.Zero;
        roamer.Setup("probe", bait);

        bool contact = false;
        roamer.PlayerContacted += _ => contact = true;

        await PhysicsFrames(60); // 1 s of chase at 2 m/s would reach x≈2 unblocked
        Check($"body chasing past a resource node is blocked by it (x={roamer.Position.X:0.00} m)",
            roamer.Position.X < 1.1f);
        Check("the node body is what stopped it (bait was never reached)",
            roamer.Position.X < bait.Position.X - 1f);
        Check("no player body in the probe world, so no encounter fired", !contact);

        // (2b) Depleted node stops blocking (collision disabled with the visual).
        view.SetDepleted(true);
        await PhysicsFrames(1);
        var bodyShape = view.GetNodeOrNull<CollisionShape3D>("%BodyShape");
        Check("depleted node disables its collision shape", bodyShape is { Disabled: true });
        view.SetDepleted(false);
        await PhysicsFrames(1);
        Check("respawned node re-enables its collision shape", bodyShape is { Disabled: false });

        // (2c) Transition sign: the 3D greybox post + %Label. It no longer carries its own blocking
        // body — a world scene authors its obstacles in the .tscn. What matters (and is what the host
        // relies on) is that it instantiates and exposes %Label for Bind().
        var sign = GD.Load<PackedScene>("res://scenes/territory/transition_sign.tscn").Instantiate<TransitionSign>();
        AddChild(sign);
        Check("transition sign instantiates as a Node3D with a %Label", sign.GetNodeOrNull<Label3D>("%Label") != null);
        sign.QueueFree();

        world.QueueFree();
        await PhysicsFrames(1);

        // (2d) Roamer vs wall: wander/chase movement is MoveAndSlide, so a StaticBody3D stops it.
        var world2 = NewProbeWorld("ProbeWorld2");
        var wall = new StaticBody3D { Name = "Wall" };
        var wallShape = new CollisionShape3D { Shape = new BoxShape3D { Size = new Vector3(0.4f, 3f, 6f) } };
        wall.AddChild(wallShape);
        world2.AddChild(wall);
        wall.Position = new Vector3(1.5f, 1.5f, 0f);

        var bait2 = new Node3D();
        world2.AddChild(bait2);
        bait2.Position = new Vector3(3.4f, 0f, 0f);
        var roamer2 = roamerScene.Instantiate<RoamingEnemy>();
        world2.AddChild(roamer2);
        roamer2.Position = Vector3.Zero;
        roamer2.Setup("wall_probe", bait2);
        bool contact2 = false;
        roamer2.PlayerContacted += _ => contact2 = true;

        await PhysicsFrames(60);
        Check($"roamer stepping toward a wall is blocked (x={roamer2.Position.X:0.00} m)",
            roamer2.Position.X < 1.4f);
        Check("wall-blocked roamer fired no contact", !contact2);
        world2.QueueFree();
        await PhysicsFrames(1);

        // (2e) The roamer→player contact seam, restored against the 3D avatar: the ContactTrigger
        // Area3D senses the PlayerController body, fires exactly once, and the roamer latches.
        var world3 = NewProbeWorld("ProbeWorld3");
        var player = GD.Load<PackedScene>("res://scenes/cozy/player.tscn").Instantiate<PlayerController>();
        world3.AddChild(player);
        player.Position = Vector3.Zero;

        var roamer3 = roamerScene.Instantiate<RoamingEnemy>();
        world3.AddChild(roamer3);
        roamer3.Position = new Vector3(2.5f, 0f, 0f);
        roamer3.Setup("contact_probe", player);
        int contacts = 0;
        roamer3.PlayerContacted += id => { if (id == "contact_probe") contacts++; };

        await PhysicsFrames(120);
        Check($"roamer walked into the player avatar and raised contact once ({contacts})", contacts == 1);
        Check("contacted roamer froze in place (velocity zeroed)",
            roamer3.Velocity.LengthSquared() < 0.01f);

        // Latched: a lingering overlap must never fire a second encounter.
        await PhysicsFrames(30);
        Check("lingering overlap does not re-fire the contact", contacts == 1);

        world3.QueueFree();
        await PhysicsFrames(1);
    }

    /// <summary>A minimal 3D physics world: a floor StaticBody3D wide enough for the probes to walk
    /// on (the bodies sink 1 m/s by design, so every probe needs ground under it).</summary>
    private Node3D NewProbeWorld(string name)
    {
        var world = new Node3D { Name = name };
        AddChild(world);

        var floor = new StaticBody3D { Name = "Floor" };
        var shape = new CollisionShape3D { Shape = new BoxShape3D { Size = new Vector3(40f, 1f, 40f) } };
        floor.AddChild(shape);
        world.AddChild(floor);
        floor.Position = new Vector3(0f, -0.5f, 0f);
        return world;
    }

    // ─────────────────────── (3) Real 3D outpost — binding + authored collision ───────────────────────

    private async Task TestRealOutpost(GameState gs)
    {
        GD.Print("-------------------- (3) Real outpost scene (3D greybox) --------------------");
        var outpost = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn").Instantiate<OutpostScene>();
        AddChild(outpost);
        await PhysicsFrames(2);

        Check("outpost exposes its authored %Ground body (floor + perimeter, no runtime baking)",
            outpost.Ground != null);
        Check("outpost node contract resolves (%PlayerSpawn / %FarmArea / %GateTrigger / %Bedroll)",
            outpost.PlayerSpawn != null && outpost.FarmArea != null
            && outpost.GateTrigger != null && outpost.Bedroll != null);

        int villagers = 0;
        foreach (Node child in outpost.GetChildren())
            if (child is VillagerNpc) villagers++;
        Check($"the three resident villagers spawned at their %Villager_<id> markers ({villagers})",
            villagers == 3);

        // --- Farm-world binding through GameState ---
        Check("tilling far outside the farm region rejected (predicate bound)",
            !gs.TillPlot(new Vector2I(-999, -999)));

        var farmCells = outpost.FarmableCells().ToList();
        Check($"the outpost exposes a farm region ({farmCells.Count} soil cells)", farmCells.Count > 0);

        var tillableCells = farmCells.Where(outpost.IsTillable).ToList();
        Check($"the unlocked (zone-0) area is a strict subset of the farm region "
              + $"({tillableCells.Count} tillable / {farmCells.Count} soil)",
            tillableCells.Count > 0 && tillableCells.Count < farmCells.Count);

        var free = tillableCells.Where(c => gs.Farm.GetPlot(c) == null).Take(2).ToList();
        Check($"found free tillable soil cells ({free.Count})", free.Count == 2);
        if (free.Count == 2)
        {
            Check("plant rejected on farmable-but-untilled soil (staging intact)",
                !gs.PlantCrop(free[0], "turnip"));
            Check("till accepted on free farm soil", gs.TillPlot(free[0]));

            // Occupancy: a placed world object claims its cell even though the soil is farm soil.
            var sign = GD.Load<PackedScene>("res://scenes/territory/transition_sign.tscn")
                .Instantiate<TransitionSign>();
            outpost.AddChild(sign);
            sign.GlobalPosition = outpost.CellToWorld(free[1]);
            Check("sign-occupied farm cell is not tillable", !outpost.IsTillable(free[1]));
            Check("till rejected on the occupied cell through GameState", !gs.TillPlot(free[1]));
            sign.QueueFree();
            await PhysicsFrames(1);
            Check("cell tillable again once the object is gone", gs.TillPlot(free[1]));
        }

        // Occupancy: a pre-placed building's %Footprint claims every cell it covers.
        var building = FindBuilding(outpost);
        Check("outpost carries pre-placed building instances", building != null);
        var box = FootprintBox(building);
        Check("the building exposes a %Footprint box collider", box != null);
        if (box is { } fp)
        {
            Vector2I underBuilding = outpost.WorldToCell(fp.Centre);
            Check($"a cell under the building footprint is never tillable {underBuilding}",
                !outpost.IsTillable(underBuilding) && !gs.TillPlot(underBuilding));
        }

        // --- Player physics: input sanity, authored perimeter, authored building footprint ---
        var player = outpost.GetNodeOrNull<PlayerController>("Player");
        Check("outpost spawned the player", player != null);
        if (player != null)
        {
            Vector3 start = player.GlobalPosition;
            Input.ActionPress("move_left");
            await PhysicsFrames(20);
            Input.ActionRelease("move_left");
            await PhysicsFrames(2);
            Check($"synthesized input moves the player ({start.DistanceTo(player.GlobalPosition):0.00} m)",
                start.DistanceTo(player.GlobalPosition) > 0.3f);

            // Authored perimeter: start 2 m inside the west wall and push west for ~4.5 m of travel.
            player.GlobalPosition = new Vector3(2f, 0f, 30f);
            await PhysicsFrames(2);
            Input.ActionPress("move_left");
            await PhysicsFrames(90);
            Input.ActionRelease("move_left");
            await PhysicsFrames(2);
            Check($"authored perimeter wall stops the player at the map edge (x={player.GlobalPosition.X:0.00})",
                player.GlobalPosition.X > 0f);

            // Authored building footprint: approach from the south (+Z) and push north (-Z) into it.
            if (box is { } fp2)
            {
                float southFace = fp2.Centre.Z + fp2.HalfExtents.Z;
                player.GlobalPosition = new Vector3(fp2.Centre.X, 0f, southFace + 2.5f);
                await PhysicsFrames(2);
                Input.ActionPress("move_up");
                await PhysicsFrames(90);
                Input.ActionRelease("move_up");
                await PhysicsFrames(2);
                Check($"building footprint stops the player (z={player.GlobalPosition.Z:0.00}, face {southFace:0.00})",
                    player.GlobalPosition.Z > southFace - 0.05f);
            }
        }

        outpost.QueueFree();
        await PhysicsFrames(2);
    }

    /// <summary>The first pre-placed building instance in the outpost.</summary>
    private static BuildingInstance? FindBuilding(Node host)
    {
        foreach (Node child in host.GetChildren())
            if (child is BuildingInstance bi)
                return bi;
        return null;
    }

    /// <summary>World-space centre + half extents of a building's %Footprint box collider.</summary>
    private static (Vector3 Centre, Vector3 HalfExtents)? FootprintBox(BuildingInstance? building)
    {
        var footprint = building?.GetNodeOrNull<StaticBody3D>("%Footprint");
        if (footprint == null)
            return null;
        foreach (Node child in footprint.GetChildren())
            if (child is CollisionShape3D { Disabled: false } cs && cs.Shape is BoxShape3D box)
                return (cs.GlobalPosition, box.Size * 0.5f);
        return null;
    }

    // ─────────────────────── (4) Real 3D forest — authored collision + forage region ───────────────────────

    /// <summary>
    /// The REAL forest territory, mirroring section (3): the scene's own AUTHORED collision is the
    /// law (perimeter wall and the pond body stop the avatar — nothing is baked at runtime), the
    /// marker/trigger node contract resolves, the world content spawned, and the region-based forage
    /// provider reports the authored ground minus the cells the scene's objects occupy.
    /// </summary>
    private async Task TestRealForest()
    {
        GD.Print("-------------------- (4) Real forest scene (3D greybox) --------------------");
        var forest = GD.Load<PackedScene>("res://scenes/territory/forest.tscn").Instantiate<TerritoryScene>();
        AddChild(forest);
        await PhysicsFrames(2);

        Check("forest exposes its authored %Ground body (floor + perimeter, no runtime baking)",
            forest.Ground != null);
        int colliders = 0;
        foreach (Node child in forest.Ground?.GetChildren() ?? new Godot.Collections.Array<Node>())
            if (child is CollisionShape3D) colliders++;
        Check($"the %Ground body carries a floor and four perimeter walls ({colliders} colliders)",
            colliders >= 5);
        Check("forest node contract resolves (%PlayerSpawn / %ExitTrigger / %DeeperTrigger / %WolfTrackedTrigger)",
            forest.PlayerSpawn != null && forest.ExitTrigger != null
            && forest.GetNodeOrNull<Area3D>("%DeeperTrigger") != null
            && forest.GetNodeOrNull<ExplorationTrigger>("%WolfTrackedTrigger") != null);

        int nodeViews = 0, roamers = 0;
        foreach (Node child in forest.GetChildren())
        {
            if (child is ResourceNodeView) nodeViews++;
            else if (child is RoamingEnemy) roamers++;
        }
        int wanderers = Bulwark.Data.Territories.Forest.Roamers.Count(r => !r.IsBoss);
        Check($"marker + placed resource nodes spawned ({nodeViews} >= "
              + $"{Bulwark.Data.Territories.Forest.Nodes.Count} marker nodes)",
            nodeViews >= Bulwark.Data.Territories.Forest.Nodes.Count);
        Check($"roamer bodies spawned ({roamers}/{wanderers})", roamers > 0 && roamers <= wanderers);
        Check("exit sign affordance present (at %ExitTrigger)",
            forest.GetNodeOrNull<TransitionSign>("ExitSign") != null);

        // --- Region forage provider: authored ground minus occupied cells ---
        var cells = forest.ForageCells;
        Rect2I rect = forest.GroundRectCells();
        Check($"the authored floor collider defines the ground rect ({rect.Size.X}x{rect.Size.Y} cells)",
            rect.Size.X > 0 && rect.Size.Y > 0);
        Check("forage cell provider built from the authored region", cells != null);
        if (cells != null)
        {
            var (x0, y0, x1, y1) = cells.PlayableRect;
            Check($"playable rect is the ground rect shrunk by one ring ({x0},{y0})-({x1},{y1})",
                x0 == rect.Position.X + 1 && y0 == rect.Position.Y + 1
                && x1 == rect.End.X - 2 && y1 == rect.End.Y - 2);
            Check("open ground in the middle of the field spawns forage",
                cells.IsOpenGround(20, 17));
            Check("cells outside the authored ground are never open",
                !cells.IsOpenGround(rect.End.X + 3, 10) && !cells.IsOpenGround(-4, 10));

            var exitCell = new Vector2I(
                Mathf.FloorToInt(forest.ExitTrigger!.GlobalPosition.X),
                Mathf.FloorToInt(forest.ExitTrigger.GlobalPosition.Z));
            Check($"the exit trigger's own cell is occupied, not open ground {exitCell}",
                !cells.IsOpenGround(exitCell.X, exitCell.Y));

            var pond = forest.GetNodeOrNull<StaticBody3D>("Pond");
            Check("forest authored a pond body", pond != null);
            if (pond != null)
            {
                Check("the pond's cells are occupied (no forage in the water)",
                    !cells.IsOpenGround(
                        Mathf.FloorToInt(pond.GlobalPosition.X), Mathf.FloorToInt(pond.GlobalPosition.Z)));
            }
            Check("the entry spawn is a trail anchor (forage keeps its distance)",
                cells.TrailCells.Count >= 2);
            Check("every authored node/roamer marker is a reserved cell",
                cells.ReservedCells.Count >= Bulwark.Data.Territories.Forest.Nodes.Count);
        }

        // --- Player physics against the AUTHORED world ---
        var player = forest.GetNodeOrNull<PlayerController>("Player");
        Check("forest spawned the player", player != null);
        if (player != null)
        {
            // Authored perimeter: start 2 m inside the west wall and push west for ~4.5 m of travel.
            player.GlobalPosition = new Vector3(2f, 0f, 18f);
            await PhysicsFrames(2);
            Input.ActionPress("move_left");
            await PhysicsFrames(90);
            Input.ActionRelease("move_left");
            await PhysicsFrames(2);
            Check($"authored perimeter wall stops the player at the map edge (x={player.GlobalPosition.X:0.00})",
                player.GlobalPosition.X > 0f);

            // Authored pond body: approach from the north (-Z) and push south (+Z) into the water.
            var pond = forest.GetNodeOrNull<StaticBody3D>("Pond");
            if (pond != null)
            {
                float northFace = pond.GlobalPosition.Z - 2.5f;
                player.GlobalPosition = new Vector3(pond.GlobalPosition.X, 0f, northFace - 2.5f);
                await PhysicsFrames(2);
                Input.ActionPress("move_down");
                await PhysicsFrames(90);
                Input.ActionRelease("move_down");
                await PhysicsFrames(2);
                Check($"the authored pond body stops the player (z={player.GlobalPosition.Z:0.00}, "
                      + $"face {northFace:0.00})",
                    player.GlobalPosition.Z < northFace + 0.05f);
            }
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
