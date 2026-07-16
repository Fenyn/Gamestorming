using System;

namespace Bulwark.Data.Dialogues;

/// <summary>
/// View-model carrying the current game state needed for dialogue condition evaluation. Built from
/// GameState at query time — the dialogue system never reads GameState directly. Pure C#, no Godot.
/// </summary>
public sealed class DialogueConditionContext
{
    /// <summary>Whether a story flag is set.</summary>
    public required Func<string, bool> HasFlag { get; init; }

    /// <summary>Current friendship hearts for a character.</summary>
    public required Func<string, int> GetHearts { get; init; }

    /// <summary>Current season name (lowercase: "spring", "summer", "autumn", "winter"), or null.</summary>
    public string? CurrentSeason { get; init; }

    /// <summary>Whether a dialogue id has been seen (for once-only gating).</summary>
    public required Func<string, bool> HasSeenDialogue { get; init; }

    /// <summary>
    /// Evaluate a condition against this context. A null or empty condition always passes.
    /// </summary>
    public static bool EvaluateCondition(DialogueCondition? cond, DialogueConditionContext ctx)
    {
        if (cond == null)
            return true;

        if (cond.Hearts != null)
        {
            foreach (var (charId, minHearts) in cond.Hearts)
            {
                if (ctx.GetHearts(charId) < minHearts)
                    return false;
            }
        }

        if (cond.FlagsRequired != null)
        {
            foreach (string flag in cond.FlagsRequired)
            {
                if (!string.IsNullOrEmpty(flag) && !ctx.HasFlag(flag))
                    return false;
            }
        }

        if (cond.FlagsBlocked != null)
        {
            foreach (string flag in cond.FlagsBlocked)
            {
                if (!string.IsNullOrEmpty(flag) && ctx.HasFlag(flag))
                    return false;
            }
        }

        if (!string.IsNullOrEmpty(cond.Season))
        {
            if (!string.Equals(cond.Season, ctx.CurrentSeason, StringComparison.OrdinalIgnoreCase))
                return false;
        }

        return true;
    }
}
