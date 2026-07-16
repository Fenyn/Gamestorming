using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Bulwark.Data.Dialogues;

/// <summary>Discriminator for the top-level dialogue file type.</summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum DialogueType
{
    Sequence,
    TalkPool,
}

/// <summary>
/// Top-level POCO for a single JSON dialogue file. Discriminated by <see cref="Type"/>:
/// <see cref="DialogueType.Sequence"/> carries <see cref="Steps"/>;
/// <see cref="DialogueType.TalkPool"/> carries <see cref="Entries"/>.
/// </summary>
public sealed class DialogueFile
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("type")]
    public DialogueType Type { get; set; }

    /// <summary>Character id for talk pools (which character this pool belongs to).</summary>
    [JsonPropertyName("character")]
    public string? Character { get; set; }

    [JsonPropertyName("conditions")]
    public DialogueCondition? Conditions { get; set; }

    /// <summary>When true, the sequence plays at most once (tracked via seen-dialogue set).</summary>
    [JsonPropertyName("once")]
    public bool Once { get; set; }

    /// <summary>Steps for a Sequence-type dialogue.</summary>
    [JsonPropertyName("steps")]
    public List<DialogueStep>? Steps { get; set; }

    /// <summary>Entries for a TalkPool-type dialogue.</summary>
    [JsonPropertyName("entries")]
    public List<TalkPoolEntry>? Entries { get; set; }
}

/// <summary>One entry in a talk pool: a priority-ordered set of lines gated by conditions.</summary>
public sealed class TalkPoolEntry
{
    [JsonPropertyName("priority")]
    public int Priority { get; set; }

    [JsonPropertyName("conditions")]
    public DialogueCondition? Conditions { get; set; }

    [JsonPropertyName("lines")]
    public List<DialogueLine> Lines { get; set; } = new();
}

/// <summary>A single spoken line (speaker + text + optional emotion). Used in talk pools.</summary>
public sealed class DialogueLine
{
    [JsonPropertyName("speaker")]
    public string Speaker { get; set; } = "";

    [JsonPropertyName("text")]
    public string Text { get; set; } = "";

    /// <summary>Emotion tag for portrait selection. Defaults to "neutral" when absent.</summary>
    [JsonPropertyName("emotion")]
    public string? Emotion { get; set; }
}

/// <summary>
/// One step in a dialogue sequence. The <see cref="Type"/> field discriminates between line,
/// choice, and staging commands. All other fields are optional and type-dependent.
/// </summary>
public sealed class DialogueStep
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "";

    [JsonPropertyName("speaker")]
    public string? Speaker { get; set; }

    [JsonPropertyName("text")]
    public string? Text { get; set; }

    [JsonPropertyName("emotion")]
    public string? Emotion { get; set; }

    [JsonPropertyName("options")]
    public List<DialogueOption>? Options { get; set; }

    [JsonPropertyName("direction")]
    public string? Direction { get; set; }

    [JsonPropertyName("duration")]
    public float? Duration { get; set; }

    [JsonPropertyName("actor")]
    public string? Actor { get; set; }

    [JsonPropertyName("marker")]
    public string? Marker { get; set; }

    [JsonPropertyName("speed")]
    public float? Speed { get; set; }

    [JsonPropertyName("seconds")]
    public float? Seconds { get; set; }

    /// <summary>Story flag to set (for "flag" step type).</summary>
    [JsonPropertyName("set")]
    public string? Set { get; set; }

    /// <summary>Character id for friendship effects.</summary>
    [JsonPropertyName("character")]
    public string? Character { get; set; }

    /// <summary>Friendship point amount for friendship effects.</summary>
    [JsonPropertyName("amount")]
    public int? Amount { get; set; }
}

/// <summary>One player choice in a choice step.</summary>
public sealed class DialogueOption
{
    [JsonPropertyName("text")]
    public string Text { get; set; } = "";

    [JsonPropertyName("conditions")]
    public DialogueCondition? Conditions { get; set; }

    [JsonPropertyName("effects")]
    public List<StepEffect>? Effects { get; set; }

    /// <summary>Inline continuation steps played after this choice before resuming the parent.</summary>
    [JsonPropertyName("steps")]
    public List<DialogueStep>? Steps { get; set; }

    /// <summary>Jump to another dialogue sequence by id (for longer branches).</summary>
    [JsonPropertyName("next_id")]
    public string? NextId { get; set; }
}

/// <summary>An effect applied by a choice option or step.</summary>
public sealed class StepEffect
{
    /// <summary>"friendship", "flag", or "item".</summary>
    [JsonPropertyName("type")]
    public string Type { get; set; } = "";

    [JsonPropertyName("character")]
    public string? Character { get; set; }

    [JsonPropertyName("amount")]
    public int? Amount { get; set; }

    [JsonPropertyName("set")]
    public string? Set { get; set; }

    [JsonPropertyName("item_id")]
    public string? ItemId { get; set; }

    [JsonPropertyName("quantity")]
    public int? Quantity { get; set; }
}

/// <summary>
/// Condition gate for sequences, talk pool entries, and choice options. All fields are optional;
/// an absent or empty condition always passes.
/// </summary>
public sealed class DialogueCondition
{
    /// <summary>Character id to minimum heart level. All must be met.</summary>
    [JsonPropertyName("hearts")]
    public Dictionary<string, int>? Hearts { get; set; }

    /// <summary>Story flags that must all be set.</summary>
    [JsonPropertyName("flags_required")]
    public List<string>? FlagsRequired { get; set; }

    /// <summary>Story flags that must NOT be set (any set flag blocks).</summary>
    [JsonPropertyName("flags_blocked")]
    public List<string>? FlagsBlocked { get; set; }

    /// <summary>Required season (null = any season).</summary>
    [JsonPropertyName("season")]
    public string? Season { get; set; }
}
