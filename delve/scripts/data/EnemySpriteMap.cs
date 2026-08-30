using System.Collections.Generic;
using PF2e.Data;

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
/// An "Elite " / "Weak " prefix from CreatureFactory's adjustment naming is stripped first, so an
/// Elite Giant Rat still finds the rat row.
///
/// ASSET REALITY: the only real combat sprites are three rat variants under
/// res://assets/sprites/enemies/. Every creature without a row here renders as the size-matched
/// MISSING-ART placeholder (magenta checkerboard with a "?"), so a rat on screen always means rat
/// and a checkerboard always means the creature needs art. Add a row the day art lands; the call
/// site never changes. Each folder holds an 8-frame side-view idle sheet (idle_1.png..idle_8.png).
/// </summary>
public static class EnemySpriteMap
{
    private const string Root = "res://assets/sprites/enemies/";

    /// <summary>Fallback folder when no size is known. Kept for tooling; play code goes through
    /// <see cref="FolderForCreature(string, CreatureSize)"/>.</summary>
    public const string DefaultFolder = Root + "placeholder_medium";

    // Only the rat family has real art; each rodent slug points at a distinct variant for a little
    // visual variety. Non-rat creatures are intentionally absent — they render as the placeholder
    // until art is authored, at which point they get a row here.
    private static readonly Dictionary<string, string> BySlug = new()
    {
        ["giant-rat"] = Root + "rat_v1",
        ["rat-swarm"] = Root + "rat_v2",
        ["wererat"]   = Root + "rat_v3",
    };

    /// <summary>Resolve the sprite folder for a creature by display name (slugified), else the
    /// missing-art placeholder for its size.</summary>
    public static string FolderForCreature(string displayName, CreatureSize size) =>
        BySlug.TryGetValue(Slugify(displayName), out var folder) ? folder : PlaceholderFolder(size);

    /// <summary>The missing-art placeholder folder for a creature size. Size is baked into the
    /// texture height (BillboardSpriteAnimator derives world height from it), so a Large creature
    /// without art still reads large on the board.</summary>
    public static string PlaceholderFolder(CreatureSize size) => size switch
    {
        CreatureSize.Tiny or CreatureSize.Small => Root + "placeholder_small",
        CreatureSize.Medium => Root + "placeholder_medium",
        _ => Root + "placeholder_large",
    };

    /// <summary>Foundry-style slug: lowercase, runs of non-alphanumerics collapsed to single
    /// hyphens, the factory's Elite/Weak name prefix dropped.</summary>
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
        string slug = sb.ToString();
        if (slug.StartsWith("elite-")) return slug["elite-".Length..];
        if (slug.StartsWith("weak-")) return slug["weak-".Length..];
        return slug;
    }
}
