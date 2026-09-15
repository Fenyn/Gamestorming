using Godot;

namespace Delve.Dungeon;
/// <summary>Small reusable blockout prop scene. No gameplay collision; the room layout owns blocking.</summary>
public partial class DungeonProp : Node3D
{
    public DungeonPalette? Palette { get; set; }

    public void Build(RoomProp p)
    {
        Position = new Vector3(p.X, 0, p.Y);
        RotationDegrees = new Vector3(0, p.Angle, 0);
        var stone = new Color("737780");
        var wood = new Color("69503a");
        var iron = new Color("343b46");
        if (BuildStation(p) || BuildFeature(p)) return;
        switch (p.Kind)
        {
            case "stairs":
                for (int i = 0; i < 4; i++)
                    Box(new(0, 0.12f * (i + 1), -0.75f + i * 0.5f), new(1.8f, 0.24f * (i + 1), 0.5f), stone.Lightened(i * 0.04f));
                break;
            case "inscription":
                Box(new(0, 0.12f, 0), new(1.2f, 0.24f, 0.5f), stone);
                AddChild(new Label3D { Text = "THE WARD REMEMBERS", FontSize = 24, PixelSize = 0.006f, Position = new(0, 0.6f, 0), Billboard = BaseMaterial3D.BillboardModeEnum.Enabled, Modulate = new Color("c5b68e") });
                break;
            case "torch":
                Box(new(0, 0.8f, 0), new(0.12f, 1.4f, 0.12f), wood, surface: "wood");
                Box(new(0, 1.5f, 0), new(0.23f, 0.35f, 0.23f), new Color("ffc16a"), true);
                AddChild(new OmniLight3D { Position = new(0, 1.9f, 0), LightColor = new Color("ffc983"), LightEnergy = 2.2f, OmniRange = 8, ShadowEnabled = false });
                break;
            case "shrine":
                foreach (float x in new[] { -0.8f, 0.8f })
                    Cylinder(new(x, 0.9f, -0.65f), 0.12f, 0.15f, 1.8f, stone);
                Box(new(0, 1.85f, -0.65f), new(1.9f, 0.2f, 0.35f), stone);
                Box(new(0, 0.2f, 0), new(2, 0.4f, 1.8f), stone);
                Box(new(0, 0.8f, -0.35f), new(0.65f, 1.1f, 0.7f), stone.Lightened(0.15f));
                Box(new(0, 1.6f, -0.35f), new(0.45f, 0.5f, 0.45f), stone.Lightened(0.2f));
                Box(new(0, 0.65f, 0.55f), new(1.4f, 0.45f, 0.6f), stone.Darkened(0.2f));
                Box(new(0, 0.95f, 0.55f), new(0.25f, 0.15f, 0.25f), new Color("7cd9dd"), true);
                AddChild(new OmniLight3D { Position = new(0, 1.6f, 0), LightColor = new Color("85d9df"), LightEnergy = 1.5f, OmniRange = 5 });
                break;
            case "cache":
                Box(new(0, 0.4f, 0), new(1.7f, 0.25f, 1.1f), wood, surface: "wood");
                Box(new(-0.6f, 0.85f, 0), new(0.65f, 0.65f, 0.7f), wood.Lightened(0.13f), surface: "wood");
                Box(new(0.5f, 0.7f, 0), new(0.6f, 0.4f, 0.65f), wood, surface: "wood");
                foreach (float x in new[]
                {
                    -0.8f,
                    0.8f
                }

                )
                    Box(new(x, 0.25f, 0.5f), new(0.15f, 0.5f, 0.5f), iron, surface: "iron");
                Box(new(0.5f, 1, 0), new(0.7f, 0.15f, 0.75f), iron, surface: "iron");
                break;
            case "collapse":
                for (int i = 0; i < 9; i++)
                {
                    var b = Box(new((i % 3 - 1) * 0.55f, 0.2f + (i / 3) * 0.25f, (i / 3 - 1) * 0.55f), new(0.7f, 0.6f, 0.8f), stone.Darkened(i * 0.025f));
                    b.RotationDegrees = new(i * 7, i * 29, i * 11);
                }

                var beam = Box(new(0, 1.1f, 0), new(2.3f, 0.2f, 0.3f), wood, surface: "wood");
                beam.RotationDegrees = new(0, 25, 25);
                break;
            case "camp":
                Box(new(-0.5f, 0.12f, 0.4f), new(0.65f, 0.18f, 1.5f), new Color("5f6c69"), surface: "cloth");
                Box(new(0.45f, 0.12f, 0.4f), new(0.65f, 0.18f, 1.5f), new Color("665862"), surface: "cloth");
                Box(new(0, 0.2f, -0.5f), new(0.6f, 0.4f, 0.6f), stone);
                Box(new(0, 0.5f, -0.5f), new(0.25f, 0.3f, 0.25f), new Color("efa462"), true);
                break;
            case "bed":
                if (p.Width > p.Depth)
                {
                    RotationDegrees += new Vector3(0, 90, 0);
                    p = p with { Width = p.Depth, Depth = p.Width };
                }
                Box(new(0, 0.3f, 0), new(p.Width, 0.4f, p.Depth), wood, surface: "wood");
                Box(new(0, 0.55f, 0), new(p.Width, 0.12f, p.Depth), new Color("6c4d4c"), surface: "cloth");
                Box(new(0, 0.66f, -p.Depth * 0.3f), new(p.Width * 0.75f, 0.18f, 0.35f), new Color("c9bfa3"), surface: "linen");
                Box(new(0, 0.5f, -p.Depth / 2 + 0.08f), new(p.Width, 0.9f, 0.14f), wood, surface: "wood");
                break;
            default:
                Box(new(0, p.Height / 2, 0), new(p.Width, p.Height, p.Depth), stone);
                break;
        }
    }

    public void Resolve()
    {
        foreach (var child in GetChildren())
            if (child is OmniLight3D light)
                light.LightEnergy *= 0.4f;
        // A small marker stays in the world without changing walkability.
        Box(new(0, 0.08f, 1), new(0.7f, 0.08f, 0.2f), new Color("76a391"));
    }

    public MeshInstance3D Box(Vector3 at, Vector3 size, Color color, bool glow = false, string surface = "stone")
    {
        var material = !glow && Palette != null ? Palette.Material(color, surface) : new StandardMaterial3D
        {
            AlbedoColor = color,
            Roughness = 0.95f,
            EmissionEnabled = glow,
            Emission = color,
            EmissionEnergyMultiplier = glow ? 1.5f : 0
        };
        var mesh = new MeshInstance3D
        {
            Position = at,
            Mesh = new BoxMesh
            {
                Size = size
            },
            MaterialOverride = material
        };
        AddChild(mesh);
        return mesh;
    }
}
