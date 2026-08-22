using System;
using Godot;

namespace Delve.UI;

/// <summary>
/// Full-rect parent of every combat HUD panel. Owns the HUD's modal state as a refcount
/// (<see cref="PushModal"/>/<see cref="PopModal"/>, clamped at zero): modal panels push on show
/// and pop on hide, non-modal panels gate their hotkeys on <see cref="ModalActive"/>. Also owns
/// the two global HUD toggles — combat_help (help overlay) and combat_log_toggle (log expansion)
/// — both inert while a modal is up. No scene file: scripted on a plain Control in combat.tscn;
/// child panels resolve it via GetParentOrNull&lt;HudRoot&gt;() and tolerate null so they still run
/// standalone in spikes.
/// </summary>
public partial class HudRoot : Control
{
    /// <summary>Fires true when the first modal opens, false when the last one resolves.</summary>
    public event Action<bool>? ModalChanged;

    private int _modalCount;
    private HelpOverlay? _help;
    private CombatLogPanel? _log;

    /// <summary>True while any modal panel (reaction prompt, victory banner) is up.</summary>
    public bool ModalActive => _modalCount > 0;

    public override void _Ready()
    {
        foreach (var child in GetChildren())
        {
            if (child is HelpOverlay help) _help = help;
            else if (child is CombatLogPanel log) _log = log;
        }
    }

    public void PushModal()
    {
        _modalCount++;
        if (_modalCount == 1)
            ModalChanged?.Invoke(true);
    }

    public void PopModal()
    {
        // Clamp at zero: a stray double-pop must never bank a "free" push that would let a later
        // modal open without actually blocking input.
        if (_modalCount == 0) return;
        _modalCount--;
        if (_modalCount == 0)
            ModalChanged?.Invoke(false);
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (ModalActive) return;

        if (@event.IsActionPressed("combat_help"))
        {
            _help?.Toggle();
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionPressed("combat_log_toggle"))
        {
            _log?.ToggleExpanded();
            GetViewport().SetInputAsHandled();
        }
    }
}
