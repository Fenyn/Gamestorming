using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Reusable render spike for building glbs dropped into the outpost backdrop
/// (scenes/dev/building_shot_spike.tscn). Instances the outpost backdrop glb at the origin — no
/// gameplay buildings/actors, because the template scene borrowed for lighting is instantiated but
/// never added to the tree, so OutpostScene's _Ready (villager/actor spawn) never runs. Runs three
/// phases in sequence:
///   1. Single-building verification — for each row in <see cref="Shots"/>, instances the building glb
///      alone at its world position and captures two frames:
///        "{prefix}_wide.png"          — the game camera angle: pitch -55 deg, south of the building
///           looking north, framed to show ~15 m of surrounding ground.
///        "{prefix}_threequarter.png"  — a closer three-quarter front view (south-east, shallower pitch).
///   2. Town beauty shots — instances every row of <see cref="TownBuildings"/> simultaneously (all four
///      top-stage buildings over the backdrop) and captures:
///        "veg_town_overview.png" — high overview camera, matches the outpost overview framing.
///        "veg_town_game.png"     — lower -55 deg game-angle pass south of the plaza, command post in
///           frame with the tavern and trading post visible beyond it.
///        "veg_treeline.png"      — low angle from outside the south gate along the perimeter forest.
///        "veg_bush_closeup.png"  — the densest bush/fern cluster inside the walls, near the tavern.
///      (the first two are also written under their original "town_*.png" names.)
///   3. Prop library verification — re-aims at the props already standing in the scene (see below) and
///      captures:
///        "proplib_town_overview.png" — the town overview framing again, props in place.
///        "proplib_plaza.png"         — -55 deg game angle over the well and both benches.
///        "proplib_gate_rubble.png"   — steep pass down the gate axis over the broken crate/barrel
///           clusters and the cart, all outside the wall.
///        "proplib_wall_base.png"     — from inside looking south-west at the crate/barrel/sack row
///           standing against the south wall, which no south-facing camera can see past the wall.
///        "proplib_trading_yard.png"  — three-quarter of the cart/barrel/crate cluster south of the
///           trading post: croco and PSX models side by side at readable size.
/// The replanted PSX vegetation (scenes/outpost/outpost_vegetation.tscn, baked by
/// <see cref="VegetationBakeSpike"/>) and the outpost's authored "Props" subtree (the scenes/props/
/// library instances, lifted out of scenes/outpost/outpost.tscn by <see cref="BuildLighting"/>) are
/// both in the tree for every phase, so all shots show the forest and the dressing the same way the
/// real outpost scene does.
/// Add a single-building verification shot by adding a row to <see cref="Shots"/>; add/move a town
/// building by editing <see cref="TownBuildings"/>; props follow outpost.tscn automatically.
/// Must run rendered (not --headless):
///   godot --path bulwark res://scenes/dev/building_shot_spike.tscn
/// </summary>
public partial class BuildingShotSpike : Node
{
    private const string OutDir = @"C:\Users\Midge\.claude\jobs\77bb4d9a\tmp";

    private readonly record struct BuildingShot(string GlbPath, Vector3 Position, string Prefix);
    private readonly record struct StaticProp(string GlbPath, Vector3 Position);

    private static readonly BuildingShot[] Shots =
    {
        new("res://assets/models/buildings/farmhouse_stage4.glb", new Vector3(20f, 0f, 44f), "farmhouse_stage4_v2"),
    };

    // All four top-stage buildings placed together over the backdrop for the town beauty shots.
    private static readonly StaticProp[] TownBuildings =
    {
        new("res://assets/models/buildings/command_post_stage1.glb", new Vector3(48f, 0f, 28f)),
        new("res://assets/models/buildings/trading_post_stage2.glb", new Vector3(70f, 0f, 66f)),
        new("res://assets/models/buildings/farmhouse_stage4.glb", new Vector3(20f, 0f, 44f)),
        new("res://assets/models/buildings/tavern_stage3.glb", new Vector3(76f, 0f, 20f)),
    };

    // The baked replant of the backdrop's stripped billboard vegetation.
    private const string VegetationScene = "res://scenes/outpost/outpost_vegetation.tscn";

    // Wide "game camera" framing: pitch -55 deg, south of the building looking north, ~15m of
    // surrounding ground visible around the building.
    private const float WidePitchDeg = 55f;
    private const float WideSouthOffset = 15f; // metres south of the building's origin
    private const float WideFov = 50f;

    // Closer three-quarter front view: south-east of the building, shallower pitch.
    private static readonly Vector3 CloseOffset = new(7f, 5.5f, 8f);
    private const float CloseFov = 50f;

    private enum Phase { SingleWide, SingleClose, TownOverview, TownGame, Treeline, BushCloseup, PropTown, PropPlaza, PropGateRubble, PropWallBase, PropYard, Done }

    private double _time;
    private Phase _phase = Phase.SingleWide;
    private int _index = -1;
    private Node3D? _building;
    private Camera3D? _camera;

    public override void _Ready()
    {
        var backdrop = GD.Load<PackedScene>("res://assets/models/environment/outpost.glb").Instantiate<Node3D>();
        AddChild(backdrop);

        AddChild(GD.Load<PackedScene>(VegetationScene).Instantiate<Node3D>());

        BuildLighting();

        _camera = new Camera3D { Name = "SpikeCamera", Current = true };
        AddChild(_camera);

        NextBuilding();
        GD.Print("[buildingshot] spike ready");
    }

    /// <summary>Borrow the real outpost's Environment + Sun (so the shots are representative of the
    /// in-game look) and its authored "Props" subtree (so the dressing never drifts from the scene it
    /// is meant to verify). The template instance is never added to the tree, so its script never
    /// runs; lifting Props out before freeing the template keeps the real instances, transforms and
    /// all.</summary>
    private void BuildLighting()
    {
        var template = GD.Load<PackedScene>("res://scenes/outpost/outpost.tscn").Instantiate<Node3D>();
        var templateEnv = template.GetNode<WorldEnvironment>("WorldEnvironment");
        var templateSun = template.GetNode<DirectionalLight3D>("Sun");

        AddChild(new WorldEnvironment { Name = "WorldEnvironment", Environment = templateEnv.Environment });

        var sun = new DirectionalLight3D
        {
            Name = "Sun",
            LightEnergy = templateSun.LightEnergy,
            ShadowEnabled = templateSun.ShadowEnabled,
            Transform = templateSun.Transform,
        };
        AddChild(sun);

        Node3D? props = template.GetNodeOrNull<Node3D>("Props");
        if (props == null)
            GD.PushWarning("[buildingshot] outpost.tscn has no Props node — prop shots will be empty.");
        else
        {
            template.RemoveChild(props);
            props.Owner = null; // still owned by the template we are about to free
            AddChild(props);
        }

        template.Free();
    }

    public override void _Process(double delta)
    {
        _time += delta;

        switch (_phase)
        {
            case Phase.SingleWide when _time > 1.5:
                Capture($"{Shots[_index].Prefix}_wide.png");
                AimClose();
                _phase = Phase.SingleClose;
                break;

            case Phase.SingleClose when _time > 2.3:
                Capture($"{Shots[_index].Prefix}_threequarter.png");
                if (_index + 1 < Shots.Length)
                    NextBuilding();
                else
                    StartTownShots();
                break;

            case Phase.TownOverview when _time > 1.8:
                Capture("veg_town_overview.png");
                Capture("town_overview.png");
                AimTownGame();
                _time = 0;
                _phase = Phase.TownGame;
                break;

            case Phase.TownGame when _time > 1.2:
                Capture("veg_town_game.png");
                Capture("town_game.png");
                AimTreeline();
                _time = 0;
                _phase = Phase.Treeline;
                break;

            case Phase.Treeline when _time > 1.5:
                Capture("veg_treeline.png");
                AimBushCloseup();
                _time = 0;
                _phase = Phase.BushCloseup;
                break;

            case Phase.BushCloseup when _time > 1.2:
                Capture("veg_bush_closeup.png");
                StartPropShots();
                break;

            case Phase.PropTown when _time > 1.5:
                Capture("proplib_town_overview.png");
                AimPropPlaza();
                _time = 0;
                _phase = Phase.PropPlaza;
                break;

            case Phase.PropPlaza when _time > 1.2:
                Capture("proplib_plaza.png");
                AimPropGateRubble();
                _time = 0;
                _phase = Phase.PropGateRubble;
                break;

            case Phase.PropGateRubble when _time > 1.2:
                Capture("proplib_gate_rubble.png");
                AimPropWallBase();
                _time = 0;
                _phase = Phase.PropWallBase;
                break;

            case Phase.PropWallBase when _time > 1.2:
                Capture("proplib_wall_base.png");
                AimPropYard();
                _time = 0;
                _phase = Phase.PropYard;
                break;

            case Phase.PropYard when _time > 1.2:
                Capture("proplib_trading_yard.png");
                GD.Print("[buildingshot] done, quitting");
                _phase = Phase.Done;
                GetTree().Quit(0);
                break;
        }
    }

    /// <summary>Low eye-level pass from outside the south gate (the wall runs along z=96.5, the scatter
    /// belt reaches z=113), looking north-west across the perimeter forest with the wall behind it.
    /// Deliberately shallow: a steep angle hides whether trunks are seated on the undulating outside
    /// terrain, and this is the shot that has to prove they are.</summary>
    private void AimTreeline()
    {
        if (_camera == null) return;
        _camera.Fov = WideFov;
        _camera.GlobalPosition = new Vector3(72f, 11f, 118f);
        _camera.LookAt(new Vector3(38f, 2.5f, 101f), Vector3.Up);
    }

    /// <summary>Three-quarter closeup of the densest bush/fern cluster inside the walls (around
    /// x 84.6 / z 23.9, the open ground east of the tavern) — the ground-cover readability check.</summary>
    private void AimBushCloseup()
    {
        if (_camera == null) return;
        Vector3 cluster = new(84.6f, 0f, 23.9f);
        _camera.Fov = CloseFov;
        _camera.GlobalPosition = cluster + new Vector3(5f, 4f, 8f);
        _camera.LookAt(cluster + new Vector3(0f, 1f, 0f), Vector3.Up);
    }

    /// <summary>Free the previous building (if any), instance the next row's glb, and aim the wide shot.</summary>
    private void NextBuilding()
    {
        _index++;
        _building?.QueueFree();

        BuildingShot shot = Shots[_index];
        _building = GD.Load<PackedScene>(shot.GlbPath).Instantiate<Node3D>();
        AddChild(_building);
        _building.GlobalPosition = shot.Position;

        AimWide(shot.Position);
        _time = 0;
        _phase = Phase.SingleWide;
    }

    private void AimWide(Vector3 buildingPos)
    {
        if (_camera == null) return;
        _camera.Fov = WideFov;
        float height = WideSouthOffset * Mathf.Tan(Mathf.DegToRad(WidePitchDeg));
        _camera.GlobalPosition = buildingPos + new Vector3(0f, height, WideSouthOffset);
        _camera.LookAt(buildingPos + new Vector3(0f, 2f, 0f), Vector3.Up);
    }

    private void AimClose()
    {
        if (_camera == null) return;
        Vector3 buildingPos = Shots[_index].Position;
        _camera.Fov = CloseFov;
        _camera.GlobalPosition = buildingPos + CloseOffset;
        _camera.LookAt(buildingPos + new Vector3(0f, 1.8f, 0f), Vector3.Up);
    }

    /// <summary>Free the single verification building, place all four top-stage town buildings
    /// together, and frame the high town overview (matches the outpost overview framing used
    /// elsewhere: camera (48, 85, 155) looking at (48, 0, 45)).</summary>
    private void StartTownShots()
    {
        _building?.QueueFree();
        _building = null;

        foreach (StaticProp prop in TownBuildings)
        {
            var building = GD.Load<PackedScene>(prop.GlbPath).Instantiate<Node3D>();
            AddChild(building);
            building.GlobalPosition = prop.Position;
        }

        if (_camera != null)
        {
            _camera.Fov = 60f;
            _camera.GlobalPosition = new Vector3(48f, 85f, 155f);
            _camera.LookAt(new Vector3(48f, 0f, 45f), Vector3.Up);
        }

        _time = 0;
        _phase = Phase.TownOverview;
    }

    /// <summary>Lower -55 deg game-angle pass south of the plaza: command post framed centre, with the
    /// tavern and trading post visible beyond it. Pulled back further than the single-building wide
    /// shot so the ~30m east-west spread between the three buildings fits in frame.</summary>
    private void AimTownGame()
    {
        if (_camera == null) return;
        const float southOffset = 55f;
        Vector3 target = new(55f, 0f, 35f); // roughly between command post and the trading post/tavern cluster
        float height = southOffset * Mathf.Tan(Mathf.DegToRad(WidePitchDeg));
        _camera.Fov = WideFov;
        _camera.GlobalPosition = target + new Vector3(0f, height, southOffset);
        _camera.LookAt(target + new Vector3(0f, 2f, 0f), Vector3.Up);
    }

    /// <summary>Re-aim the town overview for the prop-library pass. The props themselves are already in
    /// the tree (lifted from outpost.tscn in <see cref="BuildLighting"/>), as are the four top-stage
    /// buildings <see cref="StartTownShots"/> placed and never freed.</summary>
    private void StartPropShots()
    {
        if (_camera != null)
        {
            _camera.Fov = 60f;
            _camera.GlobalPosition = new Vector3(48f, 85f, 155f);
            _camera.LookAt(new Vector3(48f, 0f, 45f), Vector3.Up);
        }

        _time = 0;
        _phase = Phase.PropTown;
    }

    /// <summary>Game camera angle (pitch -55 deg, matches <see cref="WidePitchDeg"/>) over the plaza:
    /// the well (44, 78.5) and both benches (44.6, 85.6) / (51.5, 76.5) in one frame, gate road below.
    /// Narrower fov than the town pass — the plaza is only ~20 m across and the props are 0.5-2 m.</summary>
    private void AimPropPlaza()
    {
        if (_camera == null) return;
        const float southOffset = 15f;
        Vector3 target = new(47f, 0f, 82f);
        float height = southOffset * Mathf.Tan(Mathf.DegToRad(WidePitchDeg));
        _camera.Fov = 40f;
        _camera.GlobalPosition = target + new Vector3(0f, height, southOffset);
        _camera.LookAt(target + new Vector3(0f, 1f, 0f), Vector3.Up);
    }

    /// <summary>The dressing standing against the INSIDE of the south wall (crate, barrels, sack pair
    /// at z 94-95). Shot from inside looking south-west: the wall runs 6 m high along z=96.5, so from
    /// the south these props are occluded at every pitch short of straight down.</summary>
    private void AimPropWallBase()
    {
        if (_camera == null) return;
        Vector3 target = new(48f, 0f, 94.5f);
        _camera.Fov = CloseFov;
        _camera.GlobalPosition = target + new Vector3(7f, 9f, -11f);
        _camera.LookAt(target + new Vector3(0f, 0.6f, 0f), Vector3.Up);
    }

    /// <summary>Three-quarter closeup of the trading-post yard cluster — croco cart (66, 57.5) beside
    /// the PSX barrel (72.5, 58.4) and PSX crate (74.2, 58.6). The one frame where all three model
    /// sources stand together at readable size, so it is the style-mix check.</summary>
    private void AimPropYard()
    {
        if (_camera == null) return;
        Vector3 cluster = new(70.5f, 0f, 58.2f);
        _camera.Fov = CloseFov;
        _camera.GlobalPosition = cluster + new Vector3(8f, 5.5f, 10f);
        _camera.LookAt(cluster + new Vector3(0f, 0.8f, 0f), Vector3.Up);
    }

    /// <summary>The broken crate/barrel cluster straddling the south gate (x 38..57, z 94..101). Shot
    /// straight down the gate axis rather than three-quarter: the wall runs along z=96.5 at 4 m, so
    /// anything shallower or off-axis loses the props standing just inside it, and the gate gap
    /// (x 45..51) is the only line of sight to them.</summary>
    private void AimPropGateRubble()
    {
        if (_camera == null) return;
        const float southOffset = 9f;
        const float pitchDeg = 62f;
        Vector3 target = new(48f, 0f, 97f);
        float height = southOffset * Mathf.Tan(Mathf.DegToRad(pitchDeg));
        _camera.Fov = 45f;
        _camera.GlobalPosition = target + new Vector3(0f, height, southOffset);
        _camera.LookAt(target + new Vector3(0f, 0.5f, 0f), Vector3.Up);
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        img.SavePng($"{OutDir}\\{file}");
        GD.Print($"[buildingshot] saved {file}");
    }
}
