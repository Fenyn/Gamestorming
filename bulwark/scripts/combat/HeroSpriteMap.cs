using System.Collections.Generic;

namespace Bulwark.Combat;

/// <summary>
/// Maps a hero character id (<see cref="PF2e.Core.ICharacter.Id"/>) to its sprite folder.
/// Data-only and trivially editable — add or repoint a preset by changing one row here.
/// Folders live under <c>res://assets/sprites/heroes/&lt;name&gt;/</c> and each holds a baked
/// Mana Seed "page 1" sheet (<c>p1.png</c>, 512x512, 8x8 grid of 64x64 cells): rows 0-3 are the
/// stand frames facing S/N/E/W (column 0), rows 4-7 are the 6-frame walk cycle in the same
/// direction order (columns 0-5; columns 6-7 are run-cycle alternates, unused).
/// </summary>
public static class HeroSpriteMap
{
    private const string Root = "res://assets/sprites/heroes/";

    /// <summary>Fallback folder when a hero id has no explicit entry.</summary>
    public const string DefaultFolder = Root + "veteran";

    private static readonly Dictionary<string, string> ByCharacterId = new()
    {
        ["the-veteran"] = Root + "veteran",
        ["the-recruit"] = Root + "recruit",
        ["the-medic"] = Root + "cleric",    // future preset (Field Medic)
        ["the-scholar"] = Root + "wizard",  // future preset (Battle Scholar)
        ["the-scout"] = Root + "rogue",     // future preset (Scout)
    };

    /// <summary>Resolve the sprite folder for a hero id, falling back to the default.</summary>
    public static string FolderFor(string characterId) =>
        ByCharacterId.TryGetValue(characterId, out var folder) ? folder : DefaultFolder;
}
