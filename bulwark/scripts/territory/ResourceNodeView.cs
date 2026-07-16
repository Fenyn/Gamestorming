using Bulwark.Data;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Passive world adapter for one harvestable resource node. Two visual flavors share this script:
/// the placeholder token scene (scenes/territory/resource_node.tscn — colored rect + label) and the
/// real-art prefabs under scenes/territory/nodes/ (whole-object Sprite2D offset so the y-sort
/// origin sits at the trunk/base, StaticBody2D base collision with a UNIQUE shape per prefab).
/// The scene binds it to a node id + definition and toggles it when GameState announces
/// depletion/respawn — it never mutates state itself.
///
/// Placeable (design/forage.md): prefabs preset <see cref="DefinitionId"/> and are dropped
/// directly into territory .tscn files; the scene adapter discovers them at ready and registers
/// them with the territory system (save identity = territory id + node name).
/// </summary>
public partial class ResourceNodeView : Node2D
{
    /// <summary>The <see cref="ResourceNodeDefinition.Id"/> this node harvests as. Preset in the
    /// prefab scenes; read by the territory scene when discovering placed nodes.</summary>
    [Export] public string DefinitionId { get; set; } = "";

    private ColorRect? _token;
    private Label? _label;
    private CollisionShape2D? _bodyShape;

    /// <summary>The territory-local node id (marker id, placed-node name, or forage spawn id).</summary>
    public string NodeId { get; private set; } = "";

    public override void _Ready()
    {
        // Prefabs with real art carry no %Token; the placeholder scene carries no %Sprite.
        _token = GetNodeOrNull<ColorRect>("%Token");
        _label = GetNodeOrNull<Label>("%Label");
        _bodyShape = GetNodeOrNull<CollisionShape2D>("%BodyShape");
    }

    /// <summary>Bind this view to its placement. Call after instancing (the scene owns wiring).</summary>
    public void Bind(string nodeId, ResourceNodeDefinition def)
    {
        NodeId = nodeId;
        if (_label != null)
            _label.Text = def.DisplayName;
        if (_token != null)
        {
            _token.Color = def.Id switch
            {
                "rock" => new Color(0.55f, 0.55f, 0.6f),
                "herb_patch" => new Color(0.35f, 0.75f, 0.35f),
                "berry_bush" => new Color(0.7f, 0.3f, 0.55f),
                "fallen_wood" => new Color(0.6f, 0.42f, 0.22f),
                _ => new Color(0.8f, 0.8f, 0.8f),
            };
        }
    }

    /// <summary>Proximity label control: the territory scene shows only the nearest-in-range
    /// node's name (mirrors the interact hint), so a forest of trees stays label-free.</summary>
    public void SetLabelVisible(bool visible)
    {
        if (_label != null)
            _label.Visible = visible;
    }

    /// <summary>Depleted nodes hide AND stop blocking (respawn re-shows them on day change).
    /// Deferred: depletion lands from a physics-adjacent signal path.</summary>
    public void SetDepleted(bool depleted)
    {
        Visible = !depleted;
        _bodyShape?.SetDeferred(CollisionShape2D.PropertyName.Disabled, depleted);
    }
}
