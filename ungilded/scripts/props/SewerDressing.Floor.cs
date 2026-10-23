using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.MapGen;
using Ungilded.Content;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>Floor decals with a source: puddles where water reaches the floor, slime beside the
/// sludge, bones gathered where things come to rest, rubble fallen against a wall. No two of a
/// kind on neighbouring tiles, and a cap on how many a board and its halo take.</summary>
public partial class SewerDressing
{
    /// <summary>Puddles for board tiles, and for the halo floor.</summary>
    [Export] public DecorSprite[] BoardPuddles { get; set; } = Array.Empty<DecorSprite>();
    [Export] public DecorSprite[] WalkwayPuddles { get; set; } = Array.Empty<DecorSprite>();

    /// <summary>Slime on the floor beside the sludge.</summary>
    [Export] public DecorSprite? FloorSlime { get; set; }

    /// <summary>Bones a cluster draws from. Board tiles take only the flat ones.</summary>
    [Export] public DecorSprite[] BonePieces { get; set; } = Array.Empty<DecorSprite>();

    /// <summary>Rubble for halo wall feet.</summary>
    [Export] public DecorSprite[] RubblePieces { get; set; } = Array.Empty<DecorSprite>();

    /// <summary>Halo floor this many rings out still gets floor decals.</summary>
    [Export] public int ClutterRings { get; set; } = 3;

    /// <summary>Chance a floor tile around a floor grate gets a puddle.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float GrateRingChance { get; set; } = 0.15f;

    /// <summary>Chance a floor tile beside a channel gets a puddle.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float ChannelEdgeChance { get; set; } = 0.25f;

    /// <summary>Chance a floor tile beside the sludge gets slime.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float SludgeSlimeChance { get; set; } = 0.3f;

    /// <summary>Chance a halo floor tile at a wall's foot gets rubble, and the tiles kept clear
    /// between two pieces.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")] public float RubbleChance { get; set; } = 0.12f;
    [Export] public int RubbleMinGap { get; set; } = 2;

    /// <summary>Metres a pile of rubble or bones sits off its tile's centre toward the wall.</summary>
    [Export] public float WallLean { get; set; } = 0.22f;

    /// <summary>Bone clusters per board, halo included; tiles between two clusters; the fewest and
    /// most pieces in one; metres between pieces; rings around the skeleton that may take one.</summary>
    [Export] public int BoneClusters { get; set; } = 2;
    [Export] public int BoneClusterGap { get; set; } = 4;
    [Export] public Vector2I BonePieceCount { get; set; } = new(2, 3);
    [Export] public float BoneSpread { get; set; } = 0.17f;
    [Export] public int BoneSkeletonRings { get; set; } = 2;

    /// <summary>A bone cluster stays at least this many tiles (Chebyshev) from a torch, a grate,
    /// rubble and an outfall's puddle.</summary>
    [Export] public int BonePropGap { get; set; } = 2;

    /// <summary>Density caps: board tiles per floor decal, and open halo tiles per decal.</summary>
    [Export] public int BoardTilesPerDecal { get; set; } = 10;
    [Export] public int HaloTilesPerDecal { get; set; } = 4;

    private const int SaltRoll = 0x51A1;
    private const int SaltOrder = 0x51A2;
    private const int SaltPick = 0x51A3;
    private const int SaltTurn = 0x51A4;
    private const int SaltCount = 0x51A6;

    /// <summary>A decal stays this far inside its tile's edge, metres.</summary>
    private const float TileEdge = 0.04f;

    private void PlaceFloor(Pass pass, List<CulvertSpan> culverts)
    {
        var layout = pass.Layout;
        int seed = layout.Seed;
        var tiles = new List<Vector2I>();
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
            {
                var t = new Vector2I(x, y);
                if (pass.Ring(t) <= ClutterRings && layout.GetTile(x, y) == TileRole.Ground && !pass.Reserved.Contains(new PF2eVec(x, y)))
                    tiles.Add(t);
            }
        var open = tiles.ToHashSet();
        var board = pass.Context.Board;
        int boardCap = board.Width * board.Height / Math.Max(1, BoardTilesPerDecal);
        int haloCap = tiles.Count(t => pass.Ring(t) > 0) / Math.Max(1, HaloTilesPerDecal);

        bool Room(Vector2I t)
        {
            bool onBoard = pass.Ring(t) == 0;
            int used = _ledger.Placed.Count(p => p.Kind is not (DressKind.Torch or DressKind.WallGrate)
                && (pass.Ring(p.Tile + new Vector2I(pass.Margin, pass.Margin)) == 0) == onBoard);
            return used < (onBoard ? boardCap : haloCap);
        }
        bool Fits(DressKind kind, Vector2I t)
        {
            var at = pass.Board(t);
            return open.Contains(t) && _ledger.IsFree(at) && !_ledger.Near(kind, at, 1) && Room(t);
        }
        IEnumerable<Vector2I> Rolled(IEnumerable<Vector2I> from, float chance, int salt) => from
            .Where(t => MapHash.Hash01(t.X, t.Y, seed + salt) < chance)
            .OrderBy(t => MapHash.Hash01(t.Y, t.X, seed + SaltOrder));

        bool Beside(Vector2I t, TileRole role) => SewerSites.Cardinals.Any(d => SewerSites.Role(layout, t + d) == role);

        // Puddles: the floor side of each culvert, the ring around each floor grate, a channel's edge.
        foreach (var span in culverts.Where(s => Arched(layout, s)))
        {
            var mouth = span.Tiles.Select(t => new Vector2I(t.X, t.Y)).ToList();
            var spot = tiles.Where(t => pass.Ring(t) <= 1 && SewerSites.Cardinals.Any(d =>
                    SewerSites.Role(layout, t + d) is TileRole.Water or TileRole.DifficultTerrain
                    && mouth.Any(m => SewerSites.Chebyshev(m, t + d) <= 1)))
                .OrderBy(t => t.Y).ThenBy(t => t.X).FirstOrDefault(t => Fits(DressKind.Puddle, t));
            if (spot != default) Puddle(pass, spot, "culvert");
        }
        var grates = _ledger.OfKind(DressKind.FloorGrate).Select(g => g.Tile + new Vector2I(pass.Margin, pass.Margin)).ToList();
        var ring = tiles.Where(t => grates.Any(g => SewerSites.Chebyshev(g, t) == 1));
        foreach (var t in Rolled(ring, GrateRingChance, SaltRoll))
            if (Fits(DressKind.Puddle, t)) Puddle(pass, t, "grate ring");
        foreach (var t in Rolled(tiles.Where(t => Beside(t, TileRole.Water)), ChannelEdgeChance, SaltRoll))
            if (Fits(DressKind.Puddle, t)) Puddle(pass, t, "channel edge");

        if (FloorSlime != null)
            foreach (var t in Rolled(tiles.Where(t => Beside(t, TileRole.DifficultTerrain)), SludgeSlimeChance, SaltRoll))
                if (Fits(DressKind.Slime, t)) Decal(pass, FloorSlime, t, DressKind.Slime, "sludge edge");

        PlaceBones(pass, tiles, Fits);

        foreach (var t in Rolled(tiles.Where(t => pass.Ring(t) > 0 && SewerSites.WallSides(layout, t).Count > 0), RubbleChance, SaltRoll))
            if (Fits(DressKind.Rubble, t) && !_ledger.Near(DressKind.Rubble, pass.Board(t), RubbleMinGap)
                && ClearOfBoneNeighbours(pass.Board(t), DressKind.Rubble)) Rubble(pass, t);
    }

    private static bool Arched(MapLayout layout, CulvertSpan span)
    {
        var (before, after) = span.Flanks();
        return layout.GetTile(before.X, before.Y) == TileRole.Wall && layout.GetTile(after.X, after.Y) == TileRole.Wall;
    }

    private void Puddle(Pass pass, Vector2I t, string reason)
    {
        var list = pass.Ring(t) == 0 ? BoardPuddles : WalkwayPuddles;
        if (Pick(list, MapHash.Hash01(t.X, t.Y, pass.Layout.Seed + SaltPick)) is { } def) Decal(pass, def, t, DressKind.Puddle, reason);
    }

    private void Decal(Pass pass, DecorSprite def, Vector2I t, DressKind kind, string reason)
    {
        var board = pass.Board(t);
        var centre = new Vector3(board.X + 0.5f, pass.FloorY(t), board.Y + 0.5f);
        int turn = (int)(MapHash.Hash01(t.X, t.Y, pass.Layout.Seed + SaltTurn) * 4f);
        FloorClutter.AddDecal(_props!, def, centre, turn, pass.FloorShade(t));
        _ledger.Add(new DressPlacement(kind, board, board, new Vector2(centre.X, centre.Z), reason));
    }

    private void Rubble(Pass pass, Vector2I t)
    {
        int seed = pass.Layout.Seed;
        if (Pick(RubblePieces, MapHash.Hash01(t.X, t.Y, seed + SaltPick)) is not { Texture: not null } def) return;
        var sides = SewerSites.WallSides(pass.Layout, t);
        var side = sides[(int)(MapHash.Hash01(t.Y, t.X, seed + SaltPick) * sides.Count) % sides.Count];
        var board = pass.Board(t);
        var centre = new Vector3(board.X + 0.5f, pass.FloorY(t), board.Y + 0.5f)
            + new Vector3(side.X, 0f, side.Y) * Mathf.Min(WallLean, Slack(def));
        bool flip = MapHash.Hash01(t.X, t.Y, seed + SaltTurn) < 0.5f;
        if (def.Flat) FloorClutter.AddDecal(_props!, def, centre, 0, pass.FloorShade(t));
        else FloorClutter.AddStanding(_props!, def, centre, flip, pass.FloorShade(t));
        _ledger.Add(new DressPlacement(DressKind.Rubble, board, board, new Vector2(centre.X, centre.Z), "wall foot"));
    }

    /// <summary>Metres a sprite can move off its tile's centre and stay inside the tile.</summary>
    private static float Slack(DecorSprite def)
    {
        if (def.Texture == null) return 0f;
        float half = def.Flat ? def.Size * 0.5f : def.Size * def.Texture.GetWidth() / def.Texture.GetHeight() * 0.5f;
        return Mathf.Max(0f, 0.5f - half - TileEdge);
    }

    private static DecorSprite? Pick(DecorSprite[] list, float roll)
    {
        if (list.Length == 0) return null;
        float target = roll * list.Sum(d => Mathf.Max(0f, d.Weight));
        foreach (var d in list)
        {
            target -= Mathf.Max(0f, d.Weight);
            if (target <= 0f) return d;
        }
        return list[^1];
    }

    // ─────────────────────────── drips ───────────────────────────

    /// <summary>Drops fall from the ceiling over each puddle.</summary>
    private void PlaceDrips(Pass pass)
    {
        var puddles = _ledger.OfKind(DressKind.Puddle).ToList();
        if (puddles.Count == 0 || DripsScene?.Instantiate() is not GpuParticles3D drips) return;
        var points = Image.CreateEmpty(puddles.Count, 1, false, Image.Format.Rgbf);
        var low = new Vector3(float.MaxValue, float.MaxValue, float.MaxValue);
        var high = -low;
        for (int i = 0; i < puddles.Count; i++)
        {
            var p = puddles[i];
            float floor = pass.FloorY(p.Tile + new Vector2I(pass.Margin, pass.Margin));
            var top = new Vector3(p.At.X, floor + DripHeight, p.At.Y);
            points.SetPixel(i, 0, new Color(top.X, top.Y, top.Z));
            low = low.Min(top with { Y = floor });
            high = high.Max(top);
        }
        if (drips.ProcessMaterial is ParticleProcessMaterial process)
        {
            process.EmissionShape = ParticleProcessMaterial.EmissionShapeEnum.Points;
            process.EmissionPointTexture = ImageTexture.CreateFromImage(points);
            process.EmissionPointCount = puddles.Count;
        }
        drips.VisibilityAabb = new Aabb(low - Vector3.One * 0.5f, high - low + Vector3.One);
        _props!.AddChild(drips);
    }
}
