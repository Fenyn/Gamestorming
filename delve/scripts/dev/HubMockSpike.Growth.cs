using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Data;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The growing camp (scratchpad hub_growth.md): zones open as residents join, every resident works
/// at a spot that fits them, and the camera widens by whole-number sprite scales. Three stages
/// (4, 9 and 18 residents) plus a panned alternative for the full camp.
/// </summary>
public partial class HubMockSpike
{
    [Export] public Texture2D? PropAtlas { get; set; }

    private enum Job { Work, Stand, Seat }

    /// <summary>One resident's place: the stage it joins at, the spot, and the frame it holds there.</summary>
    private sealed record Post(string Id, int Stage, Vector3 Spot, Job Job, string Page = "", int Row = 0, int Column = 0, Facing Facing = Facing.South);

    private static readonly Post[] Posts =
    {
        // Stage 1: the start four.
        new("player", 1, new(-7.8f, 0, 0.1f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.East),
        new("elara", 1, new(6.3f, 0, -1.2f), Job.Work, "p2", 4, 5, Facing.South),
        new("tharr", 1, new(3.0f, 0, -6.7f), Job.Work, "p2_mine", 0, 2, Facing.West),
        new("fenwick", 1, new(1.4f, 0, 1.7f), Job.Work, "p2", 0, 5, Facing.West),
        // Stage 2: training ground, garden, infirmary, forge.
        new("raven", 2, new(-6.9f, 0, 5.9f), Job.Work, ManaSeedSheet.AxePage, 0, 2, Facing.West),
        new("thistle", 2, new(-7.3f, 0, 2.9f), Job.Work, "p2", 0, 5, Facing.West),
        new("grub", 2, new(8.2f, 0, 1.4f), Job.Work, "p2", 0, 2, Facing.East),
        new("josen", 2, new(6.9f, 0, -3.6f), Job.Seat),
        new("arkus", 2, new(-10.5f, 0, -0.6f), Job.Work, "p2_mine", 0, 2, Facing.South),
        // Stage 3: shrine, quarry, Wardstone, apothecary, junk bench, gate watch, stories.
        new("aldric", 3, new(-5.0f, 0, -4.6f), Job.Stand, Facing: Facing.South),
        new("oskar", 3, new(-8.1f, 0, -4.5f), Job.Seat),
        new("vasska", 3, new(-10.9f, 0, -5.2f), Job.Seat),
        new("hazel", 3, new(5.7f, 0, 1.9f), Job.Stand, Facing: Facing.West),
        new("wynn", 3, new(-0.6f, 0, 0.1f), Job.Stand, Facing: Facing.South),
        new("hilde", 3, new(-14.2f, 0, -2.7f), Job.Work, "p2_mine", 0, 2, Facing.North),
        new("sera", 3, new(-12.0f, 0, 3.3f), Job.Stand, Facing: Facing.West),
        new("spore", 3, new(9.1f, 0, -7.5f), Job.Work, "p2", 4, 2, Facing.East),
        new("flick", 3, new(12.5f, 0, 1.8f), Job.Work, "p2_mine", 0, 1, Facing.South),
    };

    /// <summary>Atlas props by zone ring: region in outpost_props.png and the world spot.</summary>
    private static readonly (int Ring, Rect2 Region, Vector3 Spot)[] ZoneProps =
    {
        (1, new(0, 624, 48, 96), new(-4.9f, 0, 2.0f)),      // Unlocks notice board
        (1, new(576, 192, 48, 96), new(-6.9f, 0, -0.1f)),   // stump with axe
        (1, new(480, 288, 96, 96), new(5.3f, 0, -1.7f)),    // stores cart
        (1, new(336, 672, 48, 96), new(-4.1f, 0, -5.2f)),   // gate lantern
        (1, new(336, 672, 48, 96), new(-0.25f, 0, -6.2f)),  // gate lantern
        (2, new(0, 480, 48, 96), new(-8.0f, 0, 5.8f)),      // training dummy
        (2, new(48, 480, 48, 96), new(-10.1f, 0, 4.1f)),    // archery target
        (2, new(240, 96, 48, 48), new(9.4f, 0, 0.8f)),      // crops
        (2, new(288, 96, 48, 48), new(10.2f, 0, 0.4f)),
        (2, new(336, 144, 48, 48), new(9.8f, 0, -0.4f)),
        (2, new(144, 96, 48, 96), new(-11.1f, 0, -0.9f)),   // anvil
        (2, new(48, 192, 48, 96), new(-11.8f, 0, -1.9f)),   // grindstone
        (3, new(480, 480, 48, 96), new(-8.3f, 0, -5.3f)),   // shrine marker
        (3, new(576, 480, 48, 96), new(-13.1f, 0, 3.0f)),   // Wardstone plinth stand-in
        (3, new(240, 672, 48, 48), new(10.0f, 0, -8.2f)),   // apothecary barrels
        (3, new(288, 672, 48, 48), new(10.6f, 0, -8.0f)),
        (3, new(96, 528, 96, 96), new(12.9f, 0, 1.0f)),     // junk heap
        (3, new(672, 384, 48, 48), new(13.8f, 0, 1.6f)),    // loose wheel
    };

    private readonly List<(int Ring, Sprite3D Sprite)> _zoneSprites = new();

    private async Task RunGrowth()
    {
        ArrangeGrowthProps();
        await Stage(1, "hub3_stage1", new Vector3(-1.3f, 0, -2.4f), 32f, 27.8f);
        await Stage(2, "hub3_stage2", new Vector3(-1.4f, 0, -2.9f), 34f, 34.7f);
        await Stage(3, "hub3_stage3", new Vector3(-1.6f, 0, -3.4f), 36f, 46.3f);
        // The panned alternative keeps 4x sprites and shows half the camp at a time (MYZ Ark).
        Orbit(new Vector3(-6.2f, 0, -1.6f), 34f, 34.7f);
        await Shot("hub3_stage3_pan_west");
        Orbit(new Vector3(3.4f, 0, -4.2f), 34f, 34.7f);
        await Shot("hub3_stage3_pan_east");
    }

    private async Task Stage(int stage, string name, Vector3 target, float pitch, float distance)
    {
        // Open zones are lit; the next ring shows as disused sites at the edges; later rings are hidden.
        foreach (var (ring, sprite) in _zoneSprites)
        {
            sprite.Visible = ring <= stage + 1;
            sprite.Modulate = ring <= stage ? Colors.White : new Color(0.62f, 0.62f, 0.66f);
        }
        foreach (var post in Posts) Place(post, stage);
        if (stage >= 3) _stations["wardstone"] = new Vector3(-13.1f, 1.6f, 3.0f);
        Orbit(target, pitch, distance);
        await Shot(name);
    }

    private void Place(Post post, int stage)
    {
        if (post.Stage > stage)
        {
            if (_heroes.TryGetValue(post.Id, out var absent)) absent.Hide();
            return;
        }
        switch (post.Job)
        {
            case Job.Work:
                var sprite = Sheeted(post.Id);
                sprite.Texture = Sheet(post.Id, post.Page);
                sprite.Frame = (post.Row + (int)post.Facing) * ManaSeedSheet.Columns + post.Column;
                Stand(sprite, post.Spot);
                break;
            case Job.Stand:
                Pose(post.Id, post.Spot, Walk.Stand, post.Facing);
                break;
            case Job.Seat:
                Seated(_stage, post.Id, post.Spot);
                break;
        }
        Hero(post.Id).Show();
    }

    private void ArrangeGrowthProps()
    {
        foreach (var prop in _outpost.GetChildren().OfType<Sprite3D>().Where(p => !p.Name.ToString().StartsWith("CampGrass")))
            Rescale(prop, prop.Name == "Fire" ? HeroPixel : PropPixel);
        MoveProp("Woodpile", new Vector3(-8.1f, 0, -0.6f));
        MoveProp("SharedTools", new Vector3(-9.2f, 0, 6.6f));
        MoveProp("SharedTable", new Vector3(4.6f, 0, 1.8f));
        MoveProp("HerbPots0", new Vector3(10.9f, 0, 0.2f));
        MoveProp("HerbPots1", new Vector3(8.6f, 0, 2.3f));
        MoveProp("TravelSupplies", new Vector3(6.3f, 0, -2.8f));
        MoveProp("Supplies0", new Vector3(7.1f, 0, -2.3f));
        MoveProp("Supplies1", new Vector3(12.2f, 0, 0.3f));
        MoveProp("Supplies2", new Vector3(13.4f, 0, 0.2f));
        MoveProp("Seat2", new Vector3(-3.0f, 0, 2.9f));
        MoveProp("Seat3", new Vector3(2.8f, 0, 1.3f));
        MoveProp("Seat4", new Vector3(-2.5f, 0, 0.8f));
        MoveProp("Seat5", new Vector3(1.4f, 0, -0.2f));
        foreach (string hidden in new[] { "Seat0", "Seat1" })
            if (_outpost.GetNodeOrNull<Node3D>(hidden) is { } node) node.Hide();
        if (_outpost.GetNodeOrNull<Node3D>("ShelterEast") is { } east)
            east.Position = new Vector3(8.6f, east.Position.Y - _terrain.HeightAt(east.Position) + _terrain.HeightAt(new Vector3(8.6f, 0, -5.7f)), -5.7f);
        if (_outpost.GetNodeOrNull<Node3D>("ShelterWest") is { } west)
            west.Position = new Vector3(-10.2f, west.Position.Y - _terrain.HeightAt(west.Position) + _terrain.HeightAt(new Vector3(-10.2f, 0, 8.8f)), 8.8f);

        foreach (var (ring, region, spot) in ZoneProps)
        {
            var sprite = new Sprite3D
            {
                Texture = PropAtlas,
                RegionEnabled = true,
                RegionRect = region,
                PixelSize = PropPixel,
                Billboard = BaseMaterial3D.BillboardModeEnum.FixedY,
                TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
                AlphaCut = SpriteBase3D.AlphaCutMode.Discard,
                Shaded = true,
            };
            _outpost.AddChild(sprite);
            sprite.Position = spot with { Y = _terrain.HeightAt(spot) + region.Size.Y * PropPixel * 0.5f };
            _zoneSprites.Add((ring, sprite));
        }
        _stations["unlocks"] = new Vector3(-4.9f, 2.2f, 2.0f);
        _stations["bestiary"] = new Vector3(4.6f, 1.2f, 1.8f);
        _stations["stores"] = new Vector3(5.3f, 2.0f, -1.7f);
    }
}
