using System.Collections.Generic;

namespace Delve.Data;

/// <summary>
/// Maps a creature slug (<see cref="Delve.Data.CreatureRef.Slug"/>) to its combat sprite folder,
/// mirroring <see cref="HeroSpriteMap"/> for the enemy team. Data-only and trivially editable — add
/// or repoint a creature by changing one row here.
///
/// The combat token only carries the creature's display name (<see cref="PF2e.Core.ICharacter.Name"/>,
/// e.g. "Dire Wolf"); the file slug never rides through encounter resolution onto the board. Foundry
/// slugs are just the kebab-cased display name, so <see cref="FolderForCreature"/> slugifies the name
/// and looks that up — keeping this table keyed on the same canonical slug as the encounter tables.
///
/// ASSET REALITY: the only combat sprites that exist are three rat variants under
/// res://assets/sprites/enemies/. There is NO wolf / deserter / goblin / ooze / fey art yet, so every
/// creature outside the rat family falls through to <see cref="DefaultFolder"/> and renders as a rat —
/// including the Dire Wolf boss (tutorial quest 7). Repoint each row the day its art lands; the call site never
/// changes. Each folder holds an 8-frame side-view idle sheet (idle_1.png..idle_8.png).
/// </summary>
public static class EnemySpriteMap
{
    private const string Root = "res://assets/sprites/enemies/";

    /// <summary>Fallback folder when a slug has no explicit entry. Rats are the only combat art today.</summary>
    public const string DefaultFolder = Root + "rat_v1";

    // Only the rat family has real art; each rodent slug points at a distinct variant for a little
    // visual variety. Non-rat creatures are intentionally absent — they fall back to a rat until art
    // is authored, at which point they get a row here.
    private static readonly Dictionary<string, string> BySlug = new()
    {
        ["giant-rat"] = Root + "rat_v1",
        ["rat-swarm"] = Root + "rat_v2",
        ["wererat"]   = Root + "rat_v3",
    };

    /// <summary>Resolve the sprite folder for a creature by display name (slugified), else the default.</summary>
    public static string FolderForCreature(string displayName) =>
        BySlug.TryGetValue(Slugify(displayName), out var folder) ? folder : DefaultFolder;

    /// <summary>Foundry-style slug: lowercase, runs of non-alphanumerics collapsed to single hyphens.</summary>
    private static string Slugify(string name)
    {
        var sb = new System.Text.StringBuilder(name.Length);
        bool pendingHyphen = false;
        foreach (char c in name.ToLowerInvariant())
        {
            if (char.IsLetterOrDigit(c))
            {
                if (pendingHyphen && sb.Length > 0) sb.Append('-');
                pendingHyphen = false;
                sb.Append(c);
            }
            else
            {
                pendingHyphen = true;
            }
        }
        return sb.ToString();
    }
}
