using System.Collections.Generic;

namespace Bulwark.Data.Characters;

/// <summary>
/// Registry of the authored <see cref="FriendshipProfile"/>s, keyed by character id — the same
/// static-registry pattern as <see cref="Characters"/>. A character WITHOUT an authored profile
/// falls back to a default (befriendable, all-neutral preferences, no birthday, no unlocks) per
/// the design's "townsfolk added later are befriendable by default"; the PLAYER avatar's authored
/// profile sets Befriendable = false. Authoring per-character preferences is a data-only edit in
/// the character's own file (e.g. <see cref="Tharr.Friendship"/>) plus a line here.
/// </summary>
public static class Friendships
{
    private static readonly DefinitionRegistry<FriendshipProfile> Registry = new(p => p.CharacterId,
        PlayerCharacter.Friendship,
        Tharr.Friendship
    );

    /// <summary>Every authored friendship profile.</summary>
    public static IReadOnlyCollection<FriendshipProfile> All => Registry.All;

    /// <summary>True when an explicit profile is authored for <paramref name="characterId"/>.</summary>
    public static bool IsDefined(string characterId) => Registry.IsDefined(characterId);

    /// <summary>
    /// The friendship profile for a character: the authored one when it exists, otherwise the
    /// befriendable-by-default all-neutral fallback (never null).
    /// </summary>
    public static FriendshipProfile Get(string characterId)
        => Registry.TryGet(characterId, out var p) ? p : new FriendshipProfile { CharacterId = characterId };
}
