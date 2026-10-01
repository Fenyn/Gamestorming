using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.Dev;

/// <summary>Scene construction for the village mock: terrain, sites, forest, bridge and textures.</summary>
public partial class HubMockSpike
{
    private static readonly Rect2[] CropRegions = { new(243, 100, 43, 38), new(291, 100, 43, 38), new(339, 144, 43, 42) };

    private readonly List<(Site Site, Sprite3D Sprite, OmniLight3D? Light)> _sites = new();
    private readonly List<(int From, Node3D Node)> _tiered = new();
    private readonly List<(int From, Node3D Node)> _shadows = new();
    private readonly List<(Node3D Tree, int Cut)> _forest = new();

    /// <summary>Runs before MoveGate so the arch lands on the reshaped ground at the north edge.</summary>
    private void PrepareVillage()
    {
        _gate = VillageGate;
        Reshape(VillageBanks, VillageGround);
    }

    private Texture2D? Pack(string name)
    {
        string path = PackFolder.PathJoin(name + ".png");
        return FileAccess.FileExists(path) ? ImageTexture.CreateFromImage(Image.LoadFromFile(path)) : null;
    }

    private void BuildVillage()
    {
        foreach (var prop in _outpost.GetChildren().OfType<Sprite3D>().Where(p => !p.Name.ToString().StartsWith("CampGrass")))
            Rescale(prop, prop.Name == "Fire" ? HeroPixel : PropPixel);
        foreach (string name in new[] { "SharedTools", "Woodpile", "SharedTable", "HerbPots0", "HerbPots1", "TravelSupplies", "Supplies0", "Supplies1", "Supplies2", "Seat0", "Seat1" })
            if (_outpost.GetNodeOrNull<Node3D>(name) is { } node) node.Hide();
        MoveProp("Seat2", new Vector3(-3.0f, 0, 3.05f));
        MoveProp("Seat3", new Vector3(2.8f, 0, 1.45f));
        MoveProp("Seat4", new Vector3(-2.5f, 0, 0.95f));
        MoveProp("Seat5", new Vector3(1.4f, 0, -0.05f));
        var environment = _outpost.GetNode<WorldEnvironment>("WorldEnvironment").Environment;
        environment.SsaoEnabled = true;
        environment.SsaoRadius = 1.0f;
        environment.SsaoIntensity = 1.5f;
        if (_terrain.MaterialOverride is ShaderMaterial ground && Pack("water") is { } water)
            ground.SetShaderParameter("water_texture", water);

        var footprints = new List<(int Tier, Vector2 At, float Radius)>();
        foreach (var site in Sites)
        {
            bool building = site.Building.Length > 0;
            var sprite = building ? Building(site.Building) : AtlasCard(site.Region);
            _outpost.AddChild(sprite);
            sprite.FlipH = site.Flip;
            if (building) sprite.RotationDegrees = new Vector3(-12, Yaw + site.Yaw, 0);
            var spot = new Vector3(site.At.X, 0, site.At.Y);
            sprite.Position = spot with { Y = _terrain.HeightAt(spot) + (building ? 0 : site.Region.Size.Y * PropPixel * 0.5f) };
            OmniLight3D? light = null;
            if (site.Lamp)
            {
                light = new OmniLight3D { LightColor = new Color(1.0f, 0.74f, 0.45f), OmniRange = 6f };
                _outpost.AddChild(light);
                light.Position = sprite.Position + Vector3.Up * 0.9f;
            }
            _sites.Add((site, sprite, light));
            float width = building ? sprite.Texture.GetWidth() * HeroPixel : site.Region.Size.X * PropPixel;
            if (building)
            {
                _shadows.Add((site.From, ContactShadow(spot, width)));
                if (Shapes.ContainsKey(site.Building))
                {
                    var (house, glow) = House3D(site);
                    _houses.Add((site, house, glow));
                }
            }
            footprints.Add((site.From, site.At + (building ? new Vector2(0, -2.5f) : Vector2.Zero), width / 2f + (building ? 2.4f : 1.4f)));
        }
        // Crop beds: tilled 3D ridges with the crops laid flat on top (garden rows, then the hamlet fields).
        foreach (var (tier, at) in new[] { (2, new Vector2(-2.1f, 14.6f)), (2, new Vector2(-2.1f, 15.7f)), (2, new Vector2(-2.1f, 16.8f)),
                     (3, new Vector2(-19.0f, 23.6f)), (3, new Vector2(-15.8f, 23.6f)), (3, new Vector2(-19.0f, 24.8f)),
                     (3, new Vector2(-15.8f, 24.8f)), (3, new Vector2(-19.0f, 26.0f)), (3, new Vector2(-15.8f, 26.0f)) })
            if (Model($"crop_bed{(int)Mathf.Abs(at.X + at.Y * 3) % 3}") is { } bed)
            {
                _outpost.AddChild(bed);
                var spot = new Vector3(at.X, 0, at.Y);
                bed.Position = spot with { Y = _terrain.HeightAt(spot) };
                _tiered.Add((tier, bed));
            }
        var boards = Triplanar("ih_logs");
        foreach (var (tier, a, b, palisade) in VillageFences)
        {
            var fence = Fence(new FenceRun(tier, 3, a, b, palisade));
            if (palisade)
                foreach (var mesh in fence.GetChildren().OfType<MeshInstance3D>()) mesh.MaterialOverride = boards;
            _outpost.AddChild(fence);
            _tiered.Add((tier, fence));
        }
        if (Model("bridge") is { } bridge)
        {
            _outpost.AddChild(bridge);
            var spot = new Vector3(-9, 0, 17.6f);
            bridge.Position = spot with { Y = _terrain.HeightAt(spot) - 0.2f };
            // The span runs along the model's local Z; turn it along the lane (-3, 2.5).
            bridge.Rotation = new Vector3(0, Mathf.Atan2(-3f, 2.5f), 0);
            _tiered.Add((3, bridge));
        }
        if (_outpost.GetNodeOrNull<Node3D>("Seat2") is { } log)
            foreach (var at in new[] { new Vector2(17.4f, 7.0f), new Vector2(21.2f, 7.3f), new Vector2(24.6f, 9.65f), new Vector2(12.9f, 4.55f) })
            {
                var seat = (Node3D)log.Duplicate();
                _outpost.AddChild(seat);
                float lift = log.Position.Y - _terrain.HeightAt(log.Position);
                var spot = new Vector3(at.X, 0, at.Y);
                seat.Position = spot with { Y = _terrain.HeightAt(spot) + lift };
                _tiered.Add((3, seat));
            }
        DressGate();
        Forest(footprints);
        BuildModels();
        BuildDecor();
    }

    /// <summary>
    /// The Delve is the trail itself (user, 2026-09-30): no arch, just the path running on into the
    /// woods past two standing stones and the Wardstone, with the trees darkening along it.
    /// </summary>
    private void DressGate()
    {
        _way?.Hide();
        _ruin?.Hide();
        if (_outpost.GetNodeOrNull<Node3D>("BankOutcrop0") is { } template)
            foreach (var at in new[] { new Vector3(0.4f, 0, -9.7f), new Vector3(3.4f, 0, -8.5f) })
            {
                var stone = (Node3D)template.Duplicate();
                _outpost.AddChild(stone);
                stone.Scale = Vector3.One * 0.28f;
                stone.Position = at with { Y = _terrain.HeightAt(at) };
            }
    }

    private MeshInstance3D ContactShadow(Vector3 at, float width)
    {
        var fade = new Gradient { Offsets = new[] { 0f, 1f }, Colors = new[] { new Color(0, 0, 0, 0.45f), new Color(0, 0, 0, 0) } };
        var shadow = new MeshInstance3D
        {
            Mesh = new PlaneMesh { Size = new Vector2(width * 1.1f, 2.6f) },
            MaterialOverride = new StandardMaterial3D
            {
                ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded, Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                AlbedoTexture = new GradientTexture2D { Gradient = fade, Fill = GradientTexture2D.FillEnum.Radial, FillFrom = new Vector2(0.5f, 0.5f), FillTo = new Vector2(0.5f, 0f) },
            },
            RotationDegrees = new Vector3(0, Yaw, 0),
        };
        _outpost.AddChild(shadow);
        shadow.Position = at with { Y = _terrain.HeightAt(at) + 0.03f, Z = at.Z - 0.6f };
        return shadow;
    }

    private StandardMaterial3D Triplanar(string texture)
    {
        var image = Pack(texture);
        return new StandardMaterial3D
        {
            AlbedoTexture = image, TextureFilter = BaseMaterial3D.TextureFilterEnum.NearestWithMipmaps, Roughness = 1f,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled, Uv1Triplanar = true, Uv1WorldTriplanar = true,
            Uv1Scale = Vector3.One / ((image?.GetWidth() ?? 32) * HeroPixel),
        };
    }

    private static StandardMaterial3D PixelMaterial(Texture2D texture) => new()
    {
        AlbedoTexture = texture, TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest, Roughness = 1f,
    };

    private void Tiered(int tier, Sprite3D sprite, Vector2 at, float lift)
    {
        _outpost.AddChild(sprite);
        var spot = new Vector3(at.X, 0, at.Y);
        sprite.Position = spot with { Y = _terrain.HeightAt(spot) + lift };
        _tiered.Add((tier, sprite));
    }

    /// <summary>A plank footbridge across the stream: a deck and two rails along the lane.</summary>
    private Node3D Bridge(Vector2 at, Vector2 along)
    {
        var root = new Node3D();
        var deck = Triplanar("deck");
        var box = new BoxMesh { Size = new Vector3(1.8f, 0.14f, 4.6f), Material = deck };
        root.AddChild(new MeshInstance3D { Mesh = box, Position = new Vector3(0, 0.12f, 0) });
        foreach (float side in new[] { -0.85f, 0.85f })
            root.AddChild(new MeshInstance3D { Mesh = new BoxMesh { Size = new Vector3(0.08f, 0.5f, 4.6f), Material = deck }, Position = new Vector3(side, 0.4f, 0) });
        _outpost.AddChild(root);
        var spot = new Vector3(at.X, 0, at.Y);
        root.Position = spot with { Y = _terrain.HeightAt(spot) };
        root.Rotation = new Vector3(0, Mathf.Atan2(along.X, along.Y), 0);
        return root;
    }

    /// <summary>The camp mesh rebuilt wider over new banks, with the mock ground shader.</summary>
    private void Reshape(Vector4[] banks, Shader? shader)
    {
        _terrain.Banks = banks;
        var surface = new SurfaceTool();
        surface.Begin(Mesh.PrimitiveType.Triangles);
        const float extent = 60f;
        Vector3 Point(float x, float z) => new(x, _terrain.HeightAt(new Vector3(x, 0, z)), z);
        // Smooth normals from the height field: flat per-triangle normals band into stripes under low lamps.
        Vector3 Normal(Vector3 p)
        {
            float dx = _terrain.HeightAt(p + Vector3.Right * 0.5f) - _terrain.HeightAt(p + Vector3.Left * 0.5f);
            float dz = _terrain.HeightAt(p + Vector3.Back * 0.5f) - _terrain.HeightAt(p + Vector3.Forward * 0.5f);
            return new Vector3(-dx, 1f, -dz).Normalized();
        }
        for (float z = -extent; z < extent; z += 1)
        for (float x = -extent; x < extent; x += 1)
        {
            Vector3 a = Point(x, z), b = Point(x + 1, z), c = Point(x, z + 1), d = Point(x + 1, z + 1);
            foreach (var (p, q, r) in new[] { (a, b, c), (b, d, c) })
                foreach (var point in new[] { p, q, r })
                {
                    surface.SetNormal(Normal(point));
                    surface.AddVertex(point);
                }
        }
        _terrain.Mesh = surface.Commit();
        if (shader != null && _terrain.MaterialOverride is ShaderMaterial camp)
        {
            var ground = new ShaderMaterial { Shader = shader };
            foreach (string texture in new[] { "grass_texture", "dirt_texture", "rock_texture" })
                ground.SetShaderParameter(texture, camp.GetShaderParameter(texture));
            _terrain.MaterialOverride = ground;
        }
    }

    /// <summary>
    /// The forest on a jittered grid. A tree falls at the first tier that needs its ground: a road,
    /// worn ground, or a building. Around settled ground a quarter of the trees survive, and noise
    /// opens a few glades. Tree scale varies so the rhythm of the grid breaks up.
    /// </summary>
    private void Forest(List<(int Tier, Vector2 At, float Radius)> footprints)
    {
        var templates = _outpost.GetChildren().OfType<Node3D>().Where(n => n.Name.ToString().StartsWith("Forest")).ToList();
        int used = 0;
        for (float z = -48; z <= 44; z += 3.6f)
        for (float x = -56; x <= 56; x += 3.6f)
        {
            float jx = Mathf.Sin(x * 12.9898f + z * 78.233f) * 1.3f, jz = Mathf.Cos(x * 39.346f + z * 11.135f) * 1.3f;
            var spot = new Vector2(x + jx, z + jz);
            if (Segments(Stream).Any(s => Distance(spot, s.A, s.B) < 2.4f)) continue;
            float chance = Mathf.Abs(Mathf.Sin(x * 3.1f + z * 7.7f) * 43758.5f % 1f);
            float glade = Mathf.Sin(spot.X * 0.21f + 1.3f) * Mathf.Cos(spot.Y * 0.17f - 0.4f);
            if (glade > 0.72f && spot.DistanceTo(new Vector2(_gate.X, _gate.Z)) > 10f) continue;
            int cut = 99;
            foreach (var road in Roads)
                if (Segments(road.Points).Any(s => Distance(spot, s.A, s.B) < road.Width + road.Margin)) cut = Mathf.Min(cut, road.Tier);
            foreach (var (tier, patch, thin) in Patches)
            {
                float reach = ((spot - new Vector2(patch.X, patch.Y)) / new Vector2(patch.Z, patch.W)).Length();
                if (reach < 1.25f || (thin && reach < 2.4f && chance > 0.25f)) cut = Mathf.Min(cut, tier);
            }
            foreach (var (tier, at, radius) in footprints)
                if (spot.DistanceTo(at) < radius) cut = Mathf.Min(cut, tier);
            if (((spot - new Vector2(0, 2.6f)) / new Vector2(9.5f, 8.5f)).Length() < 1f) cut = 1;
            if (cut == 1) continue;
            var tree = used < templates.Count ? templates[used] : (Node3D)templates[used % templates.Count].Duplicate();
            if (used >= templates.Count) _outpost.AddChild(tree);
            tree.Position = new Vector3(spot.X, _terrain.HeightAt(new Vector3(spot.X, 0, spot.Y)), spot.Y);
            tree.Scale = Vector3.One * (0.85f + chance * 0.4f);
            Gloom(tree, spot);
            _forest.Add((tree, cut));
            used++;
        }
        for (int i = used; i < templates.Count; i++) templates[i].Hide();
        // The shrine lane bends round one big old tree.
        if (templates.FirstOrDefault(t => !t.SceneFilePath.Contains("pine")) is { } broadleaf)
        {
            var old = (Node3D)broadleaf.Duplicate();
            _outpost.AddChild(old);
            var spot = new Vector3(10.4f, 0, -6.8f);
            old.Position = spot with { Y = _terrain.HeightAt(spot) };
            old.Scale = Vector3.One * 1.35f;
            _forest.Add((old, 99));
        }
        var hills = new[] { new Vector3(-8.5f, 0, -20f), new Vector3(4f, 0, -21f), new Vector3(-29f, 0, -9f), new Vector3(40f, 0, -4f), new Vector3(-34f, 0, 22f) };
        for (int i = 0; i < hills.Length; i++)
            if (_outpost.GetNodeOrNull<Node3D>($"BankOutcrop{i}") is { } rock)
                rock.Position = hills[i] with { Y = _terrain.HeightAt(hills[i]) + 0.3f };
    }

    /// <summary>Trees past the trailhead darken with depth, so the path reads as going somewhere deep.</summary>
    private void Gloom(Node3D tree, Vector2 spot)
    {
        float depth = Mathf.Clamp((_gate.Z - 1.5f - spot.Y) / 12f, 0, 1) * Mathf.Clamp(1.4f - Mathf.Abs(spot.X - _gate.X) / 14f, 0, 1);
        if (depth <= 0) return;
        var tint = new Color(1, 1, 1).Lerp(new Color(0.42f, 0.48f, 0.56f), depth);
        foreach (var sprite in tree.FindChildren("*", nameof(SpriteBase3D), true, false).OfType<SpriteBase3D>())
            sprite.Modulate = tint;
    }

    private static IEnumerable<(Vector2 A, Vector2 B)> Segments(Vector2[] points) =>
        points.Zip(points.Skip(1), (a, b) => (a, b));

    private static Vector4[] Padded(IEnumerable<Vector4> values, int count) =>
        values.Concat(Enumerable.Repeat(Vector4.Zero, count)).Take(count).ToArray();

    private static float Distance(Vector2 p, Vector2 a, Vector2 b)
    {
        var ab = b - a;
        float t = Mathf.Clamp((p - a).Dot(ab) / ab.LengthSquared(), 0, 1);
        return p.DistanceTo(a + ab * t);
    }

    /// <summary>Anything between the camera and a close view fades out, as the crawl's TreeFader does.</summary>
    private static bool InFront(Node3D node, Vector3 target) =>
        node.Position.Z > target.Z + 9.5f && Mathf.Abs(node.Position.X - target.X) < 20f;

    /// <summary>Trees fade earlier than props: a tree near the frame's bottom edge shows only its flattest facets.</summary>
    private static bool TreeInFront(Node3D node, Vector3 target) =>
        node.Position.Z > target.Z + 6.0f && Mathf.Abs(node.Position.X - target.X) < 22f;
}
