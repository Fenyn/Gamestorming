using Godot;

namespace Delve.Dungeon;

public partial class DungeonProp
{
    /// <summary>What the party came from, built out through the entrance's outer mouth. The prop
    /// stands on the mouth's middle tile with local -Z pointing off the floor; its depth is how far
    /// the drawn way reaches.</summary>
    private bool BuildArrival(RoomProp p)
    {
        switch (p.Kind)
        {
            case "old_road":
                BuildWaymarker(new Vector3(-p.Width / 2 - 0.7f, 0, -1.2f));
                BuildRoadCamp(new Vector3(0, 0, -(p.Depth - 1.5f)));
                return true;
            case "holloway_rise":
                BuildLanternPost(new Vector3(-p.Width / 2 + 0.3f, 0, -0.7f));
                return true;
            case "stair_rise":
                BuildStairRise(p.Width);
                return true;
            default:
                return false;
        }
    }

    /// <summary>A leaning post with a sign board and a few stones at its foot.</summary>
    private void BuildWaymarker(Vector3 at)
    {
        var wood = Tint("wood");
        var post = Box(at + new Vector3(0, 0.8f, 0), new(0.16f, 1.6f, 0.16f), wood, surface: "wood");
        post.RotationDegrees = new(0, 0, -4);
        var board = Box(at + new Vector3(0.28f, 1.35f, 0), new(0.7f, 0.24f, 0.05f), wood.Lightened(0.12f), surface: "wood");
        board.RotationDegrees = new(0, 18, 0);
        for (int i = 0; i < 3; i++)
            Box(at + new Vector3((i - 1) * 0.24f, 0.09f, 0.18f * (i % 2)), new(0.26f, 0.18f, 0.22f), Tint("stone").Darkened(i * 0.06f));
    }

    /// <summary>The party's last camp at the far end of the road: a ring of stones round the embers,
    /// two bedrolls and a handcart.</summary>
    private void BuildRoadCamp(Vector3 at)
    {
        var stone = Tint("stone");
        for (int i = 0; i < 6; i++)
        {
            float angle = i * Mathf.Tau / 6;
            Box(at + new Vector3(Mathf.Cos(angle) * 0.45f, 0.08f, Mathf.Sin(angle) * 0.45f), new(0.2f, 0.16f, 0.2f), stone.Darkened(i * 0.03f));
        }
        Box(at + new Vector3(0, 0.12f, 0), new(0.34f, 0.18f, 0.34f), Tint("camp_embers"), true);
        AddLamp(new OmniLight3D { Position = at + new Vector3(0, 0.9f, 0), LightColor = Tint("hearth_light"), LightEnergy = 2.4f, OmniRange = 7, ShadowEnabled = false });
        Box(at + new Vector3(-1.1f, 0.08f, 0.2f), new(0.6f, 0.14f, 1.4f), Tint("bedroll_moss"), surface: "cloth");
        Box(at + new Vector3(1.1f, 0.08f, 0.4f), new(0.6f, 0.14f, 1.4f), Tint("bedroll_heather"), surface: "cloth");
    }

    /// <summary>A lantern hung on a post at the holloway's foot. The sunken lane itself is terrain
    /// (<see cref="GladeShell.ArrivalBank"/>).</summary>
    private void BuildLanternPost(Vector3 at)
    {
        var wood = Tint("wood");
        Box(at + new Vector3(0, 0.9f, 0), new(0.14f, 1.8f, 0.14f), wood, surface: "wood");
        Box(at + new Vector3(0.28f, 1.72f, 0), new(0.5f, 0.08f, 0.08f), wood, surface: "wood");
        Box(at + new Vector3(0.48f, 1.5f, 0), new(0.18f, 0.24f, 0.18f), Tint("torch_flame"), true);
        AddLamp(new OmniLight3D { Position = at + new Vector3(0.48f, 1.4f, 0.3f), LightColor = Tint("torch_light"), LightEnergy = 1.4f, OmniRange = 6, ShadowEnabled = false });
    }

    /// <summary>The root stair down into the station: stone steps rising out of the wall gap between
    /// masonry cheeks, roots grown over the top, a torch at the foot.</summary>
    private void BuildStairRise(float width)
    {
        const int steps = 6;
        const float rise = 0.25f, tread = 0.5f;
        var stone = Tint("station_stone");
        for (int i = 0; i < steps; i++)
        {
            float top = rise * (i + 1);
            Box(new(0, top / 2, -0.75f - i * tread), new(width, top, tread), stone.Darkened(i * 0.05f));
        }
        float cheek = width / 2 + 0.25f, length = steps * tread + 0.5f;
        foreach (float side in new[] { -1f, 1f })
            Box(new(side * cheek, 1.6f, -0.5f - length / 2), new(0.5f, 3.2f, length), Tint("masonry"));
        var root = Tint("root");
        float end = -0.5f - length + 0.3f;
        foreach (float side in new[] { -1f, 1f })
        {
            var leg = Box(new(side * (cheek - 0.3f), 2.6f, end), new(0.24f, 1.4f, 0.24f), root, surface: "wood");
            leg.RotationDegrees = new(0, 0, side * -12);
        }
        Box(new(0, 3.3f, end), new(2 * cheek, 0.26f, 0.3f), root, surface: "wood");
        var torch = new Vector3(cheek - 0.35f, 0, -0.9f);
        Box(torch + new Vector3(0, 1.5f, 0), new(0.1f, 0.5f, 0.1f), Tint("wood"), surface: "wood");
        Box(torch + new Vector3(0, 1.82f, 0), new(0.2f, 0.26f, 0.2f), Tint("torch_flame"), true);
        AddLamp(new OmniLight3D { Position = torch + new Vector3(-0.3f, 2.1f, 0.4f), LightColor = Tint("torch_light"), LightEnergy = 1.6f, OmniRange = 6, ShadowEnabled = false });
    }
}
