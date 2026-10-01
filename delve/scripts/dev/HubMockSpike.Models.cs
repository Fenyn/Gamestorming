using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Low-poly Blender props (scratchpad blender/props.py) swapped in for the atlas cards, and 3D trees
/// for a side-by-side test with the 2D trees. Loaded from GLB at run time; dev only.
/// </summary>
public partial class HubMockSpike
{
    /// <summary>Absolute folder of the exported GLB props.</summary>
    [Export] public string ModelFolder { get; set; } = "";

    /// <summary>Which atlas card each model replaces.</summary>
    private static readonly Dictionary<Rect2, string> ModelFor = new()
    {
        [new(0, 625, 47, 47)] = "board", [new(386, 288, 88, 184)] = "well", [new(480, 301, 98, 83)] = "cart",
        [new(148, 114, 43, 57)] = "anvil", [new(336, 672, 48, 96)] = "lamp", [new(48, 678, 49, 67)] = "sign",
        [new(576, 214, 48, 74)] = "stump", [new(383, 221, 145, 63)] = "woodpile", [new(292, 415, 44, 48)] = "crate",
        [new(240, 423, 48, 36)] = "crate", [new(100, 542, 140, 81)] = "barrel", [new(244, 689, 40, 31)] = "barrel",
        [new(292, 689, 40, 31)] = "barrel", [new(578, 119, 94, 73)] = "table",
        [new(50, 212, 46, 56)] = "grindstone", [new(0, 575, 45, 50)] = "scarecrow", [new(587, 512, 26, 50)] = "standing_stone",
    };

    private readonly List<BaseMaterial3D> _glowing = new();

    /// <summary>Cards the swap hid come back before the tier pass decides what shows this shot.</summary>
    private void RestoreCards()
    {
        foreach (var (card, _) in _swaps) card.Visible = true;
    }

    private void LightLanterns(bool on)
    {
        foreach (var glass in _glowing) glass.EmissionEnabled = on;
    }

    private readonly Dictionary<string, PackedScene?> _models = new();
    private readonly List<(Sprite3D Card, Node3D Model)> _swaps = new();
    private readonly List<(Node3D Card, Node3D Model)> _treeSwaps = new();
    private bool _props3D, _trees3D;

    private Node3D? Model(string name)
    {
        if (!_models.TryGetValue(name, out var scene))
        {
            var document = new GltfDocument();
            var state = new GltfState();
            scene = document.AppendFromFile(ModelFolder.PathJoin(name + ".glb"), state) == Error.Ok
                ? PackGenerated(document.GenerateScene(state)) : null;
            _models[name] = scene;
        }
        return scene?.Instantiate<Node3D>();
    }

    /// <summary>Nearest filtering on every material so the pixel textures stay square.</summary>
    private PackedScene PackGenerated(Node root)
    {
        foreach (var mesh in root.FindChildren("*", nameof(MeshInstance3D), true, false).OfType<MeshInstance3D>())
            for (int i = 0; i < mesh.GetSurfaceOverrideMaterialCount(); i++)
                if ((mesh.GetActiveMaterial(i) ?? mesh.Mesh.SurfaceGetMaterial(i)) is BaseMaterial3D material)
                {
                    material.TextureFilter = BaseMaterial3D.TextureFilterEnum.NearestWithMipmaps;
                    material.Roughness = 1f;
                    // Leaf cards and crop decals: hard pixel edges, both sides, shadows from the cut-out.
                    if (material.ResourceName is "px_tree_bush" or "px_plant_cabbage" or "px_plant_beet" or "px_plant_wheat")
                    {
                        material.Transparency = BaseMaterial3D.TransparencyEnum.AlphaScissor;
                        material.AlphaScissorThreshold = 0.5f;
                        material.CullMode = BaseMaterial3D.CullModeEnum.Disabled;
                        material.TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest;
                    }
                    if (material.ResourceName == "px_ih_window_lit")
                    {
                        material.EmissionTexture = material.AlbedoTexture;
                        material.Emission = Colors.White;
                        material.EmissionEnergyMultiplier = 0.25f;
                        _glowing.Add(material);
                    }
                    else if (material.ResourceName == "px_stone_grey")
                        material.AlbedoColor = new Color(0.72f, 0.78f, 0.84f); // cool stone, so warm lamps don't turn it to sandstone
                    else if (material.ResourceName == "px_dirt_b")
                        material.AlbedoColor = new Color(0.98f, 0.88f, 0.72f); // the ground shader's dirt tint
                    else if (material.ResourceName == "px_ih_window")
                        _glass.Add(material);
                }
        var packed = new PackedScene();
        foreach (var child in root.FindChildren("*", "", true, false)) child.Owner = root;
        packed.Pack(root);
        return packed;
    }

    /// <summary>Places a model beside every card it replaces, the camp log seats, and a 3D twin for every forest tree.</summary>
    private void BuildModels()
    {
        foreach (var (site, sprite, _) in _sites)
            if (site.Building.Length == 0 && ModelFor.TryGetValue(site.Region, out var name) && Model(name) is { } model)
                Swap(sprite, model, site.At, name == "well" || name == "cart" ? Yaw : Yaw + (site.At.X * 37 % 30) - 15);
        var seatTexture = _outpost.GetNodeOrNull<Sprite3D>("Seat2")?.Texture;
        foreach (var seat in _outpost.GetChildren().OfType<Sprite3D>().Where(s => s.Texture == seatTexture && s.Visible))
            if (Model("log") is { } log)
                Swap(seat, log, new Vector2(seat.Position.X, seat.Position.Z), Yaw + Mathf.Sin(seat.Position.X * 3.7f) * 8f + (seat.Name == "Seat2" ? 60f : 0f));
        foreach (var (tree, _) in _forest)
        {
            bool pine = tree.SceneFilePath.Contains("conifer");
            string broad = OS.GetEnvironment("DELVE_HUB_TREES") == "cards" ? "tree_cards" : "tree_broad";
            int pick = (int)Mathf.Abs(tree.Position.X * 7 + tree.Position.Z * 13) % 3;
            string kind = pine ? (pick == 1 ? "tree_pine2" : "tree_pine") : pick == 0 ? broad : broad + (pick + 1);
            if (Model(kind) is null) kind = broad;
            if (Model(kind) is not { } twin) continue;
            _outpost.AddChild(twin);
            twin.Position = tree.Position;
            twin.Scale = tree.Scale * (pine ? 1.25f : 1.0f);
            twin.RotationDegrees = new Vector3(0, tree.Position.X * 53 % 360, 0);
            twin.Hide();
            _treeSwaps.Add((tree, twin));
            // The sprite trees carry TreeProp's lit tint; the shared 3D tree materials take the same.
            if (tree.FindChildren("*", nameof(Sprite3D), true, false).OfType<Sprite3D>().FirstOrDefault() is { } sprite)
                foreach (var mesh in twin.FindChildren("*", nameof(MeshInstance3D), true, false).OfType<MeshInstance3D>())
                    for (int i = 0; i < mesh.Mesh.GetSurfaceCount(); i++)
                        if (mesh.GetActiveMaterial(i) is BaseMaterial3D material) material.AlbedoColor = sprite.Modulate;
        }
        GD.Print($"[hub] forest {_forest.Count}, tree twins {_treeSwaps.Count}, prop swaps {_swaps.Count}");
    }

    private void Swap(Sprite3D card, Node3D model, Vector2 at, float yaw)
    {
        _outpost.AddChild(model);
        var spot = new Vector3(at.X, 0, at.Y);
        model.Position = spot with { Y = _terrain.HeightAt(spot) };
        model.RotationDegrees = new Vector3(0, yaw, 0);
        model.Hide();
        _swaps.Add((card, model));
    }

    /// <summary>After the tier pass: models take their card's visibility and the card hides.</summary>
    private void ShowModels()
    {
        foreach (var (card, model) in _swaps)
        {
            model.Visible = _props3D && card.Visible;
            if (_props3D) card.Visible = false;
        }
        foreach (var (tree, twin) in _treeSwaps)
        {
            twin.Visible = _trees3D && tree.Visible;
            if (_trees3D) tree.Visible = false;
        }
    }
}
