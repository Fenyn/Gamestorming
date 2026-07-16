using System.Collections.Generic;
using Bulwark.Data.Characters;

namespace Bulwark.Cozy;

/// <summary>
/// The quest/help friendship-award hook (design/friendship.md "helping / quests"): restoring a
/// character's ASSOCIATED BUILDING grants that character a point chunk. Pure C# — GameState calls
/// <see cref="OnBuildingAdvanced"/> from its Commission/Upgrade commands with the shipped cast;
/// the spike proves the rule with synthetic profiles. Characters whose associated building never
/// gets commissioned (or who have none) simply never receive this award.
/// </summary>
public static class FriendshipAwards
{
    /// <summary>Points awarded to a building's associated character when it is COMMISSIONED
    /// (restored to tier 1). TUNABLE placeholder — roughly one heart's worth of goodwill.</summary>
    public const int CommissionAward = 240;

    /// <summary>Points awarded to a building's associated character per tier UPGRADE. TUNABLE placeholder.</summary>
    public const int UpgradeAward = 120;

    /// <summary>
    /// Award the commission/upgrade chunk to every character in <paramref name="cast"/> whose
    /// <see cref="CharacterProfile.AssociatedBuildingId"/> matches the advanced building. Routed
    /// through <see cref="FriendshipSystem.AddFriendship"/>, so non-befriendable characters (the
    /// player) are rejected there and thresholds/events fire normally.
    /// </summary>
    public static void OnBuildingAdvanced(
        string buildingId, bool isCommission, IEnumerable<CharacterProfile> cast, FriendshipSystem friendship)
    {
        if (string.IsNullOrEmpty(buildingId) || friendship == null)
            return;

        int amount = isCommission ? CommissionAward : UpgradeAward;
        foreach (var profile in cast)
            if (profile.AssociatedBuildingId == buildingId)
                friendship.AddFriendship(profile.Id, amount, $"building:{buildingId}");
    }
}
