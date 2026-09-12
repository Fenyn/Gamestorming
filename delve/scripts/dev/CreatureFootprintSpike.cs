using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>Regression coverage for footprint centers, independent ring geometry, and asymmetric art anchors.</summary>
public partial class CreatureFootprintSpike : SpikeBase
{
    [Export] public PackedScene TokenScene { get; set; } = null!;
    [Export] public EnemySpriteDefinition MonitorSprite { get; set; } = null!;
    [Export] public EnemySpriteDefinition BeetleSprite { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        CheckTerrainCenters();
        await CheckRings();
        CheckSpriteAnchor("monitor", MonitorSprite, 80.5f, 0.018f);
        CheckSpriteAnchor("beetle", BeetleSprite, 42.5f, 0.025f);
        await CheckLargeCreatureMovement(data);
    }

    private void CheckTerrainCenters()
    {
        var anchor = new PF2eVec(2, 3);
        var expected = new[] { new Vector3(2.5f, 0, 3.5f), new Vector3(3, 0, 4),
            new Vector3(3.5f, 0, 4.5f), new Vector3(4, 0, 5) };
        for (int width = 1; width <= 4; width++)
            Check($"width {width} centers over all occupied tiles",
                GridSpace.CreatureToWorld(anchor, width, TerrainHeightMap.Flat).IsEqualApprox(expected[width - 1]));

        var layout = FlatLayout();
        for (int width = 2; width <= 4; width++)
        {
            for (int y = 0; y < 8; y++)
                for (int x = 0; x < 8; x++) layout.SetCornerHeights(x, y, TileCornerHeights.Flat(8));
            var low = new PF2eVec(anchor.x + width - 1, anchor.y + width - 1);
            layout.SetCornerHeights(low.x, low.y, TileCornerHeights.Flat(-4));
            var heights = new TerrainHeightMap(layout, 0.25f);
            Check($"width {width} uses the lowest occupied tile even away from its center",
                Mathf.IsEqualApprox(heights.FootprintCenterY(anchor, width), -1f));
            Check($"width {width} body stands on its low supporting tile",
                GridSpace.CreatureBodyToWorld(anchor, width, heights)
                    .IsEqualApprox(new Vector3(low.x + 0.5f, -1, low.y + 0.5f)));
            var mesh = TerrainFootprintMesh.Build(anchor, width, heights);
            var vertices = mesh.SurfaceGetArrays(0)[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            Check($"width {width} marks every tile at its own elevation",
                vertices.Length == width * width * 4
                && Mathf.IsEqualApprox(vertices[0].Y, 2f + HighlightMeshes.SurfaceY)
                && Mathf.IsEqualApprox(vertices[^1].Y, -1f + HighlightMeshes.SurfaceY));
        }
        layout = FlatLayout();
        layout.SetCornerHeights(3, 4, TileCornerHeights.Flat(8));
        var island = new TerrainHeightMap(layout, 0.25f);
        var body = GridSpace.CreatureBodyToWorld(anchor, 3, island);
        Check("low-tile centroid cannot place body inside a raised island",
            Mathf.IsZeroApprox(island.CenterY(GridSpace.WorldToGrid(body))) && Mathf.IsZeroApprox(body.Y));
        layout.SetCornerHeights(2, 3, new TileCornerHeights { NW = 0, NE = 4, SE = 8, SW = 12 });
        Check("one-tile slope keeps its center height", Mathf.IsEqualApprox(island.FootprintCenterY(anchor, 1), 1.5f));
    }

    private async Task CheckRings()
    {
        var sharedMesh = new CylinderMesh { TopRadius = 0.42f, BottomRadius = 0.42f, Height = 0.02f };
        var rings = new List<TeamRing>();
        for (int width = 1; width <= 4; width++)
        {
            var ring = new TeamRing { Mesh = sharedMesh };
            AddChild(ring);
            ring.SetTeamColor(Colors.Red);
            ring.SetFootprint(width);
            rings.Add(ring);
            Check($"width {width} ring has independent footprint geometry",
                ring.Mesh != sharedMesh && ring.Mesh is CylinderMesh cylinder
                && Mathf.IsEqualApprox(cylinder.TopRadius, 0.42f * width)
                && Mathf.IsEqualApprox(cylinder.BottomRadius, 0.42f * width));
            ring.SetActive(true);
        }
        Check("sizing instances does not resize the shared scene mesh",
            Mathf.IsEqualApprox(sharedMesh.TopRadius, 0.42f));
        await ToSignal(GetTree().CreateTimer(0.32), SceneTreeTimer.SignalName.Timeout);
        for (int i = 0; i < rings.Count; i++)
        {
            var ring = rings[i];
            Check($"width {i + 1} turn pulse preserves its base radius",
                ring.Scale.X > 1f && Mathf.IsEqualApprox(((CylinderMesh)ring.Mesh).TopRadius, 0.42f * (i + 1)));
            ring.SetActive(false);
        }
        await ToSignal(GetTree().CreateTimer(0.3), SceneTreeTimer.SignalName.Timeout);
        for (int i = 0; i < rings.Count; i++)
        {
            Check($"width {i + 1} deactivation restores scale without shrinking footprint",
                rings[i].Scale.IsEqualApprox(Vector3.One)
                && Mathf.IsEqualApprox(((CylinderMesh)rings[i].Mesh).BottomRadius, 0.42f * (i + 1)));
            rings[i].QueueFree();
        }
    }

    private void CheckSpriteAnchor(string name, EnemySpriteDefinition definition, float anchor, float pixelSize)
    {
        var sprite = new BillboardSpriteAnimator();
        AddChild(sprite);
        sprite.ConfigureEnemy(definition);
        sprite.SetProcess(false);
        Check($"{name} retains its authored contact anchor and pixel scale",
            Mathf.IsEqualApprox(definition.GroundAnchorX, anchor) && Mathf.IsEqualApprox(sprite.PixelSize, pixelSize));
        float halfWidth = sprite.Texture.GetWidth() * 0.5f;
        float rightOffset = 0;
        foreach (bool flipped in new[] { false, true })
        {
            sprite.Facing = flipped ? Vector2.Left : Vector2.Right;
            sprite.ApplyFacing();
            // Reconstruct where the authored contact point actually lands on the billboard quad.
            float contactX = (flipped ? halfWidth - anchor : anchor - halfWidth) + sprite.Offset.X;
            Check($"{name} {(flipped ? "flipped" : "unflipped")} contact lands on root origin",
                sprite.FlipH == flipped && Mathf.IsZeroApprox(contactX * pixelSize));
            if (!flipped) rightOffset = sprite.Offset.X;
            else Check($"{name} reverses its horizontal offset when flipped",
                Mathf.IsEqualApprox(sprite.Offset.X, -rightOffset));
        }
        using var image = sprite.Texture.GetImage();
        var bounds = image.GetUsedRect();
        float canvasHeight = (sprite.Texture.GetHeight() - definition.FootMarginPixels) * pixelSize;
        Check($"{name} HP reference excludes transparent headroom",
            bounds.Position.Y > 0 && sprite.BodyHeight < canvasHeight
            && Mathf.IsEqualApprox(sprite.BodyHeight, bounds.Size.Y * pixelSize));
        float footY = sprite.Position.Y + (definition.FootMarginPixels - sprite.Texture.GetHeight() * 0.5f) * pixelSize;
        Check($"{name} contact row is at ground height", Mathf.IsZeroApprox(footY));
        float bodyHeight = sprite.BodyHeight;
        sprite.PlayAttack(out _);
        sprite._Process(0.19);
        Check($"{name} attack holds HP reference height", Mathf.IsEqualApprox(sprite.BodyHeight, bodyHeight));
        sprite.QueueFree();
    }

    private async Task CheckLargeCreatureMovement(DataManager data)
    {
        var definition = data.ResolveCreature(new CreatureRef
        {
            DisplayName = "Giant Stag Beetle", Pack = "pathfinder-monster-core", Slug = "giant-stag-beetle",
        });
        Check("real Giant Stag Beetle pack entry loads", definition != null);
        if (definition == null) return;
        var creature = CreatureFactory.Create(definition, teamId: 2);
        Check("real beetle occupies a Large two-tile footprint", creature.TileWidth == 2 && creature.CreatureStats.Size == CreatureSize.Large);
        creature.GridPosition = new PF2eVec(1, 1);
        var layout = FlatLayout();
        layout.SetCornerHeights(1, 1, TileCornerHeights.Flat(2));
        layout.SetCornerHeights(2, 1, TileCornerHeights.Flat(4));
        layout.SetCornerHeights(1, 2, TileCornerHeights.Flat(6));
        layout.SetCornerHeights(2, 2, TileCornerHeights.Flat(8));
        layout.SetCornerHeights(3, 1, TileCornerHeights.Flat(10));
        layout.SetCornerHeights(3, 2, TileCornerHeights.Flat(12));
        var heights = new TerrainHeightMap(layout, 0.25f);
        var visual = UnitVisual3D.Spawn(TokenScene, creature,
            EnemySpriteMap.FolderForCreature(creature.Name, creature.CreatureStats.Size));
        visual.Position = GridSpace.CreatureToWorld(creature.GridPosition, creature.TileWidth, heights);
        AddChild(visual);
        visual.PlaceOnGround(creature.GridPosition, heights);
        var ring = visual.GetNode<TeamRing>("%Ring");
        var sprite = visual.GetNode<BillboardSpriteAnimator>("%Sprite");
        Check("Large body spawns on lower support without changing rules anchor", visual.Position.IsEqualApprox(new Vector3(1.5f, 0.5f, 1.5f)) && creature.GridPosition == new PF2eVec(1, 1));
        Check("Large footprint stays on board at its original anchor", ring.TopLevel && ring.Mesh is ArrayMesh
            && ring.GlobalPosition.IsEqualApprox(new Vector3(1, 0, 1)));
        var markerPose = ring.GlobalTransform;
        visual.Position += Vector3.Right * 0.2f;
        Check("body motion cannot pull footprint off terrain", ring.GlobalTransform.IsEqualApprox(markerPose));
        visual.PlaceOnGround(creature.GridPosition, heights);
        ring.SetActive(true);
        await ToSignal(GetTree().CreateTimer(0.32), SceneTreeTimer.SignalName.Timeout);
        Check("surface pulse changes brightness without moving footprint", ring.GlobalTransform.IsEqualApprox(markerPose)
            && ring.MaterialOverride is ShaderMaterial material && material.GetShaderParameter("pulse").AsSingle() > 1f);
        ring.SetActive(false);
        Check("actual HP bar is above visible art, not transparent padding",
            Mathf.IsEqualApprox(visual.HpBarHeight, sprite.BodyHeight + 0.05f));
        var popups = new Node3D();
        AddChild(popups);
        var presenter = new GodotPresenter3D(popups, heights);
        presenter.RegisterUnit(creature, visual);
        await presenter.Present(new BattleEvent { Type = BattleEventType.MovementStarted, Source = creature });
        await presenter.Present(new BattleEvent
        {
            Type = BattleEventType.MovementStep, Source = creature,
            Path = new List<PF2eVec> { new(1, 1), new(2, 1) },
        });
        Check("Large movement segment lands at destination footprint center and elevation",
            visual.Position.IsEqualApprox(new Vector3(2.5f, 1, 1.5f)));
        Check("movement also relocates the entire terrain footprint",
            ring.GlobalPosition.IsEqualApprox(new Vector3(2, 0, 1)));
        creature.GridPosition = new PF2eVec(2, 1);
        Vector3 beforeCompletion = visual.Position;
        await presenter.Present(new BattleEvent { Type = BattleEventType.MovementCompleted, Source = creature });
        Check("movement completion does not jump back by half a tile", visual.Position.IsEqualApprox(beforeCompletion));
        await presenter.Present(new BattleEvent
        {
            Type = BattleEventType.MovementStarted, Source = creature,
            Path = new List<PF2eVec> { new(2, 1), new(3, 2) },
        });
        Check("Large slide path also uses footprint center", visual.Position.IsEqualApprox(new Vector3(25f / 6f, 0, 19f / 6f)));
        creature.GridPosition = new PF2eVec(4, 3);
        await presenter.Present(new BattleEvent { Type = BattleEventType.MovementCompleted, Source = creature });
        Check("authoritative reconciliation uses Large center after interrupted or corrected movement",
            visual.Position.IsEqualApprox(new Vector3(5, 0, 4)));
        Check("reconciliation restores the footprint at the authoritative anchor",
            ring.GlobalPosition.IsEqualApprox(new Vector3(4, 0, 3)) && ring.Visible);
        presenter.ClearUnits();
        visual.QueueFree();
        popups.QueueFree();
    }

    private static MapLayout FlatLayout()
    {
        var layout = new MapLayout { Name = "footprint_fixture", Seed = 0 };
        layout.Initialize(8, 8);
        for (int y = 0; y < 8; y++)
            for (int x = 0; x < 8; x++)
            {
                layout.SetTile(x, y, TileRole.Ground);
                layout.SetCornerHeights(x, y, TileCornerHeights.Flat(0));
            }
        return layout;
    }
}
