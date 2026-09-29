using System;
using Godot;

namespace Delve.UI;

public partial class ActionBar
{
    /// <summary>combat_action_1..2, combat_spells / combat_skills, combat_delay and
    /// combat_end_turn, gated off while a modal is up. Esc closes an open flyout and is consumed
    /// here; otherwise it reaches GridInput3D's targeting cancel.</summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (_hud?.ModalActive == true || !IsVisibleInTree())
            return;

        if (_openCategory != FlyoutCategory.None && @event.IsActionPressed(InputNames.UiCancel))
        {
            CloseFlyout();
            GetViewport().SetInputAsHandled();
            return;
        }

        if (!_interactable) return;

        if (@event.IsActionPressed(InputNames.Confirm) && Decision.CanConfirmTargets)
            Activate(Decision.ConfirmTargetsButton, () => ConfirmTargetsPressed?.Invoke());
        // Move also puts its own bands away, so it works while the menu is closed for them.
        else if (@event.IsActionPressed(InputNames.Move))
            Activate(_moveBtn, () => MovePressed?.Invoke());
        // Every other command comes from the open menu. While a tile or target is picked the menu
        // is closed, so a stray key (Space above all) cannot end the turn mid-pick.
        else if (!MenuShown) return;
        else if (@event.IsActionPressed(InputNames.Action1))
            Activate(_strikeBtn, () => StrikePressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Action2))
            Activate(_shieldBtn, () => RaiseShieldPressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.Spells))
            Activate(_spellsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Spells ? FlyoutCategory.None : FlyoutCategory.Spells));
        else if (@event.IsActionPressed(InputNames.Skills))
            Activate(_skillsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Skills ? FlyoutCategory.None : FlyoutCategory.Skills));
        else if (@event.IsActionPressed(InputNames.Delay))
            Activate(_delayBtn, () => DelayPressed?.Invoke());
        else if (@event.IsActionPressed(InputNames.EndTurn))
            Activate(_endBtn, () => EndTurnPressed?.Invoke());
    }

    private void Activate(Button button, Action fire)
    {
        if (button.Disabled || !button.Visible) return;
        fire();
        GetViewport().SetInputAsHandled();
    }
}
