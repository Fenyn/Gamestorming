using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace Bulwark.Data.Dialogues;

/// <summary>
/// Loads all dialogue JSON files from a directory, indexes them by id, and provides query methods
/// for sequences and talk pools. Plain C#, no Godot dependency (uses System.IO for file loading;
/// the caller globalizes the Godot res:// path before constructing).
/// </summary>
public sealed class DialogueDatabase
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    private readonly Dictionary<string, DialogueFile> _byId = new();
    private readonly Dictionary<string, DialogueFile> _talkPoolsByChar = new();

    /// <summary>All loaded dialogue ids.</summary>
    public IReadOnlyCollection<string> AllIds => _byId.Keys;

    /// <summary>Number of loaded dialogue files.</summary>
    public int Count => _byId.Count;

    /// <summary>
    /// Create a database by loading all .json files from <paramref name="directoryPath"/> recursively.
    /// Missing or empty directory is a clean no-op (the baseline shipped state).
    /// </summary>
    public DialogueDatabase(string directoryPath)
    {
        if (string.IsNullOrEmpty(directoryPath) || !Directory.Exists(directoryPath))
            return;

        foreach (string file in Directory.EnumerateFiles(directoryPath, "*.json", SearchOption.AllDirectories))
        {
            try
            {
                string json = File.ReadAllText(file);
                var dialogue = JsonSerializer.Deserialize<DialogueFile>(json, JsonOpts);
                if (dialogue == null || string.IsNullOrEmpty(dialogue.Id))
                    continue;

                _byId[dialogue.Id] = dialogue;

                if (dialogue.Type == DialogueType.TalkPool && !string.IsNullOrEmpty(dialogue.Character))
                    _talkPoolsByChar[dialogue.Character] = dialogue;
            }
            catch (Exception)
            {
                // Skip malformed files silently (framework tolerance).
            }
        }
    }

    /// <summary>Look up a sequence by id.</summary>
    public bool TryGetSequence(string id, out DialogueFile seq)
    {
        if (_byId.TryGetValue(id, out var file) && file.Type == DialogueType.Sequence)
        {
            seq = file;
            return true;
        }
        seq = null!;
        return false;
    }

    /// <summary>
    /// From the character's talk pool, find the highest-priority entry whose conditions pass.
    /// Returns the lines of that entry, or null if no talk pool exists or no entry passes.
    /// </summary>
    public List<DialogueLine>? GetTalkLines(string charId, DialogueConditionContext ctx)
    {
        if (!_talkPoolsByChar.TryGetValue(charId, out var pool) || pool.Entries == null)
            return null;

        TalkPoolEntry? best = null;
        foreach (var entry in pool.Entries)
        {
            if (!DialogueConditionContext.EvaluateCondition(entry.Conditions, ctx))
                continue;
            if (best == null || entry.Priority > best.Priority)
                best = entry;
        }

        return best?.Lines;
    }

    /// <summary>
    /// Check whether a dialogue id exists and its conditions pass (without loading/playing it).
    /// Also checks the seen-dialogue gate for once-only sequences.
    /// </summary>
    public bool IsAvailable(string id, DialogueConditionContext ctx)
    {
        if (!_byId.TryGetValue(id, out var file))
            return false;
        if (file.Once && ctx.HasSeenDialogue(id))
            return false;
        return DialogueConditionContext.EvaluateCondition(file.Conditions, ctx);
    }

    /// <summary>Look up any dialogue file by id (sequence or talk pool).</summary>
    public bool TryGet(string id, out DialogueFile file)
        => _byId.TryGetValue(id, out file!);

    /// <summary>Whether a talk pool exists for the given character.</summary>
    public bool HasTalkPool(string charId) => _talkPoolsByChar.ContainsKey(charId);
}
