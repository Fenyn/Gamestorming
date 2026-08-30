using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>Legend swatch: one kind's silhouette at caption size, tinted like its map rim.</summary>
public partial class MapLegendGlyph : Control
{
    private NodeKind _kind;

    public void Setup(NodeKind kind)
    {
        _kind = kind;
        CustomMinimumSize = new Vector2(24f, 24f);
        QueueRedraw();
    }

    public override void _Draw()
        => MapNodeShapes.Draw(this, Size / 2f, 9f, _kind, UiColors.NodeFace, UiColors.NodeKindColor(_kind), 2f);
}
