using System;
using Godot;

namespace Ungilded.UI;

public partial class ActionBar
{
    /// <summary>combat_action_1..2, combat_spells / combat_skills, combat_delay and
    /// combat_end_turn, gated off while a modal is up. Esc closes an open flyout and is consumed
    /// here; otherwise it reaches GridInput3D's targeting cancel.</summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (HandleCommandKey(@event)) GetViewport().SetInputAsHandled();
    }

    /// <summary>Run the command a hotkey names. False when the key is not a command key, or when
    /// its entry is disabled (an action that cannot be taken, or a tutorial restriction). Spikes
    /// call it directly with an InputEventAction.</summary>
    public bool HandleCommandKey(InputEvent @event)
    {
        if (_hud?.ModalActive == true || !IsVisibleInTree())
            return false;

        if (_openCategory != FlyoutCategory.None && @event.IsActionPressed(InputNames.UiCancel))
        {
            CloseFlyout();
            return true;
        }

        if (!_interactable) return false;

        if (@event.IsActionPressed(InputNames.Confirm) && Decision.CanConfirmTargets)
            return Activate(Decision.ConfirmTargetsButton, () => ConfirmTargetsPressed?.Invoke());
        // Move also puts its own bands away, so it works while the menu is closed for them.
        if (@event.IsActionPressed(InputNames.Move))
            return Activate(_moveBtn, () => MovePressed?.Invoke());
        // Every other command comes from the open menu. While a tile or target is picked the menu
        // is closed, so a stray key (Space above all) cannot end the turn mid-pick.
        if (!MenuShown) return false;
        if (@event.IsActionPressed(InputNames.Action1))
            return Activate(_strikeBtn, () => StrikePressed?.Invoke());
        if (@event.IsActionPressed(InputNames.Action2))
            return Activate(_shieldBtn, () => RaiseShieldPressed?.Invoke());
        if (@event.IsActionPressed(InputNames.Spells))
            return Activate(_spellsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Spells ? FlyoutCategory.None : FlyoutCategory.Spells));
        if (@event.IsActionPressed(InputNames.Skills))
            return Activate(_skillsBtn, () => SetFlyout(
                _openCategory == FlyoutCategory.Skills ? FlyoutCategory.None : FlyoutCategory.Skills));
        if (@event.IsActionPressed(InputNames.Delay))
            return Activate(_delayBtn, () => DelayPressed?.Invoke());
        if (@event.IsActionPressed(InputNames.EndTurn))
            return Activate(_endBtn, () => EndTurnPressed?.Invoke());
        return false;
    }

    private static bool Activate(Button button, Action fire)
    {
        if (button.Disabled || !button.Visible) return false;
        fire();
        return true;
    }
}
