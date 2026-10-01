using System;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>Shows the fought guest and four replaceable slots. Signals choices to the run.</summary>
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
        _slots = new[] { GetNode<Button>("%SlotOne"), GetNode<Button>("%SlotTwo"), GetNode<Button>("%SlotThree"), GetNode<Button>("%SlotFour") };
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
        // The offer holds the modal stack, so Esc answers "Keep current party" and never the pause menu.
        VisibilityChanged += () =>
        {
            if (Visible) Delve.Autoload.ModalStack.Instance?.Push(this);
            else Delve.Autoload.ModalStack.Instance?.Pop(this);
        };
    }

    /// <summary>Esc answers "Keep current party", the one choice that changes nothing.</summary>
    public override void _Input(InputEvent e)
    {
        if (!IsVisibleInTree() || e.IsEcho() || !e.IsActionPressed(InputNames.UiCancel)) return;
        GetViewport().SetInputAsHandled();
        Declined?.Invoke();
    }

    public void Show(Party party, PF2eCharacter guest)
    {
        _party = party;
        _sheet.Show(HeroSheetBuilder.Read(guest), HeroPortraits.For(guest.Id), UiColors.CharacterAccent(guest.Id));
        string introduction = BulwarkWayfarers.Find(guest.Id)?.Introduction ?? "";
        _summary.Text = (introduction.Length > 0 ? introduction + "\n" : "") + $"{guest.Name} can join this expedition with {guest.Health?.CurrentHP}/{guest.Health?.MaxHP} HP. Choose a companion to send home.\n"
            + "Joining does not permanently unlock a character.";
        for (int i = 0; i < _slots.Length; i++)
        {
            _slots[i].Disabled = i >= party.MemberIds.Count;
            _slots[i].Text = i < party.MemberIds.Count ? $"Send {party.Members[i].Name} home ({party.Members[i].Health?.CurrentHP}/{party.Members[i].Health?.MaxHP} HP)" : "Empty slot";
        }
        // Enter must never send a companion home by accident.
        UiFocus.Grab(GetNode<Button>("%DeclineButton"));
    }
}
