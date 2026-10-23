using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using Ungilded.Autoload;

namespace Ungilded.Story;

/// <summary>
/// The tutorial tip layer. A rule tip (<see cref="ShowRule"/>, <see cref="ShowMessage"/>) is modal
/// with Continue; its task completes on dismiss, and rule tips queue behind each other. A step tip
/// (<see cref="OpenStep"/>) has no button and stays until its handle is disposed; it holds no modal,
/// and clicks inside its cutout reach the HUD and the board. Rule tips show before step tips, and
/// the newest step tip covers older ones. A tip with a focus dims the screen around the focus
/// quads and sits beside them with a pointer; an undimmed one only outlines them, and as a step tip
/// it lets every click through. Each unit the focus names gets an ember arrow drawn over the dim
/// (<see cref="TipArrows"/>), left out while it would cover a HUD panel, and the box keeps clear of
/// the unit and its arrow. A focus
/// of units alone shows no dim and sits beside them; as a step tip it lets every click through. A
/// tip without a focus shows centred with no dim. The per-frame layout is in
/// TutorialPopup.Layout.cs.
/// </summary>
public partial class TutorialPopup : CanvasLayer
{
    /// <summary>True when a rule tip comes on screen, false when the last one leaves.</summary>
    public event Action<bool>? ShowingChanged;

    /// <summary>True when a tip of either kind comes on screen, false when the last one leaves.</summary>
    public event Action<bool>? AnyTipChanged;

    /// <summary>True while a rule tip (modal) shows.</summary>
    public bool IsShowing { get; private set; }

    /// <summary>True while a step tip shows.</summary>
    public bool StepShowing => _shown is { Step: true };

    /// <summary>The tip on screen, or null.</summary>
    public TipRecord? Current => _shown?.Record;

    /// <summary>Every tip opened so far, in order.</summary>
    public IReadOnlyList<TipRecord> Records => _records;

    /// <summary>The ember accent from the story theme, for highlighted words.</summary>
    public Color HighlightColor => _root.GetThemeColor(EmberColor, StoryPaletteType);

    /// <summary>Width of a focused tip's box. A centred tip keeps the scene's panel size.</summary>
    [Export] public float TipWidth { get; set; } = 660f;

    /// <summary>Pixels between the cutout and the box.</summary>
    [Export] public float Gap { get; set; } = 32f;

    /// <summary>Pixels the box keeps from the screen edges.</summary>
    [Export] public float ScreenMargin { get; set; } = 16f;

    [Export] public float PointerLength { get; set; } = 22f;

    /// <summary>Pixels the pointer keeps from the box corners.</summary>
    [Export] public float PointerInset { get; set; } = 28f;

    /// <summary>Frames a new tip takes to lay out before its checks count.</summary>
    [Export] public int SettleFrames { get; set; } = 3;

    /// <summary>Pixels between the box positions tried when placing a tip.</summary>
    [Export] public float PlacementStep { get; set; } = 16f;

    /// <summary>Steps past the gap a box may move away from its cutout to clear a HUD panel.</summary>
    [Export] public int PlacementMaxPush { get; set; } = 8;

    /// <summary>Cost of one square pixel of box over a HUD panel, against one pixel of distance.</summary>
    [Export] public float PanelOverlapWeight { get; set; } = 100f;

    private const string StoryPaletteType = "StoryPalette";
    private const string EmberColor = "ember";
    private const string BorderColor = "panel_border";

    private sealed class Tip
    {
        public required TipRequest Request;
        public required bool Step;
        public required TipRecord Record;
        public TaskCompletionSource Done { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    }

    private Control _root = null!;
    private SpotlightDim _dim = null!;
    private TipPointer _pointer = null!;
    private PanelContainer _panel = null!;
    private RichTextLabel _text = null!;
    private Button _continue = null!;
    private readonly List<Tip> _rules = new();
    private readonly List<Tip> _steps = new();
    private readonly List<TipRecord> _records = new();
    private readonly List<Vector2[]> _quads = new();
    private readonly TipClearance _clear = new();
    private TipArrows _arrows = null!;
    private readonly List<Rect2> _panels = new();
    private readonly List<Rect2> _anchors = new();
    private readonly List<Vector2> _shownMarks = new();
    private Tip? _shown;
    private bool _placed;
    private bool _live;

    private float _anchorLeft, _anchorRight, _anchorTop, _anchorBottom;
    private float _offsetLeft, _offsetRight, _offsetTop, _offsetBottom;

    public override void _Ready()
    {
        _root = GetNode<Control>("%Root");
        _dim = GetNode<SpotlightDim>("%Dim");
        _pointer = GetNode<TipPointer>("%Pointer");
        _panel = GetNode<PanelContainer>("%Panel");
        _text = GetNode<RichTextLabel>("%Text");
        _continue = GetNode<Button>("%Continue");
        (_anchorLeft, _anchorRight, _anchorTop, _anchorBottom) = (_panel.AnchorLeft, _panel.AnchorRight, _panel.AnchorTop, _panel.AnchorBottom);
        (_offsetLeft, _offsetRight, _offsetTop, _offsetBottom) = (_panel.OffsetLeft, _panel.OffsetRight, _panel.OffsetTop, _panel.OffsetBottom);
        _arrows = GetNode<TipArrows>("%Arrows");
        _dim.OutlineColor = HighlightColor;
        _arrows.Tint = HighlightColor;
        _pointer.Fill = _root.GetThemeColor(BorderColor, StoryPaletteType);
        _root.Visible = false;
        _continue.Pressed += Dismiss;
    }

    /// <summary>A centred rule tip of <paramref name="bbcode"/>, after any queued one. Completes on dismiss.</summary>
    public Task ShowMessage(string bbcode) => ShowRule(new TipRequest("", bbcode));

    /// <summary>A rule tip, after any queued one. Completes on dismiss.</summary>
    public Task ShowRule(TipRequest request)
    {
        var tip = NewTip(request, step: false);
        _rules.Add(tip);
        Refresh();
        return tip.Done.Task;
    }

    /// <summary>A step tip. It shows once no rule tip is queued and stays until the handle is disposed.</summary>
    public TipHandle OpenStep(TipRequest request)
    {
        var tip = NewTip(request, step: true);
        _steps.Add(tip);
        Refresh();
        return new TipHandle(() => Close(tip));
    }

    /// <summary>Wrap <paramref name="text"/> in a BBCode colour tag with <see cref="HighlightColor"/>.</summary>
    public string Highlight(string text) => $"[color=#{HighlightColor.ToHtml(false)}]{text}[/color]";

    /// <summary>Close the rule tip on screen, as Continue does. A step tip does not dismiss.</summary>
    public void Dismiss()
    {
        if (_shown is { Step: false } tip) Close(tip);
    }

    /// <summary>True when <paramref name="point"/> (canvas pixels) lies in the shown tip's cutout.</summary>
    public bool CutoutContains(Vector2 point) => _dim.CutoutContains(point);

    /// <summary>True when a click at <paramref name="point"/> (canvas pixels) reaches the HUD and the
    /// board under the tip layer.</summary>
    public bool PassesClick(Vector2 point)
        => !_root.Visible || !_dim.TakesClick(point)
            && (_panel.MouseFilter == Control.MouseFilterEnum.Ignore || !_panel.GetGlobalRect().HasPoint(point));

    private Tip NewTip(TipRequest request, bool step)
    {
        var record = new TipRecord { Id = request.Id, Step = step, Focused = request.Resolve != null, Dimmed = request.Dimmed };
        _records.Add(record);
        return new Tip { Request = request, Step = step, Record = record };
    }

    private void Close(Tip tip)
    {
        if (!_rules.Remove(tip) && !_steps.Remove(tip)) return;
        tip.Record.Closed = true;
        Refresh();
        tip.Done.TrySetResult();
    }

    /// <summary>Show the tip that should be on screen: the first rule tip, else the newest step tip.</summary>
    private void Refresh()
    {
        var next = _rules.Count > 0 ? _rules[0] : _steps.Count > 0 ? _steps[^1] : null;
        if (next == _shown) return;
        var previous = _shown;
        _shown = next;
        previous?.Request.Hidden?.Invoke();
        _root.Visible = next != null;
        if (next != null) Present(next);
        SetModal(next is { Step: false });
        if ((previous == null) != (next == null)) AnyTipChanged?.Invoke(next != null);
        next?.Request.Shown?.Invoke();
    }

    private void SetModal(bool modal)
    {
        if (modal == IsShowing) return;
        IsShowing = modal;
        if (modal) ModalStack.Instance?.Push(this);
        else ModalStack.Instance?.Pop(this);
        ShowingChanged?.Invoke(modal);
    }

    private void Present(Tip tip)
    {
        _text.Text = tip.Request.Bbcode;
        _continue.Visible = !tip.Step;
        _dim.PassThrough = tip.Step;
        // An undimmed step tip leaves the screen live, so neither the dim nor the box takes a click.
        _live = tip.Step && !tip.Request.Dimmed;
        _dim.PassAll = _live;
        _panel.MouseFilter = _live ? Control.MouseFilterEnum.Ignore : Control.MouseFilterEnum.Stop;
        _arrows.SetMarks(System.Array.Empty<Vector2>());
        _placed = false;
        if (tip.Request.Resolve == null && tip.Request.Panels == null) Centre();
        else
        {
            // A centred tip that knows the HUD keeps the scene panel's width and moves up or down
            // off the panels; a focused tip is narrower and sits beside its cutout.
            _dim.SetCutout(null, dimmed: false);
            _pointer.Clear();
            _panel.SetAnchorsPreset(Control.LayoutPreset.TopLeft);
            _panel.CustomMinimumSize = new Vector2(tip.Request.Resolve == null ? _offsetRight - _offsetLeft : FocusedWidth(tip), 0);
            _panel.Size = _panel.CustomMinimumSize;
        }
        Layout();
        if (!tip.Step) _continue.GrabFocus();
    }

    /// <summary>The scene's own centred panel, no dim, no pointer.</summary>
    private void Centre()
    {
        _panel.CustomMinimumSize = Vector2.Zero;
        (_panel.AnchorLeft, _panel.AnchorRight, _panel.AnchorTop, _panel.AnchorBottom) = (_anchorLeft, _anchorRight, _anchorTop, _anchorBottom);
        (_panel.OffsetLeft, _panel.OffsetRight, _panel.OffsetTop, _panel.OffsetBottom) = (_offsetLeft, _offsetRight, _offsetTop, _offsetBottom);
        _dim.SetCutout(null, dimmed: false);
        _pointer.Clear();
    }
}
