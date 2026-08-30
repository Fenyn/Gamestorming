using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Terrain;
using Godot;
using PF2e.MapGen;

namespace Delve.Dev;

/// <summary>
/// Rendered smoke test for the terrain SKIRT (scenes/dev/terrain_skirt_shot_spike.tscn). Where
/// <c>terrain_skirt_render_spike</c> asserts the stage's structure headlessly, this one photographs
/// it: one stage per biome x seed, captured top-down (the whole halo in frame, where a severed
/// river or a dead-ended canyon is obvious) and obliquely from a low angle (where a height step at
/// the board seam casts a wall). The captures are the review artifact; the only assertions are that
/// every stage builds and every file saves.
///
/// Captures go to user://dev_shots. Must run rendered, NOT --headless:
///   godot --path delve res://scenes/dev/terrain_skirt_shot_spike.tscn
/// </summary>
public partial class TerrainSkirtShotSpike : SpikeBase
{
    private const string OutDir = "user://dev_shots";

    private static readonly int[] Seeds = { 7, 38, 137, 404, 4711, 20260804 };

    private static readonly string[] Biomes = { "forest", "sewer" };

    /// <summary>Seconds a freshly built stage gets before its first capture.</summary>
    private const float SettleSeconds = 0.4f;

    protected override string Banner => "================= TERRAIN SKIRT SHOT SPIKE =================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        DirAccess.MakeDirRecursiveAbsolute(OutDir);

        foreach (string biome in Biomes)
        {
            foreach (int seed in Seeds)
            {
                var board = MapGenerator.GenerateValidated(biome, seed);
                if (board == null)
                {
                    Check($"{biome} seed {seed}: GenerateValidated produced a map", false);
                    continue;
                }

                var host = BuildStage(board, biome, out var stage, out var camera);
                int margin = stage.Skirt?.Margin ?? 0;
                Check($"{biome} seed {seed}: stage built with a skirt", margin > 0);

                float span = Mathf.Max(board.Width, board.Height) + 2f * margin;
                var centre = new Vector3(board.Width / 2f, 0f, board.Height / 2f);

                PoseTopDown(camera, centre, span);
                await WaitSeconds(SettleSeconds);
                Capture($"skirt_{biome}_{seed}_top.png");

                PoseOblique(camera, centre, span);
                await WaitSeconds(SettleSeconds);
                Capture($"skirt_{biome}_{seed}_ob.png");

                host.QueueFree();
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            }
        }
    }

    // ─────────────────────────── stage + camera ───────────────────────────

    private Node3D BuildStage(
        MapLayout board, string biome, out TerrainStage stage, out Camera3D camera)
    {
        var host = new Node3D { Name = "SkirtShotHost" };
        var environment = new WorldEnvironment { Environment = new Godot.Environment() };
        var sun = new DirectionalLight3D();
        stage = new TerrainStage { Name = "TerrainStage", PlaceholderFloorPath = new NodePath() };
        DevTreeMix.Apply(stage);
        camera = new Camera3D { Name = "ShotCamera" };

        host.AddChild(environment);
        host.AddChild(sun);
        host.AddChild(stage);
        host.AddChild(camera);
        AddChild(host);

        stage.Build(board, biome, board.Width, board.Height, environment, sun);
        camera.Current = true;
        return host;
    }

    /// <summary>Whole skirt in frame from straight above, orthographic so tile edges stay square.</summary>
    private static void PoseTopDown(Camera3D camera, Vector3 centre, float span)
    {
        camera.Projection = Camera3D.ProjectionType.Orthogonal;
        camera.Size = span + 2f;
        camera.Position = centre + new Vector3(0f, 80f, 0f);
        camera.RotationDegrees = new Vector3(-90f, 0f, 0f);
    }

    /// <summary>Low view over a corner, where a height step at the seam reads as a wall.</summary>
    private static void PoseOblique(Camera3D camera, Vector3 centre, float span)
    {
        camera.Projection = Camera3D.ProjectionType.Perspective;
        camera.Position = centre + new Vector3(span * 0.62f, span * 0.42f, span * 0.62f);
        camera.LookAt(centre, Vector3.Up);
    }

    // ─────────────────────────── capture ───────────────────────────

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(1280, 720, Image.Interpolation.Bilinear);
        string path = $"{OutDir}/{file}";
        Error err = img.SavePng(path);
        GD.Print($"[skirtshot] {file}: {err} ({ProjectSettings.GlobalizePath(path)})");
        Check($"{file} saved", err == Error.Ok);
    }

    private async Task WaitSeconds(float seconds)
        => await ToSignal(GetTree().CreateTimer(seconds), Timer.SignalName.Timeout);
}
