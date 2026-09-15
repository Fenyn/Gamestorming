using System.Collections.Generic;
using Delve.Terrain;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>A collision-free copy of the actor's sprite, plus sparse positional cues.</summary>
public partial class DestinationPreview : Node3D
{
    private Sprite3D _ghost = null!;
    private Label3D _caption = null!;
    private MeshInstance3D _links = null!;
    [Export] public float GhostOpacity { get; set; } = 0.45f;
    [Export] public float LinkHeight { get; set; } = 0.1f;

    public override void _Ready()
    {
        _ghost = GetNode<Sprite3D>("%Ghost");
        _caption = GetNode<Label3D>("%Caption");
        _links = GetNode<MeshInstance3D>("%Links");
        Hide();
    }

    public void Render(UnitVisual3D actor, PF2eVec tile, TerrainHeightMap heights,
        IReadOnlyList<ICharacter> targets, string caption)
    {
        var source = actor.GetNode<BillboardSpriteAnimator>("%Sprite");
        Position = GridSpace.CreatureToWorld(tile, actor.Character.TileWidth, heights);
        _ghost.Texture = source.Texture;
        _ghost.Hframes = source.Hframes;
        _ghost.Vframes = source.Vframes;
        _ghost.Frame = source.Frame;
        _ghost.PixelSize = source.PixelSize;
        _ghost.Offset = source.Offset;
        _ghost.FlipH = source.FlipH;
        _ghost.Position = source.Position;
        _ghost.Scale = source.Scale;
        _ghost.Modulate = new Color(Colors.White.Lerp(UiColors.CharacterAccent(actor.Character.Id), 0.2f), GhostOpacity);
        _caption.Text = caption;
        _caption.Position = Vector3.Up * (actor.HpBarHeight + 0.5f);
        var mesh = new ImmediateMesh();
        if (targets.Count > 0)
        {
            mesh.SurfaceBegin(Mesh.PrimitiveType.Lines);
            foreach (var target in targets)
            {
                mesh.SurfaceAddVertex(Vector3.Up * LinkHeight);
                mesh.SurfaceAddVertex(GridSpace.CreatureToWorld(target.GridPosition, target.TileWidth, heights) - Position + Vector3.Up * LinkHeight);
            }
            mesh.SurfaceEnd();
        }
        _links.Mesh = mesh;
        Show();
    }
}
