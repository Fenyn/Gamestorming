using System.Collections.Generic;

namespace Bulwark.Combat;

/// <summary>
/// Maps a hero character id (<see cref="PF2e.Core.ICharacter.Id"/>) to its Winlu "8D Character
/// Creator" sprite folder. Data-only and trivially editable — add or repoint a preset by changing
/// one row here. Folders live under <c>res://assets/sprites/heroes/&lt;name&gt;/</c> and each holds an
/// <c>idle.png</c> (and <c>walk.png</c>) laid out 8 rows (facings) x 8 columns (animation frames).
/// </summary>
public static class HeroSpriteMap
{
    private const string Root = "res://assets/sprites/heroes/";

    /// <summary>Fallback folder when a hero id has no explicit entry.</summary>
    public const string DefaultFolder = Root + "knight_low";

    private static readonly Dictionary<string, string> ByCharacterId = new()
    {
        ["the-veteran"] = Root + "knight_low",     // Veteran  -> Knight Low
        ["the-recruit"] = Root + "king_winlu",     // Recruit  -> King Winlu
        ["the-archer"] = Root + "archer_theresa",  // future preset -> Archer Theresa
        ["the-mage"] = Root + "mage_ted",          // future preset -> Mage Ted
    };

    /// <summary>Resolve the sprite folder for a hero id, falling back to the default.</summary>
    public static string FolderFor(string characterId) =>
        ByCharacterId.TryGetValue(characterId, out var folder) ? folder : DefaultFolder;
}
