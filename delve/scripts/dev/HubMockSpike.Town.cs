using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Data;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The outpost growing into a hamlet (scratchpad hub_town.md): tiers build in place, residents keep a
/// three-slot day, and the camp's light follows the time of day. Four renders: Camp morning, Outpost
/// afternoon, Hamlet evening, and the Hamlet line-up. Building cards come from Mana Seed Iconic
/// Homestead mockups cut out into <see cref="BuildingFolder"/> (outside the project; dev only).
/// </summary>
public partial class HubMockSpike
{
    [Export] public bool Town { get; set; } = true;

    /// <summary>Absolute folder of the cut-out homestead buildings (house_01.png and so on).</summary>
    [Export] public string BuildingFolder { get; set; } = "";

    [Export] public PackedScene? TreeScene { get; set; }

    private enum Time { Morning, Afternoon, Evening }

    /// <summary>A prop that exists from one tier to another: an atlas region or a building image.</summary>
    private sealed record Piece(int From, int To, Vector3 Spot, Rect2 Region = default, string Building = "", bool Lamp = false);

    private static readonly Piece[] Pieces =
    {
        new(1, 1, new(5.3f, 0, -1.7f), new(480, 288, 96, 96)),         // camp cart
        new(1, 3, new(6.3f, 0, -2.8f), new(288, 384, 48, 48)),         // crates
        new(1, 3, new(7.1f, 0, -2.3f), new(240, 432, 48, 48)),
        new(1, 3, new(-6.9f, 0, -0.1f), new(576, 192, 48, 96)),        // stump
        new(1, 3, new(-8.1f, 0, -0.6f), new(384, 192, 144, 96)),       // woodpile
        new(1, 3, new(-4.9f, 0, 2.0f), new(0, 624, 48, 96)),           // notice board
        new(1, 3, new(4.6f, 0, 1.8f), new(576, 112, 96, 80)),          // bestiary table
        new(1, 3, new(-4.1f, 0, -5.2f), new(336, 672, 48, 96), Lamp: true), // gate lanterns
        new(1, 3, new(-0.25f, 0, -6.2f), new(336, 672, 48, 96), Lamp: true),
        new(2, 3, new(-2.6f, 0, 6.0f), new(384, 288, 96, 192)),        // well
        new(2, 3, new(-10.4f, 0, 1.1f), new(144, 96, 48, 96)),         // open-air anvil
        new(2, 3, new(-10.3f, 0, 2.5f), new(48, 192, 48, 96)),         // grindstone
        new(2, 3, new(-8.7f, 0, 6.4f), new(0, 480, 48, 96)),           // dummy
        new(2, 3, new(-11.7f, 0, 4.3f), new(48, 480, 48, 96)),         // target
        new(2, 3, new(10.1f, 0, 3.0f), new(240, 96, 48, 48)),          // crops
        new(2, 3, new(10.9f, 0, 2.6f), new(288, 96, 48, 48)),
        new(2, 3, new(10.5f, 0, 3.8f), new(336, 144, 48, 48)),
        new(2, 2, new(8.9f, 0, -3.1f), new(624, 240, 144, 96)),        // tavern frame lumber
        new(2, 3, new(6.5f, 0, -0.4f), new(288, 384, 48, 48)),         // cards crate
        new(2, 3, new(0.0f, 0, 7.1f), new(48, 672, 48, 96)),           // signpost
        new(2, 3, new(-6.9f, 0, -5.5f), new(480, 480, 48, 96)),        // shrine stone
        new(2, 3, new(5.6f, 0, -11.5f), Building: "house_01"),         // storehouse
        new(3, 3, new(-13.1f, 0, -6.0f), Building: "house_06"),        // bunkhouse
        new(3, 3, new(-13.4f, 0, 0.8f), Building: "house_05"),         // smithy
        new(3, 3, new(10.6f, 0, -5.2f), Building: "house_04"),         // tavern
        new(3, 3, new(10.2f, 0, -9.7f), Building: "house_02"),         // infirmary
        new(3, 3, new(7.6f, 0, -1.7f), new(480, 0, 96, 48)),           // tavern benches
        new(3, 3, new(9.9f, 0, -2.3f), new(480, 0, 96, 48)),
        new(3, 3, new(12.3f, 0, 0.1f), new(96, 528, 96, 96)),          // junk heap
        new(3, 3, new(-11.8f, 0, 7.0f), new(576, 480, 48, 96)),        // Wardstone stand-in
        new(3, 3, new(-5.7f, 0, 8.3f), new(240, 672, 48, 48)),         // cauldron barrels
        new(3, 3, new(-4.0f, 0, 4.7f), new(336, 672, 48, 96), Lamp: true), // lamp posts
        new(3, 3, new(4.7f, 0, 2.4f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(-7.2f, 0, -1.4f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(4.8f, 0, -5.5f), new(336, 672, 48, 96), Lamp: true),
    };

    /// <summary>A straight fence line: split rails at Outpost, pointed log palisade at Hamlet.</summary>
    private sealed record FenceRun(int From, int To, Vector2 Start, Vector2 End, bool Palisade);

    private static readonly FenceRun[] Fences =
    {
        new(2, 3, new(-9.6f, 5.3f), new(-5.2f, 4.2f), false),
        new(2, 3, new(7.0f, 2.1f), new(11.8f, 2.1f), false),
        new(3, 3, new(-16.5f, -8.8f), new(-11.8f, -10.6f), true),
        new(3, 3, new(12.0f, -12.2f), new(16.8f, -10.0f), true),
    };

    private readonly List<(Piece Piece, Sprite3D Sprite, OmniLight3D? Light)> _pieces = new();
    private readonly List<(FenceRun Run, Node3D Node)> _fences = new();

    private async Task RunTown()
    {
        BuildTown();
        await TownShot(1, Time.Morning, "hub4_r1_camp_morning", new Vector3(-1.3f, 0, -2.4f), 32f, 27.8f, new (string, string, Vector3, Job, string, int, int, Facing)[]
        {
            ("player", "CHOP", new(-7.8f, 0, 0.1f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.East),
            ("elara", "HAUL", new(6.3f, 0, -1.2f), Job.Work, "p2", 4, 5, Facing.South),
            ("tharr", "MASON", new(3.0f, 0, -6.7f), Job.Work, "p2_mine", 0, 2, Facing.West),
            ("fenwick", "TREE", new(-9.2f, 0, -5.1f), Job.Seat, "", 0, 0, Facing.South),
        });
        await TownShot(2, Time.Afternoon, "hub4_r2_outpost_afternoon", new Vector3(-1.4f, 0, -2.9f), 34f, 34.7f, new (string, string, Vector3, Job, string, int, int, Facing)[]
        {
            ("player", "WELL1", new(-1.5f, 0, 5.9f), Job.Work, "p2", 4, 2, Facing.West),
            ("elara", "CARDS1", new(5.7f, 0, -0.2f), Job.Seat, "", 0, 0, Facing.South),
            ("raven", "CARDS2", new(7.3f, 0, -0.6f), Job.Seat, "", 0, 0, Facing.South),
            ("tharr", "MASON", new(3.0f, 0, -6.7f), Job.Work, "p2_mine", 0, 2, Facing.West),
            ("fenwick", "TABLE1", new(5.7f, 0, 1.9f), Job.Stand, "", 0, 0, Facing.West),
            ("thistle", "TARGET", new(-8.7f, 0, 3.9f), Job.Work, "p2", 0, 5, Facing.West),
            ("grub", "GARDEN", new(8.5f, 0, 3.0f), Job.Work, "p2", 4, 2, Facing.East),
            ("josen", "TREE", new(-9.2f, 0, -5.1f), Job.Seat, "", 0, 0, Facing.South),
            ("arkus", "FORGE", new(-9.6f, 0, 1.4f), Job.Work, "p2_mine", 0, 2, Facing.South),
        });
        var evening = Evening();
        await TownShot(3, Time.Evening, "hub4_r3_hamlet_evening", new Vector3(-1.6f, 0, -3.4f), 36f, 46.3f, evening);
        // R4: four are called away; everyone else keeps their evening spot.
        var called = new[] { "arkus", "raven", "oskar", "sera" };
        var lineUp = evening.Where(e => !called.Contains(e.Item1))
            .Concat(called.Select((id, i) => (id, "SLOT", Slots[i], Job.Stand, "", 0, 0, Facing.South))).ToArray();
        await TownShot(3, Time.Evening, "hub4_r4_hamlet_lineup", new Vector3(-2.46f, 0, -6.78f), 30f, 23.1f, lineUp);
    }

    private static (string, string, Vector3, Job, string, int, int, Facing)[] Evening() => new (string, string, Vector3, Job, string, int, int, Facing)[]
    {
        ("player", "LOG1", new(-3.0f, 0, 2.9f), Job.Seat, "", 0, 0, Facing.South),
        ("elara", "BENCH1", new(7.6f, 0, -1.55f), Job.Seat, "", 0, 0, Facing.South),
        ("tharr", "LOG2", new(2.8f, 0, 1.3f), Job.Seat, "", 0, 0, Facing.South),
        ("fenwick", "COOK", new(1.4f, 0, 1.7f), Job.Work, "p2", 0, 5, Facing.West),
        ("raven", "CARDS1", new(5.7f, 0, -0.2f), Job.Seat, "", 0, 0, Facing.South),
        ("thistle", "FENCE1", new(-5.9f, 0, 4.6f), Job.Seat, "", 0, 0, Facing.South),
        ("grub", "LOG3", new(-2.5f, 0, 0.8f), Job.Seat, "", 0, 0, Facing.South),
        ("josen", "LOG4", new(1.4f, 0, -0.2f), Job.Seat, "", 0, 0, Facing.South),
        ("arkus", "BENCH2", new(8.8f, 0, -1.85f), Job.Seat, "", 0, 0, Facing.South),
        ("aldric", "PORCH", new(-12.9f, 0, -5.1f), Job.Stand, "", 0, 0, Facing.South),
        ("oskar", "SHRINE", new(-6.7f, 0, -4.7f), Job.Seat, "", 0, 0, Facing.North),
        ("hazel", "CARDS2", new(7.3f, 0, -0.6f), Job.Seat, "", 0, 0, Facing.South),
        ("wynn", "STORY", new(-0.6f, 0, 0.1f), Job.Stand, "", 0, 0, Facing.South),
        ("vasska", "LIE", new(3.0f, 0, 6.6f), Job.Seat, "", 0, 0, Facing.South),
        ("hilde", "BENCH3", new(9.9f, 0, -2.15f), Job.Seat, "", 0, 0, Facing.South),
        ("sera", "TREE", new(-9.2f, 0, -5.1f), Job.Seat, "", 0, 0, Facing.South),
        ("spore", "WELL2", new(-3.6f, 0, 6.1f), Job.Stand, "", 0, 0, Facing.West),
        ("flick", "FENCE2", new(7.8f, 0, 2.4f), Job.Seat, "", 0, 0, Facing.South),
    };

    private void BuildTown()
    {
        foreach (var prop in _outpost.GetChildren().OfType<Sprite3D>().Where(p => !p.Name.ToString().StartsWith("CampGrass")))
            Rescale(prop, prop.Name == "Fire" ? HeroPixel : PropPixel);
        // The scene's own loose props give way to the tier pieces; the logs ring the hearth.
        foreach (string name in new[] { "SharedTools", "Woodpile", "SharedTable", "HerbPots0", "HerbPots1", "TravelSupplies", "Supplies0", "Supplies1", "Supplies2", "Seat0", "Seat1" })
            if (_outpost.GetNodeOrNull<Node3D>(name) is { } node) node.Hide();
        MoveProp("Seat2", new Vector3(-3.0f, 0, 3.05f));
        MoveProp("Seat3", new Vector3(2.8f, 0, 1.45f));
        MoveProp("Seat4", new Vector3(-2.5f, 0, 0.95f));
        MoveProp("Seat5", new Vector3(1.4f, 0, -0.05f));
        if (TreeScene?.Instantiate() is Node3D tree)
        {
            _outpost.AddChild(tree);
            var spot = new Vector3(-9.8f, 0, -5.7f);
            tree.Position = spot with { Y = _terrain.HeightAt(spot) };
        }
        foreach (var piece in Pieces)
        {
            var sprite = piece.Building.Length > 0 ? Building(piece.Building) : AtlasCard(piece.Region);
            _outpost.AddChild(sprite);
            sprite.Position = piece.Spot with { Y = _terrain.HeightAt(piece.Spot) + (piece.Building.Length > 0 ? 0 : piece.Region.Size.Y * PropPixel * 0.5f) };
            OmniLight3D? light = null;
            if (piece.Lamp)
            {
                light = new OmniLight3D { LightColor = new Color(1.0f, 0.78f, 0.5f), OmniRange = 5f };
                _outpost.AddChild(light);
                light.Position = sprite.Position + Vector3.Up * 0.9f;
            }
            _pieces.Add((piece, sprite, light));
        }
        foreach (var run in Fences)
        {
            var fence = Fence(run);
            _outpost.AddChild(fence);
            _fences.Add((run, fence));
        }
        // Clear forest trees off the building sites.
        var sites = Pieces.Where(p => p.Building.Length > 0).Select(p => p.Spot).ToArray();
        foreach (var forest in _outpost.GetChildren().OfType<Node3D>().Where(n => n.Name.ToString().StartsWith("Forest")))
            if (sites.Any(s => new Vector2(s.X - forest.Position.X, s.Z - forest.Position.Z).Length() < 5f)) forest.Hide();
        _stations["unlocks"] = new Vector3(-4.9f, 2.2f, 2.0f);
        _stations["bestiary"] = new Vector3(4.6f, 1.4f, 1.8f);
    }

    private Node3D Fence(FenceRun run)
    {
        var root = new Node3D();
        var wood = new StandardMaterial3D { AlbedoColor = new Color(0.42f, 0.3f, 0.2f), Roughness = 1f };
        var span = run.End - run.Start;
        float spacing = run.Palisade ? 0.34f : 1.1f;
        int count = Mathf.Max(2, Mathf.RoundToInt(span.Length() / spacing) + 1);
        var post = run.Palisade
            ? new CylinderMesh { TopRadius = 0.17f, BottomRadius = 0.17f, Height = 2.2f, RadialSegments = 6, Material = wood }
            : new CylinderMesh { TopRadius = 0.07f, BottomRadius = 0.08f, Height = 1.0f, RadialSegments = 6, Material = wood };
        var tip = new CylinderMesh { TopRadius = 0f, BottomRadius = 0.17f, Height = 0.4f, RadialSegments = 6, Material = wood };
        for (int i = 0; i < count; i++)
        {
            var at = run.Start + span * (i / (float)(count - 1));
            var spot = new Vector3(at.X, 0, at.Y);
            float ground = _terrain.HeightAt(spot);
            // Hand-set posts: uneven heights, a little more on the palisade.
            float jitter = (i * 37 % 5) * (run.Palisade ? 0.06f : 0.03f) - (run.Palisade ? 0f : 0.05f);
            root.AddChild(new MeshInstance3D { Mesh = post, Position = spot with { Y = ground + post.Height / 2f + jitter } });
            if (run.Palisade)
                root.AddChild(new MeshInstance3D { Mesh = tip, Position = spot with { Y = ground + post.Height + jitter + tip.Height / 2f } });
        }
        if (!run.Palisade)
        {
            var rail = new BoxMesh { Size = new Vector3(span.Length(), 0.09f, 0.07f), Material = wood };
            var middle = run.Start + span / 2f;
            float yaw = -Mathf.Atan2(span.Y, span.X);
            float ground = _terrain.HeightAt(new Vector3(middle.X, 0, middle.Y));
            foreach (float height in new[] { 0.45f, 0.82f })
                root.AddChild(new MeshInstance3D { Mesh = rail, Position = new Vector3(middle.X, ground + height, middle.Y), Rotation = new Vector3(0, yaw, 0) });
        }
        return root;
    }

    private Sprite3D AtlasCard(Rect2 region) => new()
    {
        Texture = PropAtlas, RegionEnabled = true, RegionRect = region, PixelSize = PropPixel,
        Billboard = BaseMaterial3D.BillboardModeEnum.FixedY, TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
        AlphaCut = SpriteBase3D.AlphaCutMode.Discard, Shaded = true,
    };

    /// <summary>An upright building card at hero scale, turned to the camera and leaned back so the
    /// roof recedes, with its origin at the bottom centre.</summary>
    private Sprite3D Building(string name)
    {
        var image = Image.LoadFromFile(BuildingFolder.PathJoin(name + ".png"));
        var texture = ImageTexture.CreateFromImage(image);
        return new Sprite3D
        {
            Texture = texture, PixelSize = HeroPixel, Centered = false,
            Offset = new Vector2(-image.GetWidth() / 2f, 0),
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest, AlphaCut = SpriteBase3D.AlphaCutMode.Discard,
            Shaded = true, RotationDegrees = new Vector3(-20, Yaw, 0),
        };
    }

    private async Task TownShot(int tier, Time time, string name, Vector3 target, float pitch, float distance,
        (string Id, string Spot, Vector3 Where, Job Job, string Page, int Row, int Column, Facing Facing)[] cast)
    {
        foreach (var (piece, sprite, light) in _pieces)
        {
            bool built = tier >= piece.From && tier <= piece.To;
            sprite.Visible = built;
            if (light != null) light.LightEnergy = built && time == Time.Evening ? 1.2f : 0f;
        }
        foreach (var (run, node) in _fences) node.Visible = tier >= run.From && tier <= run.To;
        if (_outpost.GetNodeOrNull<Node3D>("ShelterWest") is { } west) west.Visible = tier < 3;
        if (_outpost.GetNodeOrNull<Node3D>("ShelterEast") is { } east) east.Visible = tier < 3;
        _stations["stores"] = tier == 1 ? new Vector3(5.3f, 2.0f, -1.7f) : new Vector3(5.6f, 7.6f, -11.5f);
        if (tier >= 3) _stations["wardstone"] = new Vector3(-11.8f, 2.0f, 7.0f);
        Light(time);
        foreach (var hero in _heroes.Values) hero.Hide();
        foreach (var (id, _, spot, job, page, row, column, facing) in cast)
            Place(new Post(id, 1, spot, job, page, row, column, facing), 1);
        Orbit(target, pitch, distance);
        await Shot(name);
    }

    private Color? _ambient;

    /// <summary>The proposed light per time of day (hub_town.md section 4; the user's call).</summary>
    private void Light(Time time)
    {
        var sun = _outpost.GetNode<DirectionalLight3D>("Moonlight");
        var environment = _outpost.GetNode<WorldEnvironment>("WorldEnvironment").Environment;
        _ambient ??= environment.AmbientLightColor;
        environment.AmbientLightColor = _ambient.Value;
        switch (time)
        {
            case Time.Morning:
                sun.RotationDegrees = new Vector3(-42, -55, 0);
                sun.LightColor = new Color(1f, 0.9f, 0.78f);
                sun.LightEnergy = 0.95f;
                environment.AmbientLightEnergy = 0.75f;
                environment.TonemapExposure = 1f;
                _stage.FireEnergy = 1.0f;
                break;
            case Time.Afternoon:
                sun.RotationDegrees = new Vector3(-55, -20, 0);
                sun.LightColor = new Color(1f, 0.98f, 0.95f);
                sun.LightEnergy = 1.1f;
                environment.AmbientLightEnergy = 0.8f;
                environment.TonemapExposure = 1f;
                _stage.FireEnergy = 0.6f;
                break;
            default:
                // Dusk (v1_visual defect 2): low warm sun, cool ambient; the tone is the user's call.
                sun.RotationDegrees = new Vector3(-12, -60, 0);
                sun.LightColor = new Color(1f, 0.62f, 0.42f);
                sun.LightEnergy = 0.35f;
                environment.AmbientLightColor = new Color(0.32f, 0.36f, 0.52f);
                environment.AmbientLightEnergy = 0.35f;
                environment.TonemapExposure = 0.85f;
                _stage.FireEnergy = 3.2f;
                break;
        }
    }
}
