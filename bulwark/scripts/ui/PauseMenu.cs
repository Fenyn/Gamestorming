using System;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Esc-opened pause modal for the cozy world scenes (outpost/territory): Resume / Save Game /
/// Options / Quit to Title, plus an inline "Quit to title?" confirm that swaps the button column.
/// Same modal CanvasLayer pattern as the other panels — passive, raises intent events, the host
/// (<see cref="Bulwark.Cozy.CozyWorldScene"/>) forwards <see cref="SaveRequested"/> to
/// GameState.SaveGame() and <see cref="QuitToTitleRequested"/> to SceneRouter.
///
/// Owns its own <see cref="OptionsPanel"/> instance as a CHILD node (not a host concern): nesting it
/// means Godot's input propagation (children before parents) naturally gives Options first crack at
/// Esc while it's open — Esc closes Options and returns to the pause menu's main buttons; a second
/// Esc then resumes. The host never opens the pause menu on Esc while ANY modal — including this
/// one — is already open; see CozyWorldScene.AnyModalOpen.
/// </summary>
public partial class PauseMenu : TogglePanel
{
    private const float SavedFeedbackSeconds = 1.5f;

    public event Action? SaveRequested;
    public event Action? QuitToTitleRequested;

    private Control _mainButtons = null!;
    private Control _confirmButtons = null!;
    private Button _resumeButton = null!;
    private Button _saveButton = null!;
    private Button _optionsButton = null!;
    private Button _quitButton = null!;
    private Button _saveAndQuitButton = null!;
    private Button _quitWithoutSavingButton = null!;
    private Button _cancelQuitButton = null!;
    private Label _savedLabel = null!;

    private OptionsPanel? _optionsPanel;

    public override void _Ready()
    {
        _mainButtons = GetNode<Control>("%MainButtons");
        _confirmButtons = GetNode<Control>("%ConfirmButtons");
        _resumeButton = GetNode<Button>("%ResumeButton");
        _saveButton = GetNode<Button>("%SaveButton");
        _optionsButton = GetNode<Button>("%OptionsButton");
        _quitButton = GetNode<Button>("%QuitButton");
        _saveAndQuitButton = GetNode<Button>("%SaveAndQuitButton");
        _quitWithoutSavingButton = GetNode<Button>("%QuitWithoutSavingButton");
        _cancelQuitButton = GetNode<Button>("%CancelQuitButton");
        _savedLabel = GetNode<Label>("%SavedLabel");

        _resumeButton.Pressed += Close;
        _saveButton.Pressed += OnSavePressed;
        _optionsButton.Pressed += OnOptionsPressed;
        _quitButton.Pressed += ShowQuitConfirm;
        _saveAndQuitButton.Pressed += OnSaveAndQuitPressed;
        _quitWithoutSavingButton.Pressed += OnQuitWithoutSavingPressed;
        _cancelQuitButton.Pressed += HideQuitConfirm;

        SpawnOptionsPanel();

        Visible = false;
        _savedLabel.Visible = false;
    }

    // Esc while open always means Resume (inherited _UnhandledInput) — the nested OptionsPanel (a
    // child, processed before this node) already claims Esc for itself while it's visible, so the
    // inherited handler only ever fires when the pause menu's own buttons (main or confirm) are
    // what's showing. PauseMenu has no hotkey of its own (ToggleAction stays empty) — the host scene
    // opens it directly via Open() on a world-level Esc when no other modal is open.
    public void Open() => SetOpen(true);

    /// <summary>Opening resets the inline quit-confirm back to the main buttons and clears the
    /// "Saved." feedback label; closing also closes the nested OptionsPanel so it never lingers
    /// visible underneath a re-opened pause menu.</summary>
    protected override void SetOpen(bool open)
    {
        if (open && !Visible)
        {
            HideQuitConfirm();
            _savedLabel.Visible = false;
        }
        else if (!open && Visible)
        {
            _optionsPanel?.Close();
        }
        base.SetOpen(open);
    }

    private void SpawnOptionsPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/options_panel.tscn");
        if (scene == null)
            return;

        _optionsPanel = scene.Instantiate<OptionsPanel>();
        AddChild(_optionsPanel);
        _optionsPanel.Opened += () => _mainButtons.Visible = false;
        _optionsPanel.Closed += () => { if (Visible) _mainButtons.Visible = true; };
    }

    private void OnSavePressed()
    {
        SaveRequested?.Invoke();
        _savedLabel.Visible = true;
        GetTree().CreateTimer(SavedFeedbackSeconds).Timeout += () => _savedLabel.Visible = false;
    }

    private void OnOptionsPressed() => _optionsPanel?.Open();

    private void ShowQuitConfirm()
    {
        _mainButtons.Visible = false;
        _confirmButtons.Visible = true;
    }

    private void HideQuitConfirm()
    {
        _confirmButtons.Visible = false;
        _mainButtons.Visible = true;
    }

    private void OnSaveAndQuitPressed()
    {
        SaveRequested?.Invoke();
        QuitToTitleRequested?.Invoke();
    }

    private void OnQuitWithoutSavingPressed() => QuitToTitleRequested?.Invoke();
}
