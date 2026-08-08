using System.Collections.Generic;
using Godot;

namespace Bulwark.Fx;

/// <summary>
/// Makes an authored or .glb-imported subtree cutaway-capable: swaps every surface onto
/// <c>assets/shaders/xray_cutaway.gdshader</c> and feeds it a focus point each frame, so geometry
/// standing between the camera and the focus dissolves behind a screen-door dither. This is what
/// retires the "knee-high south wall" staging convention — an interior set can be walled to full
/// height and still show its actors.
///
/// Placed as a plain child Node beside the geometry it governs (one per set), never spawned in code.
/// It only ever writes surface OVERRIDE materials, so the source meshes and the .glb import are
/// untouched; clearing <see cref="FocusPath"/> disables the whole thing and leaves the originals in
/// place.
///
/// Unwired (either path empty) it is a silent no-op, so a set still runs standalone under F6. A path
/// that is set but cannot be resolved — or a target holding no meshes — is a genuine authoring
/// mistake and warns.
/// </summary>
public partial class CutawayApplier : Node
{
    private const string ShaderPath = "res://assets/shaders/xray_cutaway.gdshader";

    /// <summary>Root of the geometry that may be cut away — the instanced .glb backdrop, a Walls node,
    /// a props container. The whole subtree is walked for <see cref="MeshInstance3D"/>.</summary>
    [Export] public NodePath TargetPath { get; set; } = new NodePath();

    /// <summary>Node3D whose global position the camera must be able to see. Empty leaves every source
    /// material exactly as authored.</summary>
    [Export] public NodePath FocusPath { get; set; } = new NodePath();

    /// <summary>Radius of the hole around the camera→focus ray, in metres.</summary>
    [Export] public float CutRadius { get; set; } = 2.2f;

    /// <summary>Width of the dithered falloff at both edges of the hole, in metres.</summary>
    [Export] public float CutSoftness { get; set; } = 0.8f;

    /// <summary>Toggled by cutscene staging to open and close the cut without rebuilding materials.</summary>
    [Export] public bool Enabled { get; set; } = true;

    private Node3D? _focus;

    // One material per distinct SOURCE material, not per surface: the intro_road backdrop is a single
    // mesh with four surfaces sharing four materials, and an interior set shares a handful of wall and
    // wood materials across dozens of nodes. Grouping this way keeps the per-frame uniform write at a
    // handful of calls instead of one per surface, and it is what lets a shared material stay shared.
    private readonly List<ShaderMaterial> _materials = new();

    public override void _Ready()
    {
        SetProcess(false);

        if (TargetPath.IsEmpty || FocusPath.IsEmpty)
            return; // unwired: silent, nothing touched

        Node? target = GetNodeOrNull<Node>(TargetPath);
        if (target == null)
        {
            GD.PushWarning($"[cutaway] {Name}: TargetPath '{TargetPath}' resolves to nothing.");
            return;
        }

        _focus = GetNodeOrNull<Node3D>(FocusPath);
        if (_focus == null)
        {
            GD.PushWarning($"[cutaway] {Name}: FocusPath '{FocusPath}' resolves to nothing (or is not a Node3D).");
            return;
        }

        var shader = GD.Load<Shader>(ShaderPath);
        if (shader == null)
        {
            GD.PushError($"[cutaway] {Name}: could not load {ShaderPath}.");
            return;
        }

        int surfaces = Convert(target, shader);
        if (surfaces == 0)
        {
            GD.PushWarning($"[cutaway] {Name}: no mesh surfaces found under '{TargetPath}'.");
            return;
        }

        GD.Print($"[cutaway] {Name}: {surfaces} surface(s) on {_materials.Count} material(s).");
        SetProcess(true);
        Push(); // correct from the first rendered frame, not the second
    }

    /// <summary>
    /// Walk the subtree and put every mesh surface onto a cutaway material that mirrors the source
    /// material's albedo. Returns the number of surfaces converted.
    /// </summary>
    private int Convert(Node root, Shader shader)
    {
        var bySource = new Dictionary<ulong, ShaderMaterial>();
        int converted = 0;

        foreach (MeshInstance3D mesh in Meshes(root))
        {
            if (mesh.Mesh == null)
                continue;

            for (int surface = 0; surface < mesh.Mesh.GetSurfaceCount(); surface++)
            {
                Material? source = mesh.GetActiveMaterial(surface);
                if (source == null)
                    continue;

                // Key on the source material instance: the .glb importer already de-duplicates
                // materials, and .tscn sub_resources are shared by reference, so identical surfaces
                // land on one shader material without any comparison of textures or colours.
                ulong key = source.GetInstanceId();
                if (!bySource.TryGetValue(key, out ShaderMaterial? cutaway))
                {
                    cutaway = Build(shader, source as BaseMaterial3D);
                    bySource[key] = cutaway;
                    _materials.Add(cutaway);
                }

                mesh.SetSurfaceOverrideMaterial(surface, cutaway);
                converted++;
            }
        }

        return converted;
    }

    /// <summary>Build one cutaway material carrying the source material's albedo. A source that is not a
    /// <see cref="BaseMaterial3D"/> (or has no texture) falls back to the shader's white default, so an
    /// untextured greybox surface still cuts — it just renders flat.</summary>
    private ShaderMaterial Build(Shader shader, BaseMaterial3D? source)
    {
        var material = new ShaderMaterial { Shader = shader };

        if (source?.AlbedoTexture != null)
            material.SetShaderParameter("albedo_texture", source.AlbedoTexture);
        if (source != null)
            material.SetShaderParameter("albedo_tint", source.AlbedoColor);

        return material;
    }

    /// <summary>Depth-first walk yielding every <see cref="MeshInstance3D"/> in the subtree, root included.</summary>
    private static IEnumerable<MeshInstance3D> Meshes(Node node)
    {
        if (node is MeshInstance3D mesh)
            yield return mesh;

        foreach (Node child in node.GetChildren())
            foreach (MeshInstance3D found in Meshes(child))
                yield return found;
    }

    public override void _Process(double delta) => Push();

    /// <summary>
    /// Write the frame's uniforms to every cached material. The focus moves constantly, and pushing the
    /// tunables alongside it costs four calls across a handful of materials — cheap enough to buy live
    /// inspector scrubbing of the radius and a cutscene-toggleable <see cref="Enabled"/>.
    /// </summary>
    private void Push()
    {
        if (_focus == null || !IsInstanceValid(_focus))
            return;

        Vector3 focus = _focus.GlobalPosition;
        foreach (ShaderMaterial material in _materials)
        {
            material.SetShaderParameter("focus_point", focus);
            material.SetShaderParameter("cut_radius", CutRadius);
            material.SetShaderParameter("cut_softness", CutSoftness);
            material.SetShaderParameter("enabled", Enabled);
        }
    }
}
