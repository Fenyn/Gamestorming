using System;
using System.Collections.Generic;
using Delve.Presets;
using PF2e.Core;

namespace Delve.Run;

/// <summary>One roster entry: the id everything keys on, its display name, the role line the
/// roster card prints, its builder, and whether it may lead a run. Everything the featured sheet
/// prints comes off the character <see cref="Builder"/> makes, so there is no authored copy
/// here to drift away from the build.</summary>
public sealed record CharacterDef(
    string Id, string DisplayName, string Role,
    Func<int, PF2eCharacter> Builder, bool CanLead);

/// <summary>
/// The single table of playable characters (design/core_concept.md). Hero select, unlocks and the
/// sprite maps all key on <see cref="CharacterDef.Id"/>, which is the preset id constant.
/// </summary>
public static class CharacterCatalog
{
    /// <summary>Every character in the game, in roster order.</summary>
    public static readonly IReadOnlyList<CharacterDef> All = new List<CharacterDef>
    {
        new(PresetCharacters.PlayerId, "Aldric", "Fighter · front line",
            lvl => PresetCharacters.BuildPlayer(lvl), true),
        new(PresetCharacters.ElaraId, "Elara", "Rogue · flanker",
            lvl => PresetCharacters.BuildElara(lvl), true),
        new(PresetCharacters.TharrId, "Tharr", "Cleric · healer",
            lvl => PresetCharacters.BuildTharr(lvl), true),
        new(PresetCharacters.FenwickId, "Fenwick", "Wizard · artillery",
            lvl => PresetCharacters.BuildFenwick(lvl), true),
    };

    /// <summary>The entry with this id, or null.</summary>
    public static CharacterDef? Find(string id)
    {
        foreach (var def in All)
        {
            if (def.Id == id) return def;
        }
        return null;
    }
}

/// <summary>
/// Which characters the player may pick. In memory only for now - persistence lands with the save
/// layer. Everything starts unlocked so the skeleton loop is walkable end to end.
/// </summary>
public sealed class UnlockState
{
    private readonly HashSet<string> _unlocked = new();

    /// <summary>All five characters unlocked.</summary>
    public UnlockState()
    {
        foreach (var def in CharacterCatalog.All)
            _unlocked.Add(def.Id);
    }

    /// <summary>Exactly the given ids unlocked.</summary>
    public UnlockState(IEnumerable<string> unlockedIds)
    {
        foreach (string id in unlockedIds)
            _unlocked.Add(id);
    }

    /// <summary>Ids currently available to the roster.</summary>
    public IReadOnlyCollection<string> UnlockedIds => _unlocked;

    public bool IsUnlocked(string id) => _unlocked.Contains(id);

    /// <summary>True when the id was newly unlocked.</summary>
    public bool Unlock(string id) => _unlocked.Add(id);
}
