using Godot;

namespace Delve.Terrain;

/// <summary>Two slow mist shelves in the forest halo, masked away from the playable board.</summary>
public static class OutskirtsMist
{
    public static Node3D Build(Shader shader, int width, int height, int margin, BackdropThemeDefinition theme)
    {
        var root = new Node3D { Name = "OutskirtsMist" };
        for (int layer = 0; layer < 2; layer++)
        {
            var material = new ShaderMaterial { Shader = shader };
            material.SetShaderParameter("board_size", new Vector2(width, height));
            material.SetShaderParameter("margin", (float)margin);
            material.SetShaderParameter("opacity", theme.OutskirtsMistOpacity);
            material.SetShaderParameter("mist_color", MapMaterials.ToGodot(theme.OutskirtsMistColor));
            material.SetShaderParameter("layer_phase", layer * 11.7f);
            root.AddChild(new MeshInstance3D
            {
                Name = $"Mist{layer}",
                Position = new Vector3(width / 2f, 1.3f + layer * 1.7f, height / 2f),
                Mesh = new PlaneMesh { Size = new Vector2(width + 2 * margin, height + 2 * margin) },
                MaterialOverride = material,
                CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            });
        }
        return root;
    }
}
