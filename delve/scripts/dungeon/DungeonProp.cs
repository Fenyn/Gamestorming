using System.Collections.Generic;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;
/// <summary>Small reusable blockout prop scene. No gameplay collision; the room layout owns blocking.</summary>
public partial class DungeonProp : Node3D
{
    public DungeonPalette? Palette { get; set; }

    /// <summary>Every lamp this prop lit, so the room can warm them without scanning its tree.</summary>
    public List<OmniLight3D> Lamps { get; } = new();

    /// <summary>Every mesh and tree this prop built, so the room can dim them with its fog tier.</summary>
    public List<GeometryInstance3D> Meshes { get; } = new();
    public List<Delve.Props.TreeProp> Trees { get; } = new();

    private Color Tint(string key) => Palette?.Tint(key) ?? Colors.Magenta;

    private void AddLamp(OmniLight3D lamp)
    {
        AddChild(lamp);
        Lamps.Add(lamp);
    }

    public void Build(RoomProp p)
    {
        Position = new Vector3(p.X, 0, p.Y);
        RotationDegrees = new Vector3(0, p.Angle, 0);
        var stone = Tint("stone");
        var wood = Tint("wood");
        var iron = Tint("iron");
        if (BuildStation(p) || BuildFeature(p) || BuildForest(p) || BuildArrival(p)) return;
        switch (p.Kind)
        {
            case "stairs":
                for (int i = 0; i < 4; i++)
                    Box(new(0, 0.12f * (i + 1), -0.75f + i * 0.5f), new(1.8f, 0.24f * (i + 1), 0.5f), stone.Lightened(i * 0.04f));
                break;
            case "inscription":
                Box(new(0, 0.12f, 0), new(1.2f, 0.24f, 0.5f), stone);
                AddChild(new Label3D { Text = "THE WARD REMEMBERS", FontSize = 24, PixelSize = 0.006f, Position = new(0, 0.6f, 0), Billboard = BaseMaterial3D.BillboardModeEnum.Enabled, Modulate = Tint("inscription") });
                break;
            case "torch":
                Box(new(0, 0.8f, 0), new(0.12f, 1.4f, 0.12f), wood, surface: "wood");
                Box(new(0, 1.5f, 0), new(0.23f, 0.35f, 0.23f), Tint("torch_flame"), true);
                AddLamp(new OmniLight3D { Position = new(0, 1.9f, 0), LightColor = Tint("torch_light"), LightEnergy = 2.2f, OmniRange = 8, ShadowEnabled = false });
                break;
            case "shrine":
                foreach (float x in new[] { -0.8f, 0.8f })
                    Cylinder(new(x, 0.9f, -0.65f), 0.12f, 0.15f, 1.8f, stone);
                Box(new(0, 1.85f, -0.65f), new(1.9f, 0.2f, 0.35f), stone);
                Box(new(0, 0.2f, 0), new(2, 0.4f, 1.8f), stone);
                Box(new(0, 0.8f, -0.35f), new(0.65f, 1.1f, 0.7f), stone.Lightened(0.15f));
                Box(new(0, 1.6f, -0.35f), new(0.45f, 0.5f, 0.45f), stone.Lightened(0.2f));
                Box(new(0, 0.65f, 0.55f), new(1.4f, 0.45f, 0.6f), stone.Darkened(0.2f));
                Box(new(0, 0.95f, 0.55f), new(0.25f, 0.15f, 0.25f), Tint("shrine_crystal"), true);
                AddLamp(new OmniLight3D { Position = new(0, 1.6f, 0), LightColor = Tint("shrine_light"), LightEnergy = 1.5f, OmniRange = 5 });
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
                Box(new(-0.5f, 0.12f, 0.4f), new(0.65f, 0.18f, 1.5f), Tint("bedroll_moss"), surface: "cloth");
                Box(new(0.45f, 0.12f, 0.4f), new(0.65f, 0.18f, 1.5f), Tint("bedroll_heather"), surface: "cloth");
                Box(new(0, 0.2f, -0.5f), new(0.6f, 0.4f, 0.6f), stone);
                Box(new(0, 0.5f, -0.5f), new(0.25f, 0.3f, 0.25f), Tint("camp_embers"), true);
                break;
            case "bed":
                if (p.Width > p.Depth)
                {
                    RotationDegrees += new Vector3(0, 90, 0);
                    p = p with { Width = p.Depth, Depth = p.Width };
                }
                Box(new(0, 0.3f, 0), new(p.Width, 0.4f, p.Depth), wood, surface: "wood");
                Box(new(0, 0.55f, 0), new(p.Width, 0.12f, p.Depth), Tint("bed_blanket"), surface: "cloth");
                Box(new(0, 0.66f, -p.Depth * 0.3f), new(p.Width * 0.75f, 0.18f, 0.35f), Tint("bed_linen"), surface: "linen");
                Box(new(0, 0.5f, -p.Depth / 2 + 0.08f), new(p.Width, 0.9f, 0.14f), wood, surface: "wood");
                break;
            default:
                Box(new(0, p.Height / 2, 0), new(p.Width, p.Height, p.Depth), stone);
                break;
        }
    }

    public void Resolve()
    {
        // A small marker stays in the world without changing walkability.
        Box(new(0, 0.08f, 1), new(0.7f, 0.08f, 0.2f), UiColors.Accent);
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
        Meshes.Add(mesh);
        return mesh;
    }
}
