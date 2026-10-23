using System;
using System.Collections.Generic;
using PF2e.Grid;
using PF2e.MapGen;

namespace Ungilded.Terrain;

/// <summary>
/// Which wall tiles of a rendered layout the camera cuts down, for each of the four camera
/// quadrants (the camera sits on the +x or -x side and the +z or -z side of what it looks at).
///
/// The rule follows wall faces. An outline wall (halo masonry, or a board wall joined to it) is cut
/// while the floor it bounds lies on its far side from the camera: open floor next to it, straight
/// or diagonally, away from the camera. So the camera-facing walls of a room or a passage come down
/// along their whole run, and the walls that face the camera stand along theirs. Masonry in front of
/// a cut wall (further toward the camera) is cut with it. Where a cut tile meets a standing one the
/// standing wall gets a masonry end face (<see cref="Seams"/>). A cut wall
/// draws up to a stub <see cref="StubUnits"/> above its foot if it touches open floor, and drops away
/// entirely if it lies deeper in the masonry. Never cut by this rule: a free-standing wall inside
/// the board, and any wall lower than three quarters of the wall height above the floor beside it
/// (a pillar). A pillar drops to its stub only while a unit stands right behind it
/// (<see cref="PillarsInFront"/>). Tiles can be pinned standing in chosen quadrants (the jambs of
/// a culvert arch, <see cref="WithStanding"/>). Engine-free.
/// </summary>
public sealed class CutawayMap
{
    /// <summary>Height of a cut wall's stub above its foot, in corner units (0.375 m).</summary>
    public const int StubUnits = 3;

    /// <summary>Rings of masonry next to open floor that stay as a stub when cut. A cut tile
    /// further from any open floor drops away entirely, so the cut reads as a wall in section with
    /// darkness beyond it.</summary>
    public const int StubRings = 1;

    private readonly byte[] _masks;
    private readonly int[] _stubTops;
    private readonly bool[] _deep;

    /// <summary>Low walls (pillars) by the pillar they belong to; -1 for any other tile.</summary>
    private readonly int[] _lowWall;

    private readonly MapLayout _layout;
    private readonly TileRect _board;
    private readonly int _wallHeightUnits;

    private CutawayMap(MapLayout layout, int wallHeightUnits, TileRect board)
    {
        int width = layout.Width, height = layout.Height;
        _layout = layout;
        _board = board;
        _wallHeightUnits = wallHeightUnits;
        Width = width;
        Height = height;
        _masks = new byte[width * height];
        _stubTops = new int[width * height];
        _deep = new bool[width * height];
        _lowWall = new int[width * height];
        Array.Fill(_lowWall, -1);
    }

    public int Width { get; }
    public int Height { get; }

    /// <summary>The quadrant of a camera, from the horizontal direction that points from the scene
    /// toward it.</summary>
    public static int Quadrant(float towardCameraX, float towardCameraZ)
        => (towardCameraX < 0f ? 1 : 0) | (towardCameraZ < 0f ? 2 : 0);

    /// <summary>One bit per quadrant in which the tile is cut; 0 for a tile never cut.</summary>
    public int Mask(int x, int y) => _masks[y * Width + x];

    public bool IsCut(int x, int y, int quadrant)
        => x >= 0 && y >= 0 && x < Width && y < Height && ((_masks[y * Width + x] >> quadrant) & 1) != 0;

    /// <summary>Corner height of a cut tile's stub top; for a <see cref="IsDeep"/> tile, its foot.</summary>
    public int StubTop(int x, int y) => _stubTops[y * Width + x];

    /// <summary>True for a tile more than <see cref="StubRings"/> from open floor: cut, it draws
    /// nothing above its foot.</summary>
    public bool IsDeep(int x, int y) => _deep[y * Width + x];

    /// <summary>True for a low wall (a pillar). The static rule never cuts one; it drops to its
    /// stub only while a unit stands right behind it (<see cref="PillarsInFront"/>).</summary>
    public bool IsLowWall(int x, int y) => _lowWall[y * Width + x] >= 0;

    /// <summary>Every low-wall tile of each pillar that stands on the camera side of a tile in
    /// <paramref name="occupied"/> (layout coordinates), touching it straight or diagonally. A
    /// pillar there is the only masonry that can hide a unit the static cut leaves standing.</summary>
    public HashSet<(int X, int Y)> PillarsInFront(IEnumerable<(int X, int Y)> occupied, int quadrant)
    {
        int sx = (quadrant & 1) != 0 ? -1 : 1, sz = (quadrant & 2) != 0 ? -1 : 1;
        var pillars = new HashSet<int>();
        foreach (var (x, y) in occupied)
            foreach (var (nx, ny) in new[] { (x + sx, y), (x, y + sz), (x + sx, y + sz) })
                if (nx >= 0 && ny >= 0 && nx < Width && ny < Height && _lowWall[ny * Width + nx] >= 0)
                    pillars.Add(_lowWall[ny * Width + nx]);
        var tiles = new HashSet<(int X, int Y)>();
        if (pillars.Count == 0) return tiles;
        for (int y = 0; y < Height; y++)
            for (int x = 0; x < Width; x++)
                if (pillars.Contains(_lowWall[y * Width + x])) tiles.Add((x, y));
        return tiles;
    }

    /// <summary>This map rebuilt with each tile of <paramref name="quadrantsByTile"/> left standing
    /// in the quadrants its bits name, so the masonry in front of it stands too unless its own
    /// faces cut it.</summary>
    public CutawayMap WithStanding(IReadOnlyDictionary<(int X, int Y), int> quadrantsByTile)
        => Build(_layout, _wallHeightUnits, _board, quadrantsByTile);

    /// <summary>The map for <paramref name="layout"/>, whose playable board is
    /// <paramref name="board"/>. A tile in <paramref name="standing"/> is never cut in the quadrants
    /// its bits name.</summary>
    public static CutawayMap Build(MapLayout layout, int wallHeightUnits, TileRect board,
        IReadOnlyDictionary<(int X, int Y), int>? standing = null)
    {
        ArgumentNullException.ThrowIfNull(layout);
        int w = layout.Width, h = layout.Height;
        var map = new CutawayMap(layout, wallHeightUnits, board);
        var outline = Outline(layout, board);
        var rings = RingsFromOpen(layout);
        map.FindLowWalls(layout, wallHeightUnits);
        var cuttable = new bool[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                if (!outline[y * w + x]) continue;
                int i = y * w + x;
                int top = layout.GetCornerHeights(x, y).MaxHeight;
                int? ground = LowestOpenBeside(layout, x, y);
                cuttable[i] = ground == null || top - ground.Value >= wallHeightUnits * 3 / 4;
                map._deep[i] = rings[i] > StubRings;
                map._stubTops[i] = top - wallHeightUnits + (map._deep[i] ? 0 : StubUnits);
            }

        for (int q = 0; q < 4; q++)
        {
            int sx = (q & 1) != 0 ? -1 : 1, sz = (q & 2) != 0 ? -1 : 1;
            byte bit = (byte)(1 << q);
            bool CutAt(int cx, int cy) => layout.IsInBounds(cx, cy) && (map._masks[cy * w + cx] & bit) != 0;
            // Sweep away from the far corner, so the tiles behind a tile are decided before it.
            for (int j = 0; j < h; j++)
            {
                int y = sz > 0 ? j : h - 1 - j;
                for (int i = 0; i < w; i++)
                {
                    int x = sx > 0 ? i : w - 1 - i;
                    if (!cuttable[y * w + x]) continue;
                    if (standing != null && standing.TryGetValue((x, y), out int keep) && (keep & bit) != 0) continue;
                    bool facesAway = Hides(layout, board, x, y, sx, 0) || Hides(layout, board, x, y, 0, sz)
                        || (Hides(layout, board, x, y, sx, sz) && !Open(layout, x + sx, y) && !Open(layout, x, y + sz));
                    bool inFrontOfCut = CutAt(x - sx, y) || CutAt(x, y - sz) || CutAt(x - sx, y - sz);
                    if (facesAway || inFrontOfCut) map._masks[y * w + x] |= bit;
                }
            }
        }
        map.FindSeams(layout, wallHeightUnits);
        return map;
    }

    /// <summary>
    /// True when wall tile (x, y) stands in front of open floor one step away from the camera along
    /// (dx, dy). Board floor always counts: a unit may stand there. Halo floor counts only when the
    /// tile has masonry on its camera side along that step, so a wall bounding a passage comes down,
    /// while a pier or rib standing in open floor on both sides keeps its height.
    /// </summary>
    private static bool Hides(MapLayout layout, TileRect board, int x, int y, int dx, int dy)
    {
        if (!Open(layout, x - dx, y - dy)) return false;
        return board.Contains(x - dx, y - dy) || !Open(layout, x + dx, y + dy);
    }

    /// <summary>A masonry face on the edge of wall tile (<paramref name="X"/>, <paramref name="Y"/>)
    /// toward its neighbour <paramref name="Toward"/>, from corner height <paramref name="Top"/> down
    /// to <paramref name="Bottom"/>. Hidden inside solid masonry; shown where the neighbour is cut and
    /// this tile stands.</summary>
    public readonly record struct Seam(int X, int Y, CardinalDirection Toward, int Top, int Bottom);

    private readonly List<Seam> _seams = new();

    /// <summary>The end faces between neighbouring walls whose cut can differ, both ways round.</summary>
    public IReadOnlyList<Seam> Seams => _seams;

    private void FindSeams(MapLayout layout, int wallHeightUnits)
    {
        for (int y = 0; y < Height; y++)
            for (int x = 0; x < Width; x++)
            {
                if (layout.GetTile(x, y) != TileRole.Wall) continue;
                foreach (var dir in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
                {
                    var (nx, ny) = dir switch
                    {
                        CardinalDirection.North => (x, y + 1),
                        CardinalDirection.South => (x, y - 1),
                        CardinalDirection.East => (x + 1, y),
                        _ => (x - 1, y),
                    };
                    if (!layout.IsInBounds(nx, ny) || layout.GetTile(nx, ny) != TileRole.Wall) continue;
                    int i = y * Width + x, n = ny * Width + nx;
                    if (_masks[i] == _masks[n] && _deep[i] == _deep[n]) continue;
                    int top = Math.Min(layout.GetCornerHeights(x, y).MaxHeight, layout.GetCornerHeights(nx, ny).MaxHeight);
                    int bottom = Math.Min(Foot(layout, x, y, wallHeightUnits), Foot(layout, nx, ny, wallHeightUnits));
                    if (top > bottom) _seams.Add(new Seam(x, y, dir, top, bottom));
                }
            }
    }

    /// <summary>The floor a wall stands on: its stub's foot when it can be cut, else the floor
    /// beside it, else its top less the wall height.</summary>
    private int Foot(MapLayout layout, int x, int y, int wallHeightUnits)
    {
        int i = y * Width + x;
        if (_masks[i] != 0) return _stubTops[i] - (_deep[i] ? 0 : StubUnits);
        return LowestOpenBeside(layout, x, y) ?? layout.GetCornerHeights(x, y).MaxHeight - wallHeightUnits;
    }

    /// <summary>A copy of <paramref name="layout"/> with every tile the camera can cut lowered to
    /// its stub: the surface a pick ray should hit.</summary>
    public MapLayout PickLayout(MapLayout layout)
    {
        var copy = new MapLayout { Name = layout.Name + "_pick", Seed = layout.Seed, BorderWidth = layout.BorderWidth };
        copy.Initialize(layout.Width, layout.Height);
        Array.Copy(layout.Tiles, copy.Tiles, layout.Tiles.Length);
        Array.Copy(layout.Surfaces, copy.Surfaces, layout.Surfaces.Length);
        Array.Copy(layout.Elevations, copy.Elevations, layout.Elevations.Length);
        Array.Copy(layout.CornerHeights, copy.CornerHeights, layout.CornerHeights.Length);
        Array.Copy(layout.TerrainDifficulties, copy.TerrainDifficulties, layout.TerrainDifficulties.Length);
        for (int y = 0; y < Height; y++)
            for (int x = 0; x < Width; x++)
                if (Mask(x, y) != 0)
                    copy.SetCornerHeights(x, y, TileCornerHeights.Flat(StubTop(x, y)));
        return copy;
    }

    /// <summary>Wall tiles of the room's outline: every halo wall, and every board wall joined to one
    /// through other walls. A free-standing wall inside the board is not part of it.</summary>
    private static bool[] Outline(MapLayout layout, TileRect board)
    {
        int w = layout.Width, h = layout.Height;
        var outline = new bool[w * h];
        var queue = new Queue<(int X, int Y)>();
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                if (!board.Contains(x, y) && layout.GetTile(x, y) == TileRole.Wall)
                {
                    outline[y * w + x] = true;
                    queue.Enqueue((x, y));
                }
        while (queue.Count > 0)
        {
            var (x, y) = queue.Dequeue();
            foreach (var (nx, ny) in new[] { (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1) })
            {
                if (!layout.IsInBounds(nx, ny) || outline[ny * w + nx] || layout.GetTile(nx, ny) != TileRole.Wall) continue;
                outline[ny * w + nx] = true;
                queue.Enqueue((nx, ny));
            }
        }
        return outline;
    }

    /// <summary>Numbers each pillar: a four-way connected group of walls that stand less than three
    /// quarters of the wall height above the floor beside them. Their stub is the usual height above
    /// that floor.</summary>
    private void FindLowWalls(MapLayout layout, int wallHeightUnits)
    {
        int w = Width, h = Height, next = 0;
        bool Low(int x, int y) => layout.IsInBounds(x, y) && layout.GetTile(x, y) == TileRole.Wall
            && LowestOpenBeside(layout, x, y) is { } ground
            && layout.GetCornerHeights(x, y).MaxHeight - ground < wallHeightUnits * 3 / 4;
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                if (_lowWall[y * w + x] >= 0 || !Low(x, y)) continue;
                var queue = new Queue<(int X, int Y)>();
                var pillar = new List<(int X, int Y)>();
                queue.Enqueue((x, y));
                _lowWall[y * w + x] = next;
                int ground = int.MinValue;
                while (queue.Count > 0)
                {
                    var (cx, cy) = queue.Dequeue();
                    pillar.Add((cx, cy));
                    ground = Math.Max(ground, LowestOpenBeside(layout, cx, cy)!.Value);
                    foreach (var (nx, ny) in new[] { (cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1) })
                    {
                        if (!Low(nx, ny) || _lowWall[ny * w + nx] >= 0) continue;
                        _lowWall[ny * w + nx] = next;
                        queue.Enqueue((nx, ny));
                    }
                }
                // One stub height per pillar, above the highest floor around it, so a pillar beside a
                // sunken channel does not break into two steps.
                foreach (var (px, py) in pillar) _stubTops[py * w + px] = ground + StubUnits;
                next++;
            }
    }

    /// <summary>Rings from the nearest open tile, eight-way through masonry: 1 for a wall touching
    /// open floor, 0 for open floor itself.</summary>
    private static int[] RingsFromOpen(MapLayout layout)
    {
        int w = layout.Width, h = layout.Height;
        var rings = new int[w * h];
        Array.Fill(rings, int.MaxValue);
        var queue = new Queue<(int X, int Y)>();
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                if (Open(layout, x, y))
                {
                    rings[y * w + x] = 0;
                    queue.Enqueue((x, y));
                }
        while (queue.Count > 0)
        {
            var (x, y) = queue.Dequeue();
            int next = rings[y * w + x] + 1;
            for (int oy = -1; oy <= 1; oy++)
                for (int ox = -1; ox <= 1; ox++)
                {
                    int nx = x + ox, ny = y + oy;
                    if (!layout.IsInBounds(nx, ny) || rings[ny * w + nx] <= next) continue;
                    rings[ny * w + nx] = next;
                    queue.Enqueue((nx, ny));
                }
        }
        return rings;
    }

    private static bool Open(MapLayout layout, int x, int y)
        => layout.IsInBounds(x, y) && layout.GetTile(x, y) is not (TileRole.Wall or TileRole.Empty);

    private static int? LowestOpenBeside(MapLayout layout, int x, int y)
    {
        int? lowest = null;
        for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++)
                if (Open(layout, x + ox, y + oy))
                {
                    int floor = layout.GetCornerHeights(x + ox, y + oy).MinHeight;
                    lowest = lowest == null ? floor : Math.Min(lowest.Value, floor);
                }
        return lowest;
    }
}
