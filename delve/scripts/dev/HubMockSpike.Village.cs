using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Data;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The camp growing into a village (scratchpad reviews/v1_spec.md): one settlement that spreads from
/// the old camp along an east road and down to a stream, while a narrow trail leads north through
/// the trees to the Delve cut into the hill. The camera pans between overlapping stops.
/// </summary>
public partial class HubMockSpike
{
    [Export] public bool Village { get; set; } = true;

    [Export] public Shader? VillageGround { get; set; }

    /// <summary>Absolute folder of the pack crops (cave, water, deck, boards).</summary>
    [Export] public string PackFolder { get; set; } = "";

    private static readonly Vector3 VillageGate = new(-2.4f, 0, -14.6f);

    /// <summary>One placed thing: the tier range, an atlas region or building, and a few look flags.</summary>
    private sealed record Site(int From, int To, Vector2 At, Rect2 Region = default, string Building = "",
        bool Lamp = false, bool Flip = false, float Yaw = 0, bool DayOnly = false);

    /// <summary>A worn line. Margin is how far past its width the forest is cut.</summary>
    private sealed record Road(int Tier, float Width, Vector2[] Points, float Margin = 1.8f);

    private static readonly Vector4[] VillageBanks =
    {
        new(-3, -24, 9, 3.4f), new(14, -16, 8, 2.4f), new(-30, -12, 9, 2.5f), new(42, -6, 9, 2.8f), new(-36, 24, 8, 2f),
    };

    private static readonly Vector2[] Stream =
    {
        new(-56, -4), new(-36, -1), new(-24, 4), new(-16, 11), new(-10, 17), new(-2, 22), new(8, 25), new(20, 27), new(34, 26), new(56, 30),
    };

    private static readonly Road[] Roads =
    {
        new(1, 0.7f, new Vector2[] { new(0.2f, -0.5f), new(-1.4f, -4.5f), new(0.4f, -8.5f), new(-1.2f, -12), new(-2.4f, -14.3f) }, 0.4f),
        new(1, 0.55f, new Vector2[] { new(-2.4f, -14.3f), new(-3.0f, -18f), new(-5.2f, -22.5f), new(-5.8f, -27f), new(-8.5f, -32f) }, 0.1f),
        new(1, 0.7f, new Vector2[] { new(1, 5), new(6, 8), new(12, 9), new(18, 8.5f) }),
        new(2, 1.4f, new Vector2[] { new(1, 5), new(6, 8), new(12, 9), new(18, 8.5f), new(24, 10), new(30, 13) }),
        new(3, 1.5f, new Vector2[] { new(30, 13), new(36, 12.5f) }),
        new(2, 0.9f, new Vector2[] { new(-3, 4), new(-7, 3.4f), new(-10.5f, 5.2f) }),
        new(3, 0.9f, new Vector2[] { new(-10.5f, 5.2f), new(-14, 4) }),
        new(2, 0.9f, new Vector2[] { new(0.5f, 7), new(-1.5f, 11), new(-4.5f, 14.5f) }),
        new(3, 0.9f, new Vector2[] { new(-4.5f, 14.5f), new(-9, 17.5f), new(-12, 20), new(-15, 24) }),
        new(2, 0.8f, new Vector2[] { new(12, 9), new(13.2f, 5), new(15.4f, 1), new(15.6f, -3.5f), new(13.8f, -7.5f), new(12, -10) }),
        new(3, 0.8f, new Vector2[] { new(12, -10), new(14.4f, -12.4f) }),
        new(3, 0.7f, new Vector2[] { new(24, 10), new(24.8f, 14), new(24.5f, 17) }),
    };

    /// <summary>Worn ground: tier, centre X/Z and radius X/Z, and whether the forest thins around it.</summary>
    private static readonly (int Tier, Vector4 Patch, bool Thin)[] Patches =
    {
        (1, new(0, 2.6f, 7.3f, 7.5f), true), (1, new(-2.2f, -12.4f, 3.4f, 2.2f), false), (1, new(1.9f, -8.4f, 1.4f, 1.0f), false),
        (1, new(8.2f, 5.0f, 1.8f, 1.2f), false),
        (2, new(8, 6, 3, 1.8f), true), (2, new(4.2f, 10.8f, 1.8f, 1.4f), true), (2, new(-11, 6.4f, 3.2f, 2.2f), true),
        (2, new(-2, 16, 4.5f, 2.8f), true), (2, new(18.5f, 16.5f, 6, 3.2f), true), (2, new(11.6f, -10.4f, 2.6f, 1.8f), true),
        (2, new(19, 6.6f, 3.5f, 1.6f), true), (2, new(29.2f, 10.0f, 2.0f, 1.2f), false), (2, new(15.8f, -12.6f, 1.6f, 1.0f), false),
        (3, new(19.5f, 7.4f, 5.5f, 2.2f), true), (3, new(29.2f, 10.4f, 3, 1.4f), true), (3, new(37, 11.5f, 3.2f, 2.2f), true),
        (3, new(-15, 4.2f, 5, 2), true), (3, new(15.6f, -12.4f, 3, 1.8f), true), (3, new(-17, 25, 5, 3), true),
        (3, new(36.2f, 8.6f, 1.6f, 0.9f), false), (3, new(24.5f, 19.6f, 1.8f, 1.0f), false), (3, new(27.5f, 19.8f, 2.2f, 1.0f), false),
        (3, new(19, 6.4f, 1.6f, 0.9f), false),
    };

    private static readonly Site[] Sites =
    {
        // The old camp: notice board, bestiary table, woodyard, and the cart until the storehouse exists.
        new(1, 3, new(-4.9f, 2.0f), new(0, 625, 47, 47)),
        new(1, 3, new(4.6f, 1.8f), new(578, 119, 94, 73)),
        new(1, 3, new(-6.9f, -0.1f), new(576, 214, 48, 74)),
        new(1, 3, new(-9.0f, -1.4f), new(383, 221, 145, 63)),
        new(1, 1, new(5.3f, -1.7f), new(480, 301, 98, 83)),
        new(1, 1, new(6.3f, -2.8f), new(292, 415, 44, 48)),
        // The way to the Delve: a signpost at the town edge, the Wardstone at the threshold, lanterns at the arch.
        new(1, 3, new(1.0f, -4.8f), new(48, 678, 49, 67)),
        new(1, 3, new(4.6f, -10.4f), new(587, 512, 26, 50)),
        new(1, 3, new(-4.0f, -15.6f), new(336, 672, 48, 96), Lamp: true),
        new(1, 3, new(-0.6f, -16.2f), new(336, 672, 48, 96), Lamp: true),
        // Sites staked one tier early.
        new(1, 1, new(8.2f, 4.4f), new(625, 240, 139, 80)),
        new(2, 2, new(29.2f, 9.0f), new(625, 240, 139, 80)),
        new(2, 2, new(15.8f, -13.8f), new(625, 240, 139, 80)),
        new(2, 2, new(19.0f, 4.5f), new(625, 240, 139, 80)),
        // Outpost.
        new(2, 3, new(8.2f, 3.6f), Building: "house_01", Yaw: -4),
        new(2, 3, new(11.0f, 6.2f), new(480, 301, 98, 83)),
        new(2, 3, new(6.2f, 5.2f), new(292, 415, 44, 48)),
        new(2, 3, new(6.9f, 5.8f), new(240, 423, 48, 36)),
        new(2, 3, new(4.2f, 10.2f), new(386, 288, 88, 184)),
        new(2, 3, new(13.0f, 10.2f), new(48, 678, 49, 67)),
        new(2, 3, new(-11.8f, 6.0f), new(148, 114, 43, 57)),
        new(2, 3, new(-9.8f, 7.2f), new(50, 212, 46, 56)),
        new(2, 3, new(1.6f, 15.2f), new(0, 575, 45, 50)),
        new(2, 3, new(19.5f, 16.8f), new(0, 483, 48, 81)),
        new(2, 3, new(14.4f, 15.0f), new(49, 483, 46, 67)),
        new(2, 3, new(13.4f, 16.6f), new(97, 483, 46, 45)),
        new(2, 3, new(21.0f, 14.4f), new(0, 289, 96, 74)),
        new(2, 3, new(11.0f, -10.6f), new(490, 503, 30, 62)),
        new(2, 3, new(12.4f, -11.2f), new(538, 503, 28, 59)),
        // Hamlet.
        new(3, 3, new(19.0f, 4.2f), Building: "house_04", Yaw: 3),
        new(3, 3, new(-15.5f, 1.6f), Building: "house_05", Yaw: 8),
        new(3, 3, new(29.2f, 8.2f), Building: "house_06", Yaw: -6),
        new(3, 3, new(15.8f, -14.6f), Building: "house_02", Yaw: -8),
        new(3, 3, new(36.2f, 6.6f), Building: "house_03", Yaw: 5),
        new(3, 3, new(24.5f, 18.2f), Building: "house_01", Flip: true, Yaw: 10),
        new(3, 3, new(11.5f, 3.4f), new(100, 542, 140, 81)),
        new(3, 3, new(13.6f, 2.0f), new(638, 480, 123, 84)),
        new(3, 3, new(13.8f, 4.6f), new(673, 392, 47, 39)),
        new(3, 3, new(-7.2f, 13.0f), new(244, 689, 40, 31)),
        new(3, 3, new(-7.8f, 12.6f), new(292, 689, 40, 31)),
        new(3, 3, new(27.5f, 18.8f), new(418, 646, 316, 92), DayOnly: true),
        new(3, 3, new(6.2f, 6.4f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(14.8f, 10.9f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(25.6f, 9.2f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(33.4f, 11.0f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(-3.5f, 9.8f), new(336, 672, 48, 96), Lamp: true),
        new(3, 3, new(14.6f, -6.4f), new(336, 672, 48, 96), Lamp: true),
    };

    private static readonly (int Tier, Vector2 A, Vector2 B, bool Palisade)[] VillageFences =
    {
        (2, new(-5.5f, 13.2f), new(2.4f, 13.2f), false),
        (2, new(2.4f, 13.2f), new(2.4f, 18.2f), false),
        (2, new(12.8f, 13.4f), new(24.0f, 13.6f), false),
        (3, new(-19f, 3.6f), new(-15f, 4.6f), false),
        (3, new(33f, 16.5f), new(38f, 15.5f), true),
        (3, new(38f, 15.5f), new(41.5f, 11f), true),
        (3, new(-26f, -5.5f), new(-20.5f, -10.5f), true),
        (3, new(-21, 22.2f), new(-13, 22.2f), false),
    };

    /// <summary>Anchors for the painted place tags.</summary>
    private static readonly (string Key, int From, int To, Vector2 At)[] Places =
    {
        ("hearth", 1, 3, new(0, 2.4f)), ("storehouse", 2, 3, new(8.2f, 3.6f)), ("well", 2, 3, new(4.2f, 10.2f)),
        ("anvil", 2, 2, new(-11.8f, 6.0f)), ("smithy", 3, 3, new(-15.5f, 1.6f)), ("garden", 2, 3, new(-1.5f, 15.8f)),
        ("yard", 2, 3, new(18.0f, 15.8f)), ("shrine", 2, 3, new(11.6f, -10.8f)), ("frame", 2, 2, new(19.0f, 4.5f)),
        ("tavern", 3, 3, new(19.0f, 4.2f)), ("bunkhouse", 3, 3, new(29.2f, 8.2f)), ("infirmary", 3, 3, new(15.8f, -14.6f)),
        ("cottage", 3, 3, new(36.2f, 6.6f)), ("fields", 3, 3, new(-17.7f, 24.9f)), ("bridge", 3, 3, new(-9.0f, 17.6f)),
        ("cabin", 3, 3, new(24.5f, 18.2f)), ("track", 1, 1, new(16.0f, 8.6f)), ("ward", 1, 3, new(4.6f, -10.4f)),
        ("waypost", 1, 3, new(1.0f, -4.8f)), ("site_store", 1, 1, new(8.2f, 4.4f)), ("site_bunk", 2, 2, new(29.2f, 9.0f)),
        ("site_infirmary", 2, 2, new(15.8f, -13.8f)),
    };

    private async Task RunVillage()
    {
        _heroLift = 0.75f;
        BuildVillage();
        if (OS.GetEnvironment("DELVE_HUB_ONLY") == "lineup")
        {
            await RunLineup();
            return;
        }
        if (OS.GetEnvironment("DELVE_HUB_ONLY") == "delve")
        {
            _solid = _props3D = _trees3D = true;
            await VillageShot(3, Time.Afternoon, "debug_delve_day", VillageGate + new Vector3(-0.3f, 0, -1.4f), 30f, 23.1f, DelveLineUp());
            await VillageShot(3, Time.Afternoon, "debug_delve_top", VillageGate + new Vector3(0, 0, 2f), 89f, 60f, DelveLineUp());
            return;
        }
        var town = new Vector3(8, 0, 2);
        await VillageShot(1, Time.Morning, "hub7_camp", town, 56f, 118f, new[]
        {
            Cast("player", new(-7.8f, 0, 0.1f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.East),
            Cast("elara", new(6.3f, 0, -1.2f), Job.Work, "p2", 4, 5, Facing.South),
            Cast("tharr", new(1.0f, 0, -8.4f), Job.Stand, facing: Facing.East),
            Cast("fenwick", new(-3.0f, 0, 2.9f), Job.Seat),
        });
        await VillageShot(2, Time.Afternoon, "hub7_outpost", town, 56f, 118f, VillageDay().Take(12).ToArray());
        await VillageShot(3, Time.Afternoon, "hub7_hamlet", town, 56f, 118f, VillageDay());
        await VillageShot(3, Time.Morning, "hub7_stop_hearth", new Vector3(-1.2f, 0, -3.8f), 34f, 34.7f, new[]
        {
            Cast("tharr", new(1.0f, 0, -8.4f), Job.Stand, facing: Facing.East),
            Cast("fenwick", new(5.7f, 0, 1.9f), Job.Stand, facing: Facing.West),
            Cast("player", new(-7.8f, 0, 0.1f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.East),
            Cast("hazel", new(1.8f, 0, -4.2f), Job.Stand, facing: Facing.West),
            Cast("wynn", new(-3.0f, 0, 2.9f), Job.Seat),
        });
        var shift = VillageGate - Gate;
        await VillageShot(3, Time.Evening, "hub7_stop_delve", VillageGate + new Vector3(-0.16f, 0, -0.48f), 30f, 23.1f, new[]
        {
            Cast("hilde", Slots[0] + shift, Job.Stand),
            Cast("raven", Slots[1] + shift, Job.Stand),
            Cast("oskar", Slots[2] + shift, Job.Stand),
            Cast("sera", Slots[3] + shift, Job.Stand),
            Cast("tharr", new(1.0f, 0, -8.4f), Job.Stand, facing: Facing.East),
        });
        await VillageShot(3, Time.Afternoon, "hub7_stop_river", new Vector3(-6.2f, 1.2f, 15.4f), 34f, 34.7f, VillageDay());
        await VillageShot(3, Time.Evening, "hub7_stop_road", new Vector3(16, 3.0f, 5.5f), 34f, 34.7f, RoadEvening());
        await VillageShot(3, Time.Afternoon, "hub7_stop_east", new Vector3(29, 3.2f, 11), 34f, 34.7f, VillageDay());
        await VillageShot(3, Time.Evening, "hub7_stop_hill", new Vector3(13.5f, 2.6f, -11), 34f, 34.7f, HillEvening());
        await RunSolid();
        await RunLineup();
    }

    /// <summary>The same stops with the low-poly 3D twins in place of the cards (user suggestion, 2026-09-30).</summary>
    private async Task RunSolid()
    {
        _solid = true;
        _props3D = true;
        foreach (bool trees in new[] { false, true })
        {
            _trees3D = trees;
            string tag = trees ? "_3dtrees" : "_3d";
            await VillageShot(3, Time.Afternoon, "hub8_hamlet" + tag, new Vector3(8, 0, 2), 56f, 118f, VillageDay());
            await VillageShot(3, Time.Morning, "hub8_hearth" + tag, new Vector3(-1.2f, 0, -3.8f), 34f, 34.7f, VillageDay());
            await VillageShot(3, Time.Afternoon, "hub8_river" + tag, new Vector3(-6.2f, 1.2f, 15.4f), 34f, 34.7f, VillageDay());
            await VillageShot(3, Time.Evening, "hub8_road" + tag, new Vector3(16, 3.0f, 5.5f), 34f, 34.7f, RoadEvening());
            await VillageShot(3, Time.Afternoon, "hub8_east" + tag, new Vector3(29, 3.2f, 11), 34f, 34.7f, VillageDay());
            await VillageShot(3, Time.Evening, "hub8_delve" + tag, VillageGate + new Vector3(-0.3f, 0, -1.4f), 30f, 23.1f, DelveLineUp());
        }
        _solid = _props3D = _trees3D = false;
    }

    /// <summary>The four picks on their gate slots, which moved north with the gate.</summary>
    private static (string, string, Vector3, Job, string, int, int, Facing)[] DelveLineUp()
    {
        var shift = VillageGate - Gate;
        return new[]
        {
            Cast("hilde", Slots[0] + shift, Job.Stand), Cast("raven", Slots[1] + shift, Job.Stand),
            Cast("oskar", Slots[2] + shift, Job.Stand), Cast("sera", Slots[3] + shift, Job.Stand),
        };
    }

    private static (string, string, Vector3, Job, string, int, int, Facing)[] RoadEvening() => new[]
    {
        Cast("elara", new(16.9f, 0, 7.65f), Job.Seat),
        Cast("arkus", new(17.9f, 0, 7.65f), Job.Seat),
        Cast("hilde", new(21.2f, 0, 7.95f), Job.Seat),
        Cast("raven", new(19.0f, 0, 9.0f), Job.Stand, facing: Facing.East),
        Cast("hazel", new(20.1f, 0, 9.0f), Job.Stand, facing: Facing.West),
        Cast("wynn", new(23.4f, 0, 9.6f), Job.Stand, facing: Facing.West),
        Cast("thistle", new(24.6f, 0, 10.3f), Job.Seat),
        Cast("flick", new(12.9f, 0, 5.2f), Job.Seat),
    };

    private static (string, string, Vector3, Job, string, int, int, Facing)[] HillEvening() => new[]
    {
        Cast("oskar", new(15.4f, 0, -12.6f), Job.Stand, facing: Facing.West),
        Cast("josen", new(11.6f, 0, -9.8f), Job.Seat),
        Cast("vasska", new(9.0f, 0, -8.8f), Job.Seat),
    };

    private static (string, string, Vector3, Job, string, int, int, Facing)[] VillageDay() => new[]
    {
        Cast("tharr", new(1.0f, 0, -8.4f), Job.Stand, facing: Facing.East),
        Cast("fenwick", new(5.7f, 0, 1.9f), Job.Stand, facing: Facing.West),
        Cast("player", new(-7.8f, 0, 0.1f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.East),
        Cast("hilde", new(-11.0f, 0, 6.3f), Job.Work, "p2_mine", 0, 2, Facing.West),
        Cast("grub", new(-2.5f, 0, 16.6f), Job.Work, "p2", 4, 2, Facing.East),
        Cast("elara", new(7.2f, 0, 6.4f), Job.Work, "p2", 4, 5, Facing.South),
        Cast("raven", new(20.7f, 0, 16.9f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.West),
        Cast("thistle", new(16.4f, 0, 15.4f), Job.Work, "p2", 0, 5, Facing.West),
        Cast("josen", new(11.6f, 0, -9.8f), Job.Seat),
        Cast("hazel", new(1.8f, 0, -4.2f), Job.Stand, facing: Facing.West),
        Cast("oskar", new(15.4f, 0, -12.6f), Job.Stand, facing: Facing.West),
        Cast("wynn", new(-3.0f, 0, 2.9f), Job.Seat),
        Cast("arkus", new(-13.8f, 0, 3.2f), Job.Work, "p2", 4, 5, Facing.South),
        Cast("spore", new(-6.4f, 0, 13.4f), Job.Work, "p2", 0, 5, Facing.West),
        Cast("flick", new(13.2f, 0, 5.0f), Job.Work, "p2_mine", 0, 1, Facing.West),
        Cast("aldric", new(22.6f, 0, 16.0f), Job.Stand, facing: Facing.West),
        Cast("sera", new(3.0f, 0, -9.6f), Job.Stand, facing: Facing.West),
        Cast("vasska", new(9.0f, 0, -8.8f), Job.Seat),
    };

    private static (string, string, Vector3, Job, string, int, int, Facing) Cast(string id, Vector3 spot, Job job,
        string page = "", int row = 0, int column = 0, Facing facing = Facing.South) => (id, "", spot, job, page, row, column, facing);

    private async Task VillageShot(int tier, Time time, string name, Vector3 target, float pitch, float distance,
        (string Id, string Spot, Vector3 Where, Job Job, string Page, int Row, int Column, Facing Facing)[] cast)
    {
        bool close = distance < 50f;
        RestoreCards();
        LightLanterns(time == Time.Evening);
        foreach (var (site, sprite, light) in _sites)
        {
            bool built = tier >= site.From && tier <= site.To && !(site.DayOnly && time == Time.Evening);
            sprite.Visible = built && !(close && InFront(sprite, target));
            if (light != null) light.LightEnergy = built && time == Time.Evening ? 2.0f : 0f;
        }
        foreach (var (from, node) in _tiered) node.Visible = tier >= from && !(close && InFront(node, target));
        foreach (var (from, node) in _shadows) node.Visible = tier >= from && !(close && InFront(node, target));
        ShowHouses(tier, time, close, target);
        ShowModels();
        LightDoors(time == Time.Evening);
        foreach (var (tree, cut) in _forest) tree.Visible = tier < cut && !(close && TreeInFront(tree, target));
        foreach (string tent in new[] { "ShelterWest", "ShelterEast" })
            if (_outpost.GetNodeOrNull<Node3D>(tent) is { } shelter) shelter.Visible = tier < 3;
        if (_terrain.MaterialOverride is ShaderMaterial ground)
        {
            var doors = Sites.Where(s => s.Building.Length > 0 && s.From <= tier && tier <= s.To && DoorX.ContainsKey(s.Building))
                .Select(s => new Vector4(s.At.X + DoorX[s.Building], s.At.Y + 0.9f, 1.6f, 1.0f));
            ground.SetShaderParameter("patches", Padded(Patches.Where(p => p.Tier <= tier).Select(p => p.Patch).Concat(doors), 32));
            var segments = Roads.Where(r => r.Tier <= tier).SelectMany(r => Segments(r.Points).Select(s => (s.A, s.B, r.Width))).ToArray();
            ground.SetShaderParameter("roads", Padded(segments.Select(s => new Vector4(s.A.X, s.A.Y, s.B.X, s.B.Y)), 32));
            ground.SetShaderParameter("road_widths", segments.Select(s => s.Width).Concat(Enumerable.Repeat(0f, 32)).Take(32).ToArray());
            ground.SetShaderParameter("stream", Padded(Segments(Stream).Select(s => new Vector4(s.A.X, s.A.Y, s.B.X, s.B.Y)), 12));
        }
        _stations.Clear();
        _stations["delve"] = _gate + new Vector3(0, 2.6f, 0);
        _stations["unlocks"] = new Vector3(-4.9f, 2.2f, 2.0f);
        _stations["bestiary"] = new Vector3(4.6f, 1.4f, 1.8f);
        foreach (var (key, from, to, at) in Places)
            if (tier >= from && tier <= to) _stations[key] = new Vector3(at.X, 1.0f, at.Y);
        Light(time);
        foreach (var hero in _heroes.Values) hero.Hide();
        foreach (var (id, _, spot, job, page, row, column, facing) in cast)
            Place(new Post(id, 1, spot, job, page, row, column, facing), 1);
        SyncShadows();
        Orbit(target, pitch, distance);
        await Shot(name);
    }
}
