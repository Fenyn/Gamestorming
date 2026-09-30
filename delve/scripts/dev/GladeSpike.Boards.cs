using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

public partial class GladeSpike
{
    /// <summary>Generated wilds combat boards grow the same undergrowth as the glades: trees in from
    /// the edge and brush, with the deployment zones clear and no open ground cut off.</summary>
    private void CheckBoards()
    {
        var biome = MapGenRegistry.GetBiome(Dungeon.GladeGeneration.Biome);
        int hedged = 0, blocked = 0, cut = 0, noBrush = 0, differ = 0;
        for (int seed = 1; seed <= Seeds; seed++)
        {
            int side = BoardSides[seed % BoardSides.Length];
            var sized = biome.DefaultParams.WithSize(side, side + seed % 3);
            var layout = MapGenerator.GenerateValidated(biome.Id, seed, sized);
            var open = Walkable(layout);
            var before = Reach(layout, open.FirstOrDefault(p => InZone(layout, p, 0)));
            EncounterFactory.GrowUndergrowth(layout, seed);
            var again = MapGenerator.GenerateValidated(biome.Id, seed, sized);
            EncounterFactory.GrowUndergrowth(again, seed);
            if (!again.Tiles.SequenceEqual(layout.Tiles)) differ++;

            int w = layout.Width, h = layout.Height;
            int Depth(PF2eVec p) => Math.Min(Math.Min(p.x, p.y), Math.Min(w - 1 - p.x, h - 1 - p.y));
            var tiles = Enumerable.Range(0, w * h).Select(i => new PF2eVec(i % w, i / w)).ToArray();
            bool Grown(PF2eVec p) => layout.GetTile(p.x, p.y) == TileRole.Wall && open.Contains(p);
            if (!tiles.Any(p => Depth(p) <= 1 && Grown(p))) hedged++;
            if (!tiles.Any(p => layout.GetTile(p.x, p.y) == TileRole.DifficultTerrain && layout.GetPlantTerrain(p.x, p.y))) noBrush++;
            if (tiles.Any(p => (InZone(layout, p, 0) || InZone(layout, p, 1)) && !layout.IsWalkable(p.x, p.y) && open.Contains(p))) blocked++;
            var after = Reach(layout, open.FirstOrDefault(p => InZone(layout, p, 0)));
            if (before.Any(p => layout.IsWalkable(p.x, p.y) && !after.Contains(p))) cut++;
        }
        Check($"wilds combat boards grow trees in from the edge: {hedged} of {Seeds} keep a bare edge", hedged == 0);
        Check($"wilds combat boards grow brush beside those trees: {noBrush} of {Seeds} without", noBrush == 0);
        Check($"undergrowth leaves both deployment zones open: {blocked} boards blocked", blocked == 0);
        Check($"undergrowth never cuts off open ground: {cut} boards cut", cut == 0);
        Check($"the same seed grows the same undergrowth: {differ} differ", differ == 0);
    }

    /// <summary>Board widths the check sweeps; heights run up to two tiles longer.</summary>
    private static readonly int[] BoardSides = { 12, 14, 16, 18, 20 };

    private static HashSet<PF2eVec> Walkable(MapLayout layout) =>
        Enumerable.Range(0, layout.Width * layout.Height).Select(i => new PF2eVec(i % layout.Width, i / layout.Width))
            .Where(p => layout.IsWalkable(p.x, p.y)).ToHashSet();

    private static bool InZone(MapLayout layout, PF2eVec p, int team) =>
        layout.DeploymentZones is { } zones && zones.Length > team && zones[team] is { } z
        && p.x >= Math.Min(z.CornerA.x, z.CornerB.x) && p.x <= Math.Max(z.CornerA.x, z.CornerB.x)
        && p.y >= Math.Min(z.CornerA.y, z.CornerB.y) && p.y <= Math.Max(z.CornerA.y, z.CornerB.y);

    /// <summary>Walkable tiles reached from <paramref name="start"/>, one elevation per step.</summary>
    private static HashSet<PF2eVec> Reach(MapLayout layout, PF2eVec start)
    {
        var seen = new HashSet<PF2eVec>();
        if (!layout.IsWalkable(start.x, start.y)) return seen;
        var queue = new Queue<PF2eVec>();
        seen.Add(start);
        queue.Enqueue(start);
        while (queue.TryDequeue(out var p))
            foreach (var d in Dungeon.GladeGeneration.Steps)
            {
                var q = new PF2eVec(p.x + d.x, p.y + d.y);
                if (q.x < 0 || q.y < 0 || q.x >= layout.Width || q.y >= layout.Height || seen.Contains(q) || !layout.IsWalkable(q.x, q.y)) continue;
                if (Math.Abs(layout.GetElevation(q.x, q.y) - layout.GetElevation(p.x, p.y)) > 1) continue;
                seen.Add(q);
                queue.Enqueue(q);
            }
        return seen;
    }
}
