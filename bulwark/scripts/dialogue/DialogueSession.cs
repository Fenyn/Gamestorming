using System;
using System.Collections.Generic;
using Bulwark.Data.Dialogues;

using Bulwark.Cozy;
namespace Bulwark.Dialogue;

/// <summary>
/// Owns the live dialogue/cutscene session state (design/dialogue.md): the once-only SEEN set, the
/// "a sequence is playing" flag, and the start/end/mark commands over the shared
/// <see cref="DialogueDatabase"/>. Plain C# and unit-testable; GameState keeps thin forwarders and
/// re-exposes <see cref="DialogueStarted"/> / <see cref="DialogueEnded"/> through its event hub.
///
/// The seen set is persisted: <see cref="Seen"/> is captured by the save pipeline and
/// <see cref="Restore"/> reloads it (null clears to "nothing seen" — the new-game and pre-v9-save
/// path). The condition context is built here from the injected flag / hearts / calendar seams so the
/// same live state gates dialogue conditions and once-only replay.
/// </summary>
public sealed class DialogueSession
{
    private readonly DialogueDatabase _db;
    private readonly Func<string, bool> _hasFlag;
    private readonly Func<string, int> _getHearts;
    private readonly DayClock _clock;

    /// <summary>Dialogue ids that have been seen (once-only sequences never replay).</summary>
    private readonly HashSet<string> _seen = new();

    /// <summary>True while a dialogue sequence is actively playing.</summary>
    public bool IsDialogueActive { get; private set; }

    /// <summary>Raised when a dialogue sequence starts playing, with the dialogue id.</summary>
    public event Action<string>? DialogueStarted;

    /// <summary>Raised when a dialogue sequence finishes playing.</summary>
    public event Action? DialogueEnded;

    /// <param name="db">The loaded dialogue database (empty database = the shipped no-op baseline).</param>
    /// <param name="hasFlag">Derived + real flag resolver (dialogue condition context).</param>
    /// <param name="getHearts">Friendship heart lookup (dialogue condition context).</param>
    /// <param name="clock">Calendar source for the season condition.</param>
    public DialogueSession(DialogueDatabase db, Func<string, bool> hasFlag, Func<string, int> getHearts, DayClock clock)
    {
        _db = db ?? throw new ArgumentNullException(nameof(db));
        _hasFlag = hasFlag ?? throw new ArgumentNullException(nameof(hasFlag));
        _getHearts = getHearts ?? throw new ArgumentNullException(nameof(getHearts));
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
    }

    /// <summary>Query: the dialogue database (for talk-pool queries by the world scene).</summary>
    public DialogueDatabase Db => _db;

    /// <summary>The seen dialogue ids (for save capture).</summary>
    public IReadOnlyCollection<string> Seen => _seen;

    // ===================== Commands =====================

    /// <summary>
    /// Start a dialogue sequence by id. Validates the sequence exists, conditions pass, and it has not
    /// been seen (if once-only). Returns false (clean reject) otherwise. On success fires
    /// <see cref="DialogueStarted"/> and sets <see cref="IsDialogueActive"/>. The caller (world scene)
    /// wires the runner to a dialogue box and a cutscene director.
    /// </summary>
    public bool StartDialogue(string sequenceId)
    {
        if (string.IsNullOrEmpty(sequenceId))
            return false;
        if (!_db.TryGetSequence(sequenceId, out var seq))
            return false;
        if (seq.Once && _seen.Contains(sequenceId))
            return false;
        if (!DialogueConditionContext.EvaluateCondition(seq.Conditions, BuildConditionContext()))
            return false;

        IsDialogueActive = true;
        DialogueStarted?.Invoke(sequenceId);
        return true;
    }

    /// <summary>
    /// Start a talk-pool dialogue for a character. Returns false if no talk pool exists or no entry
    /// passes conditions (caller falls back to toast). On success fires <see cref="DialogueStarted"/>.
    /// </summary>
    public bool StartTalkDialogue(string charId)
    {
        if (string.IsNullOrEmpty(charId))
            return false;
        var lines = _db.GetTalkLines(charId, BuildConditionContext());
        if (lines == null || lines.Count == 0)
            return false;

        IsDialogueActive = true;
        DialogueStarted?.Invoke($"talk:{charId}");
        return true;
    }

    /// <summary>Called by the dialogue system when a sequence ends.</summary>
    public void EndDialogue()
    {
        IsDialogueActive = false;
        DialogueEnded?.Invoke();
    }

    /// <summary>Query: whether a dialogue id has been seen (for once-only gating).</summary>
    public bool HasSeenDialogue(string id) => _seen.Contains(id);

    /// <summary>Mark a dialogue as seen (called by the runner when a once-only sequence ends).</summary>
    public void MarkDialogueSeen(string id)
    {
        if (!string.IsNullOrEmpty(id))
            _seen.Add(id);
    }

    /// <summary>Build a condition context from the current game state.</summary>
    public DialogueConditionContext BuildConditionContext() => new()
    {
        HasFlag = _hasFlag,
        GetHearts = _getHearts,
        CurrentSeason = _clock.Season.ToString().ToLowerInvariant(),
        HasSeenDialogue = HasSeenDialogue,
    };

    // ===================== Save / restore =====================

    /// <summary>
    /// Overwrite the seen set from a save (or clear it). Null (a pre-v9 save or a new game) clears to
    /// "nothing seen" — once-only sequences replay. Byte-identical to the previous inline restore:
    /// null-or-empty ids are skipped.
    /// </summary>
    public void Restore(IEnumerable<string>? ids)
    {
        _seen.Clear();
        if (ids == null)
            return;
        foreach (var id in ids)
            if (!string.IsNullOrEmpty(id))
                _seen.Add(id);
    }
}
