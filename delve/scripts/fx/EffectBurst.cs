using System.Linq;
using Godot;

namespace Delve.Fx;

/// <summary>
/// Plays a PolyBlocks EffectBlocks scene once and frees it. The pack has no playback API and its demo
/// scripts replay on Enter, so they are stripped before the scene enters the tree. The pack's scenes
/// are third-party trees with no unique names, so this is the one place that searches them for emitters.
/// </summary>
public static class EffectBurst
{
    /// <summary>The pack's only ambient script worth keeping; the others poll ui_accept.</summary>
    private const string KeptScript = "light_flicker.gd";

    /// <summary>Instances <paramref name="scene"/> under <paramref name="parent"/> at a local position,
    /// fires every emitter once, and frees the node when the last emitter reports Finished.
    /// <paramref name="amount"/> and <paramref name="explosiveness"/> override the pack's values when set.</summary>
    public static Node3D? Play(PackedScene? scene, Node3D parent, Vector3 position, float scale = 1,
        int amount = 0, float explosiveness = -1)
    {
        if (scene == null) return null;
        var effect = scene.Instantiate<Node3D>();
        StripScripts(effect);
        effect.Position = position;
        effect.Scale = Vector3.One * scale;
        parent.AddChild(effect);
        var emitters = Emitters(effect);
        if (emitters.Length == 0) { effect.QueueFree(); return null; }
        int running = emitters.Length;
        foreach (var emitter in emitters)
        {
            if (amount > 0) emitter.Amount = amount;
            if (explosiveness >= 0) emitter.Explosiveness = explosiveness;
            emitter.OneShot = true;
            emitter.Finished += () =>
            {
                if (--running == 0 && GodotObject.IsInstanceValid(effect)) effect.QueueFree();
            };
            emitter.Restart();
        }
        return effect;
    }

    /// <summary>Instances a looping ambient effect with its demo scripts removed.</summary>
    public static Node3D? Ambient(PackedScene? scene, Node3D parent, Vector3 position, float scale = 1)
    {
        if (scene == null) return null;
        var effect = scene.Instantiate<Node3D>();
        StripScripts(effect);
        effect.Position = position;
        effect.Scale = Vector3.One * scale;
        parent.AddChild(effect);
        return effect;
    }

    /// <summary>Recolours an effect to one palette colour: every emitter's process colour (on a copy
    /// of its material) and every light. Shader-driven meshes keep their authored colours.</summary>
    public static void Tint(Node3D? effect, Color color)
    {
        if (effect == null) return;
        foreach (var emitter in Emitters(effect))
            if (emitter.ProcessMaterial is ParticleProcessMaterial process)
            {
                var copy = (ParticleProcessMaterial)process.Duplicate();
                copy.Color = color;
                emitter.ProcessMaterial = copy;
            }
        foreach (var light in effect.FindChildren("*", nameof(Light3D), true, false).OfType<Light3D>())
            light.LightColor = color;
    }

    private static GpuParticles3D[] Emitters(Node3D effect)
        => effect.FindChildren("*", nameof(GpuParticles3D), true, false).OfType<GpuParticles3D>()
            .Prepend(effect as GpuParticles3D).OfType<GpuParticles3D>().ToArray();

    private static void StripScripts(Node node)
    {
        if (node.GetScript().Obj is Script script && !script.ResourcePath.EndsWith(KeptScript))
            node.SetScript(default);
        foreach (var child in node.GetChildren()) StripScripts(child);
    }
}
