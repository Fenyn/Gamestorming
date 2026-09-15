using System.Text;
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

        if (tip == null) { Visible = false; return; }
        _delay.Start(DelaySeconds);
    }

    /// <summary>Show a tip now, with no hover and no delay. The rendered shot uses this.</summary>
    public void ShowNow(SheetTip tip, Control? source)
    {
        _delay.Stop();
        _expanded = false;
        _leaving = false;
        _pending = tip;
        _source = source;
        Reveal();
    }

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

    /// <summary>
    /// Hold every line to one measure so the panel is a column, not a staircase: the longest line
    /// the tip needs, capped at the reading width. The lines are broken here rather than by
    /// autowrap because a wrapping label only reports the height it needs once it has been laid
    /// out at a width, and the panel has to know its size in the frame it appears.
    /// </summary>
    /// <summary>The meta label column: the widest label the tip carries, plus the gap.</summary>
    private int MetaLabelWidth(SheetTip tip)
    {
        float widest = 0f;
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
            widest = Mathf.Max(widest, LineWidth(_metaMeasure, row.Label));
        return widest > 0f ? (int)Mathf.Ceil(widest) + MetaLabelGap : 0;
    }

    private int Measure(SheetTip tip, int metaLabels)
    {
        float headline = LineWidth(_title, tip.Title) + CostWidth(tip);
        float widest = Mathf.Max(
            Mathf.Max(headline, LineWidth(_subtitle, tip.Subtitle)),
            Mathf.Max(LineWidth(_bodyMeasure, tip.Body), LineWidth(_footer, tip.Footer ?? "")));
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
            widest = Mathf.Max(widest, metaLabels + LineWidth(_bodyMeasure, row.Text));

        int limit = Mathf.Max(80, Mathf.Min(MaxWidth,
            (int)GetViewportRect().Size.X - ScreenMargin * 2 - 48));
        int width = Mathf.Clamp((int)Mathf.Ceil(widest), Mathf.Min(MinWidth, limit), limit);
        Line(_title, tip.Title, Mathf.Max(1, width - (int)Mathf.Ceil(CostWidth(tip))));
        Line(_subtitle, tip.Subtitle, width);
        Line(_footer, tip.Footer ?? "", width);
        return width;
    }

    private float CostWidth(SheetTip tip) => tip.Cost switch
    {
        { Actions: > 0 } c => c.Actions * (_costPips.PipSize.X + 4f) + 8f,
        { Word: not null } c => LineWidth(_costWord, c.Word) + 8f,
        _ => 0f,
    };

    /// <summary>Short values share a label column; prose gets a full-width section below its label.</summary>
    private void FillMeta(SheetTip tip, int width, int metaLabels)
    {
        Clear(_meta);
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
        {
            bool stacked = tip.FullRules != null || LineWidth(_bodyMeasure, row.Text) > width - metaLabels;
            BoxContainer line = stacked ? new VBoxContainer() : new HBoxContainer();
            line.MouseFilter = MouseFilterEnum.Ignore;
            line.AddThemeConstantOverride("separation", stacked ? 4 : 0);
            if (stacked && _meta.GetChildCount() > 0)
                _meta.AddChild(new HSeparator { MouseFilter = MouseFilterEnum.Ignore });
            var metaLabel = new Label
            {
                Text = row.Label,
                ThemeTypeVariation = ThemeNames.TipMetaLabel,
                CustomMinimumSize = new Vector2(stacked ? 0 : metaLabels, 0),
                MouseFilter = MouseFilterEnum.Ignore,
                SizeFlagsVertical = SizeFlags.ShrinkBegin,
            };
            if (_accent is { } accent) metaLabel.AddThemeColorOverride("font_color", accent);
            line.AddChild(metaLabel);
            var value = new Label
            {
                Text = Wrap(_bodyMeasure, row.Text, stacked ? width : width - metaLabels),
                ThemeTypeVariation = ThemeNames.TipBody,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            value.CustomMinimumSize = new Vector2(stacked ? width : width - metaLabels, 0);
            line.AddChild(value);
            _meta.AddChild(line);
        }
        _meta.Visible = _meta.GetChildCount() > 0;
    }

    /// <summary>A maroon trait chip, PF2e stat-block style.</summary>
    private static PanelContainer TraitChip(string label)
    {
        var chip = new PanelContainer { ThemeTypeVariation = ThemeNames.TraitChip };
        chip.AddChild(new Label { Text = label, ThemeTypeVariation = ThemeNames.ChipLabel });
        return chip;
    }

    private static void Clear(Node host)
    {
        foreach (var child in host.GetChildren())
        {
            host.RemoveChild(child);
            child.QueueFree();
        }
    }

    /// <summary>Break one label's text to the shared measure and hold it there.</summary>
    private static void Line(Label label, string text, int width)
    {
        label.Text = Wrap(label, text, width);
        label.CustomMinimumSize = new Vector2(width, 0);
    }

    /// <summary>Greedy word wrap at a pixel measure. Line breaks already in the text - a spell
    /// group lists one spell per line - survive the wrap. A word wider than the measure keeps its
    /// own line rather than being broken.</summary>
    private static string Wrap(Label label, string text, int width)
    {
        if (text.Length == 0) return text;

        var font = label.GetThemeFont("font");
        int size = label.GetThemeFontSize("font_size");
        var wrapped = new StringBuilder(text.Length + 16);

        foreach (string source in text.Split(NEWLINE))
        {
            if (wrapped.Length > 0) wrapped.Append(NEWLINE);
            WrapLine(font, size, source, width, wrapped);
        }
        return wrapped.ToString();
    }

    private static void WrapLine(
        Font font, int size, string text, int width, StringBuilder wrapped)
    {
        var line = new StringBuilder(64);
        foreach (string word in text.Split(' '))
        {
            if (word.Length == 0) continue;
            string candidate = line.Length == 0 ? word : $"{line} {word}";
            if (line.Length > 0
                && font.GetStringSize(candidate, HorizontalAlignment.Left, -1, size).X > width)
            {
                wrapped.Append(line).Append(NEWLINE);
                line.Clear();
                line.Append(word);
                continue;
            }
            line.Clear();
            line.Append(candidate);
        }
        wrapped.Append(line);
    }

    /// <summary>The widest single line the text already contains, before wrapping.</summary>
    private static float LineWidth(Label label, string text)
    {
        if (text.Length == 0) return 0f;

        var font = label.GetThemeFont("font");
        int size = label.GetThemeFontSize("font_size");
        float widest = 0f;
        foreach (string line in text.Split(NEWLINE))
            widest = Mathf.Max(widest, font.GetStringSize(line, HorizontalAlignment.Left, -1, size).X);
        return widest;
    }

    /// <summary>
    /// Below and to the right of the pointer, or below the element itself when the pointer is not
    /// on it. A panel that would run off the bottom flips above its anchor rather than being
    /// clamped up over the thing it explains - a tooltip covering its own subject explains nothing.
    /// </summary>
    private void Place()
    {
        var screen = GetViewportRect().Size;
        var pointer = GetGlobalMousePosition();
        bool onSource = _source == null || _source.GetGlobalRect().HasPoint(pointer);
        var anchor = onSource
            ? new Rect2(pointer, Vector2.Zero)
            : _source!.GetGlobalRect();

        var at = new Vector2(
            anchor.Position.X + (onSource ? PointerOffset.X : 0f),
            anchor.End.Y + PointerOffset.Y);
        if (at.Y + Size.Y > screen.Y - ScreenMargin)
            at.Y = anchor.Position.Y - PointerOffset.Y - Size.Y;

        at.X = Mathf.Clamp(at.X, ScreenMargin, Mathf.Max(ScreenMargin, screen.X - Size.X - ScreenMargin));
        at.Y = Mathf.Clamp(at.Y, ScreenMargin, Mathf.Max(ScreenMargin, screen.Y - Size.Y - ScreenMargin));
        Position = at;
    }
}
