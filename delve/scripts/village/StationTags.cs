using System.Collections.Generic;
using Delve.UI;
using Godot;

namespace Delve.Village;

/// <summary>
/// A nameplate over each <see cref="VillageStation"/>, always on while the town is browsed, so the
/// player can see what is clickable. The plate under the pointer switches to the hover style.
/// </summary>
public partial class StationTags : Control
{
    [Export] public Camera3D Camera { get; set; } = null!;
    [Export] public VillageStation[] Stations { get; set; } = System.Array.Empty<VillageStation>();
    [Export] public StringName TagStyle { get; set; } = "";
    [Export] public StringName HoverStyle { get; set; } = "";
    [Export] public float EdgeMargin { get; set; } = 12f;

    /// <summary>How far past the frame, as a share of the view, a station that pins to the edge still shows its plate.</summary>
    [Export] public float EdgeReach { get; set; } = 0.15f;

    private readonly Dictionary<VillageStation, Label> _tags = new();

    public override void _Ready()
    {
        foreach (var station in Stations)
        {
            string key = station.Action.IsEmpty ? "" : InputNames.KeyLabelFor(station.Action);
            var tag = new Label
            {
                Text = key == "" ? station.Title : $"{station.Title}  {key}",
                ThemeTypeVariation = TagStyle,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            AddChild(tag);
            _tags[station] = tag;
            station.Hovered += (_, over) => tag.ThemeTypeVariation = over ? HoverStyle : TagStyle;
        }
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        var view = new Rect2(Vector2.Zero, Size);
        var near = view.Grow(Mathf.Max(Size.X, Size.Y) * EdgeReach);
        foreach (var (station, tag) in _tags)
        {
            var anchor = station.GlobalPosition + station.TagOffset;
            var point = Camera.UnprojectPosition(anchor);
            tag.Visible = station.IsVisibleInTree() && !Camera.IsPositionBehind(anchor)
                && (station.PinToEdge ? near : view).HasPoint(point);
            tag.Size = tag.GetCombinedMinimumSize();
            // A way out just past the frame keeps its plate on the nearest edge, so it still reads as a way to go.
            var corner = point - new Vector2(tag.Size.X / 2f, tag.Size.Y);
            var limit = Size - tag.Size - new Vector2(EdgeMargin, EdgeMargin);
            tag.Position = corner.Clamp(new Vector2(EdgeMargin, EdgeMargin), limit.Max(Vector2.Zero)).Round();
        }
    }
}
