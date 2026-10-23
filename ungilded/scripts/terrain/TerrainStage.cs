using System;
using System.Collections.Generic;
using Ungilded.Data;
using Ungilded.Look;
using Godot;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;

namespace Ungilded.Terrain;

/// <summary>
/// The board's ground, as one component a scene places in its .tscn. Owns the three pieces that
/// together make a surface to stand on — the generated terrain view, the biome backdrop around it,
/// and the flat placeholder floor a board with no layout falls back to — and exposes the single
/// ordered entry point that builds them, <see cref="Build"/>.
///
///     TerrainStage
///       ├─ PlaceholderFloor  (authored MeshInstance3D, shown only on a flat board)
///       ├─ MapView           (built per encounter, absent on a flat board)
///       ├─ Backdrop          (created on first Build, re-applied never duplicated)
///       └─ Look              (the biome's LookScene, swapped when the biome changes)
///
/// Knows nothing about combat: a hub or overworld scene places the same node and calls the same
/// Build. The biome's lighting setup (<see cref="LookScene"/>) is instanced here too, because the
/// biome id that picks it arrives with the build.
/// </summary>
public partial class TerrainStage : Node3D
{
    [Export] public Shader? OutskirtsMistShader { get; set; }

    /// <summary>Lighting setup per biome id. A biome with no entry gets <see cref="DefaultLook"/>.</summary>
    [Export] public Godot.Collections.Dictionary<string, PackedScene> Looks { get; set; } = new();

    /// <summary>Lighting setup for the flat board and any biome without its own.</summary>
    [Export] public PackedScene? DefaultLook { get; set; }

    private LookScene? _look;
    private PackedScene? _lookSource;

    /// <summary>The lighting setup the last build instanced, or null before the first build.</summary>
    public LookScene? Look => _look;
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

    /// <summary>The wall cutaway (a biome with <see cref="BackdropThemeDefinition.Cutaway"/>).
    /// Created on first use, reconfigured per build, switched off by <see cref="Clear"/>.</summary>
    private TerrainCutaway? _cutaway;

    /// <summary>The wall cutaway of the current build, or null when the biome has none.</summary>
    public TerrainCutaway? Cutaway => _cutaway?.Map != null ? _cutaway : null;

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
    /// <param name="halo">The board's authored halo, or null to let the biome synthesize one.</param>
    public void Build(MapLayout? layout, string? biomeId, int width, int height, HaloPlan? halo = null)
    {
        Clear();

        // A biome with no theme is a content bug, not a reason to lose the scene — say so loudly and
        // dress the map in the fallback palette. The resolved id also dresses the backdrop, so the
        // halo the skirt style grows and the ground it runs out onto are always the same biome's.
        string id = biomeId ?? MapThemes.Forest.BiomeId;
        // First, so halo scenery below can take the look's shading.
        ApplyLook(layout != null ? id : null, width, height);

        if (layout != null)
        {
            if (!MapThemes.TryGet(id, out var theme))
                GD.PushWarning($"[TerrainStage] No map theme for biome '{id}'; using '{theme.BiomeId}'.");

            // The rendered layout is the board plus a halo of synthesized terrain, translated back
            // so the BOARD's tile (0,0) still sits on the world origin: gameplay, camera and input
            // all keep board coordinates and never learn the halo exists.
            var backdrop = BackdropThemes.Get(id);
            int wallHeight = WallHeightFor(id);
            var skirt = SkirtLayout.Build(layout, backdrop.Skirt, wallHeight, halo);

            // A tree biome's Wall tiles become tree spots on the RENDER copy before the mesh is
            // built: the ground flattens, the crate-shaped block disappears, and a billboard tree
            // stands there instead. The gameplay layout keeps its Wall role untouched — the tile
            // still blocks movement and sight.
            var treeWallSpots = backdrop.WallsAreTrees
                ? TreeWalls.Convert(skirt.Layout)
                : new List<(int X, int Y)>();

            var origin = new Vector2(-skirt.Margin, -skirt.Margin);
            var boardRect = new TileRect(skirt.Margin, skirt.Margin, layout.Width, layout.Height);
            var cutaway = backdrop.Cutaway ? CutawayMap.Build(skirt.Layout, wallHeight, boardRect) : null;

            // Board y runs along world z.
            var (fx, fy) = halo?.Flow ?? default;
            var flow = new Vector2(fx, fy);

            _mapView = new MapView3D { Name = MapViewName };
            AddChild(_mapView);
            _mapView.Build(skirt.Layout, theme, new TerrainMeshOptions
            {
                WorldOrigin = origin,
                GridLineRect = boardRect,
                WaterFlow = flow * (_look?.WaterFlowSpeed ?? 0f),
                SludgeFlow = flow * (_look?.SludgeFlowSpeed ?? 0f),
            }, cutaway?.PickLayout(skirt.Layout));
            if (cutaway != null) ApplyCutaway(cutaway, origin, theme, backdrop);

            Layout = layout;
            Skirt = skirt;
            HeightMap = new TerrainHeightMap(layout, theme.HeightScale);
            _skirtHeights = new TerrainHeightMap(skirt.Layout, theme.HeightScale);

            _fader ??= AddFader();
            _trees = TreeScatter.Build(
                skirt, _skirtHeights, theme.HeightScale, _fader,
                new TreeMix(HaloTreeScenes, HaloTreeWeights, HaloTreeMinRings),
                new TreeMix(BoardTreeScenes, BoardTreeWeights, Array.Empty<float>()),
                treeWallSpots,
                _look == null ? null : ring => _look.HaloShade(ring));
            if (_trees != null) AddChild(_trees);

            _look?.Dress(new DressingContext(layout, skirt, _skirtHeights, theme.HeightScale,
                cutaway != null ? _cutaway : null));
        }

        ApplyBackdrop(layout != null ? id : null, width, height);
        ApplyFloor(width, height);
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
        _cutaway?.Clear();
        _look?.Undress();

        Layout = null;
        Skirt = null;
        HeightMap = TerrainHeightMap.Flat;
        _skirtHeights = TerrainHeightMap.Flat;
        if (_floor != null) _floor.Visible = true;
    }

}
