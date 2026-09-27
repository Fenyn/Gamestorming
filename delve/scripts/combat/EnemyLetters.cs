using System.Collections.Generic;
using PF2e.Core;

namespace Delve.Combat;

/// <summary>
/// Gives each enemy of an encounter one letter (A, B, C...) and appends it to the name, so the
/// engine's log text, the turn strip, the inspect card and the token badge all name the same
/// creature. <see cref="Restore"/> puts the original names back when the encounter ends.
/// </summary>
public sealed class EnemyLetters
{
    private readonly Dictionary<ICharacter, (string Letter, string BaseName)> _entries = new();

    public void Assign(IReadOnlyList<ICharacter> enemies)
    {
        Restore();
        for (int i = 0; i < enemies.Count; i++)
        {
            if (enemies[i] is not PF2eCharacter enemy) continue;
            string letter = LetterAt(i);
            _entries[enemy] = (letter, enemy.Name);
            enemy.Name = $"{enemy.Name} {letter}";
        }
    }

    public void Restore()
    {
        foreach (var (character, entry) in _entries)
            if (character is PF2eCharacter enemy) enemy.Name = entry.BaseName;
        _entries.Clear();
    }

    public string LetterFor(ICharacter character)
        => _entries.TryGetValue(character, out var entry) ? entry.Letter : "";

    public string BaseNameFor(ICharacter character)
        => _entries.TryGetValue(character, out var entry) ? entry.BaseName : character.Name;

    private static string LetterAt(int index)
        => index < 26 ? ((char)('A' + index)).ToString() : $"{(char)('A' + index / 26 - 1)}{(char)('A' + index % 26)}";
}
