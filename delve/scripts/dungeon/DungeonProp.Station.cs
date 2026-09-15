using Godot;

namespace Delve.Dungeon;

public partial class DungeonProp
{
    private bool BuildStation(RoomProp p)
    {
        float w = p.Width, d = p.Depth;
        var wood = new Color("b9a083");
        var iron = new Color("56606a");
        var stone = new Color("949b9e");
        void Timber(Vector3 at, Vector3 size) => Box(at, size, wood, surface: "wood");
        void Table(float height, float width, float depth)
        {
            Timber(new(0, height, 0), new(width, 0.12f, depth));
            foreach (float x in new[] { -width * 0.38f, width * 0.38f })
                foreach (float z in new[] { -depth * 0.4f, depth * 0.4f })
                    Timber(new(x, height / 2, z), new(0.12f, height, 0.12f));
        }
        switch (p.Kind)
        {
            case "bunkbed":
                foreach (float height in new[] { 0.4f, 1.25f })
                {
                    Timber(new(0, height, 0), new(w, 0.13f, d));
                    Box(new(0, height + 0.1f, 0), new(w * 0.94f, 0.13f, d * 0.9f), wood, surface: "cloth");
                    Box(new(-w * 0.32f, height + 0.22f, 0), new(w * 0.2f, 0.14f, d * 0.75f), new Color("c8bda5"), surface: "linen");
                }
                foreach (float x in new[] { -w * 0.46f, w * 0.46f })
                    foreach (float z in new[] { -d * 0.45f, d * 0.45f }) Timber(new(x, 0.8f, z), new(0.08f, 1.6f, 0.08f));
                for (int i = 0; i < 4; i++) Timber(new(w * 0.4f, 0.2f + i * 0.3f, 0), new(0.08f, 0.06f, d * 0.8f));
                return true;
            case "reception":
            case "prep_counter":
            case "tool_bench":
            case "control_desk":
                Table(0.88f, w, d);
                Timber(new(0, 0.48f, d * 0.4f), new(w, 0.65f, 0.08f));
                for (int i = 0; i < 3; i++)
                {
                    float x = (i - 1) * w * 0.22f;
                    if (p.Kind == "control_desk")
                    {
                        Cylinder(new(x, 0.99f, 0), 0.11f, 0.11f, 0.08f, iron, "iron");
                        Box(new(x, 1.1f, 0), new(0.04f, 0.2f, 0.04f), iron, surface: "iron");
                    }
                    else Box(new(x, 0.98f + i * 0.01f, 0), new(w * 0.17f, 0.055f, d * 0.32f), new Color("ccb894"), surface: p.Kind == "tool_bench" ? "iron" : "paper");
                }
                Cylinder(new(w * 0.35f, 1.02f, -d * 0.25f), 0.08f, 0.08f, 0.18f, iron, "iron");
                return true;
            case "dining":
                Table(0.8f, w * 0.5f, d * 0.9f);
                foreach (int side in new[] { -1, 1 })
                {
                    Timber(new(side * w * 0.39f, 0.4f, 0), new(w * 0.18f, 0.12f, d * 0.9f));
                    foreach (float z in new[] { -d * 0.32f, d * 0.32f }) Timber(new(side * w * 0.39f, 0.2f, z), new(0.1f, 0.4f, 0.15f));
                    for (float z = -d * 0.32f; z <= d * 0.34f; z += 0.85f)
                    {
                        Cylinder(new(side * w * 0.14f, 0.885f, z), 0.12f, 0.12f, 0.035f, new Color("bea982"), "pottery");
                        Cylinder(new(side * w * 0.12f, 0.96f, z + 0.18f), 0.055f, 0.06f, 0.14f, iron, "iron");
                    }
                }
                return true;
            case "bench":
                Table(0.42f, w, d);
                return true;
            case "pantry":
            case "weapon_cabinet":
                foreach (float x in new[] { -w * 0.44f, w * 0.44f })
                    foreach (float z in new[] { -d * 0.44f, d * 0.44f }) Timber(new(x, 0.8f, z), new(0.09f, 1.6f, 0.09f));
                foreach (float y in new[] { 0.18f, 0.75f, 1.35f })
                {
                    Timber(new(0, y, 0), new(w, 0.09f, d));
                    for (int i = 0; i < 3; i++)
                        Box(new((i - 1) * w * 0.27f, y + 0.21f, 0), new(w * 0.22f, 0.32f, d * 0.65f), p.Kind == "pantry" ? wood : iron, surface: p.Kind == "pantry" ? "wood" : "iron");
                }
                return true;
            case "screen":
            case "notice_board":
                Timber(new(0, 0.9f, 0), new(w, 1.5f, d * 0.15f));
                foreach (float x in new[] { -w * 0.4f, w * 0.4f }) Timber(new(x, 0.8f, 0), new(0.1f, 1.6f, d * 0.6f));
                if (p.Kind == "notice_board")
                    for (int i = 0; i < 3; i++) Box(new((i - 1) * w * 0.2f, 1 + i * 0.1f, d * 0.09f), new(w * 0.25f, 0.35f, 0.025f), new Color("d2c5a8"), surface: "paper");
                return true;
            case "hearth":
            case "stove":
                Box(new(0, 0.12f, 0), new(w, 0.24f, d), stone);
                foreach (float x in new[] { -w * 0.36f, w * 0.36f }) Box(new(x, 0.6f, 0), new(w * 0.25f, 1, d), stone);
                Box(new(0, 1.12f, 0), new(w, 0.2f, d), stone);
                Box(new(0, 1.5f, -d * 0.25f), new(w * 0.45f, 0.6f, d * 0.45f), stone);
                Box(new(0, 0.35f, 0), new(w * 0.35f, 0.12f, d * 0.6f), new Color("cf713a"), true);
                Cylinder(new(0, 0.75f, 0), 0.22f, 0.16f, 0.28f, iron, "iron");
                AddChild(new OmniLight3D { Position = new(0, 0.6f, 0.2f), LightColor = new Color("ffb16e"), LightEnergy = 1.3f, OmniRange = 5 });
                return true;
            case "ward_engine":
                Box(new(0, 0.18f, 0), new(w, 0.36f, d), stone);
                Cylinder(new(0, 0.55f, 0), d * 0.35f, d * 0.4f, 0.4f, iron, "iron");
                foreach (float x in new[] { -w * 0.38f, w * 0.38f })
                {
                    Box(new(x, 1.25f, 0), new(0.25f, 2, d * 0.55f), stone);
                    Box(new(x * 0.5f, 2.2f, 0), new(w * 0.5f, 0.18f, 0.2f), iron, surface: "iron");
                }
                var crystal = Box(new(0, 1.25f, 0), new(0.6f, 1, 0.6f), new Color("77d5d6"), true);
                crystal.RotationDegrees = new(0, 45, 8);
                AddChild(new OmniLight3D { Position = new(0, 1.6f, 0), LightColor = new Color("85dadd"), LightEnergy = 2, OmniRange = 8 });
                return true;
            case "pump":
                Table(0.25f, w, d);
                for (int i = 0; i < 2; i++)
                {
                    float z = (i - 0.5f) * d * 0.45f;
                    Cylinder(new(0, 0.65f, z), 0.2f, 0.28f, 0.8f, iron, "iron");
                    Box(new(0, 1.2f, z), new(w * 0.8f, 0.08f, 0.08f), iron, surface: "iron");
                    Cylinder(new(0, 1.05f, z), 0.07f, 0.07f, 0.3f, iron, "iron");
                }
                return true;
            case "footlocker":
            case "packed_supplies":
            case "luggage":
                Timber(new(0, 0.25f, 0), new(w * 0.8f, 0.5f, d * 0.85f));
                foreach (float x in new[] { -w * 0.25f, w * 0.25f }) Box(new(x, 0.26f, 0), new(0.07f, 0.54f, d * 0.87f), iron, surface: "iron");
                if (p.Kind != "footlocker") Box(new(w * 0.15f, 0.65f, 0), new(w * 0.55f, 0.3f, d * 0.6f), wood, surface: "cloth");
                return true;
            case "washstand":
                Table(0.8f, w, d);
                Cylinder(new(0, 0.94f, 0), 0.28f, 0.2f, 0.18f, iron, "iron");
                return true;
            case "scavenger_bed":
                Box(new(-w * 0.15f, 0.12f, 0), new(w * 0.6f, 0.18f, d * 0.85f), wood, surface: "cloth");
                Cylinder(new(w * 0.35f, 0.13f, 0), 0.12f, 0.08f, 0.18f, iron, "iron");
                Box(new(w * 0.3f, 0.06f, d * 0.3f), new(0.22f, 0.12f, 0.3f), wood, surface: "wood");
                return true;
            case "broken_component":
                var part = Box(new(0, 0.25f, 0), new(w * 0.7f, 0.35f, d * 0.6f), iron, surface: "iron");
                part.RotationDegrees = new(0, 12, 12);
                Box(new(0, 0.45f, 0), new(0.3f, 0.12f, 0.3f), new Color("557e7f"));
                return true;
            case "leak":
                Box(new(0, 0.015f, 0), new(w, 0.025f, d), new Color("344e51"), surface: "iron");
                return true;
            default: return false;
        }
    }
}
