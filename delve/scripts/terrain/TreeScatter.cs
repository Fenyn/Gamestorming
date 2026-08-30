using System;
using System.Collections.Generic;
using Delve.Props;
using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Terrain;

/// <summary>One tree mix: prop scenes, their pick weights, and the smallest halo ring each may
/// stand on. Entries past the end of <see cref="Weights"/> count as weight 1; past
/// <see cref="MinRings"/>, as ring 0 (anywhere).</summary>
public readonly record struct TreeMix(PackedScene[] Scenes, float[] Weights, float[] MinRings);

/// <summary>
/// Stands the tree props on a built skirt: the halo scatter's spots get the halo mix (ring-gated,
/// so brush hugs the clearing and giants stay deep), and the flattened tree-wall tiles get the
/// tighter board mix, barely off their tile centres — the trunk IS the blocked tile. Every spawned
/// prop is enrolled in the <see cref="TreeFader"/> occluder pass, which is configured here with the
/// battlefield's world box. All picks and jitters hash off the layout seed: same seed, same forest.
///
/// Split out of <see cref="TerrainStage"/>, which owns the exported mixes and the node lifecycle;
/// this file owns what a forest of props IS.
/// </summary>
public static class TreeScatter
{
    /// <summary>Hash stream for the scene picks and placement jitter.</summary>
    private const int PickSalt = 0x4D2F;

    /// <summary>Placement jitter radius, tiles: halo trees wander freely; a board tree stays close
    /// to its tile centre so the blocked tile and the trunk read as the same thing.</summary>
    private const float HaloJitter = 0.3f;
    private const float BoardJitter = 0.12f;

    /// <summary>
    /// Build the tree layer for one skirt. Returns the parent node of every spawned prop —
    /// positioned to overlay the terrain mesh, ready to be added under the stage — or null when
    /// nothing spawned. <paramref name="fader"/> is reconfigured for this battlefield.
    /// </summary>
    public static Node3D? Build(
        SkirtResult skirt,
        TerrainHeightMap heights,
        float heightScale,
        TreeFader fader,
        TreeMix halo,
        TreeMix board,
        List<(int X, int Y)> treeWallSpots)
    {
        var box = BattlefieldBox(skirt, heightScale);
        fader.Configure(box);

        var root = new Node3D { Name = "Trees", Position = new Vector3(-skirt.Margin, 0f, -skirt.Margin) };
        int boardW = skirt.Layout.Width - 2 * skirt.Margin;
        int boardH = skirt.Layout.Height - 2 * skirt.Margin;

        foreach (var (x, y) in skirt.Trees)
        {
            // Chebyshev ring of the spot from the board rectangle (same measure the skirt uses),
            // gating which kinds are allowed to stand this close to the clearing.
            int dx = Math.Max(Math.Max(skirt.Margin - x, x - (skirt.Margin + boardW - 1)), 0);
            int dy = Math.Max(Math.Max(skirt.Margin - y, y - (skirt.Margin + boardH - 1)), 0);
            Spawn(root, skirt, heights, fader, box, halo, x, y, Math.Max(dx, dy), HaloJitter);
        }

        foreach (var (x, y) in treeWallSpots)
            Spawn(root, skirt, heights, fader, box, board, x, y, int.MaxValue, BoardJitter);

        if (root.GetChildCount() > 0) return root;
        root.QueueFree();
        return null;
    }

    private static void Spawn(
        Node3D root, SkirtResult skirt, TerrainHeightMap heights, TreeFader fader, Aabb box,
        TreeMix mix, int x, int y, int ring, float jitter)
    {
        int seed = skirt.Layout.Seed;
        int pick = PickWeighted(MapHash.Hash01(x, y, seed + PickSalt), ring, mix);
        if (pick < 0) return;
        if (mix.Scenes[pick].Instantiate() is not Node3D tree) return;

        float angle = MapHash.Hash01(x, y, seed + PickSalt + 1) * Mathf.Tau;
        float radius = MapHash.Hash01(y, x, seed + PickSalt + 2) * jitter;
        tree.Position = GridSpace.GridToWorld(new PF2eVec(x, y), heights)
                        + new Vector3(Mathf.Cos(angle) * radius, 0f, Mathf.Sin(angle) * radius);
        root.AddChild(tree);
        if (tree is not TreeProp prop) return;
        fader.Track(prop);
        prop.SetBattlefield(box);
    }

    /// <summary>World-space box the fade pass protects: the board's footprint up to its tallest
    /// ground plus headroom for a unit standing on it.</summary>
    private static Aabb BattlefieldBox(SkirtResult skirt, float heightScale)
    {
        int boardW = skirt.Layout.Width - 2 * skirt.Margin;
        int boardH = skirt.Layout.Height - 2 * skirt.Margin;

        int maxUnits = 0;
        for (int y = 0; y < boardH; y++)
            for (int x = 0; x < boardW; x++)
            {
                var c = skirt.Layout.GetCornerHeights(x + skirt.Margin, y + skirt.Margin);
                if (c.MaxHeight > maxUnits) maxUnits = c.MaxHeight;
            }

        float top = maxUnits * heightScale + 1.6f;
        return new Aabb(new Vector3(0f, -0.5f, 0f), new Vector3(boardW, top + 0.5f, boardH));
    }

    /// <summary>Index of one weighted pick over the mix, skipping entries whose min ring lies
    /// beyond <paramref name="ring"/>; -1 when nothing is allowed at this ring.</summary>
    private static int PickWeighted(float roll, int ring, TreeMix mix)
    {
        float WeightAt(int i) => i < mix.Weights.Length ? Mathf.Max(0f, mix.Weights[i]) : 1f;
        float RingAt(int i) => i < mix.MinRings.Length ? mix.MinRings[i] : 0f;

        float total = 0f;
        for (int i = 0; i < mix.Scenes.Length; i++)
            if (RingAt(i) <= ring) total += WeightAt(i);
        if (total <= 0f) return -1;

        float target = roll * total;
        int last = -1;
        for (int i = 0; i < mix.Scenes.Length; i++)
        {
            if (RingAt(i) > ring) continue;
            last = i;
            target -= WeightAt(i);
            if (target <= 0f) return i;
        }
        return last;
    }
}
