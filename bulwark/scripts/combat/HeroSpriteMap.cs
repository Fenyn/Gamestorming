using System.Collections.Generic;
using Bulwark.Presets;

namespace Bulwark.Combat;

/// <summary>
/// Maps a hero character id (<see cref="PF2e.Core.ICharacter.Id"/>) to its sprite folder.
/// Data-only and trivially editable — add or repoint a preset by changing one row here.
/// Folders live under <c>res://assets/sprites/heroes/&lt;name&gt;/</c> and each holds a baked
/// Mana Seed "page 1" sheet, <c>p1.png</c> (anatomy: <see cref="Bulwark.Data.ManaSeedSheet"/>).
/// </summary>
public static class HeroSpriteMap
{
    private const string Root = "res://assets/sprites/heroes/";

    /// <summary>Fallback folder when a hero id has no explicit entry.</summary>
    public const string DefaultFolder = Root + "veteran";

    private static readonly Dictionary<string, string> ByCharacterId = new()
    {
        [PresetCharacters.PlayerId] = Root + "veteran",
        [PresetCharacters.RecruitId] = Root + "recruit",
        [PresetCharacters.TharrId] = Root + "cleric",
        [PresetCharacters.ScholarId] = Root + "wizard",
        [PresetCharacters.ScoutId] = Root + "rogue",
    };

    /// <summary>Resolve the sprite folder for a hero id, falling back to the default.</summary>
    public static string FolderFor(string characterId) =>
        ByCharacterId.TryGetValue(characterId, out var folder) ? folder : DefaultFolder;
}
