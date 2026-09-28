using System;
using Godot;

namespace Delve.UI;

/// <summary>
/// Full-rect parent of every combat HUD panel. Owns the HUD's modal state as a refcount
/// (<see cref="PushModal"/>/<see cref="PopModal"/>, clamped at zero): modal panels push on show
/// and pop on hide, non-modal panels gate their hotkeys on <see cref="ModalActive"/>. Also owns
/// the global HUD toggles — combat_help (help overlay), combat_log_toggle (log expansion) and
/// combat_journal (creature journal) — all inert while a modal is up. No scene file: scripted on a plain Control in combat.tscn.
/// It joins <see cref="Group"/> in _EnterTree, which runs before any child's _Ready, so child
/// panels can resolve it and still tolerate its absence when they run standalone in a spike.
/// </summary>
public partial class HudRoot : Control
{
    /// <summary>Scene group a child panel looks the HUD root up through.</summary>
    public const string Group = "hud_root";

    /// <summary>Fires true when the first modal opens, false when the last one resolves.</summary>
    public event Action<bool>? ModalChanged;

    /// <summary>Path to the controls-help overlay this root toggles on combat_help.</summary>
    [Export] public NodePath HelpPath { get; set; } = new("HelpOverlay");

    /// <summary>Path to the combat log this root expands on combat_log_toggle.</summary>
    [Export] public NodePath LogPath { get; set; } = new("CombatLog");

    /// <summary>Path to the creature journal this root toggles on combat_journal.</summary>
    [Export] public NodePath JournalPath { get; set; } = new("CombatJournal");

    /// <summary>Resolved <see cref="HelpPath"/>. Node-typed exports do not bind from hand-authored
    /// .tscn text in this project, so the path is resolved in _Ready.</summary>
    public HelpOverlay? Help { get; private set; }

    /// <summary>Resolved <see cref="LogPath"/>.</summary>
    public CombatLogPanel? Log { get; private set; }

    /// <summary>Resolved <see cref="JournalPath"/>.</summary>
    public CombatJournalPanel? Journal { get; private set; }

    private int _modalCount;

    /// <summary>True while any modal panel (reaction prompt, victory banner) is up.</summary>
    public bool ModalActive => _modalCount > 0;

    /// <summary>The HUD root of the current scene, or null when a panel runs without one.</summary>
    public static HudRoot? Find(Node from)
        => from.GetTree()?.GetFirstNodeInGroup(Group) as HudRoot;

    public override void _EnterTree()
    {
        AddToGroup(Group);
        AddToGroup(PauseMenu.HostGroup);
    }

    public override void _Ready()
    {
        Help = HelpPath.IsEmpty ? null : GetNodeOrNull<HelpOverlay>(HelpPath);
        Log = LogPath.IsEmpty ? null : GetNodeOrNull<CombatLogPanel>(LogPath);
        Journal = JournalPath.IsEmpty ? null : GetNodeOrNull<CombatJournalPanel>(JournalPath);
        if (Help == null) GD.PushWarning("[HudRoot] HelpPath did not resolve.");
        if (Log == null) GD.PushWarning("[HudRoot] LogPath did not resolve.");
        if (Journal == null) GD.PushWarning("[HudRoot] JournalPath did not resolve.");
    }

    public void PushModal()
    {
        _modalCount++;
        if (_modalCount != 1) return;
        Delve.Autoload.ModalStack.Instance?.Push(this);
        ModalChanged?.Invoke(true);
    }

    public void PopModal()
    {
        // Clamp at zero: a stray double-pop must never bank a "free" push that would let a later
        // modal open without actually blocking input.
        if (_modalCount == 0) return;
        _modalCount--;
        if (_modalCount != 0) return;
        Delve.Autoload.ModalStack.Instance?.Pop(this);
        ModalChanged?.Invoke(false);
    }

    /// <summary>True while the encounter intro plays. The HUD toggles wait for the board.</summary>
    public bool IntroPlaying { get; set; }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (ModalActive || IntroPlaying) return;

        if (Help is { Visible: true } && @event.IsActionPressed(InputNames.UiCancel))
        {
            Help.Toggle();
            GetViewport().SetInputAsHandled();
        }
        else if (Journal is { Visible: true } && @event.IsActionPressed(InputNames.UiCancel))
        {
            Journal.Toggle();
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionPressed(InputNames.Journal))
        {
            Journal?.Toggle();
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionPressed(InputNames.Help))
        {
            Help?.Toggle();
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionPressed(InputNames.LogToggle))
        {
            Log?.ToggleExpanded();
            GetViewport().SetInputAsHandled();
        }
    }
}
