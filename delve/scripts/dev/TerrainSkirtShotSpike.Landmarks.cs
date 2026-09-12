using System.Threading.Tasks;
using Godot;
using PF2e.MapGen;
using PF2e.MapGen.Biomes;
using PF2e.MapGen.Phases;
using PF2e.MapGen.Setpieces;

namespace Delve.Dev;

public partial class TerrainSkirtShotSpike
{
    private async Task ReviewLandmarksAsync()
    {
        foreach (string id in new[] { "ruined_foundation", "rocky_outcrop", "gully", "rocky_escarpment" })
        {
            var board = new MapLayout();
            board.Initialize(24, 22);
            board.Seed = 42;
            for (int y = 0; y < board.Height; y++)
                for (int x = 0; x < board.Width; x++) board.SetTile(x, y, TileRole.Ground);
            var ctx = new MapGenerationContext
            {
                Layout = board, Seed = 42, Rng = new System.Random(42),
                Biome = BiomeCatalog.All["forest"], Params = BiomeCatalog.All["forest"].DefaultParams,
                RegionIds = new int[board.Width * board.Height],
                RegionKinds = new[] { RegionKind.Plain }, RegionBaseElevations = new[] { 0 },
                ReservedMask = new bool[board.Width * board.Height]
            };
            var definition = SetpieceCatalog.All[id];
            var anchor = new PF2e.Vector2Int((board.Width - definition.FootprintSize.x) / 2,
                (board.Height - definition.FootprintSize.y) / 2);
            bool placed = definition.TryPlan(ctx, anchor, Rotation.Zero, out var plan);
            Check($"{id} placed", placed);
            if (!placed) continue;
            definition.Apply(ctx, plan);
            ctx.PlacedSetpieces.Add(plan);
            new SurfaceWaterPhase().Run(ctx);
            var host = BuildStage(board, "forest", out var stage, out var camera);
            var centre = new Vector3(board.Width * 0.5f, stage.HeightMap.MeanCenterY, board.Height * 0.5f);
            camera.Projection = Camera3D.ProjectionType.Orthogonal;
            camera.Size = 18f;
            camera.Position = centre + new Vector3(13f, 13f, id == "rocky_escarpment" ? -16f : 16f);
            camera.LookAt(centre);
            await WaitSeconds(SettleSeconds);
            Capture($"landmark_{id}.png");
            host.QueueFree();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
    }
}

