using System.Collections.Generic;
using Delve.Flow;
using Godot;
using PF2e.Core;
using Delve.Run;

namespace Delve.UI;

public partial class VictoryBanner
{
    private IReadOnlyList<PF2eCharacter> _party = System.Array.Empty<PF2eCharacter>();

    private void WirePartyDetails()
    {
        GetNode<CharacterDetailsOverlay>("%ResultDetails").GetNode<Button>("%CloseDetails").Text = "Return to results  [Esc]";
        GetNode<Button>("%DetailsButton").Pressed += () =>
        {
            int index = GetNode<OptionButton>("%PartyMember").Selected;
            if (index < 0 || index >= _party.Count) return;
            var member = _party[index];
            GetNode<CharacterDetailsOverlay>("%ResultDetails").Open(member,
                HeroPortraits.For(member.Id), UiColors.CharacterAccent(member.Id));
        };
        GetNode<CharacterDetailsOverlay>("%ResultDetails").Closed += () => GetNode<Button>("%DetailsButton").GrabFocus();
        GetNode<CharacterDetailsOverlay>("%ResultDetails").Promoted += () => RefreshPartyLabels();
        GetNode<OptionButton>("%PartyMember").ItemSelected += _ => RefreshDetailsButton();
    }

    public void ShowParty(IReadOnlyList<PF2eCharacter> members)
    {
        _party = members;
        var selector = GetNode<OptionButton>("%PartyMember");
        selector.Clear();
        foreach (var member in members) selector.AddItem(member.Name);
        RefreshPartyLabels();
        GetNode<Control>("%PartyDetails").Visible = members.Count > 0;
    }

    private void RefreshPartyLabels()
    {
        var selector = GetNode<OptionButton>("%PartyMember");
        for (int i = 0; i < _party.Count; i++)
        {
            string status = CharacterPromotion.Status(_party[i]);
            selector.SetItemText(i, _party[i].Name + (status.Length > 0 ? $" · {status}" : ""));
        }
        RefreshDetailsButton();
    }

    private void RefreshDetailsButton()
    {
        int index = GetNode<OptionButton>("%PartyMember").Selected;
        GetNode<Button>("%DetailsButton").Text = index >= 0 && index < _party.Count
            && CharacterPromotion.Status(_party[index]).Length > 0 ? "Promote · Character sheet" : "Character details";
    }
}
