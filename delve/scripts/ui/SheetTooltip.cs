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
/// Passive. It shows what <see cref="Request"/> hands it, after the hover has lasted long enough
/// that the reader meant it, and hides the moment the pointer leaves.
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
    private Label _body = null!;
    private Label _footer = null!;
    private Timer _delay = null!;

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
        _body = GetNode<Label>("%Body");
        _footer = GetNode<Label>("%Footer");
        _delay = GetNode<Timer>("%Delay");
        _delay.Timeout += Reveal;
        Visible = false;
    }

    /// <summary>Ask for a tip after the hover delay, or hand null to take the panel away.</summary>
    public void Request(SheetTip? tip, Control? source)
    {
        _delay.Stop();
        _pending = tip;
        _source = source;

        if (tip == null) { Visible = false; return; }
        _delay.Start(DelaySeconds);
    }

    /// <summary>Show a tip now, with no hover and no delay. The rendered shot uses this.</summary>
    public void ShowNow(SheetTip tip, Control? source)
    {
        _delay.Stop();
        _pending = tip;
        _source = source;
        Reveal();
    }

    // ---------------------------------------------------------------- Render

    private void Reveal()
    {
        if (_pending is not { } tip) return;

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

        int labels = MetaLabelWidth(tip);
        int width = Measure(tip, labels);
        FillMeta(tip, width, labels);
        _bodySep.Visible = _body.Visible
            && (_meta.GetChildCount() > 0 || _traitBand.Visible || _subtitle.Visible);

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
            widest = Mathf.Max(widest, LineWidth(_subtitle, row.Label));
        return widest > 0f ? (int)Mathf.Ceil(widest) + MetaLabelGap : 0;
    }

    private int Measure(SheetTip tip, int metaLabels)
    {
        float headline = LineWidth(_title, tip.Title) + CostWidth(tip);
        float widest = Mathf.Max(
            Mathf.Max(headline, LineWidth(_subtitle, tip.Subtitle)),
            Mathf.Max(LineWidth(_body, tip.Body), LineWidth(_footer, tip.Footer ?? "")));
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
            widest = Mathf.Max(widest, metaLabels + LineWidth(_body, row.Text));

        int width = Mathf.Clamp((int)Mathf.Ceil(widest), MinWidth, MaxWidth);
        Line(_title, tip.Title, width);
        Line(_subtitle, tip.Subtitle, width);
        Line(_body, tip.Body, width);
        Line(_footer, tip.Footer ?? "", width);
        return width;
    }

    private float CostWidth(SheetTip tip) => tip.Cost switch
    {
        { Actions: > 0 } c => c.Actions * (_costPips.PipSize.X + 4f) + 8f,
        { Word: not null } c => LineWidth(_costWord, c.Word) + 8f,
        _ => 0f,
    };

    /// <summary>One HBox per meta row: a dim label column, then the wrapped value.</summary>
    private void FillMeta(SheetTip tip, int width, int metaLabels)
    {
        Clear(_meta);
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
        {
            var line = new HBoxContainer();
            line.AddThemeConstantOverride("separation", 0);
            var metaLabel = new Label
            {
                Text = row.Label,
                ThemeTypeVariation = ThemeNames.TipMetaLabel,
                CustomMinimumSize = new Vector2(metaLabels, 0),
                SizeFlagsVertical = SizeFlags.ShrinkBegin,
            };
            if (_accent is { } accent) metaLabel.AddThemeColorOverride("font_color", accent);
            line.AddChild(metaLabel);
            var value = new Label
            {
                Text = Wrap(_body, row.Text, width - metaLabels),
                ThemeTypeVariation = ThemeNames.TipBody,
            };
            value.CustomMinimumSize = new Vector2(width - metaLabels, 0);
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
