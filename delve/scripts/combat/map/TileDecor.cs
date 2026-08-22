using System.Collections.Generic;
using Godot;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat.Map;

/// <summary>
/// HD-2D tile dressing: scatters small pixel-art sprites — grass tufts, stones, flowers, deadfall —
/// over the battlefield's walkable tiles, so the board reads as painted ground rather than bare
/// colour fields. The sprites are Winlu-derived crops (assets/sprites/decor/) rendered exactly like
/// the unit tokens: Y-billboard Sprite3D, nearest filtering, alpha scissor, unshaded. Flower patches
/// are the exception — they lie flat on the tile surface instead of billboarding.
///
/// Placement is deterministic (seeded by the layout, hashed per tile like EdgeSceneryBuilder) and
/// role-aware: ordinary ground gets a sparse scatter, difficult terrain gets a dense scrub of tall
/// grass and deadfall so the mechanical penalty is visible at a glance. Everything is offset away
/// from the tile centre so a unit standing on the tile keeps clear feet. Visual only — no colliders,
/// no rules.
/// </summary>
public static class TileDecor
{
    private sealed record DecorDef(string Texture, float Weight, float Height, bool Flat = false);

    /// <summary>Decor sets by <see cref="BackdropThemeDefinition.DecorSetId"/>.</summary>
    private static readonly Dictionary<string, (DecorDef[] Ground, DecorDef[] Difficult)> Sets = new()
    {
        ["forest"] = (
            Ground: new[]
            {
                new DecorDef("forest/grass_mid_a.png", 6f, 0.42f),
                new DecorDef("forest/grass_mid_b.png", 6f, 0.42f),
                new DecorDef("forest/grass_low_a.png", 5f, 0.38f),
                new DecorDef("forest/grass_low_b.png", 5f, 0.38f),
                new DecorDef("forest/grass_tall_a.png", 3f, 0.55f),
                new DecorDef("forest/grass_tall_b.png", 3f, 0.55f),
                new DecorDef("forest/stone_flat.png", 2f, 0.16f),
                new DecorDef("forest/stone_small.png", 2f, 0.13f),
                new DecorDef("forest/stone_tall.png", 0.8f, 0.32f),
                new DecorDef("forest/fireweed_a.png", 1.2f, 0.50f),
                new DecorDef("forest/fireweed_b.png", 1.2f, 0.50f),
                new DecorDef("forest/mushroom.png", 0.6f, 0.26f),
                new DecorDef("forest/flowers_mixed.png", 2f, 0.66f, Flat: true),
                new DecorDef("forest/flowers_red.png", 1.2f, 0.66f, Flat: true),
                new DecorDef("forest/flowers_orange.png", 1.2f, 0.66f, Flat: true),
            },
            Difficult: new[]
            {
                new DecorDef("forest/grass_tall_a.png", 6f, 0.60f),
                new DecorDef("forest/grass_tall_b.png", 6f, 0.60f),
                new DecorDef("forest/bush_small.png", 3f, 0.48f),
                new DecorDef("forest/grass_mid_a.png", 2f, 0.45f),
                new DecorDef("forest/grass_mid_b.png", 2f, 0.45f),
                new DecorDef("forest/fireweed_a.png", 1.5f, 0.52f),
                new DecorDef("forest/fireweed_b.png", 1.5f, 0.52f),
            }),
    };

    private const string BasePath = "res://assets/sprites/decor/";

    /// <summary>Chance an ordinary ground tile gets a decor sprite; a fraction get a second.</summary>
    private const float GroundChance = 0.32f;
    private const float GroundSecondChance = 0.10f;

    /// <summary>Difficult terrain always gets two, half the time a third — the density IS the tell.</summary>
    private const float DifficultThirdChance = 0.5f;

    /// <summary>Placement offset from tile centre, tiles. The floor keeps unit feet clear; the
    /// ceiling keeps sprites visually inside their own tile.</summary>
    private const float OffsetMin = 0.15f;
    private const float OffsetMax = 0.34f;

    /// <summary>Billboards sink slightly so baked ground-contact pixels nestle into the surface.</summary>
    private const float BillboardSink = 0.03f;

    /// <summary>Flat patches hover just off the surface to dodge z-fighting with the tile top.</summary>
    private const float FlatLift = 0.02f;

    // Distinct hash streams per decision so adding a roll never reshuffles unrelated tiles.
    private const int SaltPlace = 101;
    private const int SaltPick = 202;
    private const int SaltOffset = 303;
    private const int SaltAngle = 404;
    private const int SaltFlip = 505;

    /// <summary>
    /// Build the decor scatter for a board, or null when the theme has no decor set. A null layout
    /// (the flat dev board) treats every tile as ordinary ground at a reduced density.
    /// </summary>
    public static Node3D? Build(
        BackdropThemeDefinition theme,
        MapLayout? layout,
        int gridWidth,
        int gridHeight,
        TerrainHeightMap heightMap)
    {
        if (theme.DecorSetId == null || !Sets.TryGetValue(theme.DecorSetId, out var set))
            return null;

        var root = new Node3D { Name = "TileDecor" };
        int seed = layout?.Seed ?? 0;
        var textures = new Dictionary<string, Texture2D>();

        for (int y = 0; y < gridHeight; y++)
        for (int x = 0; x < gridWidth; x++)
        {
            TileRole role = layout?.GetTile(x, y) ?? TileRole.Ground;
            int count;
            DecorDef[] defs;
            switch (role)
            {
                case TileRole.Ground:
                    defs = set.Ground;
                    float chance = layout == null ? GroundChance * 0.6f : GroundChance;
                    float roll = Hash01(x, y, seed + SaltPlace);
                    count = roll < chance ? (Hash01(x, y, seed + SaltPlace + 1) < GroundSecondChance ? 2 : 1) : 0;
                    break;
                case TileRole.DifficultTerrain:
                    defs = set.Difficult;
                    count = Hash01(x, y, seed + SaltPlace) < DifficultThirdChance ? 3 : 2;
                    break;
                default:
                    continue;
            }

            for (int i = 0; i < count; i++)
                PlaceOne(root, defs, textures, layout, heightMap, x, y, seed, i);
        }

        return root;
    }

    private static void PlaceOne(
        Node3D root,
        DecorDef[] defs,
        Dictionary<string, Texture2D> textures,
        MapLayout? layout,
        TerrainHeightMap heightMap,
        int x,
        int y,
        int seed,
        int index)
    {
        var def = PickWeighted(defs, Hash01(x + index * 73, y, seed + SaltPick));

        // Flat patches need a level surface; on a sloped tile fall back to the first billboard def.
        if (def.Flat && layout != null && layout.GetCornerHeights(x, y).HeightSpan != 0)
            def = defs[0];

        if (!textures.TryGetValue(def.Texture, out var tex))
        {
            tex = GD.Load<Texture2D>(BasePath + def.Texture);
            textures[def.Texture] = tex;
        }

        // Offset from tile centre: hashed angle, hashed radius inside the keep-clear ring. The
        // radius ceiling shrinks by the sprite's half-width so nothing overhangs the tile — a tuft
        // poking past a cliff lip or over water reads as a glitch, not as ground cover.
        float halfWidth = def.Flat
            ? def.Height * 0.5f * 1.45f // rotated square: corners swing out to the half-diagonal
            : def.Height * tex.GetWidth() / tex.GetHeight() * 0.5f;
        float maxRadius = Mathf.Min(OffsetMax, 0.5f - halfWidth - 0.04f);
        float minRadius = Mathf.Min(OffsetMin, Mathf.Max(0f, maxRadius));
        float angle = Hash01(x + index * 31, y, seed + SaltAngle) * Mathf.Tau;
        float radius = minRadius
            + Hash01(x, y + index * 57, seed + SaltOffset) * Mathf.Max(0f, maxRadius - minRadius);
        var tile = new PF2eVec(x, y);
        Vector3 pos = Combat.GridSpace.GridToWorld(tile, heightMap)
            + new Vector3(Mathf.Cos(angle) * radius, 0f, Mathf.Sin(angle) * radius);

        var sprite = new Sprite3D
        {
            Texture = tex,
            PixelSize = def.Height / tex.GetHeight(),
            Shaded = false,
            TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
            AlphaCut = SpriteBase3D.AlphaCutMode.Discard,
            AlphaScissorThreshold = 0.5f,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };

        if (def.Flat)
        {
            sprite.Axis = Vector3.Axis.Y;
            sprite.RotateY(Hash01(x, y + index * 19, seed + SaltAngle + 1) * Mathf.Tau);
            sprite.Position = pos + new Vector3(0f, FlatLift, 0f);
        }
        else
        {
            sprite.Billboard = BaseMaterial3D.BillboardModeEnum.FixedY;
            sprite.FlipH = Hash01(x + index * 11, y, seed + SaltFlip) < 0.5f;
            sprite.Position = pos + new Vector3(0f, def.Height * 0.5f - BillboardSink, 0f);
        }

        root.AddChild(sprite);
    }

    private static DecorDef PickWeighted(DecorDef[] defs, float roll)
    {
        float total = 0f;
        foreach (var d in defs) total += d.Weight;
        float target = roll * total;
        foreach (var d in defs)
        {
            target -= d.Weight;
            if (target <= 0f) return d;
        }
        return defs[^1];
    }

    /// <summary>Same hash as EdgeSceneryBuilder's — deterministic per (tile, decision) pair.</summary>
    private static float Hash01(int a, int b, int seed)
    {
        unchecked
        {
            uint h = (uint)seed * 374761393u + (uint)a * 668265263u + (uint)b * 974634321u;
            h = (h ^ (h >> 13)) * 1274126177u;
            h ^= h >> 16;
            return (h & 0xFFFFFFu) * (1f / 0x1000000);
        }
    }
}
