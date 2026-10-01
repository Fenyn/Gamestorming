using Godot;

namespace Delve.UI;

/// <summary>
/// String consts for every input action the HUD reads, plus the keycap lookup that turns an action
/// into the key the player presses. UI code reads actions only (never raw keycodes) and writes no
/// literal action names, so a rebind reaches every caption and the help overlay at once.
/// </summary>
public static class InputNames
{
    public const string Move = "combat_move";
    public const string Action1 = "combat_action_1";
    public const string Action2 = "combat_action_2";
    public const string EndTurn = "combat_end_turn";
    public const string Delay = "combat_delay";
    public const string Spells = "combat_spells";
    public const string Skills = "combat_skills";
    public const string Confirm = "combat_confirm";
    public const string Decline = "combat_decline";
    public const string Help = "combat_help";
    public const string LogToggle = "combat_log_toggle";
    public const string Journal = "combat_journal";
    /// <summary>Re-centre the combat camera on the active unit.</summary>
    public const string Focus = "combat_focus";

    /// <summary>Turn the camera a quarter turn around the pivot.</summary>
    public const string RotateLeft = "camera_rotate_left";
    public const string RotateRight = "camera_rotate_right";

    /// <summary>Out-of-combat screens: the number keys pick a frame's page, Q and E page through
    /// party members, and J opens the journal while exploring.</summary>
    public const string MenuPrev = "menu_prev";
    public const string MenuNext = "menu_next";
    public const string ExploreJournal = "explore_journal";
    public const string ExploreParty = "explore_party";

    /// <summary>Godot's built-in cancel action. Listed here so no script carries the literal.</summary>
    public const string UiCancel = "ui_cancel";

    /// <summary>Godot's built-in list navigation, read by the menu screens.</summary>
    public const string UiUp = "ui_up";
    public const string UiDown = "ui_down";
    public const string UiLeft = "ui_left";
    public const string UiRight = "ui_right";
    public const string UiFocusNext = "ui_focus_next";
    public const string UiFocusPrev = "ui_focus_prev";

    /// <summary>
    /// Display name of the first key bound to <paramref name="action"/> ("1", "Q", "Space").
    /// Falls back to the given text when the action has no key event, so an unbound action reads
    /// as itself instead of as an empty keycap.
    /// </summary>
    public static string KeyLabelFor(StringName action)
    {
        if (!InputMap.HasAction(action)) return action.ToString();

        foreach (var evt in InputMap.ActionGetEvents(action))
        {
            if (evt is not InputEventKey key) continue;

            Key code = key.Keycode != Key.None
                ? key.Keycode
                : DisplayServer.KeyboardGetKeycodeFromPhysical(key.PhysicalKeycode);
            if (code == Key.Escape) return "Esc";
            if (code != Key.None) return OS.GetKeycodeString(code);
        }
        return action.ToString();
    }
}
