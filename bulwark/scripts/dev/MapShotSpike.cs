using System;
using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Combat.Map;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// RENDERED smoke test for the battle-map view (scenes/dev/map_shot_spike.tscn). Boots a generated
/// map with unit tokens standing on its deployment anchors and slope-conforming move highlights around
/// the party, and captures five frames:
///
///  (a) forest at the default orbit angle — terrain reads, tokens stand ON the ground, highlights
///      follow the slopes rather than floating over or sinking into them;
///  (b) forest at the MINIMUM camera pitch, aimed square at the tallest cliff face on the map — the
///      shot that catches an inverted triangle winding, which shows up as a big black (backface-culled)
///      wall. Arithmetically MapGenSpike already proves the winding; this proves the whole render path.
///      It is also the angle that shows the overlays best: mortar bands down the face, a dark strip
///      along its lip, the lattice across the tops;
///  (c) sewer at the default orbit angle — the second biome, a different palette, and its drainage
///      channel: translucent water with wave-locked skirts where it leaves the map;
///  (d) a riverbank map at the default orbit angle — the only shipped shape that puts a raised bridge
///      over open water. The forest biome weights it at 0, so the spike composes a dev-only biome from
///      the forest tunings plus <c>small_river</c> rather than fishing for a seed that cannot occur;
///  (e) the same map from the water at a low pitch, square onto the bridge — the bridge shot: slab
///      edge, underside, pillars at the bank, water running on under the span;
///  (f) the same map from OUTSIDE the edge the river runs off, low down — the skirt shot: the water
///      cross-section band over stone bedrock, at the same depth as the ground walls beside it.
///
/// Runs windowed, NOT headless (it needs a real rasterizer), which is why it is excluded from the
/// headless spike gate the way CombatShotSpike is:
///   godot --path bulwark res://scenes/dev/map_shot_spike.tscn
/// </summary>
public partial class MapShotSpike : Node3D
{
    /// <summary>Where the PNGs land. Exported so a later run can redirect without editing the file.</summary>
    [Export] public string OutDir { get; set; } =
        @"C:\Users\Midge\AppData\Local\Temp\claude\G--Godot-Gamestorming\456819b1-cb41-4028-ad00-2e684744eae1\scratchpad";

    [Export] public int MapSeed { get; set; } = 20260804;

    /// <summary>Seed for the riverbank shots. 3 lands a wide river with a two-row bridge across it.</summary>
    [Export] public int RiverSeed { get; set; } = 3;

    private static readonly PackedScene UnitTokenScene =
        GD.Load<PackedScene>("res://scenes/combat/unit_token.tscn");

    // Mirrors OrbitCameraRig's defaults so shot (a) frames the map the way the game does.
    private const float DefaultYawDegrees = 45f;
    private const float DefaultPitchDegrees = 50f;
    private const float DefaultDistance = 16f;
    // OrbitCameraRig clamps pitch at 15 degrees; sit just inside it for the worst legal viewing angle.
    private const float LowPitchDegrees = 16f;
    private const float CliffDistance = 8f;
    // Close enough to read a 0.25 m slab edge, high enough to still see the deck.
    private const float BridgePitchDegrees = 22f;
    private const float BridgeDistance = 5.5f;
    // The river map has to fit its own boundary in frame — that is where the water skirts live.
    private const float RiverDistance = 22f;
    // Outside the map looking back in, low enough to see the full cross-section of a skirt.
    private const float SkirtPitchDegrees = 18f;
    private const float SkirtDistance = 7f;
    private const float SkirtPivotDrop = 1.5f;

    /// <summary>
    /// Dev-only biome: the forest tunings with the shipped <c>small_river</c> macro shape as its only
    /// weighted entry. The forest biome carries that shape at weight 0 (Unity's tuning), so no forest
    /// seed can ever produce a river with a bridge over it, and the bridge geometry would otherwise go
    /// un-photographed. Composition only — every field but <c>MacroShapes</c> is the catalogued forest.
    /// </summary>
    private static readonly BiomeDefinition RiverBiome = BuildRiverBiome();

    private Camera3D _camera = null!;
    private MapView3D _mapView = null!;
    private GridOverlay3D _overlay = null!;
    private Node3D _tokenLayer = null!;

    private EnemyDefinition? _enemyDef;
    private TerrainHeightMap _height = TerrainHeightMap.Flat;
    private MapLayout? _layout;

    private double _time;
    private int _step;

    public override void _Ready()
    {
        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[mapshot] DataManager not loaded — aborting.");
            GetTree().Quit(1);
            return;
        }
        _enemyDef = data.ResolveCreature(EncounterTables.GoblinWarrior);

        BuildStaticScene();
        LoadBiome("forest");
        AimDefaultOrbit();
        GD.Print("[mapshot] spike ready");
    }

    public override void _Process(double delta)
    {
        _time += delta;
        switch (_step)
        {
            case 0 when _time > 1.2:
                Capture("mapshot_forest_orbit.png");
                AimAtTallestCliff();
                _step = 1;
                break;

            case 1 when _time > 1.9:
                Capture("mapshot_forest_cliff_lowpitch.png");
                LoadBiome("sewer");
                AimDefaultOrbit();
                _step = 2;
                break;

            case 2 when _time > 2.8:
                Capture("mapshot_sewer_orbit.png");
                LoadRiver();
                AimDefaultOrbit(RiverDistance);
                _step = 3;
                break;

            case 3 when _time > 3.7:
                Capture("mapshot_river_orbit.png");
                AimAtBridge();
                _step = 4;
                break;

            case 4 when _time > 4.4:
                Capture("mapshot_river_bridge.png");
                AimAtWaterEdge();
                _step = 5;
                break;

            case 5 when _time > 5.1:
                Capture("mapshot_river_skirt.png");
                GD.Print("[mapshot] done, quitting");
                GetTree().Quit(0);
                _step = 6;
                break;
        }
    }

    // ─────────────────────────── Scene assembly ───────────────────────────

    /// <summary>The parts that do not change between biomes: light, environment, camera, containers.</summary>
    private void BuildStaticScene()
    {
        // Same lighting/environment values as scenes/combat/combat.tscn, so the shots are representative.
        var env = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Color,
            BackgroundColor = new Color(0.08f, 0.09f, 0.12f),
            AmbientLightSource = Godot.Environment.AmbientSource.Color,
            AmbientLightColor = new Color(0.62f, 0.64f, 0.72f),
            AmbientLightEnergy = 1f,
        };
        AddChild(new WorldEnvironment { Name = "WorldEnvironment", Environment = env });

        var light = new DirectionalLight3D { Name = "Sun", ShadowEnabled = true };
        light.Transform = new Transform3D(
            new Vector3(0.766f, -0.469f, 0.44f),
            new Vector3(0f, 0.685f, 0.729f),
            new Vector3(-0.643f, -0.558f, 0.524f),
            new Vector3(0f, 12f, 0f));
        AddChild(light);

        _mapView = new MapView3D { Name = "MapView" };
        AddChild(_mapView);

        _overlay = new GridOverlay3D { Name = "GridOverlay" };
        AddChild(_overlay);

        _tokenLayer = new Node3D { Name = "Tokens" };
        AddChild(_tokenLayer);

        _camera = new Camera3D { Name = "Camera3D", Current = true };
        AddChild(_camera);
    }

    /// <summary>Generate a catalogued biome, rebuild the terrain, and repopulate tokens + highlights.</summary>
    private void LoadBiome(string biomeId) =>
        Show(MapGenerator.GenerateValidated(biomeId, MapSeed), biomeId, biomeId);

    /// <summary>Generate the dev riverbank map, dressed in the forest theme.</summary>
    private void LoadRiver() =>
        Show(MapGenerator.Generate(RiverBiome, null, RiverSeed), "forest", "river");

    /// <summary>Rebuild the terrain, heightmap, tokens and highlights for one layout.</summary>
    private void Show(MapLayout? layout, string themeId, string label)
    {
        _layout = layout;
        if (_layout == null)
        {
            GD.PushError($"[mapshot] could not generate '{label}'.");
            return;
        }

        var theme = MapThemes.Get(themeId);
        _mapView.Build(_layout, theme);
        _height = new TerrainHeightMap(_layout, theme.HeightScale);
        _overlay.SetHeightMap(_height);

        var party = DeploymentPlanner.GetAnchors(_layout, teamId: 0, count: 4);
        var foes = DeploymentPlanner.GetAnchors(_layout, teamId: 1, count: 3);
        SpawnTokens(party, foes);
        HighlightAround(party);

        GD.Print($"[mapshot] {label} {_layout.Width}x{_layout.Height} seed {_layout.Seed}, "
                 + $"surfaces={_mapView.SurfaceCount}, meanY={_height.MeanCenterY:F2}, "
                 + $"anchors={party.Count}/{foes.Count}");
    }

    /// <summary>Forest tunings, small_river as the only weighted shape. See <see cref="RiverBiome"/>.</summary>
    private static BiomeDefinition BuildRiverBiome()
    {
        var forest = BiomeCatalog.All["forest"];
        return new BiomeDefinition
        {
            Id = forest.Id,
            BiomeName = "Riverbank",
            WallHeight = forest.WallHeight,
            CoverHeight = forest.CoverHeight,
            CliffThreshold = forest.CliffThreshold,
            MaxElevation = forest.MaxElevation,
            MinSize = forest.MinSize,
            MaxSize = forest.MaxSize,
            DefaultGroundSurface = forest.DefaultGroundSurface,
            DefaultDifficultSurface = forest.DefaultDifficultSurface,
            DefaultCoverSurface = forest.DefaultCoverSurface,
            DefaultWallSurface = forest.DefaultWallSurface,
            MinFeatures = forest.MinFeatures,
            MaxFeatures = forest.MaxFeatures,
            DefaultParams = forest.DefaultParams,
            MacroShapes = new[]
            {
                new MacroShapeEntry { Shape = MacroShapeCatalog.All["small_river"], Weight = 1f },
            },
            AvailableSetpieces = forest.AvailableSetpieces,
            AvailableDebrisPatches = forest.AvailableDebrisPatches,
            ForcedSetpieces = forest.ForcedSetpieces,
            OnlyForcedSetpieces = forest.OnlyForcedSetpieces,
        };
    }

    private void SpawnTokens(List<PF2eVec> party, List<PF2eVec> foes)
    {
        foreach (var child in _tokenLayer.GetChildren())
        {
            _tokenLayer.RemoveChild(child);
            child.QueueFree();
        }

        var heroes = new ICharacter[]
        {
            PresetCharacters.BuildPlayer(level: GameState.SquadStartLevel, teamId: 1),
            PresetCharacters.BuildScout(level: GameState.SquadStartLevel, teamId: 1),
            PresetCharacters.BuildTharr(level: GameState.SquadStartLevel, teamId: 1),
            PresetCharacters.BuildScholar(level: GameState.SquadStartLevel, teamId: 1),
        };

        for (int i = 0; i < party.Count && i < heroes.Length; i++)
            AddToken(heroes[i], party[i]);

        if (_enemyDef == null) return;
        foreach (var anchor in foes)
            AddToken(CreatureFactory.Create(_enemyDef, teamId: 2), anchor);
    }

    private void AddToken(ICharacter character, PF2eVec tile)
    {
        string? enemyFolder = character.CreatureStats != null
            ? EnemySpriteMap.FolderForCreature(character.Name)
            : null;

        var visual = UnitTokenScene.Instantiate<UnitVisual3D>();
        visual.Configure(character, enemyFolder);
        // The line under test: a token's feet must land exactly on the tile's surface.
        visual.Position = GridSpace.GridToWorld(tile, _height);
        _tokenLayer.AddChild(visual);
        visual.SetCamera(_camera);
    }

    /// <summary>Move highlights over every walkable tile within 3 of the first party anchor.</summary>
    private void HighlightAround(List<PF2eVec> party)
    {
        var tiles = new List<PF2eVec>();
        if (_layout != null && party.Count > 0)
        {
            var origin = party[0];
            for (int dy = -3; dy <= 3; dy++)
            {
                for (int dx = -3; dx <= 3; dx++)
                {
                    var t = new PF2eVec(origin.x + dx, origin.y + dy);
                    if (_layout.IsInBounds(t.x, t.y) && _layout.IsWalkable(t.x, t.y))
                        tiles.Add(t);
                }
            }
        }
        _overlay.SetHighlights(tiles, HighlightKind.Move);
    }

    // ─────────────────────────── Camera ───────────────────────────

    private void AimDefaultOrbit(float distance = DefaultDistance)
    {
        if (_layout == null) return;
        var pivot = GridSpace.BoardCenter(_layout.Width, _layout.Height, _height);
        PlaceCamera(pivot, DefaultYawDegrees, DefaultPitchDegrees, distance);
    }

    /// <summary>
    /// Frame a water tile that runs off the edge of the map, from outside that edge and low down: the
    /// deep-edge skirt is a vertical cross-section, so it is invisible from above and backfacing from
    /// three of the four sides. Pivot drops below the surface to put the whole band in frame.
    /// </summary>
    private void AimAtWaterEdge()
    {
        if (_layout == null) return;

        for (int y = 0; y < _layout.Height; y++)
        {
            for (int x = 0; x < _layout.Width; x++)
            {
                if (_layout.GetTile(x, y) != TileRole.Water) continue;

                (int ox, int oz) =
                    x == 0 ? (-1, 0)
                    : x == _layout.Width - 1 ? (1, 0)
                    : y == 0 ? (0, -1)
                    : y == _layout.Height - 1 ? (0, 1)
                    : (0, 0);
                if (ox == 0 && oz == 0) continue;

                var pivot = GridSpace.GridToWorld(new PF2eVec(x, y), _height);
                pivot.Y -= SkirtPivotDrop;
                float yaw = Mathf.RadToDeg(Mathf.Atan2(ox, oz));
                GD.Print($"[mapshot] water leaves the map at ({x},{y}), yaw {yaw:F0}");
                PlaceCamera(pivot, yaw, SkirtPitchDegrees, SkirtDistance);
                return;
            }
        }

        GD.Print("[mapshot] no water at the map edge; keeping the previous angle for shot (f)");
    }

    /// <summary>
    /// Frame the biggest cliff on the map from its LOW side at the minimum legal pitch: pivot on the
    /// high tile, camera out over the low neighbour. That is the angle at which a back-facing wall
    /// triangle would render as a black hole, so it is the one worth photographing.
    /// </summary>
    private void AimAtTallestCliff()
    {
        if (_layout == null) return;

        int bestDrop = 0;
        PF2eVec high = default;
        PF2eVec low = default;

        // Skip the outermost ring: a cliff on the map edge puts the camera outside the map and half the
        // frame becomes empty background, which photographs nothing.
        for (int y = 1; y < _layout.Height - 1; y++)
        {
            for (int x = 1; x < _layout.Width - 1; x++)
            {
                if (_layout.GetTile(x, y) == TileRole.Empty) continue;
                var corners = _layout.GetCornerHeights(x, y);

                foreach (var dir in new[]
                         {
                             CardinalDirection.North, CardinalDirection.East,
                             CardinalDirection.South, CardinalDirection.West,
                         })
                {
                    (int nx, int ny) = dir switch
                    {
                        CardinalDirection.North => (x, y + 1),
                        CardinalDirection.South => (x, y - 1),
                        CardinalDirection.East => (x + 1, y),
                        _ => (x - 1, y),
                    };
                    // The viewpoint has to be somewhere a creature could stand, so require walkable.
                    if (!_layout.IsInBounds(nx, ny) || !_layout.IsWalkable(nx, ny)) continue;

                    int drop = corners.MinHeight - _layout.GetCornerHeights(nx, ny).MaxHeight;
                    if (drop <= bestDrop) continue;

                    bestDrop = drop;
                    high = new PF2eVec(x, y);
                    low = new PF2eVec(nx, ny);
                }
            }
        }

        if (bestDrop == 0)
        {
            GD.Print("[mapshot] no cliff found; keeping the default angle for shot (b)");
            return;
        }

        var pivot = GridSpace.GridToWorld(high, _height);
        // Yaw that puts the camera on the low side: the rig's offset direction is (sin yaw, ., cos yaw).
        float yaw = Mathf.RadToDeg(Mathf.Atan2(low.x - high.x, low.y - high.y));
        GD.Print($"[mapshot] tallest cliff: ({high.x},{high.y}) over ({low.x},{low.y}), "
                 + $"{bestDrop} corner units, yaw {yaw:F0}");
        PlaceCamera(pivot, yaw, LowPitchDegrees, CliffDistance);
    }

    /// <summary>
    /// Frame the bridge from the water: pivot on the bridge tile with the most water around it, camera
    /// out over one of those water neighbours at a low pitch. That is the only angle from which the
    /// slab side face, the underside and the bank pillars are all visible at once.
    /// </summary>
    private void AimAtBridge()
    {
        if (_layout == null) return;

        int mostWater = 0;
        PF2eVec bridge = default;
        PF2eVec water = default;

        for (int y = 0; y < _layout.Height; y++)
        {
            for (int x = 0; x < _layout.Width; x++)
            {
                if (_layout.GetTile(x, y) != TileRole.Bridge) continue;

                int count = 0;
                PF2eVec firstWater = default;
                foreach (var (dx, dy) in new[] { (0, 1), (1, 0), (0, -1), (-1, 0) })
                {
                    int nx = x + dx, ny = y + dy;
                    if (!_layout.IsInBounds(nx, ny) || _layout.GetTile(nx, ny) != TileRole.Water) continue;
                    if (count == 0) firstWater = new PF2eVec(nx, ny);
                    count++;
                }

                if (count <= mostWater) continue;
                mostWater = count;
                bridge = new PF2eVec(x, y);
                water = firstWater;
            }
        }

        if (mostWater == 0)
        {
            GD.Print("[mapshot] no bridge over water on this map; keeping the default angle for shot (e)");
            return;
        }

        var pivot = GridSpace.GridToWorld(bridge, _height);
        float yaw = Mathf.RadToDeg(Mathf.Atan2(water.x - bridge.x, water.y - bridge.y));
        GD.Print($"[mapshot] bridge at ({bridge.x},{bridge.y}) with {mostWater} water neighbours, yaw {yaw:F0}");
        PlaceCamera(pivot, yaw, BridgePitchDegrees, BridgeDistance);
    }

    /// <summary>Same pose math as <see cref="OrbitCameraRig"/>: orbit the pivot at (yaw, pitch, distance).</summary>
    private void PlaceCamera(Vector3 pivot, float yawDegrees, float pitchDegrees, float distance)
    {
        float pitch = Mathf.DegToRad(pitchDegrees);
        float yaw = Mathf.DegToRad(yawDegrees);
        float horizontal = distance * Mathf.Cos(pitch);

        _camera.Position = pivot + new Vector3(
            horizontal * Mathf.Sin(yaw),
            distance * Mathf.Sin(pitch),
            horizontal * Mathf.Cos(yaw));
        _camera.LookAt(pivot, Vector3.Up);
    }

    // ─────────────────────────── Capture ───────────────────────────

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        Error err = img.SavePng(System.IO.Path.Combine(OutDir, file));
        GD.Print($"[mapshot] saved {file} ({err})");
    }
}
