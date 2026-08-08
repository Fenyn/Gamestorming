using Bulwark.Data;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Passive world adapter for one harvestable resource node. Two visual flavors share this script:
/// the placeholder token scene (scenes/territory/resource_node.tscn — a plain coloured box) and the
/// greybox prefabs under scenes/territory/nodes/ (simple BoxMesh/SphereMesh/CylinderMesh bodies
/// standing on the ground plane, each with its OWN StaticBody3D + uniquely sized CollisionShape3D
/// so the user can swap one prefab at a time). The scene binds it to a node id + definition and
/// toggles it when GameState announces depletion/respawn — it never mutates state itself.
///
/// Placeable (design/forage.md): prefabs preset <see cref="DefinitionId"/> and are dropped
/// directly into territory .tscn files; the scene adapter discovers them at ready and registers
/// them with the territory system (save identity = territory id + node name).
///
/// GRID: one cell is ONE METRE. A prefab's origin sits on the ground (y = 0) at the node's cell
/// centre; the meshes are authored upward from there. Depth sorting is the 3D depth buffer's job —
/// there is no y-sort contract any more.
/// </summary>
public partial class ResourceNodeView : Node3D
{
    /// <summary>The <see cref="ResourceNodeDefinition.Id"/> this node harvests as. Preset in the
    /// prefab scenes; read by the territory scene when discovering placed nodes.</summary>
    [Export] public string DefinitionId { get; set; } = "";

    private MeshInstance3D? _token;
    private Label3D? _label;
    private CollisionShape3D? _bodyShape;

    /// <summary>The territory-local node id (marker id, placed-node name, or forage spawn id).</summary>
    public string NodeId { get; private set; } = "";

    public override void _Ready()
    {
        // Greybox prefabs carry no %Token; the placeholder scene carries the token box.
        _token = GetNodeOrNull<MeshInstance3D>("%Token");
        _label = GetNodeOrNull<Label3D>("%Label");
        _bodyShape = GetNodeOrNull<CollisionShape3D>("%BodyShape");
    }

    /// <summary>Bind this view to its placement. Call after instancing (the scene owns wiring).</summary>
    public void Bind(string nodeId, ResourceNodeDefinition def)
    {
        NodeId = nodeId;
        _label ??= GetNodeOrNull<Label3D>("%Label");
        _token ??= GetNodeOrNull<MeshInstance3D>("%Token");
        if (_label != null)
            _label.Text = def.DisplayName;
        if (_token != null)
        {
            var color = def.Id switch
            {
                "rock" => new Color(0.55f, 0.55f, 0.6f),
                "herb_patch" => new Color(0.35f, 0.75f, 0.35f),
                "berry_bush" => new Color(0.7f, 0.3f, 0.55f),
                "fallen_wood" => new Color(0.6f, 0.42f, 0.22f),
                _ => new Color(0.8f, 0.8f, 0.8f),
            };
            // Per-instance override so sibling tokens never share (and repaint) one material.
            _token.MaterialOverride = new StandardMaterial3D { AlbedoColor = color, Roughness = 1f };
        }
    }

    /// <summary>Proximity label control: the territory scene shows only the nearest-in-range
    /// node's name (mirrors the interact hint), so a forest of trees stays label-free.</summary>
    public void SetLabelVisible(bool visible)
    {
        _label ??= GetNodeOrNull<Label3D>("%Label");
        if (_label != null)
            _label.Visible = visible;
    }

    /// <summary>Depleted nodes hide AND stop blocking (respawn re-shows them on day change).
    /// Deferred: depletion lands from a physics-adjacent signal path.</summary>
    public void SetDepleted(bool depleted)
    {
        Visible = !depleted;
        _bodyShape ??= GetNodeOrNull<CollisionShape3D>("%BodyShape");
        _bodyShape?.SetDeferred(CollisionShape3D.PropertyName.Disabled, depleted);
    }
}
