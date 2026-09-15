using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Presets;
using PF2e.Core;

namespace Delve.Run;

/// <summary>One roster entry: the id everything keys on, its display name, the role line the
/// roster card prints, and its builder. Everything the featured sheet
/// prints comes off the character <see cref="Builder"/> makes, so there is no authored copy
/// here to drift away from the build.</summary>
public sealed record CharacterDef(
    string Id, string DisplayName, string Role,
    Func<int, PF2eCharacter> Builder,
    bool StartsUnlocked = false, bool CanMeet = true);

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
            lvl => PresetCharacters.BuildPlayer(lvl), StartsUnlocked: true),
        new(PresetCharacters.ElaraId, "Elara", "Rogue · flanker",
            lvl => PresetCharacters.BuildElara(lvl), StartsUnlocked: true),
        new(PresetCharacters.TharrId, "Tharr", "Cleric · healer",
            lvl => PresetCharacters.BuildTharr(lvl), StartsUnlocked: true),
        new(PresetCharacters.FenwickId, "Fenwick", "Wizard · artillery",
            lvl => PresetCharacters.BuildFenwick(lvl), StartsUnlocked: true),
        new(PresetCharacters.RavenId, "Raven", "Swashbuckler · duelist",
            PresetCharacters.BuildRaven),
        new(PresetCharacters.ThistleId, "Thistle", "Ranger · scout",
            PresetCharacters.BuildThistle),
    }.Concat(BulwarkWayfarers.All.Select(spec => new CharacterDef(spec.Id, spec.Name,
        $"{spec.IntendedClass} - {spec.Role}", level => PresetCharacters.BuildWayfarer(spec, level)))).ToArray();

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
/// Which characters may start a run. Guest eligibility is independent of this state.
/// </summary>
public sealed class UnlockState
{
    private readonly HashSet<string> _unlocked = new();

    /// <summary>The four starter characters unlocked.</summary>
    public UnlockState()
    {
        foreach (var def in CharacterCatalog.All)
            if (def.StartsUnlocked) _unlocked.Add(def.Id);
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
    public bool Unlock(string id) => CharacterCatalog.Find(id) != null && _unlocked.Add(id);
}
