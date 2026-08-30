using System;
using System.Collections.Generic;
using Delve.Data;
using Godot;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Delve.Terrain;

/// <summary>
/// The board's ground, as one component a scene places in its .tscn. Owns the three pieces that
/// together make a surface to stand on — the generated terrain view, the biome backdrop around it,
/// and the flat placeholder floor a board with no layout falls back to — and exposes the single
/// ordered entry point that builds them, <see cref="Build"/>.
///
///     TerrainStage
///       ├─ PlaceholderFloor  (authored MeshInstance3D, shown only on a flat board)
///       ├─ MapView           (built per encounter, absent on a flat board)
///       └─ Backdrop          (created on first Build, re-applied never duplicated)
///
/// Knows nothing about combat: a hub or overworld scene places the same node and calls the same
/// Build. The host keeps owning its WorldEnvironment and sun and hands them in, because a scene has
/// exactly one of each and they are not the terrain's to create.
/// </summary>
public partial class TerrainStage : Node3D
{
    /// <summary>Name of the per-build terrain view child.</summary>
    private const string MapViewName = "MapView";

    /// <summary>Name of the backdrop child, created once and reused.</summary>
    private const string BackdropName = "Backdrop";

    /// <summary>Default child name of the placeholder floor.</summary>
    private const string DefaultFloorName = "PlaceholderFloor";

    /// <summary>Tree/wall rise, corner units, for a biome the map-gen registry does not know. Equals
    /// the forest biome's own WallHeight, so an unknown id grows a plausible woodland halo instead
    /// of a flat one.</summary>
    private const int FallbackWallHeightUnits = 8;

    /// <summary>
    /// Path (relative to this node) of the flat checker plane shown when <see cref="Build"/> gets no
    /// layout. Authored in the scene with its mesh and material; this node only sizes, places and
    /// shows/hides it. Empty or unresolvable means the stage runs with no placeholder floor.
    /// </summary>
    [Export] public NodePath PlaceholderFloorPath { get; set; } = new(DefaultFloorName);

    /// <summary>Tree prop scenes the halo's tree spots are dressed with (open biomes), and their
    /// pick weights, index for index. Both are wired where the stage is placed; extra scenes with
    /// no matching weight count as weight 1. Left empty (a bare dev stage) the spots go undressed
    /// and the halo is just rolling ground.</summary>
    [Export] public PackedScene[] HaloTreeScenes { get; set; } = Array.Empty<PackedScene>();

    /// <summary>Pick weight per <see cref="HaloTreeScenes"/> entry.</summary>
    [Export] public float[] HaloTreeWeights { get; set; } = Array.Empty<float>();

    /// <summary>Smallest halo ring each <see cref="HaloTreeScenes"/> entry may stand on (entries
    /// past the array's end count as 0 = anywhere). This is what keeps the clearing's edge low:
    /// tall trees close to the board would screen edge units from the camera's pitch floor, so the
    /// forest grows upward as it recedes — brush by the clearing, canopy behind it, giants deep.</summary>
    [Export] public float[] HaloTreeMinRings { get; set; } = Array.Empty<float>();

    /// <summary>Tree prop scenes for the BOARD's own tree-walls (a biome with
    /// <see cref="BackdropThemeDefinition.WallsAreTrees"/>), and their pick weights. Board trees
    /// keep a tight mix — a giant overhanging three tiles of battlefield is scenery, not a tile.</summary>
    [Export] public PackedScene[] BoardTreeScenes { get; set; } = Array.Empty<PackedScene>();

    /// <summary>Pick weight per <see cref="BoardTreeScenes"/> entry.</summary>
    [Export] public float[] BoardTreeWeights { get; set; } = Array.Empty<float>();

    /// <summary>The resolved <see cref="PlaceholderFloorPath"/>, or null when there is none.</summary>
    private MeshInstance3D? _floor;

    /// <summary>Parent of every spawned tree prop (halo scatter and board tree-walls). Rebuilt with
    /// the terrain.</summary>
    private Node3D? _trees;

    /// <summary>The occluder-fade pass over the spawned trees. Created once, reconfigured per build.</summary>
    private TreeFader? _fader;

    /// <summary>Generated terrain for the current build. Null on a flat board.</summary>
    private MapView3D? _mapView;

    /// <summary>Biome atmosphere + far scenery around the board. Created on the first
    /// <see cref="Build"/> and re-applied (never duplicated) on any later one.</summary>
    private Backdrop? _backdrop;

    /// <summary>
    /// The board's surface heights — the one instance every elevation-aware view piece reads.
    /// <see cref="TerrainHeightMap.Flat"/> until a layout is built, which makes both paths run the
    /// same code with all-zero heights.
    /// </summary>
    public TerrainHeightMap HeightMap { get; private set; } = TerrainHeightMap.Flat;

    /// <summary>The layout currently on the stage, or null for a flat board.</summary>
    public MapLayout? Layout { get; private set; }

    /// <summary>The board plus its generated halo — what is actually rendered — or null for a flat
    /// board. The board's tile (x, y) is skirt tile (x + Margin, y + Margin).</summary>
    public SkirtResult? Skirt { get; private set; }

    /// <summary>Heights of <see cref="Skirt"/>, in SKIRT tile coordinates. Scenery standing on the
    /// halo reads this; everything on the board reads <see cref="HeightMap"/>.</summary>
    private TerrainHeightMap _skirtHeights = TerrainHeightMap.Flat;

    public override void _Ready() =>
        _floor = PlaceholderFloorPath.IsEmpty ? null : GetNodeOrNull<MeshInstance3D>(PlaceholderFloorPath);

    /// <summary>
    /// Put a surface under the scene and publish its heights into <see cref="HeightMap"/>. The steps
    /// run in this order because each reads the one before it: theme lookup, terrain mesh + collider,
    /// height map, backdrop (which dresses the ground the terrain just defined), placeholder floor.
    ///
    /// With a layout: the terrain mesh and its trimesh collider are built under this node and the
    /// placeholder floor is hidden. Without one: the flat board — the checker plane is sized to
    /// <paramref name="width"/> x <paramref name="height"/> and centred, the height map is the
    /// all-zeros null object, and the backdrop gets the neutral default theme.
    /// </summary>
    /// <param name="layout">Generated map to render, or null for the flat placeholder board.</param>
    /// <param name="biomeId">Biome whose map + backdrop themes dress the board. Unknown ids fall
    /// back to the default theme with a warning; ignored on a flat board.</param>
    /// <param name="width">Board width in tiles.</param>
    /// <param name="height">Board height in tiles.</param>
    /// <param name="worldEnvironment">The host scene's environment, reconfigured in place.</param>
    /// <param name="sun">The host scene's one directional light, retuned in place.</param>
    public void Build(
        MapLayout? layout,
        string? biomeId,
        int width,
        int height,
        WorldEnvironment worldEnvironment,
        DirectionalLight3D sun)
    {
        Clear();

        // A biome with no theme is a content bug, not a reason to lose the scene — say so loudly and
        // dress the map in the fallback palette. The resolved id also dresses the backdrop, so the
        // halo the skirt style grows and the ground it runs out onto are always the same biome's.
        string id = biomeId ?? MapThemes.Forest.BiomeId;

        if (layout != null)
        {
            if (!MapThemes.TryGet(id, out var theme))
                GD.PushWarning($"[TerrainStage] No map theme for biome '{id}'; using '{theme.BiomeId}'.");

            // The rendered layout is the board plus a halo of synthesized terrain, translated back
            // so the BOARD's tile (0,0) still sits on the world origin: gameplay, camera and input
            // all keep board coordinates and never learn the halo exists.
            var backdrop = BackdropThemes.Get(id);
            var skirt = SkirtLayout.Build(layout, backdrop.Skirt, WallHeightFor(id));

            // A tree biome's Wall tiles become tree spots on the RENDER copy before the mesh is
            // built: the ground flattens, the crate-shaped block disappears, and a billboard tree
            // stands there instead. The gameplay layout keeps its Wall role untouched — the tile
            // still blocks movement and sight.
            var treeWallSpots = backdrop.WallsAreTrees
                ? TreeWalls.Convert(skirt.Layout)
                : new List<(int X, int Y)>();

            var origin = new Vector2(-skirt.Margin, -skirt.Margin);

            _mapView = new MapView3D { Name = MapViewName };
            AddChild(_mapView);
            _mapView.Build(skirt.Layout, theme, new TerrainMeshOptions
            {
                WorldOrigin = origin,
                GridLineRect = new TileRect(skirt.Margin, skirt.Margin, layout.Width, layout.Height),
            });

            Layout = layout;
            Skirt = skirt;
            HeightMap = new TerrainHeightMap(layout, theme.HeightScale);
            _skirtHeights = new TerrainHeightMap(skirt.Layout, theme.HeightScale);

            _fader ??= AddFader();
            _trees = TreeScatter.Build(
                skirt, _skirtHeights, theme.HeightScale, _fader,
                new TreeMix(HaloTreeScenes, HaloTreeWeights, HaloTreeMinRings),
                new TreeMix(BoardTreeScenes, BoardTreeWeights, Array.Empty<float>()),
                treeWallSpots);
            if (_trees != null) AddChild(_trees);
        }

        ApplyBackdrop(layout != null ? id : null, width, height, worldEnvironment, sun);
        ApplyFloor(width, height);
    }

    private TreeFader AddFader()
    {
        var fader = new TreeFader { Name = "TreeFader" };
        AddChild(fader);
        return fader;
    }

    /// <summary>
    /// Drop the built terrain and go back to the flat placeholder board. Idempotent and safe before
    /// the first build. The backdrop node stays — Apply is idempotent and rebuilds its own scenery,
    /// so keeping it is what stops a rebuild from stacking backdrops.
    /// </summary>
    public void Clear()
    {
        if (_mapView != null)
        {
            // Clear first, then free the node: the meshes and the collider go away in the same order
            // a rebuild would replace them.
            _mapView.Clear();
            RemoveChild(_mapView);
            _mapView.QueueFree();
            _mapView = null;
        }

        if (_trees != null)
        {
            RemoveChild(_trees);
            _trees.QueueFree();
            _trees = null;
        }
        _fader?.Configure(default);

        Layout = null;
        Skirt = null;
        HeightMap = TerrainHeightMap.Flat;
        _skirtHeights = TerrainHeightMap.Flat;
        if (_floor != null) _floor.Visible = true;
    }

    /// <summary>
    /// Dress the space around the board: biome sky/fog/sun plus far scenery. Reuses one backdrop
    /// node so a rebuild never stacks backdrops.
    /// </summary>
    private void ApplyBackdrop(
        string? biomeId, int width, int height, WorldEnvironment worldEnvironment, DirectionalLight3D sun)
    {
        if (_backdrop == null)
        {
            _backdrop = new Backdrop { Name = BackdropName };
            AddChild(_backdrop);
        }
        _backdrop.Apply(biomeId, Skirt, _skirtHeights, width, height, worldEnvironment, sun);
    }

    /// <summary>
    /// How far a tree or vault wall rises in the halo: the biome's own <c>WallHeight</c>, so the
    /// synthesized trees match the board's. An id the map-gen registry does not carry is a content
    /// bug — say so and fall back rather than lose the scene.
    /// </summary>
    private static int WallHeightFor(string biomeId)
    {
        try
        {
            return MapGenRegistry.GetBiome(biomeId).WallHeight;
        }
        catch (Exception e) when (e is KeyNotFoundException or ArgumentException)
        {
            GD.PushWarning(
                $"[TerrainStage] No map-gen biome '{biomeId}'; halo walls use {FallbackWallHeightUnits} units.");
            return FallbackWallHeightUnits;
        }
    }

    /// <summary>
    /// Size, place and show the placeholder floor for a flat board; hide it once real terrain is up.
    /// The floor mesh is sized from the board bounds so every dimension renders correctly — grid tile
    /// (x, y) spans world x..x+1 / y..y+1, so a WxH plane sits at the board centre. The checker shader
    /// works in world space and follows automatically.
    /// </summary>
    private void ApplyFloor(int width, int height)
    {
        if (_floor == null) return;

        if (Layout != null)
        {
            _floor.Visible = false;
            return;
        }

        if (_floor.Mesh is PlaneMesh floorPlane)
            floorPlane.Size = new Vector2(width, height);
        _floor.Position = GridSpace.BoardCenter(width, height);
        _floor.Visible = true;
    }
}
