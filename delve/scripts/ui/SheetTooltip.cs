using Delve.Flow;
using Godot;

namespace Delve.UI;

/// <summary>
/// The one hover panel the hero sheet explains itself through, laid out as a standardized PF2e
/// stat-block card: title with the action cost beside it, trait chips with a level/rank tag, the
/// meta lines (Trigger, Frequency, Range...), a hairline, the rules text, and a dim numeric
/// footer. Every tip fills only the slots it has; the order never changes, so a feat, a spell and
/// a strike all read from familiar places.
///
/// Hover cards allow a brief pointer crossing into the card for full rules and scrolling.
/// Explicit dismissal from the sheet still hides them immediately.
/// </summary>
public partial class SheetTooltip : PanelContainer
{
    /// <summary>How long the pointer rests before the panel appears. Assigned in
    /// sheet_tooltip.tscn.</summary>
    [Export] public float DelaySeconds { get; set; } = 0.1f;

    /// <summary>The widest the card is allowed to run before text wraps.</summary>
    [Export] public int MaxWidth { get; set; } = 440;

    /// <summary>The narrowest the panel goes, so a two-word tip is not a sliver.</summary>
    [Export] public int MinWidth { get; set; } = 240;

    /// <summary>How far below and to the right of the pointer the panel sits.</summary>
    [Export] public Vector2 PointerOffset { get; set; } = new(16, 16);

    /// <summary>Clearance kept between the panel and the edge of the screen.</summary>
    [Export] public int ScreenMargin { get; set; } = 12;

    private const char NEWLINE = '\n';

    /// <summary>Space between a meta row's label column and its value.</summary>
    private const int MetaLabelGap = 12;

    private Label _title = null!;
    private PipRow _costPips = null!;
    private Label _costWord = null!;
    private Control _traitBand = null!;
    private Control _traits = null!;
    private Label _tag = null!;
    private Label _subtitle = null!;
    private VBoxContainer _meta = null!;
    private Control _bodySep = null!;
    private VBoxContainer _body = null!;
    private Label _bodyMeasure = null!;
    private Label _metaMeasure = null!;
    private Label _footer = null!;
    private Timer _delay = null!;
    private ScrollContainer _scroll = null!;
    private VBoxContainer _content = null!;
    private Button _fullRules = null!;
    private Label _scrollHint = null!;
    private bool _expanded;
    private bool _leaving;
    private float _awaySeconds;

    private SheetTip? _pending;
    private Control? _source;
    private Color? _accent;

    /// <summary>Colour the card's tag and meta labels for the character who owns the page;
    /// null returns them to the theme.</summary>
    public void SetAccent(Color? accent)
    {
        _accent = accent;
        if (accent is { } c) _tag.AddThemeColorOverride("font_color", c);
        else _tag.RemoveThemeColorOverride("font_color");
    }

    public override void _Ready()
    {
        _title = GetNode<Label>("%Title");
        _costPips = GetNode<PipRow>("%CostPips");
        _costWord = GetNode<Label>("%CostWord");
        _traitBand = GetNode<Control>("%TraitBand");
        _traits = GetNode<Control>("%Traits");
        _tag = GetNode<Label>("%Tag");
        _subtitle = GetNode<Label>("%Subtitle");
        _meta = GetNode<VBoxContainer>("%Meta");
        _bodySep = GetNode<Control>("%BodySep");
        _body = GetNode<VBoxContainer>("%Body");
        _bodyMeasure = new Label { ThemeTypeVariation = ThemeNames.TipBody, Visible = false };
        AddChild(_bodyMeasure);
        _metaMeasure = new Label { ThemeTypeVariation = ThemeNames.TipMetaLabel, Visible = false };
        AddChild(_metaMeasure);
        _footer = GetNode<Label>("%Footer");
        _delay = GetNode<Timer>("%Delay");
        _delay.Timeout += Reveal;
        _scroll = GetNode<ScrollContainer>("%Scroll");
        _content = GetNode<VBoxContainer>("%Content");
        _fullRules = GetNode<Button>("%FullRules");
        _scrollHint = GetNode<Label>("%ScrollHint");
        _fullRules.Pressed += () =>
        {
            var at = Position;
            _expanded = !_expanded;
            Reveal();
            var screen = GetViewportRect().Size;
            Position = new Vector2(Mathf.Clamp(at.X, ScreenMargin, Mathf.Max(ScreenMargin, screen.X - Size.X - ScreenMargin)),
                Mathf.Clamp(at.Y, ScreenMargin, Mathf.Max(ScreenMargin, screen.Y - Size.Y - ScreenMargin)));
        };
        Visible = false;
    }

    /// <summary>Ask for a tip after the hover delay, or hand null to take the panel away.</summary>
    public void Request(SheetTip? tip, Control? source)
    {
        _delay.Stop();
        if (tip == null && source != null && source != _source) return;
        if (tip == null && source != null && Visible && source == _source)
        {
            _leaving = true;
            _awaySeconds = 0;
            return;
        }
        if (tip != null && tip == _pending && Visible) return;
        _expanded = false;
        _leaving = false;
        _pending = tip;
        _source = source;

        _anchorPoint = null;
        if (tip == null) { Visible = false; return; }
        _delay.Start(DelaySeconds);
    }

    /// <summary>Show a tip now, with no hover and no delay. The rendered shot uses this.</summary>
    public void ShowNow(SheetTip tip, Control? source)
    {
        _delay.Stop();
        _expanded = false;
        _leaving = false;
        _anchorPoint = null;
        _pending = tip;
        _source = source;
        Reveal();
    }

    /// <summary>Show a tip beside a screen point, for things that are not Controls (a doorway).</summary>
    public void ShowAt(SheetTip tip, Vector2 screenPoint)
    {
        _delay.Stop();
        _expanded = false;
        _leaving = false;
        _source = null;
        _anchorPoint = screenPoint;
        if (Visible && _pending != null && SameContent(tip, _pending)) { Place(); return; }
        _pending = tip;
        Reveal();
    }

    public void HideTip()
    {
        _delay.Stop();
        _pending = null;
        _anchorPoint = null;
        Visible = false;
    }

    /// <summary>Set by <see cref="ShowAt"/>: the panel anchors here instead of the pointer.</summary>
    private Vector2? _anchorPoint;

    // ---------------------------------------------------------------- Render

    public override void _Process(double delta)
    {
        if (!Visible || !_leaving) return;
        var pointer = GetGlobalMousePosition();
        bool inside = GetGlobalRect().HasPoint(pointer)
            || (IsInstanceValid(_source) && _source!.GetGlobalRect().HasPoint(pointer));
        _awaySeconds = inside ? 0 : _awaySeconds + (float)delta;
        if (_awaySeconds > 0.3f) Request(null, null);
    }

    public override void _Input(InputEvent @event)
    {
        if (Visible && @event.IsActionPressed(InputNames.UiCancel))
        {
            _delay.Stop();
            _pending = null;
            _source = null;
            _anchorPoint = null;
            Visible = false;
            GetViewport().SetInputAsHandled();
            return;
        }
        // A reader can scroll without moving off the hovered sheet entry.
        if (!Visible || !_scrollHint.Visible || @event is not InputEventMouseButton { Pressed: true } wheel
            || !IsInstanceValid(_source) || !_source!.GetGlobalRect().HasPoint(GetGlobalMousePosition())) return;
        if (wheel.ButtonIndex != MouseButton.WheelDown && wheel.ButtonIndex != MouseButton.WheelUp) return;
        _scroll.ScrollVertical += wheel.ButtonIndex == MouseButton.WheelDown ? 72 : -72;
        GetViewport().SetInputAsHandled();
    }

    private void Reveal()
    {
        if (_pending is not { } tip) return;
        _fullRules.Visible = tip.FullRules is { Length: > 0 };
        _fullRules.Text = _expanded ? "Back to summary" : "Full rules";
        if (_expanded) tip = tip with { Body = tip.FullRules!, Meta = null };

        _costPips.Visible = tip.Cost is { Actions: > 0 };
        if (tip.Cost is { Actions: > 0 } pips) _costPips.SetCost(pips.Actions, enabled: true);
        _costWord.Visible = tip.Cost is { Word: not null };
        _costWord.Text = tip.Cost?.Word ?? "";

        bool anyTraits = tip.Traits is { Count: > 0 };
        _traitBand.Visible = anyTraits || tip.Tag != null;
        Clear(_traits);
        if (anyTraits)
        {
            foreach (string trait in tip.Traits!)
                _traits.AddChild(TraitChip(trait));
        }
        _tag.Visible = tip.Tag != null;
        _tag.Text = tip.Tag ?? "";

        _subtitle.Visible = tip.Subtitle.Length > 0;
        RenderFigures(tip);
        _body.Visible = tip.Body.Length > 0;
        _footer.Visible = tip.Footer is { Length: > 0 };
        GetNode<Control>("%FooterSep").Visible = _footer.Visible;

        int labels = MetaLabelWidth(tip);
        int width = Measure(tip, labels);
        FillMeta(tip, width, labels);
        Clear(_body);
        foreach (string paragraph in tip.Body.Split(NEWLINE, System.StringSplitOptions.RemoveEmptyEntries))
        {
            var text = new Label { ThemeTypeVariation = ThemeNames.TipBody, MouseFilter = MouseFilterEnum.Ignore };
            _body.AddChild(text);
            Line(text, paragraph, width);
        }
        _bodySep.Visible = _body.Visible
            && (_meta.GetChildCount() > 0 || _traitBand.Visible || _subtitle.Visible);

        _scroll.ScrollVertical = 0;
        _scroll.CustomMinimumSize = Vector2.Zero;
        _scrollHint.Visible = false;
        float overhead = GetNode<Control>("Stack").GetCombinedMinimumSize().Y
            + GetThemeStylebox("panel").GetMinimumSize().Y;
        float available = Mathf.Max(48, Mathf.Min(640, GetViewportRect().Size.Y - ScreenMargin * 2) - overhead - 32);
        float contentHeight = _content.GetCombinedMinimumSize().Y;
        _scrollHint.Visible = contentHeight > available;
        _scroll.CustomMinimumSize = new Vector2(width + 16, Mathf.Min(contentHeight, available));

        Size = Vector2.Zero;
        ResetSize();
        Visible = true;
        Place();
    }
}
