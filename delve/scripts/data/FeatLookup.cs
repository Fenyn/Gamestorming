using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace Delve.Data;

/// <summary>
/// One pack feat or class feature, with the card-relevant fields the engine's own
/// CharacterFeature does not carry: how it is paid for, its traits, and how often it can be used.
/// <see cref="DescriptionHtml"/> is the raw pack HTML - Trigger/Requirements paragraphs and all -
/// for <see cref="PackText"/> to split.
/// </summary>
public sealed record FeatEntry(
    string Slug,
    string ActionType,
    int Actions,
    IReadOnlyList<string> Traits,
    string? Frequency,
    int Level,
    string DescriptionHtml);

/// <summary>
/// Slug lookup over the pack's feats and class-features folders. Pack files are named by their
/// slug, so the index is one directory walk of file names; a file is opened and parsed only when
/// its feat is actually asked for, then cached. Pure C# - the pack root comes in from DataManager.
/// </summary>
public static class FeatLookup
{
    private static readonly Dictionary<string, string> Paths = new();
    private static readonly Dictionary<string, FeatEntry?> Cache = new();

    /// <summary>Folders holding feat-shaped items, relative to the pack root.</summary>
    private static readonly string[] Folders = { "feats", "class-features" };

    public static int IndexedCount => Paths.Count;

    /// <summary>Walk the pack once and remember where every slug lives. Safe to call again.</summary>
    public static void Index(string dataRoot)
    {
        Paths.Clear();
        Cache.Clear();
        foreach (string folder in Folders)
        {
            string dir = Path.Combine(dataRoot, folder);
            if (!Directory.Exists(dir)) continue;
            foreach (string file in Directory.EnumerateFiles(dir, "*.json", SearchOption.AllDirectories))
            {
                string slug = Path.GetFileNameWithoutExtension(file);
                // The feats folder wins over class-features on a slug collision: the feat card is
                // the one the sheet links from.
                if (folder == Folders[0] || !Paths.ContainsKey(slug)) Paths[slug] = file;
            }
        }
    }

    /// <summary>The pack entry for this slug, parsed on first use, or null.</summary>
    public static FeatEntry? Find(string slug)
    {
        if (string.IsNullOrEmpty(slug)) return null;
        if (Cache.TryGetValue(slug, out var cached)) return cached;
        if (!Paths.TryGetValue(slug, out string? file)) return Cache[slug] = null;

        try
        {
            return Cache[slug] = Parse(slug, File.ReadAllText(file));
        }
        catch (Exception)
        {
            // A malformed pack file downgrades to "no pack data", never to a crash mid-hover.
            return Cache[slug] = null;
        }
    }

    private static FeatEntry Parse(string slug, string json)
    {
        using var doc = JsonDocument.Parse(json);
        var system = doc.RootElement.GetProperty("system");

        string actionType = Value(system, "actionType") ?? "passive";
        int actions = int.TryParse(Value(system, "actions"), out int n) ? n : 0;
        int level = int.TryParse(Value(system, "level"), out int lvl) ? lvl : 0;
        string html = Value(system, "description") ?? "";

        var traits = new List<string>();
        if (system.TryGetProperty("traits", out var traitsEl)
            && traitsEl.TryGetProperty("value", out var list) && list.ValueKind == JsonValueKind.Array)
        {
            foreach (var t in list.EnumerateArray())
            {
                if (t.GetString() is { Length: > 0 } trait) traits.Add(trait);
            }
        }

        return new FeatEntry(slug, actionType, actions, traits, Frequency(system), level, html);
    }

    /// <summary>"once per turn" from the pack's {max, per} frequency object, when present.</summary>
    private static string? Frequency(JsonElement system)
    {
        if (!system.TryGetProperty("frequency", out var freq)
            || freq.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        int max = freq.TryGetProperty("max", out var maxEl) && maxEl.TryGetInt32(out int m) ? m : 1;
        string per = freq.TryGetProperty("per", out var perEl) ? perEl.GetString() ?? "" : "";
        string times = max == 1 ? "once" : max == 2 ? "twice" : $"{max} times";
        return per.Length > 0 ? $"{times} per {PerNoun(per)}" : times;
    }

    /// <summary>The pack encodes the period as an ISO-ish token ("PT1M", "turn", "round", "day").</summary>
    private static string PerNoun(string per) => per switch
    {
        "turn" => "turn",
        "round" => "round",
        "day" => "day",
        "PT1M" => "minute",
        "PT10M" => "10 minutes",
        "PT1H" => "hour",
        "P1D" => "day",
        _ => per,
    };

    /// <summary>system.X.value as a string, tolerating numbers; null when absent.</summary>
    private static string? Value(JsonElement system, string property)
    {
        if (!system.TryGetProperty(property, out var el)) return null;
        if (el.ValueKind == JsonValueKind.Object && el.TryGetProperty("value", out var inner)) el = inner;
        return el.ValueKind switch
        {
            JsonValueKind.String => el.GetString(),
            JsonValueKind.Number => el.GetRawText(),
            _ => null,
        };
    }
}
