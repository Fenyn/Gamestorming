using Godot;

namespace Delve.Dungeon;

public partial class DungeonProp
{
    /// <summary>The Regent's grove centrepiece, stood on its landmark footprint.</summary>
    [Export] public PackedScene? RegentTreeScene { get; set; }

    /// <summary>Forest landmarks: the beacon cairn the guardian dens by, and the two ways onward.</summary>
    private bool BuildForest(RoomProp p)
    {
        var stone = Tint("beacon_stone");
        var earth = Tint("earth");
        var root = Tint("root");
        switch (p.Kind)
        {
            case "beacon":
                for (int i = 0; i < 4; i++)
                {
                    float size = 1.5f - i * 0.3f;
                    var block = Box(new(0, 0.2f + i * 0.36f, 0), new(size, 0.38f, size), stone.Darkened(i * 0.04f));
                    block.RotationDegrees = new(0, i * 23, 0);
                }
                Box(new(0, 1.62f, 0), new(0.28f, 0.28f, 0.28f), Tint("beacon_flame"), true);
                AddLamp(new OmniLight3D { Position = new(0, 2f, 0), LightColor = Tint("beacon_light"), LightEnergy = 1.6f, OmniRange = 7 });
                return true;
            case "holloway":
                // A sunken lane: the path drops between two earth banks, so the party walks down into it.
                for (int i = 0; i < 4; i++)
                    Box(new(0, -0.08f - i * 0.14f, -0.75f + i * 0.5f), new(1.4f, 0.16f, 0.5f), earth.Darkened(i * 0.08f), surface: "earth");
                foreach (float x in new[] { -0.9f, 0.9f })
                    Box(new(x, 0.35f, 0), new(0.4f, 0.7f, 2f), earth.Lightened(0.05f), surface: "earth");
                return true;
            case "root_stair":
                for (int i = 0; i < 4; i++)
                    Box(new(0, -0.08f - i * 0.16f, -0.75f + i * 0.5f), new(1.4f, 0.16f, 0.5f), earth.Darkened(0.1f + i * 0.06f), surface: "earth");
                foreach (float x in new[] { -0.85f, 0.85f })
                {
                    var arch = Box(new(x, 0.8f, 0.2f), new(0.3f, 1.8f, 0.3f), root, surface: "wood");
                    arch.RotationDegrees = new(0, 0, x < 0 ? -12 : 12);
                }
                Box(new(0, 1.65f, 0.2f), new(2f, 0.28f, 0.3f), root, surface: "wood");
                return true;
            case GladeGeneration.BigTree:
                return true;
            case "regent_tree":
                if (RegentTreeScene?.Instantiate() is Delve.Props.TreeProp tree)
                {
                    AddChild(tree);
                    Trees.Add(tree);
                }
                return true;
            default:
                return false;
        }
    }
}
