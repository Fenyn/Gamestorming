using System.Collections.Generic;
using Godot;

namespace Ungilded.Story;

/// <summary>Each frame's layout of the shown tip: resolve its focus, cut it out, place the box and
/// the pointer, and record what the spikes check.</summary>
public partial class TutorialPopup
{
    /// <summary>Pixels added to a measured line so the label does not wrap its last word.</summary>
    [Export] public float TextSlack { get; set; } = 8f;

    private static readonly StringName NormalFont = "normal_font";
    private static readonly StringName NormalFontSize = "normal_font_size";
    private static readonly StringName PanelStyle = "panel";

    public override void _Process(double delta)
    {
        if (_shown != null) Layout();
    }

    /// <summary>A focused tip's width: <see cref="TipWidth"/>, or less for a step tip whose text
    /// fits on one shorter line, so a short instruction fits beside its cutout.</summary>
    private float FocusedWidth(Tip tip)
    {
        if (!tip.Step) return TipWidth;
        var font = _text.GetThemeFont(NormalFont);
        int size = _text.GetThemeFontSize(NormalFontSize);
        float line = font.GetStringSize(_text.GetParsedText(), HorizontalAlignment.Left, -1, size).X;
        float frame = _panel.GetThemeStylebox(PanelStyle).GetMinimumSize().X;
        return Mathf.Min(TipWidth, Mathf.Ceil(line + frame + TextSlack));
    }

    /// <summary>Resolve the focus, cut it out, draw the unit arrows and put the box beside it, clear
    /// of the arrows too. A focus that resolves to keep-clear rects only (named units) has nothing to
    /// cut out: the dim lifts, a step tip lets every click through, and the box sits beside those
    /// rects. With nothing resolved the dim
    /// lifts and the box stays where it was. A tip with no focus that knows the HUD moves up or
    /// down off its panels.</summary>
    private void Layout()
    {
        var tip = _shown!;
        var record = tip.Record;
        record.FramesShown++;
        bool counts = record.FramesShown > SettleFrames;
        var screen = _root.GetGlobalRect();
        _panels.Clear();
        tip.Request.Panels?.Invoke(_panels);
        var space = new TipSpace(screen, Gap, ScreenMargin, PlacementStep, PlacementMaxPush, PanelOverlapWeight, _panels);
        if (tip.Request.Resolve is not { } resolve)
        {
            if (tip.Request.Panels == null) return;
            _panel.Size = _panel.CustomMinimumSize;
            _panel.Position = TipPlacement.PlaceCentred(space, _panel.Size, _offsetTop);
            NotePanels(record, new Rect2(_panel.Position, _panel.Size), counts);
            return;
        }
        _quads.Clear();
        _clear.Reset();
        resolve(_quads, _clear);
        // An arrow over a HUD panel would read as pointing at the panel; the unit gets it once the
        // panel moves off.
        _shownMarks.Clear();
        foreach (var mark in _clear.Marks)
        {
            var arrow = _arrows.ArrowRect(mark);
            if (TipPlacement.Covers(arrow, _panels)) continue;
            _shownMarks.Add(mark);
            _clear.Add(arrow);
        }
        _arrows.SetMarks(_shownMarks);
        record.MostArrows = Mathf.Max(record.MostArrows, _shownMarks.Count);
        bool marksOnly = _quads.Count == 0;
        _dim.PassAll = _live || tip.Step && marksOnly && _clear.Count > 0;
        if (marksOnly && _clear.Count == 0)
        {
            _dim.SetCutout(null, dimmed: false);
            _pointer.Clear();
            if (!_placed) _panel.Position = (screen.Size - _panel.Size) / 2;
            if (counts) record.FramesUnresolved++;
            return;
        }
        _anchors.Clear();
        if (marksOnly) _anchors.AddRange(_clear);
        else foreach (var quad in _quads) _anchors.Add(QuadBounds(quad));
        // Board cutouts can run past the screen edge; the box only needs to clear what shows.
        var full = Bounds(_anchors);
        var bounds = full.Intersection(screen);
        _dim.SetCutout(marksOnly ? null : _quads, tip.Request.Dimmed && !marksOnly);
        _panel.Size = _panel.CustomMinimumSize;
        var layout = TipPlacement.Place(space, bounds, _clear, bounds.GetCenter(), _panel.Size, PointerLength, PointerInset);
        _panel.Position = layout.BoxPosition;
        _placed = true;
        var box = new Rect2(layout.BoxPosition, _panel.Size);
        // With several cutouts or marks the pointer aims at the one nearest the box.
        var (pointerBase, pointerTip) = TipPlacement.Pointer(box, layout.Side, NearestCentre(_anchors, box.GetCenter(), screen),
            PointerLength, PointerInset);
        _pointer.Point(pointerBase, pointerTip);

        record.LastCutout = bounds;
        record.LastBox = box;
        if (bounds.Area > 0 && screen.HasPoint(full.GetCenter())) record.FramesResolved++;
        else if (counts) record.FramesUnresolved++;
        if (!counts) return;
        if (!screen.Encloses(box)) record.FramesOffScreen++;
        if (box.Intersects(bounds) || TipPlacement.Covers(box, _clear)) record.FramesOverlap++;
        NotePanels(record, box, counts);
    }

    private void NotePanels(TipRecord record, Rect2 box, bool counts)
    {
        if (!counts) return;
        float area = TipPlacement.Overlap(box, _panels);
        if (area <= 0) return;
        record.FramesPanelOverlap++;
        record.MostPanelOverlap = Mathf.Max(record.MostPanelOverlap, area);
    }

    /// <summary>The on-screen centre of the rect nearest <paramref name="from"/>.</summary>
    private static Vector2 NearestCentre(List<Rect2> rects, Vector2 from, Rect2 screen)
    {
        var best = from;
        float distance = float.PositiveInfinity;
        foreach (var rect in rects)
        {
            var visible = rect.Intersection(screen);
            if (visible.Area <= 0) continue;
            var centre = visible.GetCenter();
            float d = centre.DistanceSquaredTo(from);
            if (d >= distance) continue;
            distance = d;
            best = centre;
        }
        return best;
    }

    private static Rect2 Bounds(List<Rect2> rects)
    {
        var bounds = rects[0];
        foreach (var rect in rects) bounds = bounds.Merge(rect);
        return bounds;
    }

    private static Rect2 QuadBounds(Vector2[] quad)
    {
        var rect = new Rect2(quad[0], Vector2.Zero);
        foreach (var corner in quad) rect = rect.Expand(corner);
        return rect;
    }
}
