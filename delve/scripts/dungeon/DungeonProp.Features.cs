using Godot;

namespace Delve.Dungeon;

public partial class DungeonProp
{
    private bool BuildFeature(RoomProp p)
    {
        var stone = Tint("feature_stone");
        var wood = Tint("feature_wood");
        var iron = Tint("feature_iron");
        switch (p.Kind)
        {
            case "water_rim":
                Box(new(0, p.Height / 2, 0), new(p.Width, p.Height, p.Depth), stone);
                return true;
            case "cover_trim":
                // Dress the existing half-metre tactical block; do not place a
                // freestanding obstacle on top of a walkable cover tile.
                foreach (float z in new[] { -0.49f, 0.49f })
                    Box(new(0, 0.28f, z), new(0.95f, 0.1f, 0.02f), iron, surface: "iron");
                return true;
            case "sigil":
                var brass = Tint("brass");
                for (int i = 0; i < 12; i++)
                {
                    float angle = i * Mathf.Tau / 12;
                    var mark = Box(new(Mathf.Sin(angle) * 1.15f, 0.012f, Mathf.Cos(angle) * 1.15f), new(0.05f, 0.012f, 0.22f), brass, surface: "iron");
                    mark.Rotation = new Vector3(0, angle, 0);
                }
                Box(new(0, 0.012f, 0), new(0.6f, 0.012f, 0.045f), brass, surface: "iron");
                Box(new(0, 0.012f, 0), new(0.045f, 0.012f, 0.6f), brass, surface: "iron");
                return true;
            case "column":
                Box(new(0, 0.08f, 0), new(0.98f, 0.16f, 0.98f), stone);
                Box(new(0, 1.43f, 0), new(0.98f, 0.14f, 0.98f), stone);
                Cylinder(new(0, 1.65f, 0), 0.42f, 0.34f, 0.3f, stone);
                Box(new(0, 1.85f, 0), new(0.98f, 0.14f, 0.98f), stone);
                return true;
            case "barrel":
                Cylinder(new(0, 0.45f, 0), 0.34f, 0.38f, 0.85f, wood, "wood");
                foreach (float y in new[] { 0.14f, 0.7f })
                    Cylinder(new(0, y, 0), 0.39f, 0.39f, 0.07f, iron, "iron");
                Cylinder(new(0, 0.89f, 0), 0.34f, 0.34f, 0.04f, wood, "wood");
                return true;
            case "urn":
                Box(new(0, 0.1f, 0), new(0.8f, 0.2f, 0.8f), stone);
                Cylinder(new(0, 0.38f, 0), 0.35f, 0.18f, 0.36f, stone);
                Cylinder(new(0, 0.7f, 0), 0.2f, 0.35f, 0.28f, stone);
                Cylinder(new(0, 0.9f, 0), 0.25f, 0.2f, 0.12f, stone);
                return true;
            case "brazier":
            case "votive":
                Box(new(0, 0.1f, 0), new(0.7f, 0.2f, 0.7f), stone);
                Cylinder(new(0, 0.55f, 0), 0.15f, 0.24f, 0.75f, stone);
                Cylinder(new(0, 0.98f, 0), 0.38f, 0.15f, 0.25f, iron, "iron");
                var flame = p.Kind == "votive" ? Tint("votive_flame") : Tint("brazier_flame");
                Box(new(0, 1.18f, 0), new(0.18f, 0.25f, 0.18f), flame, true);
                AddLamp(new OmniLight3D { Position = new(0, 1.5f, 0), LightColor = flame, LightEnergy = 0.65f, OmniRange = 3.5f, ShadowEnabled = false });
                return true;
            case "rack":
                foreach (float x in new[] { -0.34f, 0.34f })
                    Box(new(x, 0.65f, 0.25f), new(0.1f, 1.3f, 0.15f), wood, surface: "wood");
                Box(new(0, 1.1f, 0.25f), new(0.85f, 0.12f, 0.15f), wood, surface: "wood");
                for (int i = 0; i < 3; i++)
                {
                    float x = -0.24f + i * 0.24f;
                    Box(new(x, 0.6f, 0.08f), new(0.055f, 1, 0.055f), wood, surface: "wood");
                    Box(new(x, 1.15f, 0.08f), new(0.13f, 0.23f, 0.08f), iron, surface: "iron");
                }
                return true;
            case "supplies":
                Box(new(0, 0.3f, 0), new(0.8f, 0.6f, 0.8f), wood, surface: "wood");
                foreach (float x in new[] { -0.28f, 0.28f })
                    Box(new(x, 0.31f, 0), new(0.07f, 0.64f, 0.83f), iron, surface: "iron");
                Box(new(0.1f, 0.8f, 0.05f), new(0.55f, 0.35f, 0.6f), wood, surface: "wood");
                Box(new(-0.13f, 1, 0), new(0.3f, 0.12f, 0.48f), Colors.White, surface: "cloth");
                return true;
            case "pipe":
                Cylinder(new(0, 0.65f, 0), 0.2f, 0.2f, 1.3f, iron, "iron");
                foreach (float y in new[] { 0.25f, 1.1f })
                    Cylinder(new(0, y, 0), 0.29f, 0.29f, 0.1f, iron, "iron");
                var outlet = Cylinder(new(0, 0.95f, 0.2f), 0.18f, 0.18f, 0.4f, iron, "iron");
                outlet.RotationDegrees = new(90, 0, 0);
                return true;
            case "rubble":
                for (int i = 0; i < 4; i++)
                {
                    var rock = Box(new((i % 2 - 0.5f) * 0.34f, 0.17f + i * 0.06f, (i / 2 - 0.5f) * 0.34f), new(0.36f, 0.35f, 0.35f), stone);
                    rock.RotationDegrees = new(i * 13, i * 27, i * 8);
                }
                return true;
            case "entrance":
                foreach (float x in new[] { -0.65f, 0.65f })
                    foreach (float z in new[] { -0.55f, 0.55f })
                        Box(new(x, 0.4f, z), new(0.12f, 0.8f, 0.12f), wood, surface: "wood");
                Box(new(0, 0.83f, 0), new(1.7f, 0.14f, 1.4f), wood, surface: "wood");
                Box(new(0, 0.92f, 0), new(1.05f, 0.025f, 0.8f), Tint("ledger_paper"), surface: "paper");
                for (int i = 0; i < 3; i++)
                    Box(new(-0.35f + i * 0.3f, 0.95f, i % 2 * 0.22f - 0.1f), new(0.09f, 0.05f, 0.09f), iron, surface: "iron");
                return true;
            default: return false;
        }
    }

    private MeshInstance3D Cylinder(Vector3 at, float top, float bottom, float height, Color color, string surface = "stone")
    {
        var mesh = new MeshInstance3D
        {
            Position = at,
            Mesh = new CylinderMesh { TopRadius = top, BottomRadius = bottom, Height = height, RadialSegments = 12, Rings = 1 },
            MaterialOverride = Palette?.Material(color, surface) ?? new StandardMaterial3D { AlbedoColor = color, Roughness = 0.9f }
        };
        AddChild(mesh);
        Meshes.Add(mesh);
        return mesh;
    }
}
