using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.Core;
using PF2e.MapGen;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>
/// Which units the drawn terrain hides from a camera position: a straight line from a point above
/// each unit's tile to the camera, tested against the terrain as the cutaway draws it for that
/// camera's quadrant (a cut wall counts at its stub, and so does a pillar with a unit right behind
/// it). Full walls and low walls (pillars) are reported apart.
/// </summary>
public static class CutawaySight
{
    public readonly record struct Blocked(string Unit, PF2eVec Tile, bool ByPillar);

    private const float Step = 0.04f;
    private const float Reach = 16f;

    public static List<Blocked> Hidden(SkirtResult skirt, CutawayMap map, float heightScale, TerrainHeightMap boardHeights,
        IEnumerable<ICharacter> units, Vector3 camera, int quadrant, float pointHeight, int wallHeightUnits) =>
        Hidden(skirt, map, heightScale, boardHeights,
            units.Where(u => u.Health is not { IsDead: true }).Select(u => (u.Name, u.GridPosition)),
            camera, quadrant, pointHeight, wallHeightUnits);

    /// <summary>The same check for named figures standing on board tiles (halo tiles included).</summary>
    public static List<Blocked> Hidden(SkirtResult skirt, CutawayMap map, float heightScale, TerrainHeightMap boardHeights,
        IEnumerable<(string Name, PF2eVec Tile)> figures, Vector3 camera, int quadrant, float pointHeight, int wallHeightUnits)
    {
        var hidden = new List<Blocked>();
        var standing = figures.ToList();
        var open = map.PillarsInFront(standing.Select(f => (f.Tile.x + skirt.Margin, f.Tile.y + skirt.Margin)), quadrant);
        foreach (var (name, tile) in standing)
        {
            var from = new Vector3(tile.x + 0.5f, boardHeights.CenterY(tile) + pointHeight, tile.y + 0.5f);
            if (Blocker(skirt, map, open, heightScale, from, camera, tile, quadrant, wallHeightUnits) is { } pillar)
                hidden.Add(new Blocked(name, tile, pillar));
        }
        return hidden;
    }

    /// <summary>Null when the line is clear; else whether the first blocker is a low wall.</summary>
    private static bool? Blocker(SkirtResult skirt, CutawayMap map, HashSet<(int X, int Y)> openPillars, float heightScale,
        Vector3 from, Vector3 camera, PF2eVec own, int quadrant, int wallHeightUnits)
    {
        var layout = skirt.Layout;
        int margin = skirt.Margin;
        var direction = (camera - from).Normalized();
        var flat = new Vector2(direction.X, direction.Z).Length();
        for (float t = Step; t * flat < Reach; t += Step)
        {
            var p = from + direction * t;
            int sx = Mathf.FloorToInt(p.X) + margin, sy = Mathf.FloorToInt(p.Z) + margin;
            if (!layout.IsInBounds(sx, sy)) return null;
            if (sx - margin == own.x && sy - margin == own.y) continue;
            if (layout.GetTile(sx, sy) != TileRole.Wall) continue;
            bool cut = map.IsCut(sx, sy, quadrant) || openPillars.Contains((sx, sy));
            int top = cut ? map.StubTop(sx, sy) : layout.GetCornerHeights(sx, sy).MaxHeight;
            if (p.Y >= top * heightScale) continue;
            return map.IsLowWall(sx, sy);
        }
        return null;
    }
}
