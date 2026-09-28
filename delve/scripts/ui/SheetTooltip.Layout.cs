using System.Text;
using Delve.Flow;
using Godot;

namespace Delve.UI;

/// <summary>The card's measure, its meta rows, the word wrap and its place beside the anchor.</summary>
public partial class SheetTooltip
{
    /// <summary>
    /// Hold every line to one measure so the panel is a column, not a staircase: the longest line
    /// the tip needs, capped at the reading width. The lines are broken here rather than by
    /// autowrap because a wrapping label only reports the height it needs once it has been laid
    /// out at a width, and the panel has to know its size in the frame it appears.
    /// </summary>
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

    /// <summary>The meta label column: the widest label the tip carries, plus the gap.</summary>
    private int MetaLabelWidth(SheetTip tip)
    {
        float widest = 0f;
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
            widest = Mathf.Max(widest, LineWidth(_metaMeasure, row.Label));
        return widest > 0f ? (int)Mathf.Ceil(widest) + MetaLabelGap : 0;
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
        var pointer = _anchorPoint ?? GetGlobalMousePosition();
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
