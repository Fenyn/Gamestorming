using System.Collections.Generic;
using System;
using System.Text;
using System.Text.RegularExpressions;

namespace Delve.Data;

/// <summary>
/// Turns a Foundry pack description into a sentence a tooltip can print. The importer already
/// removes HTML tags, but it leaves the enrichers Foundry resolves at display time - @UUID links,
/// @Damage and @Check macros, inline rolls - so a raw description reads as markup. This resolves
/// each enricher to the words it stands for and collapses the leftover whitespace.
///
/// Godot-free: the sheet spike reads the same text the tooltip prints.
/// </summary>
public static class PackText
{
    /// <summary>An enricher that already carries the words to show: "@UUID[...]{Stupefied 2}".</summary>
    private static readonly Regex Labelled = new(
        @"@\w+\[(?:[^\[\]]|\[[^\[\]]*\])*\]\{([^}]*)\}", RegexOptions.Compiled);

    /// <summary>An enricher with no label, so the words come out of its argument.</summary>
    private static readonly Regex Bare = new(
        @"@(\w+)\[((?:[^\[\]]|\[[^\[\]]*\])*)\]", RegexOptions.Compiled);

    /// <summary>An inline roll with a label: "[[/r 1d4 #rounds]]{1d4 rounds}".</summary>
    private static readonly Regex LabelledRoll = new(@"\[\[[^\]]*\]\]\{([^}]*)\}", RegexOptions.Compiled);

    /// <summary>A bare inline roll: "[[/r 2d6]]".</summary>
    private static readonly Regex Roll = new(@"\[\[/[a-z]+\s*([^\]]*)\]\]", RegexOptions.Compiled);

    /// <summary>A bold-led block: "&lt;p&gt;&lt;strong&gt;Critical Success&lt;/strong&gt; ...". The label
    /// becomes a lead-in on its own line.</summary>
    private static readonly Regex LeadIn = new(
        @"<p>\s*<strong>\s*([^<]+?)\s*</strong>\s*", RegexOptions.Compiled);

    /// <summary>Paragraph and section boundaries.</summary>
    private static readonly Regex Break = new(@"</p>|<hr\s*/?>|<br\s*/?>", RegexOptions.Compiled);

    /// <summary>List items become bullet lines.</summary>
    private static readonly Regex Bullet = new(@"<li>", RegexOptions.Compiled);

    private static readonly Regex Tag = new(@"<[^>]+>", RegexOptions.Compiled);
    private static readonly Regex Whitespace = new(@"\s+", RegexOptions.Compiled);

    /// <summary>
    /// Pack prose as readable lines, cut to <paramref name="maxChars"/> on a word boundary. The
    /// pack's own structure survives as line breaks - each paragraph, hr section, list item and
    /// bold-led block ("Critical Success ...") gets its own line - and a paragraph that still runs
    /// long is split at sentence boundaries, so a card body reads as short statements rather than
    /// one brick of text.
    /// </summary>
    public static string Plain(string? source, int maxChars = 600)
    {
        if (string.IsNullOrWhiteSpace(source)) return "";

        string text = Labelled.Replace(source, m => m.Groups[1].Value);
        text = LabelledRoll.Replace(text, m => m.Groups[1].Value);
        text = Bare.Replace(text, m => Resolve(m.Groups[1].Value, m.Groups[2].Value));
        text = Roll.Replace(text, m => m.Groups[1].Value);

        // Structure to line breaks BEFORE tags are stripped.
        text = LeadIn.Replace(text, m => "\n" + m.Groups[1].Value + " — ");
        text = Break.Replace(text, "\n");
        text = Bullet.Replace(text, "\n• ");
        text = Tag.Replace(text, " ");
        text = Entities(text);

        var lines = new List<string>();
        foreach (string raw in text.Split('\n'))
        {
            string line = Whitespace.Replace(raw, " ").Trim();
            if (line.Length == 0) continue;
            if (line.Length <= LongLine || line.StartsWith("• ", StringComparison.Ordinal))
            {
                lines.Add(line);
                continue;
            }
            foreach (string sentence in Sentences(line)) lines.Add(sentence);
        }

        // Packs often end with a bare link label ("Bastion") - a stub line with no sentence
        // punctuation and nothing to say. Drop it.
        if (lines.Count > 1)
        {
            string tail = lines[^1];
            if (!tail.Contains('.') && !tail.StartsWith("• ", StringComparison.Ordinal)
                && tail.Split(' ').Length <= 3)
            {
                lines.RemoveAt(lines.Count - 1);
            }
        }

        return Cap(string.Join("\n", lines), maxChars);
    }

    /// <summary>A paragraph longer than this splits into one sentence per line.</summary>
    private const int LongLine = 160;

    /// <summary>Split on sentence ends; abbreviations the packs use do not end sentences.</summary>
    private static IEnumerable<string> Sentences(string line)
    {
        var current = new StringBuilder();
        for (int i = 0; i < line.Length; i++)
        {
            current.Append(line[i]);
            bool stop = line[i] == '.' && i + 1 < line.Length && line[i + 1] == ' '
                && !line.EndsWith("ft.", StringComparison.Ordinal)
                && !line.EndsWith("pg.", StringComparison.Ordinal);
            if (!stop) continue;
            yield return current.ToString().Trim();
            current.Clear();
            i++;
        }
        if (current.Length > 0) yield return current.ToString().Trim();
    }

    /// <summary>
    /// The first sentence of pack prose, for a line that has room for one. Falls back to the
    /// capped whole when the text carries no sentence break.
    /// </summary>
    public static string Sentence(string? source, int maxChars = 200)
    {
        string text = Plain(source, 0);
        if (text.Length == 0) return "";

        // The first sentence of the first line: a structural break ends the sentence too.
        int line = text.IndexOf('\n');
        if (line > 0) text = text[..line];
        int stop = text.IndexOf(". ", StringComparison.Ordinal);
        if (stop > 0) text = text[..(stop + 1)];
        return Cap(text, maxChars);
    }

    /// <summary>
    /// The plain words of one bold-labelled lead paragraph - the packs write
    /// "&lt;p&gt;&lt;strong&gt;Trigger&lt;/strong&gt; An enemy hits you...&lt;/p&gt;" ahead of the
    /// rules text. Empty when the description has no such block.
    /// </summary>
    public static string MetaBlock(string? html, string label)
    {
        if (string.IsNullOrEmpty(html)) return "";
        var m = MetaPattern(label).Match(html);
        return m.Success ? Plain(m.Groups[1].Value, 300) : "";
    }

    /// <summary>The description with every bold-labelled lead paragraph removed, so the card's
    /// body does not repeat what its meta rows already show.</summary>
    public static string WithoutMetaBlocks(string? html)
    {
        if (string.IsNullOrEmpty(html)) return "";
        foreach (string label in MetaLabels)
            html = MetaPattern(label).Replace(html, "");
        return html;
    }

    private static readonly string[] MetaLabels =
        { "Trigger", "Requirements", "Frequency", "Prerequisites", "Cost", "Access" };

    private static Regex MetaPattern(string label) => new(
        $@"<p>\s*<strong>\s*{label}\s*</strong>(.*?)</p>",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.Singleline);

    /// <summary>Cut long prose on a word boundary and mark that it was cut.</summary>
    public static string Cap(string text, int maxChars)
    {
        if (maxChars <= 0 || text.Length <= maxChars) return text;

        int cut = text.LastIndexOf(' ', maxChars - 1);
        if (cut < maxChars / 2) cut = maxChars - 1;
        return text[..cut].TrimEnd(' ', ',', ';', '.') + "…";
    }

    /// <summary>The pack's slug for a display name: "Breathe Fire" reaches "breathe-fire".</summary>
    public static string Slug(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "";

        var slug = new StringBuilder(name.Length);
        foreach (char c in name.ToLowerInvariant())
        {
            if (char.IsLetterOrDigit(c)) slug.Append(c);
            else if (c == ' ') slug.Append('-');
        }
        return slug.ToString();
    }

    // ---------------------------------------------------------------- Enrichers

    /// <summary>The words behind one unlabelled enricher. An unknown kind falls back to its first
    /// argument, which is the readable half of every macro the packs use.</summary>
    private static string Resolve(string kind, string argument) => kind.ToLowerInvariant() switch
    {
        "uuid" => LastSegment(argument),
        "damage" => argument.Replace('[', ' ').Replace("]", "").Trim(),
        "check" => $"{Capitalize(First(argument))} save",
        "template" => Template(argument),
        _ => First(argument),
    };

    /// <summary>"Compendium.pf2e.conditionitems.Item.Stupefied" names Stupefied.</summary>
    private static string LastSegment(string reference)
    {
        int dot = reference.LastIndexOf('.');
        return dot < 0 ? reference : reference[(dot + 1)..];
    }

    /// <summary>"burst|distance:15" is a 15-foot burst.</summary>
    private static string Template(string argument)
    {
        string shape = First(argument);
        foreach (string part in argument.Split('|'))
        {
            if (part.StartsWith("distance:")) return $"{part[9..]}-foot {shape}";
        }
        return shape;
    }

    private static string First(string argument)
    {
        int bar = argument.IndexOf('|');
        return bar < 0 ? argument : argument[..bar];
    }

    private static string Capitalize(string word)
        => word.Length == 0 ? word : char.ToUpperInvariant(word[0]) + word[1..];

    private static string Entities(string text) => text
        .Replace("&nbsp;", " ")
        .Replace("&amp;", "&")
        .Replace("&lt;", "<")
        .Replace("&gt;", ">")
        .Replace("&quot;", "\"")
        .Replace("&#39;", "'")
        .Replace("&rsquo;", "'");
}
