using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// One node of the run map: a kind-shaped medallion drawn over an empty-styled Button, so click,
/// focus, tooltip and disabled behaviour stay stock while the face is fully custom. Reachable
/// nodes breathe - a slow bob plus a pulsing halo - and the party's node carries a bobbing
/// chevron marker. Everything else draws once and stays still.
/// </summary>
public partial class MapNodeButton : Button
{
    private const float ShapeInset = 8f;
    private const float PulseSpeed = 2.6f;

    private NodeKind _kind;
    private bool _reachable;
    private bool _isCurrent;
    private bool _visited;
    private bool _dead;
    private float _shapeRadius;
    private float _time;

    /// <summary>Configure on spawn. The panel positions the button; size follows the kind table.
    /// <paramref name="live"/> means the node can still be reached this run - dead nodes (visited
    /// or bypassed) go grey and give up their kind colour.</summary>
    public void Setup(MapNode node, bool reachable, bool isCurrent, bool live)
    {
        var entry = NodeKindInfo.Get(node.Kind);
        _kind = node.Kind;
        _reachable = reachable;
        _isCurrent = isCurrent;
        _visited = node.Visited;
        _dead = !live && !isCurrent;
        _shapeRadius = entry.MapDiameter * 0.5f - ShapeInset;

        ThemeTypeVariation = ThemeNames.MapNode;
        Size = new Vector2(entry.MapDiameter, entry.MapDiameter);
        string title = isCurrent ? $"{entry.DisplayName} (you are here)"
            : _visited ? $"{entry.DisplayName} (visited)"
            : _dead ? $"{entry.DisplayName} (passed by)"
            : entry.DisplayName;
        TooltipText = $"{title}\n{entry.Blurb}";
        Disabled = !reachable;
        FocusMode = reachable ? FocusModeEnum.All : FocusModeEnum.None;
        MouseDefaultCursorShape = reachable ? CursorShape.PointingHand : CursorShape.Arrow;
    }

    public override void _Process(double delta)
    {
        if (!_reachable && !_isCurrent) return;
        _time += (float)delta;
        QueueRedraw();
    }

    public override void _Draw()
    {
        float wave = Mathf.Sin(_time * PulseSpeed);
        var center = Size / 2f;
        if (_reachable)
            center.Y += wave * 1.5f;

        var kindColor = UiColors.NodeKindColor(_kind);
        float rimWidth = _kind == NodeKind.Boss ? 3.5f : 2.5f;

        Color face = UiColors.NodeFace;
        Color rim = kindColor;
        if (_reachable)
        {
            var mode = GetDrawMode();
            if (mode == DrawMode.Hover || mode == DrawMode.HoverPressed)
                face = UiColors.NodeFaceHover;
            if (mode == DrawMode.Pressed || mode == DrawMode.HoverPressed)
                face = face.Darkened(0.3f);

            // The come-hither halo: the same silhouette, swelling and fading just outside the rim.
            var halo = MapNodeShapes.Outline(_kind, center, _shapeRadius + 4f + wave * 2f);
            MapNodeShapes.DrawRim(this, halo, kindColor with { A = 0.35f + 0.15f * wave }, 2f);
        }
        else if (_dead)
        {
            // Visited or bypassed: the run can never come back here, so the node gives up its
            // kind colour entirely and sinks toward the backdrop.
            rim = UiColors.TextDisabled;
            face = face.Darkened(0.25f);
        }
        else if (!_isCurrent)
        {
            // Still ahead on some path, just not pickable yet. A light fade keeps the kind
            // colour readable - the Warden included, so it looms from the entrance.
            rim = kindColor.Lerp(UiColors.TextDisabled, 0.45f);
        }

        MapNodeShapes.Draw(this, center, _shapeRadius, _kind, face, rim, rimWidth);

        if (HasFocus())
        {
            var ring = MapNodeShapes.Outline(_kind, center, _shapeRadius + 8f);
            MapNodeShapes.DrawRim(this, ring, UiColors.Text, 1.5f);
        }

        if (_isCurrent)
            DrawPartyMarker(center);
    }

    /// <summary>Ember chevron floating above the node the party stands on.</summary>
    private void DrawPartyMarker(Vector2 center)
    {
        var tip = center + new Vector2(0f, -_shapeRadius - 12f + Mathf.Sin(_time * PulseSpeed) * 2.5f);
        var accent = UiColors.Accent;
        DrawLine(tip + new Vector2(-7f, -7f), tip, accent, 3f, true);
        DrawLine(tip + new Vector2(7f, -7f), tip, accent, 3f, true);
    }
}
