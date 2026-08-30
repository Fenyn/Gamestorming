using System.Collections.Generic;
using Godot;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Terrain;

/// <summary>
/// HD-2D tile dressing: scatters small pixel-art sprites — grass tufts, stones, flowers, mushrooms —
/// over the battlefield's walkable tiles, so the board reads as painted ground rather than bare
/// colour fields. The sprites are Winlu-derived crops (assets/sprites/decor/) rendered exactly like
/// the unit tokens: Y-billboard Sprite3D, nearest filtering, alpha scissor, unshaded. Flower patches
/// are the exception — they lie flat on the tile surface instead of billboarding.
///
/// The sprite lists themselves are content, so they live with the rest of the biome's look on
/// <see cref="BackdropThemeDefinition.Decor"/>; this class only places what the theme names.
///
/// Placement is deterministic (seeded by the layout, hashed per tile) and role-aware: ordinary
/// ground gets a sparse scatter, difficult terrain gets a dense scrub of tall grass and bushes so
/// the mechanical penalty is visible at a glance. Everything is offset away from the tile centre so
/// a unit standing on the tile keeps clear feet. Visual only — no colliders, no rules.
///
/// The layout it walks is the SKIRT (board plus generated halo), so the same tufts and flowers carry
/// on past the board edge; density tapers outward from full at the board to
/// <see cref="RimDensity"/> at the rim, which stops the halo from out-shouting the playfield.
/// </summary>
public static class TileDecor
{
    private const string BasePath = "res://assets/sprites/decor/";

    /// <summary>Chance an ordinary ground tile gets a decor sprite; a fraction get a second.</summary>
    private const float GroundChance = 0.32f;
    private const float GroundSecondChance = 0.10f;

    /// <summary>Difficult terrain always gets two, half the time a third — the density IS the tell.</summary>
    private const float DifficultThirdChance = 0.5f;

    /// <summary>Share of the board's decor density left at the halo's outer ring. The scatter thins
    /// outward from 1.0 at the board edge, so the eye keeps reading the playfield as the near thing.</summary>
    private const float RimDensity = 0.4f;

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
    private const int SaltTaper = 606;

    /// <summary>
    /// Build the decor scatter for one rendered layout, or null when the theme has no decor set.
    /// <paramref name="layout"/> is the skirt (board plus halo) with <paramref name="gridWidth"/> x
    /// <paramref name="gridHeight"/> its size and <paramref name="heightMap"/> its heights, all in
    /// SKIRT coordinates; <paramref name="margin"/> is the halo width, which both places the result
    /// back on the board's own origin and drives the outward density taper. A null layout (the flat
    /// dev board) treats every tile as ordinary ground at a reduced density.
    /// </summary>
    public static Node3D? Build(
        BackdropThemeDefinition theme,
        MapLayout? layout,
        int gridWidth,
        int gridHeight,
        TerrainHeightMap heightMap,
        int margin = 0)
    {
        if (theme.Decor is not { } set)
            return null;

        // The whole scatter is placed in layout tile space and then shifted like the terrain mesh,
        // so a halo tile's sprite lands over the halo tile that carries its height.
        var root = new Node3D { Name = "TileDecor", Position = new Vector3(-margin, 0f, -margin) };
        int seed = layout?.Seed ?? 0;
        var textures = new Dictionary<string, Texture2D>();

        for (int y = 0; y < gridHeight; y++)
        for (int x = 0; x < gridWidth; x++)
        {
            TileRole role = layout?.GetTile(x, y) ?? TileRole.Ground;
            float taper = Taper(x, y, gridWidth, gridHeight, margin);
            int count;
            DecorDef[] defs;
            switch (role)
            {
                case TileRole.Ground:
                    defs = set.Ground;
                    float chance = layout == null ? GroundChance * 0.6f : GroundChance;
                    float roll = MapHash.Hash01(x, y, seed + SaltPlace);
                    count = roll < chance ? (MapHash.Hash01(x, y, seed + SaltPlace + 1) < GroundSecondChance ? 2 : 1) : 0;
                    break;
                case TileRole.DifficultTerrain:
                    defs = set.Difficult;
                    count = MapHash.Hash01(x, y, seed + SaltPlace) < DifficultThirdChance ? 3 : 2;
                    break;
                default:
                    continue;
            }

            count = Thin(count, taper, MapHash.Hash01(x, y, seed + SaltTaper));
            for (int i = 0; i < count; i++)
                PlaceOne(root, defs, textures, layout, heightMap, x, y, seed, i);
        }

        return root;
    }

    /// <summary>
    /// Density multiplier for one tile: 1.0 anywhere on the board, falling linearly to
    /// <see cref="RimDensity"/> at the halo's outer ring. Ring distance is Chebyshev from the board
    /// rectangle, which sits inset by <paramref name="margin"/> on every side.
    /// </summary>
    private static float Taper(int x, int y, int gridWidth, int gridHeight, int margin)
    {
        if (margin <= 0) return 1f;

        int dx = Mathf.Max(Mathf.Max(margin - x, x - (gridWidth - margin - 1)), 0);
        int dy = Mathf.Max(Mathf.Max(margin - y, y - (gridHeight - margin - 1)), 0);
        int ring = Mathf.Max(dx, dy);
        return Mathf.Lerp(1f, RimDensity, (float)ring / margin);
    }

    /// <summary>Scale a sprite count by the taper, resolving the fraction with a hashed roll so the
    /// thinning is per-tile rather than a hard step. Taper 1.0 returns the count unchanged.</summary>
    private static int Thin(int count, float taper, float roll)
    {
        float wanted = count * taper;
        int whole = (int)wanted;
        return roll < wanted - whole ? whole + 1 : whole;
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
        var def = PickWeighted(defs, MapHash.Hash01(x + index * 73, y, seed + SaltPick));

        // Flat patches need a level surface; on a sloped tile fall back to the first billboard def.
        if (def.Flat && layout != null && layout.GetCornerHeights(x, y).HeightSpan != 0)
            def = defs[0];

        if (!textures.TryGetValue(def.Texture, out var tex))
        {
            tex = GD.Load<Texture2D>(BasePath + def.Texture);
            if (tex == null)
            {
                GD.PushError($"[TileDecor] decor texture missing at {BasePath + def.Texture}; tile is left bare.");
                return;
            }
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
        float angle = MapHash.Hash01(x + index * 31, y, seed + SaltAngle) * Mathf.Tau;
        float radius = minRadius
            + MapHash.Hash01(x, y + index * 57, seed + SaltOffset) * Mathf.Max(0f, maxRadius - minRadius);
        var tile = new PF2eVec(x, y);
        Vector3 pos = GridSpace.GridToWorld(tile, heightMap)
            + new Vector3(Mathf.Cos(angle) * radius, 0f, Mathf.Sin(angle) * radius);

        var sprite = new Sprite3D
        {
            Texture = tex,
            PixelSize = def.Height / tex.GetHeight(),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        // Same pixel-art draw rules as the unit tokens (see PixelSprite).
        PixelSprite.Configure(sprite);

        if (def.Flat)
        {
            sprite.Axis = Vector3.Axis.Y;
            sprite.RotateY(MapHash.Hash01(x, y + index * 19, seed + SaltAngle + 1) * Mathf.Tau);
            sprite.Position = pos + new Vector3(0f, FlatLift, 0f);
        }
        else
        {
            sprite.Billboard = BaseMaterial3D.BillboardModeEnum.FixedY;
            sprite.FlipH = MapHash.Hash01(x + index * 11, y, seed + SaltFlip) < 0.5f;
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
}
