using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Godot;

namespace Delve.UI;

/// <summary>Formats engine text; names and messages cannot inject BBCode.</summary>
public sealed class CombatLogFormat
{
    private readonly Dictionary<string, Color> _actors = new(StringComparer.Ordinal);
    private Regex? _tokens;
    public int RollFontSize { get; set; } = 26;

    public void SetActors(IEnumerable<(string Name, Color Color)> actors)
    {
        _actors.Clear();
        foreach (var (name, color) in actors)
            if (!string.IsNullOrWhiteSpace(name)) _actors[name] = color;
        string names = string.Join("|", _actors.Keys.OrderByDescending(n => n.Length).Select(Regex.Escape));
        _tokens = new Regex((names.Length > 0 ? $@"(?<!\w)(?:{names})(?!\w)|" : "") + @"\b\d+\b");
    }

    public static string Escape(string text) => text.Replace("[", "[lb]");
    private static string Ink(string text, Color color) => $"[color=#{color.ToHtml()}]{text}[/color]";

    public string Text(string text)
    {
        if (_tokens == null) return Escape(text);
        var result = new StringBuilder();
        int cursor = 0;
        foreach (Match token in _tokens.Matches(text))
        {
            result.Append(Escape(text[cursor..token.Index]));
            string value = $"[b]{Escape(token.Value)}[/b]";
            result.Append(_actors.TryGetValue(token.Value, out var color) ? Ink(value, color) : value);
            cursor = token.Index + token.Length;
        }
        return result.Append(Escape(text[cursor..])).ToString();
    }

    public string Entry(string message, int severity, bool detail, bool compact = false)
    {
        var roll = CombatRoll.Parse(message);
        if (roll != null)
        {
            string badge = Ink($"[b]{roll.Outcome}[/b]", Severity(severity));
            if (compact) return badge;
            string math = $"{Text(roll.Prefix)}{Number(roll.Die)}{Text(roll.Modifiers)} = {Number(roll.Total)} vs {roll.Defense} {Number(roll.DC)}";
            return $"{badge}  {math}";
        }
        string formatted = Text(message);
        if (severity == 8) return formatted;
        string marker = severity switch {
            2 => "CRITICAL", 5 => "HEAL", 6 => "CONDITION", 7 => "RECOVERED", 9 => "REACTION", _ => "",
        };
        if (marker.Length > 0) return $"{Ink($"[b]{marker}[/b]", Severity(severity))}  {formatted}";
        return detail && severity is >= 1 and <= 4 ? Ink(formatted, Severity(severity)) : formatted;
    }

    public string Turn(string name) => $"[b]{Text(name)}'s turn[/b]";
    public string Summary(string message, int severity)
    {
        if (CombatRoll.Parse(message) != null) return Entry(message, severity, true, true);
        var effect = Regex.Match(message, @"(?:takes|regains) (\d+.*?)(?:\.|$)");
        return effect.Success ? Text(message.TrimEnd('.')) : "";
    }
    private static Color Severity(int severity)
        => severity >= 0 && severity < UiColors.LogSeverity.Length ? UiColors.LogSeverity[severity] : UiColors.Text;
    private string Number(int number) => $"[font_size={RollFontSize}][b]{number}[/b][/font_size]";
}
