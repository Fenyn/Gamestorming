using PF2e.Core;

namespace Delve.Combat;

/// <summary>Builds a party chip view from a character. Shared by the combat column and the dungeon strip.</summary>
public static class SquadMemberViews
{
    public static SquadMemberView From(ICharacter member, bool framed = false, bool focused = false,
        bool showReaction = true, bool promotionPending = false)
    {
        var detail = ActiveCharacterView.From(member);
        var conditions = ConditionMarks.For(member);
        string tooltip = detail?.Tooltip ?? member.Name;
        if (promotionPending) tooltip += "\nA feat is ready to choose. Click to open the character sheet.";
        return new SquadMemberView
        {
            Id = member.UniqueId,
            HeroId = member.Id,
            Name = member.Name,
            Hp = member.Health?.CurrentHP ?? 0,
            MaxHp = member.Health?.MaxHP ?? 0,
            Framed = framed,
            Focused = focused,
            Down = member.Health?.IsAlive != true,
            Reaction = showReaction ? detail?.Reaction ?? ReactionMark.None : ReactionMark.None,
            Conditions = conditions,
            PromotionPending = promotionPending,
            Tooltip = tooltip,
        };
    }
}
