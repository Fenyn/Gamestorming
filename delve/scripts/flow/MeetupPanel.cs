using System;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>Shows the fought guest and three replaceable slots. Signals choices to the run.</summary>
public partial class MeetupPanel : Control
{
    private HeroSheet _sheet = null!;
    private Label _summary = null!;
    private Button[] _slots = Array.Empty<Button>();
    private Party? _party;

    public event Action<string>? CompanionPicked;
    public event Action? Declined;

    public override void _Ready()
    {
        _sheet = GetNode<HeroSheet>("%GuestSheet");
        _summary = GetNode<Label>("%Summary");
        _slots = new[] { GetNode<Button>("%SlotOne"), GetNode<Button>("%SlotTwo"), GetNode<Button>("%SlotThree") };
        for (int i = 0; i < _slots.Length; i++)
        {
            int slot = i;
            _slots[i].Pressed += () =>
            {
                if (_party != null && slot < _party.MemberIds.Count)
                    CompanionPicked?.Invoke(_party.MemberIds[slot]);
            };
        }
        GetNode<Button>("%DeclineButton").Pressed += () => Declined?.Invoke();
    }

    public void Show(Party party, PF2eCharacter guest)
    {
        _party = party;
        _sheet.Show(HeroSheetBuilder.Read(guest), HeroPortraits.For(guest.Id), UiColors.CharacterAccent(guest.Id));
        _summary.Text = $"{guest.Name} can join this expedition with {guest.Health?.CurrentHP}/{guest.Health?.MaxHP} HP. Choose a companion to send home.\n"
            + $"{party.Members[0].Name} remains your leader. Joining does not permanently unlock a character.";
        for (int i = 0; i < _slots.Length; i++)
        {
            _slots[i].Disabled = i >= party.MemberIds.Count;
            _slots[i].Text = i < party.MemberIds.Count ? $"Send {party.Members[i + 1].Name} home ({party.Members[i + 1].Health?.CurrentHP}/{party.Members[i + 1].Health?.MaxHP} HP)" : "Empty slot";
        }
    }
}
