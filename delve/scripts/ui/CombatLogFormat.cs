using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Godot;

namespace Delve.UI;

/// <summary>A log line in both name forms: full names for history, short enemy names for the compact rows.</summary>
public readonly record struct LogText(string Full, string Short)
{
    public string For(bool shortNames) => shortNames ? Short : Full;
}

/// <summary>Formats engine text; names and messages cannot inject BBCode.</summary>
public sealed class CombatLogFormat
{
    /// <summary>Joins the words of one figure group, so a wrapped row never splits "29 vs 17".</summary>
    public const char Tie = ' ';

    private readonly Dictionary<string, Color> _actors = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _short = new(StringComparer.Ordinal);
    private Regex? _tokens;
    public int RollFontSize { get; set; } = 27;

    /// <summary>Trailing words that name a role, so "Goblin Warrior E" shortens to "Goblin E".</summary>
    private static readonly HashSet<string> RoleWords = new(StringComparer.Ordinal)
    {
        "Warrior", "Scout", "Commando", "Chanter", "Archer", "Shaman", "Mage", "Brute", "Captain", "Chief", "Guard",
    };

    public void SetActors(IEnumerable<(string Name, Color Color)> actors)
    {
        _actors.Clear();
        foreach (var (name, color) in actors)
            if (!string.IsNullOrWhiteSpace(name)) _actors[name] = color;
        string names = string.Join("|", _actors.Keys.OrderByDescending(n => n.Length).Select(Regex.Escape));
        _tokens = new Regex((names.Length > 0 ? $@"(?<!\w)(?:{names})(?!\w)|" : "") + @"\b\d+\b");
    }

    public void SetShortNames(IEnumerable<string> enemies)
    {
        _short.Clear();
        foreach (string name in enemies) _short[name] = ShortName(name);
    }

    /// <summary>"Goblin Warrior E" → "Goblin E", "Hunting Spider A" → "Spider A". A name without a
    /// letter stays whole.</summary>
    public static string ShortName(string lettered)
    {
        int space = lettered.LastIndexOf(' ');
        if (space <= 0) return lettered;
        string letter = lettered[(space + 1)..];
        if (letter.Length is < 1 or > 2 || !letter.All(char.IsUpper)) return lettered;
        string[] words = lettered[..space].Split(' ');
        if (words.Length < 2) return lettered;
        string head = RoleWords.Contains(words[^1]) ? words[0] : words[^1];
        return $"{head} {letter}";
    }

    public static string Escape(string text) => text.Replace("[", "[lb]");
    private static string Ink(string text, Color color) => $"[color=#{color.ToHtml()}]{text}[/color]";
    private static string Tied(string text) => text.Replace(' ', Tie);

    public string Text(string text, bool shortNames = false)
    {
        if (_tokens == null) return Escape(text);
        var result = new StringBuilder();
        int cursor = 0;
        foreach (Match token in _tokens.Matches(text))
        {
            result.Append(Escape(text[cursor..token.Index]));
            string shown = shortNames && _short.TryGetValue(token.Value, out var brief) ? brief : token.Value;
            string value = $"[b]{Tied(Escape(shown))}[/b]";
            result.Append(_actors.TryGetValue(token.Value, out var color) ? Ink(value, color) : value);
            cursor = token.Index + token.Length;
        }
        return result.Append(Escape(text[cursor..])).ToString();
    }

    private LogText Both(Func<bool, string> format) => new(format(false), format(true));

    public string Entry(string message, int severity, bool detail)
    {
        var roll = CombatRoll.Parse(message);
        if (roll != null)
        {
            string badge = Ink($"[b]{roll.Outcome}[/b]", Severity(severity));
            string math = $"{Text(roll.Prefix)}{Number(roll.Die)}{Text(roll.Modifiers)} = {Number(roll.Total)} vs {roll.Defense} {Number(roll.DcText)}";
            return $"{badge}  {Tied(math)}";
        }
        string formatted = Text(message);
        if (severity == 8) return formatted;
        string marker = Marker(severity);
        if (marker.Length > 0) return $"{Ink($"[b]{marker}[/b]", Severity(severity))}  {formatted}";
        return detail && severity is >= 1 and <= 4 ? Ink(formatted, Severity(severity)) : formatted;
    }

    private static string Marker(int severity) => severity switch {
        2 => "CRITICAL", 5 => "HEAL", 6 => "CONDITION", 7 => "RECOVERED", 9 => "REACTION", _ => "",
    };

    /// <summary>The outcome group of a compact row: "CRIT 29 vs 17".</summary>
    private string CompactRoll(CombatRoll roll, int severity)
        => Tied($"{Ink($"[b]{roll.ShortOutcome}[/b]", Severity(severity))} [b]{roll.Total}[/b] vs [b]{roll.DcText}[/b]");

    public string Turn(string name) => $"[b]{Text(name)}'s turn[/b]";

    private static readonly Regex StrikeTitle = new(@"^(.+?) Strikes (.+?) with .+$");
    private static readonly Regex Effect = new(@"^(.+?) (takes|regains) (\d+)(.*?) (?:damage|HP)\.?$");

    /// <summary>The one-line form of an action title: "Aldric → Spider A" for a Strike.</summary>
    public LogText CompactTitle(string message)
    {
        var strike = StrikeTitle.Match(message);
        return Both(brief => strike.Success
            ? $"{Text(strike.Groups[1].Value, brief)}{Tie}→{Tie}{Text(strike.Groups[2].Value, brief)}"
            : Text(message, brief));
    }

    /// <summary>The longest known actor name that <paramref name="text"/> starts with.</summary>
    public string? LeadingActor(string text)
        => _actors.Keys.Where(name => text.StartsWith(name, StringComparison.Ordinal))
            .OrderByDescending(name => name.Length).FirstOrDefault();

    /// <summary>The creature a Strike title names as its target, or "".</summary>
    public static string StrikeTarget(string message)
    {
        var strike = StrikeTitle.Match(message);
        return strike.Success ? strike.Groups[2].Value : "";
    }

    /// <summary>A detail line cut to its figures. A damage or healing line drops the creature's name
    /// when the action title or the previous line already names it. <paramref name="lead"/> is true for
    /// a roll, which leads the compact row.</summary>
    public LogText Summary(string message, int severity, ref string subject, out bool lead)
    {
        lead = false;
        if (CombatRoll.Parse(message) is { } roll)
        {
            lead = true;
            string figures = CompactRoll(roll, severity);
            return new(figures, figures);
        }
        var effect = Effect.Match(message);
        if (effect.Success)
        {
            string who = effect.Groups[1].Value;
            string amount = Tied((effect.Groups[2].Value == "regains" ? "+" : "") + effect.Groups[3].Value
                + (effect.Groups[2].Value == "regains" ? " HP" : effect.Groups[4].Value));
            bool named = who != subject;
            subject = who;
            return Both(brief => named ? $"{Text(who, brief)} [b]{amount}[/b]" : $"[b]{amount}[/b]");
        }
        subject = LeadingActor(message) ?? subject;
        if (severity is >= 1 and <= 7 or 9)
        {
            string trimmed = message.TrimEnd('.');
            string marker = Marker(severity);
            return Both(brief =>
            {
                string formatted = Text(trimmed, brief);
                return marker.Length > 0 ? $"{Ink($"[b]{marker}[/b]", Severity(severity))}  {formatted}"
                    : severity is >= 1 and <= 4 ? Ink(formatted, Severity(severity)) : formatted;
            });
        }
        return new("", "");
    }

    private static Color Severity(int severity)
        => severity >= 0 && severity < UiColors.LogSeverity.Length ? UiColors.LogSeverity[severity] : UiColors.Text;
    private string Number(int number) => Number(number.ToString());
    private string Number(string number) => $"[font_size={RollFontSize}][b]{number}[/b][/font_size]";

    private static readonly Regex UsesTitle = new(@"^.+? uses .+? against (.+?) with .+$");

    /// <summary>The creature an attack title names as its target ("Strikes Y with", "uses X against Y with"), or "".</summary>
    public static string AttackTarget(string message)
    {
        string strike = StrikeTarget(message);
        if (strike.Length > 0) return strike;
        var uses = UsesTitle.Match(message);
        return uses.Success ? uses.Groups[1].Value : "";
    }
}
