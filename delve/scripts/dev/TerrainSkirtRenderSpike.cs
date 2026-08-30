using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;

namespace Delve.Dev;

/// <summary>
/// Headless proof that a <see cref="TerrainStage"/> RENDERS the generated skirt, where
/// <c>terrain_skirt_spike</c> proves only that the skirt layout is well formed. Builds a real stage
/// per biome x seed and asserts on the scene it produced:
///
///  (a) Placement  — one MapView carrying a terrain mesh and a collider, translated by exactly
///                   -Margin on X and Z, so the board's tile (0,0) is still the world origin.
///  (b) Gameplay   — the stage publishes the BOARD's height map, not the skirt's: a unit stands
///                   where it stood before the halo existed.
///  (c) Grid lines — the top-surface lattice covers the board and nothing else. Asserted as an
///                   exact vertex count against a board-only build of the same layout: any line
///                   leaking onto the halo, or any board line lost, moves that number.
///  (d) Decor      — the tile scatter reaches past the board on all four sides, so the halo is
///                   dressed ground rather than bare colour.
///  (e) Ground     — the matte surround the halo rim runs out onto is there.
///  (f) Removed    — nothing named after the old prop-based apron survives anywhere in the stage.
/// </summary>
public partial class TerrainSkirtRenderSpike : SpikeBase
{
    private static readonly int[] Seeds = { 7, 137, 404, 4711, 20260804 };

    private static readonly string[] Biomes = { "forest", "sewer" };

    /// <summary>Node names the old prop apron built. None of them may exist any more.</summary>
    private static readonly string[] RetiredNodes =
    {
        "EdgeScenery", "Apron", "ApronWater", "Forest", "Perimeter", "GroundPlane",
    };

    /// <summary>Resource name of the grid-line overlay material (see <see cref="MapMaterials"/>).</summary>
    private const string GridLineMaterial = "terrain_grid_line";

    protected override string Banner => "================= TERRAIN SKIRT RENDER SPIKE =================";

    protected override Task RunSpikeAsync(DataManager data)
    {
        int stages = 0;
        var defects = new Dictionary<string, int>();

        foreach (string biome in Biomes)
        {
            GD.Print($"-------------------- {biome} --------------------");

            foreach (int seed in Seeds)
            {
                var board = MapGenerator.GenerateValidated(biome, seed);
                if (board == null)
                {
                    Check($"{biome} seed {seed}: GenerateValidated produced a map", false);
                    continue;
                }

                var host = BuildStage(board, biome, out var stage);
                stages++;

                CheckStage(stage, board, biome, defects);
                GD.Print($"        · seed {seed}: board {board.Width}x{board.Height}, "
                         + $"margin {stage.Skirt?.Margin}, MapView at {stage.GetNode<Node3D>("MapView").Position}");

                host.QueueFree();
            }
        }

        Check($"{stages} stages built over {Biomes.Length} biomes", stages == Biomes.Length * Seeds.Length);
        Check("(a) the MapView holds a terrain mesh and a collider", Clean(defects, "mesh"));
        Check("(a) the MapView is translated by -Margin on X and Z", Clean(defects, "offset"));
        Check("(b) the published height map is the board's, not the skirt's", Clean(defects, "heights"));
        Check("(c) grid lines cover the board exactly, halo included in neither", Clean(defects, "gridlines"));
        Check("(d) tile decor reaches past the board on all four sides", Clean(defects, "decor"));
        Check("(e) the ground surround is built", Clean(defects, "ground"));
        Check("(f) no node of the retired prop apron survives", Clean(defects, "retired"));

        return Task.CompletedTask;
    }

    // ─────────────────────────── the stage under test ───────────────────────────

    /// <summary>
    /// A live TerrainStage for one map, with the environment and sun a host scene would own. Returns
    /// the host so the caller can free the whole subtree when it is done reading it.
    /// </summary>
    private Node3D BuildStage(MapLayout board, string biome, out TerrainStage stage)
    {
        var host = new Node3D { Name = "SkirtRenderHost" };
        var environment = new WorldEnvironment { Environment = new Godot.Environment() };
        var sun = new DirectionalLight3D();
        stage = new TerrainStage { Name = "TerrainStage", PlaceholderFloorPath = new NodePath() };
        DevTreeMix.Apply(stage);

        host.AddChild(environment);
        host.AddChild(sun);
        host.AddChild(stage);
        AddChild(host);

        stage.Build(board, biome, board.Width, board.Height, environment, sun);
        return host;
    }

    private static void CheckStage(
        TerrainStage stage, MapLayout board, string biome, Dictionary<string, int> defects)
    {
        int margin = stage.Skirt?.Margin ?? 0;
        var view = stage.GetNodeOrNull<Node3D>("MapView");
        var terrain = view?.GetNodeOrNull<MeshInstance3D>("Terrain");

        if (view == null || terrain?.Mesh == null || view.GetNodeOrNull<Node3D>("TerrainBody") == null)
        {
            Add(defects, "mesh");
            return;
        }

        if (margin <= 0 || !view.Position.IsEqualApprox(new Vector3(-margin, 0f, -margin)))
            Add(defects, "offset");

        CheckHeights(stage, board, defects);
        CheckGridLines((ArrayMesh)terrain.Mesh, board, biome, defects);
        CheckDecor(stage, board, margin, defects);

        if (stage.GetNodeOrNull<Node3D>("Backdrop/GroundSurround") == null) Add(defects, "ground");

        foreach (string name in RetiredNodes)
            if (stage.FindChild(name, recursive: true, owned: false) != null)
                Add(defects, "retired");
    }

    /// <summary>The stage's height map must answer in BOARD tiles: sample every one of them.</summary>
    private static void CheckHeights(TerrainStage stage, MapLayout board, Dictionary<string, int> defects)
    {
        for (int y = 0; y < board.Height; y++)
        {
            for (int x = 0; x < board.Width; x++)
            {
                var expected = board.GetCornerHeights(x, y);
                var got = stage.HeightMap.Corners(new PF2e.Vector2Int(x, y));
                if (got.NW != expected.NW || got.NE != expected.NE
                    || got.SE != expected.SE || got.SW != expected.SW)
                {
                    Add(defects, "heights");
                    return;
                }
            }
        }
    }

    /// <summary>
    /// The rendered lattice against the one a board-only build emits. Vertex count is the robust
    /// signal: the two meshes share no coordinates (the skirted one is offset by the margin) but
    /// must draw the same strips, so any halo tile that gained lines — or any board tile that lost
    /// them — shows up as a different total.
    /// </summary>
    private static void CheckGridLines(
        ArrayMesh skirted, MapLayout board, string biome, Dictionary<string, int> defects)
    {
        var boardOnly = TerrainMeshBuilder.Build(board, MapThemes.Get(biome)).Visual;
        if (GridLineVertices(skirted) != GridLineVertices(boardOnly)) Add(defects, "gridlines");
    }

    /// <summary>Vertices across every surface carrying the grid-line overlay material.</summary>
    private static int GridLineVertices(ArrayMesh mesh)
    {
        int total = 0;
        for (int i = 0; i < mesh.GetSurfaceCount(); i++)
            if (mesh.SurfaceGetMaterial(i)?.ResourceName == GridLineMaterial)
                total += mesh.SurfaceGetArrayLen(i);
        return total;
    }

    /// <summary>
    /// Decor over the halo: sprites must appear beyond the board's footprint on every side. Positions
    /// are read in world space, where the board occupies 0..Width by 0..Height.
    /// </summary>
    private static void CheckDecor(
        TerrainStage stage, MapLayout board, int margin, Dictionary<string, int> defects)
    {
        var decor = stage.GetNodeOrNull<Node3D>("Backdrop/TileDecor");
        if (decor == null || margin <= 0) return;   // a theme with no decor set builds none

        bool west = false, east = false, south = false, north = false;
        foreach (var child in decor.GetChildren())
        {
            if (child is not Node3D sprite) continue;
            Vector3 p = decor.Position + sprite.Position;
            west |= p.X < 0f;
            east |= p.X > board.Width;
            south |= p.Z < 0f;
            north |= p.Z > board.Height;
        }

        if (decor.GetChildCount() > 0 && !(west && east && south && north)) Add(defects, "decor");
    }

    // ─────────────────────────── defect tally ───────────────────────────

    private static void Add(Dictionary<string, int> defects, string tag) =>
        defects[tag] = defects.GetValueOrDefault(tag) + 1;

    private static bool Clean(Dictionary<string, int> defects, string tag)
    {
        if (!defects.TryGetValue(tag, out int n)) return true;
        GD.Print($"        ! {tag}: {n} defect(s)");
        return false;
    }
}
