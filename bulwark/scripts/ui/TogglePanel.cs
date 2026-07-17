using System;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Base class for the modal CanvasLayer panels that toggle open with a hotkey and close on Esc
/// (QuestPanel, BuildPanel, InventoryPanel, CraftingPanel, FriendshipPanel, SmithyPanel,
/// TradingPostPanel, SquadPanel, CalendarPanel, PartySelectPanel, PauseMenu). Extracted to delete the
/// copy-pasted <c>_UnhandledInput</c>/<c>SetOpen</c>/<c>Toggled</c> boilerplate that was identical
/// across all of them — nothing more; each panel keeps its own node wiring, rendering, and intent
/// events. Per-panel open/close side effects (state resets, nested-panel bookkeeping, etc.) hook in
/// by overriding <see cref="SetOpen"/> and calling <c>base.SetOpen(open)</c>.
/// </summary>
public abstract partial class TogglePanel : CanvasLayer
{
    /// <summary>
    /// Input action that flips the panel open/closed (e.g. "toggle_quest_panel"). Empty (the
    /// default) means the panel has no hotkey and is only opened programmatically — Esc still closes
    /// it while visible.
    /// </summary>
    [Export] public StringName ToggleAction { get; set; } = "";

    /// <summary>Raised when the panel opens (true) or closes (false).</summary>
    public event Action<bool>? Toggled;

    public override void _UnhandledInput(InputEvent @event)
    {
        if (!string.IsNullOrEmpty(ToggleAction) && @event.IsActionPressed(ToggleAction))
        {
            SetOpen(!Visible);
            GetViewport().SetInputAsHandled();
        }
        else if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            SetOpen(false);
            GetViewport().SetInputAsHandled();
        }
    }

    /// <summary>Host command: close the panel if open (fires Toggled(false) so the host unfreezes).</summary>
    public void Close() => SetOpen(false);

    /// <summary>
    /// Open/close the panel, guarding no-op transitions and raising <see cref="Toggled"/>. Override
    /// to add open/close side effects; call <c>base.SetOpen(open)</c> to apply the visibility change
    /// and fire the event (side effects run first, matching every panel's original ordering).
    /// </summary>
    protected virtual void SetOpen(bool open)
    {
        if (Visible == open)
            return;
        Visible = open;
        Toggled?.Invoke(open);
    }
}
