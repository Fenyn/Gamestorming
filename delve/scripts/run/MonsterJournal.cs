using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using PF2e.Data;

namespace Delve.Run;

/// <summary>
/// Campaign-wide creature knowledge, keyed by species slug. A species is listed once it enters a
/// fight; Recall Knowledge reveals its fields one at a time in <see cref="KnowledgeRevealOrder"/>.
/// Nothing is learned passively. Godot-free; persisted inside <see cref="CampaignProgress"/>.
/// </summary>
public sealed class MonsterJournal : ICreatureKnowledgeProvider
{
    private sealed class Entry
    {
        public string Name = "";
        public CreatureKnowledgeField Revealed;
    }

    private readonly Dictionary<string, Entry> _entries = new();

    /// <summary>Raised after a species is first encountered or learns a field.</summary>
    public event Action? Changed;

    public static int TotalFields => KnowledgeRevealOrder.Fields.Count;

    public static string Key(string? creatureId) => CreatureSlug.Normalize(creatureId);

    public bool IsFieldRevealed(string creatureId, CreatureKnowledgeField field)
    {
        var known = CreatureKnowledgeField.Name;
        if (_entries.TryGetValue(Key(creatureId), out var entry)) known |= entry.Revealed;
        return (known & field) == field;
    }

    public bool IsEncountered(string creatureId) => _entries.ContainsKey(Key(creatureId));

    public bool IsComplete(string creatureId) => KnownCount(creatureId) == TotalFields;

    public int KnownCount(string creatureId)
        => _entries.TryGetValue(Key(creatureId), out var entry)
            ? KnowledgeRevealOrder.Fields.Count(row => (entry.Revealed & row.Field) != 0) : 0;

    public string NameFor(string creatureId) => _entries.TryGetValue(Key(creatureId), out var e) ? e.Name : "";

    /// <summary>Encountered species as (slug, name), by name.</summary>
    public IReadOnlyList<(string Id, string Name)> Encountered
        => _entries.OrderBy(pair => pair.Value.Name, StringComparer.OrdinalIgnoreCase)
            .Select(pair => (pair.Key, pair.Value.Name)).ToArray();

    /// <summary>List a species. True when it was new.</summary>
    public bool MarkEncountered(string? creatureId, string name)
    {
        string key = Key(creatureId);
        if (key.Length == 0 || _entries.ContainsKey(key)) return false;
        _entries[key] = new Entry { Name = string.IsNullOrWhiteSpace(name) ? key : name };
        Changed?.Invoke();
        return true;
    }

    /// <summary>Apply one Recall Knowledge result: the next unknown fields in order, as many as the
    /// degree allows. Returns the fields revealed now, empty on a failure.</summary>
    public IReadOnlyList<CreatureKnowledgeField> Reveal(string? creatureId, DegreeOfSuccess degree, string name = "")
    {
        int count = KnowledgeRevealOrder.RevealCount(degree);
        string key = Key(creatureId);
        if (count == 0 || key.Length == 0) return Array.Empty<CreatureKnowledgeField>();
        if (!_entries.TryGetValue(key, out var entry))
            _entries[key] = entry = new Entry { Name = string.IsNullOrWhiteSpace(name) ? key : name };
        var revealed = new List<CreatureKnowledgeField>();
        foreach (var row in KnowledgeRevealOrder.Fields)
        {
            if (revealed.Count == count) break;
            if ((entry.Revealed & row.Field) != 0) continue;
            entry.Revealed |= row.Field;
            revealed.Add(row.Field);
        }
        if (revealed.Count > 0) Changed?.Invoke();
        return revealed;
    }

    public Dictionary<string, JournalEntryData> Capture() => _entries.ToDictionary(
        pair => pair.Key,
        pair => new JournalEntryData
        {
            Name = pair.Value.Name,
            Fields = KnowledgeRevealOrder.Fields.Where(row => (pair.Value.Revealed & row.Field) != 0)
                .Select(row => row.Field.ToString()).ToArray(),
        });

    public static MonsterJournal Restore(Dictionary<string, JournalEntryData>? data)
    {
        var journal = new MonsterJournal();
        foreach (var (id, saved) in data ?? new())
        {
            string key = Key(id);
            if (key.Length == 0 || saved == null) continue;
            var entry = new Entry { Name = string.IsNullOrWhiteSpace(saved.Name) ? key : saved.Name };
            foreach (string field in saved.Fields ?? Array.Empty<string>())
                if (Enum.TryParse(field, out CreatureKnowledgeField parsed)
                    && KnowledgeRevealOrder.Fields.Any(row => row.Field == parsed))
                    entry.Revealed |= parsed;
            journal._entries[key] = entry;
        }
        return journal;
    }
}

public sealed class JournalEntryData
{
    public string Name { get; set; } = "";
    public string[] Fields { get; set; } = Array.Empty<string>();
}
