using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Ungilded.Terrain;

/// <summary>
/// Applies a <see cref="CutawayMap"/> to the drawn terrain. It writes the map into the shader
/// globals the terrain shaders read (cutaway.gdshaderinc), tracks the camera's quadrant every
/// frame (or holds the one a cutscene shot gives it), draws a stone cap on every stub it may cut and a dark floor under the masonry that drops
/// away, and hides the wall props (torches, pipes) that hang on a wall while that wall is cut. A
/// prop tracked with its lights kept (a torch) hides only its visuals, so its light still falls on
/// the floor while its wall is away. <see cref="TerrainStage"/> configures it per build.
/// </summary>
public partial class TerrainCutaway : Node3D
{
    public const string MapGlobal = "cutaway_map";
    public const string RectGlobal = "cutaway_rect";
    public const string StateGlobal = "cutaway_state";

    /// <summary>The dark floor sits this far under a dropped tile's foot, metres, clear of the
    /// faces that end there.</summary>
    private const float VoidDrop = 0.02f;

    private readonly List<(Node3D Node, (int X, int Y)[] Tiles, bool KeepLights)> _tracked = new();
    private readonly List<MeshInstance3D> _meshes = new();
    private readonly HashSet<(int X, int Y)> _occupied = new();
    private HashSet<(int X, int Y)> _openPillars = new();
    private CutawayMap? _map;
    private Material? _capMaterial, _voidMaterial, _wallMaterial;
    private Image? _image;
    private ImageTexture? _texture;
    private Vector2 _origin;
    private int _quadrant = -1;
    private float _heightScale;
    private bool _occupiedChanged, _held;

    /// <summary>The map in force, or null while the cut is off.</summary>
    public CutawayMap? Map => _map;

    /// <summary>The camera quadrant the cut was last drawn for, or -1 before the first frame.</summary>
    public int CameraQuadrant => _quadrant;

    /// <summary>Switch the cut on for a built layout. <paramref name="origin"/> is the world XZ of
    /// the layout's tile (0, 0). <paramref name="capMaterial"/> draws the stub tops,
    /// <paramref name="voidMaterial"/> the floor under dropped masonry.</summary>
    public void Configure(CutawayMap map, Vector2 origin, float heightScale, Material? capMaterial, Material? voidMaterial,
        Material? wallMaterial)
    {
        Clear();
        _origin = origin;
        _heightScale = heightScale;
        _capMaterial = capMaterial;
        _voidMaterial = voidMaterial;
        _wallMaterial = wallMaterial;
        Draw(map);
        Apply(QuadrantNow() ?? 0);
    }

    /// <summary>Rebuild the map in force with each tile of <paramref name="quadrantsByTile"/> left
    /// standing in the quadrants its bits name (<see cref="CutawayMap.WithStanding"/>). Tracked
    /// props and the held quadrant carry over.</summary>
    public void KeepStanding(IReadOnlyDictionary<(int X, int Y), int> quadrantsByTile)
    {
        if (_map == null) return;
        FreeMeshes();
        Draw(_map.WithStanding(quadrantsByTile));
        _openPillars = new HashSet<(int X, int Y)>();
        Apply(_quadrant >= 0 ? _quadrant : QuadrantNow() ?? 0);
    }

    private void Draw(CutawayMap map)
    {
        _map = map;
        _image = Image.CreateEmpty(map.Width, map.Height, false, Image.Format.Rgf);
        for (int y = 0; y < map.Height; y++)
            for (int x = 0; x < map.Width; x++)
                _image.SetPixel(x, y, new Color(map.Mask(x, y), map.StubTop(x, y) * _heightScale, 0f));
        _texture = ImageTexture.CreateFromImage(_image);
        RenderingServer.GlobalShaderParameterSet(MapGlobal, _texture);
        RenderingServer.GlobalShaderParameterSet(RectGlobal, new Vector4(_origin.X, _origin.Y, map.Width, map.Height));
        AddLayer("CutawayCaps", map, _origin, _capMaterial, deep: false, y => y * _heightScale);
        AddLayer("CutawayVoid", map, _origin, _voidMaterial, deep: true, y => y * _heightScale - VoidDrop);
        AddSeams(map, _origin, _heightScale, _wallMaterial);
    }

    /// <summary>Switch the cut off and forget the tracked props.</summary>
    public void Clear()
    {
        _map = null;
        _image = null;
        _texture = null;
        _quadrant = -1;
        _held = false;
        _tracked.Clear();
        _occupied.Clear();
        _openPillars = new HashSet<(int X, int Y)>();
        FreeMeshes();
        RenderingServer.GlobalShaderParameterSet(StateGlobal, Vector4.Zero);
    }

    private void FreeMeshes()
    {
        foreach (var mesh in _meshes)
        {
            RemoveChild(mesh);
            mesh.QueueFree();
        }
        _meshes.Clear();
    }

    /// <summary>Hide <paramref name="node"/> whenever layout tile (<paramref name="x"/>,
    /// <paramref name="y"/>) is cut. With <paramref name="keepLights"/> the node stays and only its
    /// children other than lights hide.</summary>
    public void Track(Node3D node, int x, int y, bool keepLights = false) => Track(node, new[] { (x, y) }, keepLights);

    /// <summary>Hide <paramref name="node"/> whenever any of <paramref name="tiles"/> is cut.</summary>
    public void Track(Node3D node, IEnumerable<(int X, int Y)> tiles, bool keepLights = false)
    {
        var own = tiles.ToArray();
        _tracked.Add((node, own, keepLights));
        if (_map != null && _quadrant >= 0) SetCut(node, keepLights, AnyCut(own, _quadrant));
    }

    /// <summary>False while a wall a tracked prop hangs on is cut; true for anything untracked.</summary>
    public bool IsShown(Node3D node)
    {
        if (_map == null || _quadrant < 0) return true;
        foreach (var (tracked, tiles, _) in _tracked)
            if (tracked == node) return !AnyCut(tiles, _quadrant);
        return true;
    }

    private bool AnyCut((int X, int Y)[] tiles, int quadrant)
    {
        foreach (var (x, y) in tiles)
            if (_map!.IsCut(x, y, quadrant)) return true;
        return false;
    }

    private static void SetCut(Node3D node, bool keepLights, bool cut)
    {
        if (!keepLights)
        {
            node.Visible = !cut;
            return;
        }
        foreach (var child in node.GetChildren())
            if (child is Node3D part && part is not Light3D) part.Visible = !cut;
    }

    /// <summary>The board tiles units stand on now. A pillar on the camera side of one drops to its
    /// stub until the unit moves on.</summary>
    public void SetOccupied(IEnumerable<(int X, int Y)> boardTiles)
    {
        var next = new HashSet<(int X, int Y)>();
        foreach (var (x, y) in boardTiles)
            next.Add((x - Mathf.RoundToInt(_origin.X), y - Mathf.RoundToInt(_origin.Y)));
        if (next.SetEquals(_occupied)) return;
        _occupied.Clear();
        _occupied.UnionWith(next);
        _occupiedChanged = true;
    }

    /// <summary>The pillar tiles dropped to their stub for the units and camera of this frame.</summary>
    public IReadOnlyCollection<(int X, int Y)> OpenPillars => _openPillars;

    /// <summary>World height a board tile's masonry is drawn up to while the cut takes it down this
    /// frame (its stub top, or its foot where it drops away), or null while it stands at full height.</summary>
    public float? CutTopY(int boardX, int boardY)
    {
        if (_map == null || _quadrant < 0) return null;
        int x = boardX - Mathf.RoundToInt(_origin.X), y = boardY - Mathf.RoundToInt(_origin.Y);
        if (x < 0 || y < 0 || x >= _map.Width || y >= _map.Height) return null;
        bool cut = _map.IsCut(x, y, _quadrant) || _openPillars.Contains((x, y));
        return cut ? _map.StubTop(x, y) * _heightScale : null;
    }

    /// <summary>Draw the cut for a camera on the <paramref name="toward"/> side of its subject (a
    /// floor-plane direction, x and z) and stop following the current camera. A cutscene calls this
    /// as each shot starts, with the shot's end pose, so the cut holds through the blend.</summary>
    public void Hold(Vector2 toward)
    {
        if (_map == null) return;
        int quadrant = QuadrantFor(toward.Normalized(), _held ? _quadrant : -1);
        _held = true;
        if (quadrant != _quadrant) Apply(quadrant);
    }

    public override void _Process(double delta)
    {
        if (_map == null) return;
        if (!_held && QuadrantNow() is { } quadrant && quadrant != _quadrant) Apply(quadrant);
        else if (_occupiedChanged) OpenPillarsFor(_quadrant);
    }

    public override void _ExitTree() => Clear();

    private int? QuadrantNow()
    {
        var camera = GetViewport()?.GetCamera3D();
        if (camera == null) return null;
        return QuadrantFor(new Vector2(camera.GlobalBasis.Z.X, camera.GlobalBasis.Z.Z).Normalized(), _quadrant);
    }

    private static int QuadrantFor(Vector2 toward, int previous)
    {
        int quadrant = CutawayMap.Quadrant(toward.X, toward.Y);
        if (previous < 0) return quadrant;
        // Near an axis the camera keeps its side, so the cut does not flicker while a turn or a
        // drag passes the axis.
        if (Mathf.Abs(toward.X) < QuadrantHysteresis) quadrant = (quadrant & ~1) | (previous & 1);
        if (Mathf.Abs(toward.Y) < QuadrantHysteresis) quadrant = (quadrant & ~2) | (previous & 2);
        return quadrant;
    }

    /// <summary>How far past an axis, as the sine of the angle (about 5 degrees), the camera turns
    /// before the cut switches sides.</summary>
    private const float QuadrantHysteresis = 0.09f;

    private void Apply(int quadrant)
    {
        _quadrant = quadrant;
        RenderingServer.GlobalShaderParameterSet(StateGlobal, new Vector4(quadrant, 0f, 0f, 1f));
        if (_map == null) return;
        foreach (var (node, tiles, keepLights) in _tracked)
            if (IsInstanceValid(node)) SetCut(node, keepLights, AnyCut(tiles, quadrant));
        OpenPillarsFor(quadrant);
    }

    /// <summary>Rewrite the pillar texels whose state changed: every quadrant bit on while a unit
    /// stands behind the pillar, off again after.</summary>
    private void OpenPillarsFor(int quadrant)
    {
        _occupiedChanged = false;
        if (_map == null || _image == null || _texture == null) return;
        var next = _map.PillarsInFront(_occupied, quadrant);
        if (next.SetEquals(_openPillars)) return;
        var changed = new HashSet<(int X, int Y)>(next);
        changed.SymmetricExceptWith(_openPillars);
        foreach (var (x, y) in changed)
            _image.SetPixel(x, y, new Color(next.Contains((x, y)) ? AllQuadrants : 0f, _map.StubTop(x, y) * _heightScale, 0f));
        _openPillars = next;
        _texture.Update(_image);
    }

    /// <summary>The red channel with every quadrant bit set.</summary>
    private const float AllQuadrants = 15f;

    /// <summary>The masonry end faces where a cut wall meets a standing one, drawn with the terrain's
    /// wall material so the standing wall ends in brick with its top lip, like any other face.</summary>
    private void AddSeams(CutawayMap map, Vector2 origin, float heightScale, Material? material)
    {
        if (material == null || map.Seams.Count == 0) return;
        var buffer = new MeshBuffer();
        foreach (var seam in map.Seams)
        {
            var (topLeft, topRight, bottomLeft, bottomRight) = LayoutQueries.GetEdgeWorldPositions(
                seam.X, seam.Y, seam.Toward, seam.Top, seam.Top, seam.Bottom, seam.Bottom, heightScale);
            TerrainGeometry.AddWallQuad(buffer, null, topLeft, topRight, bottomRight, bottomLeft);
        }
        var mesh = new MeshInstance3D
        {
            Name = "CutawaySeams",
            Mesh = buffer.ToArrayMesh("cutaway_seams", material),
            Position = new Vector3(origin.X, 0f, origin.Y),
        };
        AddChild(mesh);
        _meshes.Add(mesh);
    }

    /// <summary>One flat quad per cuttable tile of one kind (stub or dropped) at its stub top. The
    /// stub caps show only while cut (their shader checks); the dark floor needs no check, because
    /// a standing wall covers it.</summary>
    private void AddLayer(string name, CutawayMap map, Vector2 origin, Material? material, bool deep,
        System.Func<int, float> height)
    {
        if (material == null) return;
        var buffer = new MeshBuffer(withUv: false, withColor: false);
        for (int y = 0; y < map.Height; y++)
            for (int x = 0; x < map.Width; x++)
            {
                bool cuttable = map.Mask(x, y) != 0 || (!deep && map.IsLowWall(x, y));
                if (!cuttable || map.IsDeep(x, y) != deep) continue;
                float top = height(map.StubTop(x, y));
                TerrainGeometry.AddQuad(buffer, null,
                    new Vector3(x, top, y), new Vector3(x + 1, top, y),
                    new Vector3(x + 1, top, y + 1), new Vector3(x, top, y + 1));
            }
        if (buffer.IsEmpty) return;
        var mesh = new MeshInstance3D
        {
            Name = name,
            Mesh = buffer.ToArrayMesh(name, material),
            Position = new Vector3(origin.X, 0f, origin.Y),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        AddChild(mesh);
        _meshes.Add(mesh);
    }
}
