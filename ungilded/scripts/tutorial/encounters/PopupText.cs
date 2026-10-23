using System;
using System.Text;
using Godot;
using Ungilded.Story;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// Turns a spec popup into BBCode. " // " in the spec text is a paragraph break. The gold words are
/// listed in the order they appear, as the spec tables list them: each one is found after the
/// previous match, so a word listed twice lights its first two uses and a word that also appears
/// earlier in passing stays plain.
/// </summary>
internal static class PopupText
{
    private const string ParagraphMark = " // ";

    internal static string Build(TutorialPopup popup, string text, params string[] gold)
    {
        string plain = Plain(text);
        var output = new StringBuilder();
        int cursor = 0;
        foreach (string word in gold)
        {
            int at = plain.IndexOf(word, cursor, StringComparison.Ordinal);
            if (at < 0)
            {
                GD.PushWarning($"[PopupText] gold word '{word}' not found in \"{plain}\".");
                continue;
            }
            output.Append(plain, cursor, at - cursor).Append(popup.Highlight(word));
            cursor = at + word.Length;
        }
        output.Append(plain, cursor, plain.Length - cursor);
        return output.ToString();
    }

    /// <summary>The text with its paragraph marks as blank lines, no BBCode.</summary>
    internal static string Plain(string text) => text.Replace(ParagraphMark, "\n\n");
}
