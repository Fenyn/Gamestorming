using Bulwark.Data;
using Godot;

namespace Bulwark.Territory;

/// <summary>
/// Placeholder visual for one harvestable resource node (scenes/territory/resource_node.tscn).
/// Passive world adapter: the forest scene binds it to a node id + definition and toggles it when
/// GameState announces depletion/respawn — it never mutates state itself. The colored token + label
/// stand in until real art; the user replaces visuals, the node id contract stays.
/// </summary>
public partial class ResourceNodeView : Node2D
{
    private ColorRect _token = null!;
    private Label _label = null!;

    /// <summary>The territory-local node id (matches TerritoryNode.NodeId and the %Node_ marker).</summary>
    public string NodeId { get; private set; } = "";

    public override void _Ready()
    {
        _token = GetNode<ColorRect>("%Token");
        _label = GetNode<Label>("%Label");
    }

    /// <summary>Bind this view to its placement. Call after instancing (the scene owns wiring).</summary>
    public void Bind(string nodeId, ResourceNodeDefinition def)
    {
        NodeId = nodeId;
        _label.Text = def.DisplayName;
        _token.Color = def.Id switch
        {
            "rock" => new Color(0.55f, 0.55f, 0.6f),
            "herb_patch" => new Color(0.35f, 0.75f, 0.35f),
            "berry_bush" => new Color(0.7f, 0.3f, 0.55f),
            "fallen_wood" => new Color(0.6f, 0.42f, 0.22f),
            _ => new Color(0.8f, 0.8f, 0.8f),
        };
    }

    /// <summary>Depleted nodes hide (respawn re-shows them on day change).</summary>
    public void SetDepleted(bool depleted) => Visible = !depleted;
}
