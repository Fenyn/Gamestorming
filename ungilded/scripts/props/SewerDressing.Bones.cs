using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Ungilded.Content;
using Ungilded.Terrain;

namespace Ungilded.Props;

/// <summary>Bones gather where things come to rest: around the slumped skeleton, in dead ends,
/// niches and the inside corners of the chamber. Each spot takes one cluster of a few pieces.</summary>
public partial class SewerDressing
{
    private void PlaceBones(Pass pass, List<Vector2I> tiles, Func<DressKind, Vector2I, bool> fits)
    {
        if (BonePieces.Length == 0 || BoneClusters <= 0) return;
        var layout = pass.Layout;
        int seed = layout.Seed;
        var skeletons = pass.Context.Skirt.Plan?.Marks.Where(k => k.Kind == SewerBoard.SkeletonMark)
            .Select(k => new Vector2I(k.X + pass.Margin, k.Y + pass.Margin)).ToList() ?? new List<Vector2I>();
        var recesses = Openings.Where(o => o.Kind == OpeningKind.Recess)
            .SelectMany(o => Enumerable.Range(0, o.Width).SelectMany(i => Enumerable.Range(1, o.Depth).Select(r => o.At(i, r))))
            .ToHashSet();

        string? Reason(Vector2I t) =>
            skeletons.Any(s => SewerSites.Chebyshev(s, t) <= BoneSkeletonRings) ? "skeleton"
            : SewerSites.IsDeadEnd(layout, t) ? "dead end"
            : recesses.Contains(t) ? "niche"
            : SewerSites.IsInsideCorner(layout, t) ? "corner"
            : null;
        string[] order = { "skeleton", "dead end", "niche", "corner" };

        var spots = tiles.Select(t => (Tile: t, Reason: Reason(t))).Where(s => s.Reason != null)
            .OrderBy(s => Array.IndexOf(order, s.Reason)).ThenBy(s => MapHash.Hash01(s.Tile.Y, s.Tile.X, seed + SaltOrder));
        var placed = new List<Vector2I>();
        foreach (var (tile, reason) in spots)
        {
            if (placed.Count >= BoneClusters) break;
            if (placed.Any(p => SewerSites.Chebyshev(p, tile) < BoneClusterGap) || !fits(DressKind.Bones, tile)
                || !ClearOfBoneNeighbours(pass.Board(tile), DressKind.Bones)) continue;
            if (Cluster(pass, tile, reason!)) placed.Add(tile);
        }
    }

    /// <summary>The props a bone cluster keeps <see cref="BonePropGap"/> tiles from: torches, grates,
    /// rubble and the puddle under an outfall.</summary>
    public static bool KeepsFromBones(DressPlacement p) => p.Kind is DressKind.Torch or DressKind.WallGrate
        or DressKind.FloorGrate or DressKind.Rubble || p is { Kind: DressKind.Puddle, Reason: OutfallReason };

    /// <summary>The puddle reason under an outfall or water pipe.</summary>
    public const string OutfallReason = "outfall";

    /// <summary>A <paramref name="kind"/> placed at <paramref name="board"/> keeps the bone gap: bones
    /// from the props in <see cref="KeepsFromBones"/>, and those props from bones.</summary>
    private bool ClearOfBoneNeighbours(Vector2I board, DressKind kind)
    {
        var others = kind == DressKind.Bones ? _ledger.Placed.Where(KeepsFromBones) : _ledger.OfKind(DressKind.Bones);
        return others.All(p => SewerSites.Chebyshev(p.Tile, board) >= BonePropGap && SewerSites.Chebyshev(p.Wall, board) >= BonePropGap);
    }

    /// <summary>Two or three pieces side by side, pushed toward the walls around the tile.</summary>
    private bool Cluster(Pass pass, Vector2I t, string reason)
    {
        int seed = pass.Layout.Seed;
        bool onBoard = pass.Ring(t) == 0;
        var pool = BonePieces.Where(p => p.Texture != null && (p.Flat || !onBoard))
            .Select((p, i) => (Piece: p, Roll: MapHash.Hash01(i, t.X * 31 + t.Y, seed + SaltPick)))
            .OrderBy(p => p.Roll).Select(p => p.Piece).ToList();
        if (pool.Count == 0) return false;
        int extra = BonePieceCount.Y - BonePieceCount.X + 1;
        int count = Math.Min(pool.Count, BonePieceCount.X + (int)(MapHash.Hash01(t.X, t.Y, seed + SaltCount) * extra));

        var toward = SewerSites.WallSides(pass.Layout, t).Aggregate(Vector2.Zero, (a, d) => a + new Vector2(d.X, d.Y));
        toward = toward.LengthSquared() > 0f ? toward.Normalized() : Vector2.Zero;
        var across = toward == Vector2.Zero ? Vector2.Right : new Vector2(-toward.Y, toward.X);
        var board = pass.Board(t);
        var centre = new Vector3(board.X + 0.5f, pass.FloorY(t), board.Y + 0.5f);
        for (int k = 0; k < count; k++)
        {
            var piece = pool[k];
            var offset = toward * WallLean + across * ((k - (count - 1) * 0.5f) * BoneSpread);
            float slack = Slack(piece);
            var spot = centre + new Vector3(Mathf.Clamp(offset.X, -slack, slack), 0f, Mathf.Clamp(offset.Y, -slack, slack));
            int turn = (int)(MapHash.Hash01(k, t.X + t.Y, seed + SaltTurn) * 4f);
            if (piece.Flat) FloorClutter.AddDecal(_props!, piece, spot, turn, pass.FloorShade(t));
            else FloorClutter.AddStanding(_props!, piece, spot, turn % 2 == 1, pass.FloorShade(t));
        }
        _ledger.Add(new DressPlacement(DressKind.Bones, board, board, new Vector2(centre.X, centre.Z), reason));
        return true;
    }
}
