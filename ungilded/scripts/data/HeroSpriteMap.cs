using System.Collections.Generic;
using Godot;
using Ungilded.Content;
using Ungilded.Presets;

namespace Ungilded.Data;

/// <summary>
/// Maps a hero character id (<see cref="PF2e.Core.ICharacter.Id"/>) to its sprite folder.
/// Data-only and trivially editable — add or repoint a preset by changing one row here.
/// Folders live under <c>res://assets/sprites/heroes/&lt;name&gt;/</c>. An authored folder holds a
/// <c>sprite.tres</c> (<see cref="EnemySpriteDefinition"/>) and draws like an enemy, with one facing
/// plus flip. The others hold a baked Mana Seed "page 1" sheet, <c>p1.png</c> (anatomy:
/// <see cref="Ungilded.Data.ManaSeedSheet"/>).
/// </summary>
public static class HeroSpriteMap
{
    private const string Root = "res://assets/sprites/heroes/";

    /// <summary>Fallback folder when a hero id has no explicit entry.</summary>
    public const string DefaultFolder = Root + "veteran";

    private static readonly Dictionary<string, string> ByCharacterId = new()
    {
        // The Prologue pair (PrologueCast.PlayerId is the same "player" id), drawn for the Prologue
        // in the enemies' style: source masters in design/hero-sprites.
        [PresetCharacters.PlayerId] = Root + "player",
        [PrologueCast.FriendId] = Root + "friend",
        [PresetCharacters.RecruitId] = Root + "recruit",
        [PresetCharacters.TharrId] = Root + "cleric",
        [PresetCharacters.FenwickId] = Root + "wizard",
        [PresetCharacters.ElaraId] = Root + "rogue",
        [PresetCharacters.RavenId] = Root + "rogue",
        [PresetCharacters.ThistleId] = Root + "recruit",
    };

    /// <summary>True when the folder holds a <c>sprite.tres</c> instead of a Mana Seed sheet.</summary>
    public static bool IsAuthored(string folder) => ResourceLoader.Exists(EnemySpriteMap.DefinitionPath(folder));

    /// <summary>Resolve the sprite folder for a hero id, falling back to the default.</summary>
    public static string FolderFor(string characterId) =>
        ByCharacterId.TryGetValue(characterId, out var folder) ? folder
            : BulwarkWayfarers.Find(characterId) is { } spec ? Root + spec.Sprite : DefaultFolder;
}
