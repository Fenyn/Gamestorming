using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Ungilded.Story;

/// <summary>
/// Breaks text into lines of near-equal width. Each paragraph keeps the line count a greedy wrap
/// gives at the full width, then takes the narrowest width that still keeps that count, so no
/// line is left short. Paragraphs are separated by a blank line.
/// </summary>
public static class BalancedWrap
{
    private const string ParagraphBreak = "\n\n";

    public static string Wrap(string text, Font font, int fontSize, float maxWidth)
    {
        var paragraphs = text.Split(ParagraphBreak).Select(p => WrapParagraph(p, font, fontSize, maxWidth));
        return string.Join(ParagraphBreak, paragraphs);
    }

    private static string WrapParagraph(string paragraph, Font font, int fontSize, float maxWidth)
    {
        var words = paragraph.Split(' ', System.StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0) return "";
        int target = Greedy(words, font, fontSize, maxWidth).Count;
        float low = 0f, high = maxWidth;
        while (high - low > 1f)
        {
            float mid = (low + high) / 2f;
            if (Greedy(words, font, fontSize, mid).Count == target) high = mid;
            else low = mid;
        }
        return string.Join("\n", Greedy(words, font, fontSize, high));
    }

    private static List<string> Greedy(string[] words, Font font, int fontSize, float width)
    {
        var lines = new List<string>();
        string current = words[0];
        for (int i = 1; i < words.Length; i++)
        {
            string candidate = current + " " + words[i];
            if (Measure(candidate, font, fontSize) <= width)
                current = candidate;
            else
            {
                lines.Add(current);
                current = words[i];
            }
        }
        lines.Add(current);
        return lines;
    }

    private static float Measure(string text, Font font, int fontSize) =>
        font.GetStringSize(text, HorizontalAlignment.Left, -1, fontSize).X;
}
