using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Lived-in detail for the village (round B, scratchpad reviews/b_brief.md): flower tufts at plinths
/// and path edges, chickens, baskets and a bucket, chimney smoke, wall lanterns at house doors, and
/// edging stones along the Delve trail. Sprites are LimeZu Modern Farm crops at the hero texel density.
/// </summary>
public partial class HubMockSpike
{
    /// <summary>Absolute folder of the cropped decor sprites (tufts, chickens, smoke, baskets).</summary>
    [Export] public string DecorFolder { get; set; } = "";

    /// <summary>Chimney top in each house's local frame (houses.py: far slope, 0.8 above the ridge).</summary>
    private static readonly Dictionary<string, Vector3> ChimneyTops = new()
    {
        ["house_02"] = new(0.63f, 5.83f, -1.8f), ["house_03"] = new(0.84f, 6.54f, -1.8f), ["house_04"] = new(1.05f, 9.6f, -1.8f),
        ["house_05"] = new(2.88f, 5.83f, -1.8f), ["house_06"] = new(0.84f, 8.89f, -2.25f),
    };

    private readonly Dictionary<string, Texture2D?> _decor = new();
    private readonly List<OmniLight3D> _doorLights = new();

    private Sprite3D? Decor(string name, bool shadow = false)
    {
        if (!_decor.TryGetValue(name, out var texture))
        {
            string path = DecorFolder.PathJoin(name + ".png");
            texture = _decor[name] = FileAccess.FileExists(path) ? ImageTexture.CreateFromImage(Image.LoadFromFile(path)) : null;
        }
        if (texture == null) return null;
        return new Sprite3D
        {
            Texture = texture, PixelSize = HeroPixel, Centered = false, Offset = new Vector2(-texture.GetWidth() / 2f, 0),
            Billboard = BaseMaterial3D.BillboardModeEnum.FixedY, TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
            AlphaCut = SpriteBase3D.AlphaCutMode.Discard, Shaded = true,
            CastShadow = shadow ? GeometryInstance3D.ShadowCastingSetting.On : GeometryInstance3D.ShadowCastingSetting.Off,
        };
    }

    /// <summary>A decor sprite on the ground at a world spot, shown from `tier`.</summary>
    private void Scatter(int tier, string name, Vector2 at, bool shadow = false)
    {
        if (Decor(name, shadow) is not { } sprite) return;
        _outpost.AddChild(sprite);
        var spot = new Vector3(at.X, 0, at.Y);
        sprite.Position = spot with { Y = _terrain.HeightAt(spot) - 0.02f };
        _tiered.Add((tier, sprite));
    }

    private static string Tuft(int k) => $"tuft{1 + (k * 7) % 11}";

    private void BuildDecor()
    {
        foreach (var (site, house, _) in _houses)
        {
            var size = Shapes[site.Building];
            float front = size.Y / 2f;
            // Flower tufts along the plinth and at the corners.
            int k = site.Building.GetHashCode() & 7;
            foreach (float x in new[] { -size.X / 2f - 0.3f, -size.X / 2f + 0.6f, size.X / 2f - 0.5f, size.X / 2f + 0.35f })
                if (Decor(Tuft(k++)) is { } tuft)
                {
                    house.AddChild(tuft);
                    tuft.Position = new Vector3(x, -0.02f, front + 0.25f);
                }
            // Wall lantern beside the door, lit in the evening.
            if (Model("wall_lantern") is { } lantern)
            {
                house.AddChild(lantern);
                float door = DoorX[site.Building];
                lantern.Position = new Vector3(door + 1.15f, 2.3f, front + 0.02f);
                var light = new OmniLight3D { LightColor = new Color(1f, 0.74f, 0.45f), OmniRange = 3f, LightEnergy = 0f };
                lantern.AddChild(light);
                light.Position = new Vector3(0, -0.1f, 0.5f);
                _doorLights.Add(light);
            }
            // Chimney smoke: three frames of the pack's smoke sheet stacked into a rising, thinning plume.
            if (ChimneyTops.TryGetValue(site.Building, out var chimney))
                foreach (var (frame, rise, drift, alpha) in new[] { ("smoke2", 0.2f, 0f, 0.8f), ("smoke", 0.9f, 0.25f, 0.55f), ("smoke6", 1.8f, 0.55f, 0.3f) })
                    if (Decor(frame) is { } smoke)
                    {
                        house.AddChild(smoke);
                        smoke.Position = chimney + new Vector3(drift, rise, 0);
                        smoke.Modulate = new Color(1, 1, 1, alpha);
                        smoke.AlphaCut = SpriteBase3D.AlphaCutMode.Disabled;
                    }
            if (site.Building == "house_05")
                foreach (var (name, local) in new[] { ("bucket_1_single", new Vector3(5.4f, 0, 1.6f)), (Tuft(9), new Vector3(6.8f, 0, -0.8f)) })
                    if (Decor(name, true) is { } item)
                    {
                        house.AddChild(item);
                        item.Position = local;
                    }
        }
        // The camp's own grass sprites read as black spikes by the trail at night; the trail keeps its stones only.
        foreach (var grass in _outpost.GetChildren().OfType<Sprite3D>().Where(s => s.Name.ToString().StartsWith("CampGrass")))
            if (Segments(Roads[0].Points.Concat(Roads[1].Points).ToArray()).Any(s => Distance(new Vector2(grass.Position.X, grass.Position.Z), s.A, s.B) < 3.5f))
                grass.Hide();
        // Hearth: a log basket and a bucket by the east seat.
        Scatter(1, "basket_empty", new Vector2(3.9f, 1.2f), true);
        Scatter(1, "bucket_1_single", new Vector2(-4.7f, 4.2f), true);
        // Hearth: a cooking tripod over the fire.
        if (Model("tripod") is { } tripod)
        {
            _outpost.AddChild(tripod);
            var fire = new Vector3(0, 0, 2.4f);
            tripod.Position = fire with { Y = _terrain.HeightAt(fire) };
            _tiered.Add((1, tripod));
        }
        // Reeds along both stream banks.
        int r = 0;
        foreach (var (a, b) in Segments(Stream))
        {
            var along = (b - a).Normalized();
            var side = new Vector2(-along.Y, along.X);
            for (float t = 1f; t < a.DistanceTo(b); t += 2.5f, r++)
                Scatter(1, $"tuft{(r % 2 == 0 ? 2 : 3)}", a + along * t + side * (r % 2 == 0 ? 2.0f : -2.0f));
        }
        // Grey pebbles on the grass just past the road edge; none inside worn yards, where every side is dirt.
        bool InYard(Vector2 at) => Patches.Any(q => ((at - new Vector2(q.Patch.X, q.Patch.Y)) / new Vector2(q.Patch.Z, q.Patch.W)).Length() < 1.1f);
        int p = 0;
        foreach (var (a, b) in Segments(Roads[2].Points))
        {
            var along = (b - a).Normalized();
            var side = new Vector2(-along.Y, along.X);
            for (float t = 1.5f; t < a.DistanceTo(b); t += 3.0f, p++)
            {
                var at = a + along * t + side * (p % 2 == 0 ? 1.0f : -1.0f) * (Roads[2].Width + 0.25f);
                if (!InYard(at)) Edge(2, "pebbles", at, p * 61);
            }
        }
        // The Delve trail: pebbles on both verges, clear of the line-up.
        int n = 0;
        foreach (var (a, b) in Segments(Roads[0].Points.Concat(Roads[1].Points.Skip(1)).ToArray()))
        {
            var along = (b - a).Normalized();
            var side = new Vector2(-along.Y, along.X);
            for (float t = 0.8f; t < a.DistanceTo(b); t += 2.6f, n++)
            {
                var at = a + along * t + side * (n % 2 == 0 ? 1.0f : -1.0f) * (Roads[0].Width + 0.3f);
                if (at.DistanceTo(new Vector2(VillageGate.X, VillageGate.Z + 2.5f)) > 6.0f && !InYard(at)) Edge(1, "pebbles", at, n * 47);
            }
        }
        // The trailhead: a small cairn outside the left lantern, standing stones inside the lantern pools,
        // and a warm fill at the line-up's feet in the evening.
        Edge(1, "cairn", new Vector2(-4.9f, -15.0f), 20);
        var fill = new OmniLight3D { LightColor = new Color(1f, 0.74f, 0.45f), OmniRange = 6f, LightEnergy = 0f };
        _outpost.AddChild(fill);
        fill.Position = VillageGate + new Vector3(-0.6f, _terrain.HeightAt(VillageGate) + 1.2f, 2.6f);
        _doorLights.Add(fill);
        foreach (var at in new[] { new Vector2(-5.1f, -16.6f), new Vector2(0.6f, -17.1f) })
            if (Model("standing_stone") is { } stone)
            {
                _outpost.AddChild(stone);
                var spot = new Vector3(at.X, 0, at.Y);
                stone.Position = spot with { Y = _terrain.HeightAt(spot) - 0.1f };
                stone.RotationDegrees = new Vector3(0, at.X * 31, 0);
                _tiered.Add((1, stone));
            }
        // Storehouse yard: baskets, bucket and chickens.
        Scatter(2, "basket_apple", new Vector2(6.0f, 4.6f), true);
        Scatter(2, "crop_cabbage_brown_basket", new Vector2(6.6f, 4.9f), true);
        Scatter(2, "chicken_a", new Vector2(9.6f, 7.4f), true);
        Scatter(2, "chicken_b", new Vector2(10.3f, 7.9f), true);
        Scatter(3, "chicken_a", new Vector2(0.4f, 17.6f), true);
        // Well: bucket and tufts.
        Scatter(2, "bucket_1_single", new Vector2(5.4f, 10.9f), true);
        foreach (var (k, at) in new[] { (1, new Vector2(3.0f, 11.2f)), (2, new Vector2(5.5f, 9.6f)) })
            Scatter(2, Tuft(k), at);
        // Bridge abutments.
        foreach (var (k, at) in new[] { (3, new Vector2(-6.8f, 15.6f)), (4, new Vector2(-11.4f, 19.4f)), (5, new Vector2(-10.6f, 20.2f)) })
            Scatter(3, Tuft(k), at);
    }

    /// <summary>A small model on the ground at a world spot, turned, shown from `tier`.</summary>
    private void Edge(int tier, string model, Vector2 at, float yaw)
    {
        if (Model(model) is not { } node) return;
        _outpost.AddChild(node);
        var spot = new Vector3(at.X, 0, at.Y);
        node.Position = spot with { Y = _terrain.HeightAt(spot) };
        node.RotationDegrees = new Vector3(0, yaw, 0);
        _tiered.Add((tier, node));
    }

    private void LightDoors(bool evening)
    {
        foreach (var light in _doorLights) light.LightEnergy = evening && light.IsVisibleInTree() ? 1.2f : 0f;
    }
}
