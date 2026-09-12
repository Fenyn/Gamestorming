using System;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Godot;

namespace Delve.Dev;

/// <summary>Rendered comparisons: occluded pixels change, visible pixels do not.</summary>
public partial class CreatureSilhouetteSpike : SpikeBase
{
    [Export] public PackedScene SpriteScene { get; set; } = null!;
    [Export] public EnemySpriteDefinition Bear { get; set; } = null!;
    [Export] public string OutputDirectory { get; set; } = "";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (DisplayServer.GetName() == "headless")
            throw new InvalidOperationException("This spike requires a renderer.");
        var viewport = new SubViewport { Size = new Vector2I(384, 256), OwnWorld3D = true,
            RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
        AddChild(viewport);
        var world = new Node3D(); viewport.AddChild(world);
        var camera = new Camera3D { Position = new Vector3(0, 1, 4), Current = true };
        world.AddChild(camera); camera.LookAt(new Vector3(0, 0.7f, 0));
        var sprite = SpriteScene.Instantiate<BillboardSpriteAnimator>(); world.AddChild(sprite);
        sprite.ConfigureEnemy(Bear); sprite.Frozen = true;
        var overlay = sprite.MaterialOverlay;
        var block = new MeshInstance3D
        {
            Mesh = new BoxMesh { Size = new Vector3(0.7f, 0.7f, 0.3f) },
            Position = new Vector3(0.25f, 0.35f, 0.6f),
            MaterialOverride = new StandardMaterial3D { ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
                AlbedoColor = new Color(0.2f, 0.25f, 0.3f) },
            Visible = false,
        };
        world.AddChild(block);
        async Task<Image> Capture(bool enabled)
        {
            sprite.MaterialOverlay = enabled ? overlay : null;
            for (int i = 0; i < 3; i++)
                await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            return viewport.GetTexture().GetImage();
        }
        using (var off = await Capture(false))
        using (var on = await Capture(true))
            Check("unobstructed sprite pixels stay unchanged", Difference(off, on) == 0);
        block.Visible = true;
        foreach (var angle in new[] { 0, 1, 2 })
        {
            camera.Position = angle switch { 1 => new Vector3(1.6f, 1.3f, 3.5f),
                2 => new Vector3(-1.6f, 1.3f, 3.5f), _ => new Vector3(0, 1, 4) };
            camera.LookAt(new Vector3(0, 0.7f, 0));
            sprite.Facing = angle == 2 ? Vector2.Left : Vector2.Right;
            sprite.ApplyFacing();
            using var off = await Capture(false);
            using var on = await Capture(true);
            Check($"angle {angle}: hidden body gains a silhouette", Difference(off, on) > 40);
            block.Visible = false;
            using var clear = await Capture(false);
            int visibleChanges = 0;
            for (int y = 0; y < on.GetHeight(); y++)
                for (int x = 0; x < on.GetWidth(); x++)
                    if (off.GetPixel(x, y).IsEqualApprox(clear.GetPixel(x, y))
                        && !off.GetPixel(x, y).IsEqualApprox(on.GetPixel(x, y))) visibleChanges++;
            Check($"angle {angle}: overlay changes only pixels behind the obstacle", visibleChanges == 0);
            block.Visible = true;
            if (!string.IsNullOrEmpty(OutputDirectory))
            {
                System.IO.Directory.CreateDirectory(ProjectSettings.GlobalizePath(OutputDirectory));
                on.SavePng($"{OutputDirectory}/angle_{angle}.png");
            }
        }
        sprite.Frozen = false; sprite.PlayAttack(out _); sprite._Process(0.19); sprite.Frozen = true;
        using var attackCapture = await Capture(true);
        Check("frozen attack silhouette samples the current pose",
            ((ShaderMaterial)overlay).GetShaderParameter("sprite_tex").AsGodotObject() == sprite.Texture);
        sprite.Modulate = new Color(1, 1, 1, 0);
        using (var hidden = await Capture(true))
        {
            Check("silhouette follows body fade", Mathf.IsZeroApprox(
                ((ShaderMaterial)overlay).GetShaderParameter("body_alpha").AsSingle()));
        }
        viewport.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        Check("freeing sprites releases pre-draw callbacks", !GodotObject.IsInstanceValid(sprite));
    }

    private static int Difference(Image a, Image b)
    {
        int n = 0;
        for (int y = 0; y < a.GetHeight(); y++)
            for (int x = 0; x < a.GetWidth(); x++)
                if (!a.GetPixel(x, y).IsEqualApprox(b.GetPixel(x, y))) n++;
        return n;
    }
}
