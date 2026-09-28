using System;
using System.Linq;
using Delve.Combat;
using Delve.Flow;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;

public partial class DungeonHud
{
    /// <summary>A party chip was clicked: the member's engine UniqueId.</summary>
    public event Action<int>? MemberPressed;

    private SquadPanel _party = null!;
    private SheetTooltip _doorTip = null!;
    private string _partySignature = "";

    public SquadPanel PartyStrip => _party;
    public SheetTooltip DoorTip => _doorTip;

    private void ReadyParty()
    {
        _party = GetNode<SquadPanel>("%PartyStrip");
        _doorTip = GetNode<SheetTooltip>("%DoorTip");
        _party.FocusRequested += id => MemberPressed?.Invoke(id);
        AddToGroup(PauseMenu.HostGroup);
    }

    private void RenderParty(RunState state, bool fighting)
    {
        _party.Visible = !fighting;
        if (fighting) { HideDoorTip(); return; }
        var views = state.Party.Members
            .Select(m => SquadMemberViews.From(m, showReaction: false, promotionPending: CombatResults.HasFeatChoice(m)))
            .ToArray();
        string signature = string.Join(",", views.Select(v => v.Id));
        if (signature != _partySignature)
        {
            _partySignature = signature;
            _party.Setup(views);
        }
        else _party.Render(views);
    }

    public void ShowDoorTip(SheetTip tip, Vector2 screen) => _doorTip.ShowAt(tip, screen);

    public void HideDoorTip()
    {
        if (_doorTip.Visible) _doorTip.HideTip();
    }
}
