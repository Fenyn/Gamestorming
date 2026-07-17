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

/// <summary>
/// One entry in a talk pool: a priority-ordered set of lines gated by conditions. Optionally
/// latches <see cref="Effects"/> (e.g. a story flag) and/or offers player <see cref="Choices"/>
/// when it plays, reusing the exact same <see cref="StepEffect"/> / <see cref="DialogueOption"/>
/// vocabulary that dialogue sequences use. Entries with neither field are plain line-only talks
/// (the historical shape) — both fields are optional and absent by default, so existing JSON loads
/// unchanged.
/// </summary>
public sealed class TalkPoolEntry
{
    [JsonPropertyName("priority")]
    public int Priority { get; set; }

    [JsonPropertyName("conditions")]
    public DialogueCondition? Conditions { get; set; }

    [JsonPropertyName("lines")]
    public List<DialogueLine> Lines { get; set; } = new();

    /// <summary>
    /// Effects latched when this entry plays (e.g. set a story flag on first talk). Same
    /// vocabulary as sequence choice options — flag / friendship / item. Applied once, up front,
    /// before the entry's lines are shown (Stardew-style: talking latches immediately). Absent =>
    /// no effects.
    /// </summary>
    [JsonPropertyName("effects")]
    public List<StepEffect>? Effects { get; set; }

    /// <summary>
    /// Optional player choices presented after the entry's lines. Reuses the sequence
    /// <see cref="DialogueOption"/> shape (text + per-option effects / inline steps / next_id) and
    /// renders through the same DialogueBox choice UI. When present, the entry's LAST line becomes
    /// the choice prompt; author at least one line to anchor it. Absent => a plain line-only talk.
    /// </summary>
    [JsonPropertyName("choices")]
    public List<DialogueOption>? Choices { get; set; }

    /// <summary>
    /// Flatten this talk entry into the <see cref="DialogueStep"/> list the shared
    /// <see cref="Bulwark.Cozy.DialogueRunner"/> executes. Entry-level <see cref="Effects"/> become
    /// leading immediate effect steps; each line becomes a "line" step; when <see cref="Choices"/>
    /// are present the last line becomes a "choice" step carrying them. Pure data transform — no
    /// Godot dependency — so it is unit-testable via the dialogue spike.
    /// </summary>
    public List<DialogueStep> ToSteps()
    {
        var steps = new List<DialogueStep>();

        if (Effects != null)
        {
            foreach (var effect in Effects)
                steps.Add(effect.ToStep());
        }

        bool hasChoices = Choices != null && Choices.Count > 0;
        for (int i = 0; i < Lines.Count; i++)
        {
            DialogueLine line = Lines[i];
            bool isPrompt = hasChoices && i == Lines.Count - 1;
            steps.Add(new DialogueStep
            {
                Type = isPrompt ? "choice" : "line",
                Speaker = line.Speaker,
                Text = line.Text,
                Emotion = line.Emotion ?? "neutral",
                Options = isPrompt ? Choices : null,
            });
        }

        // Choices authored without any line to anchor the prompt: emit a bare choice step so the
        // options still render rather than being silently dropped.
        if (hasChoices && Lines.Count == 0)
            steps.Add(new DialogueStep { Type = "choice", Options = Choices });

        return steps;
    }
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

    /// <summary>Item id to grant (for the "item" effect step type).</summary>
    [JsonPropertyName("item_id")]
    public string? ItemId { get; set; }

    /// <summary>Item quantity to grant (defaults to 1 when absent, for "item" steps).</summary>
    [JsonPropertyName("quantity")]
    public int? Quantity { get; set; }

    /// <summary>Audio stream path for the "sfx" staging step (e.g. <c>res://assets/sfx/wolf_howl.ogg</c>).
    /// Loaded and played one-shot by the cutscene director; a missing asset degrades to a warning and
    /// an immediate staging completion so an authored-but-not-yet-produced sound never stalls a cutscene.</summary>
    [JsonPropertyName("sound")]
    public string? Sound { get; set; }
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

    /// <summary>
    /// Project this effect onto an equivalent immediate <see cref="DialogueStep"/> (type "flag",
    /// "friendship", or "item"), so entry-level talk effects run through the same runner path as
    /// sequence effect steps rather than a parallel application system.
    /// </summary>
    public DialogueStep ToStep() => new()
    {
        Type = Type,
        Character = Character,
        Amount = Amount,
        Set = Set,
        ItemId = ItemId,
        Quantity = Quantity,
    };
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
