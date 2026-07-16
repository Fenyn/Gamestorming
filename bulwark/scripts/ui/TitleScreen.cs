using System;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Boot title screen: game title, subtitle, menu buttons (New Game / Continue / Options).
/// Passive UI — raises intent events, never touches GameState. The boot flow wires the
/// events to SceneRouter transitions.
/// </summary>
public partial class TitleScreen : Control
{
    public event Action? NewGameRequested;
    public event Action? ContinueRequested;
    public event Action? OptionsRequested;

    private Button _newGame = null!;
    private Button _continue = null!;
    private Button _options = null!;
    private Label _toast = null!;
    private OptionsPanel? _optionsPanel;

    public override void _Ready()
    {
        _newGame = GetNode<Button>("%NewGameButton");
        _continue = GetNode<Button>("%ContinueButton");
        _options = GetNode<Button>("%OptionsButton");
        _toast = GetNode<Label>("%ToastLabel");

        _newGame.Pressed += () => NewGameRequested?.Invoke();
        _continue.Pressed += () => ContinueRequested?.Invoke();
        _options.Pressed += OnOptionsPressed;

        _toast.Visible = false;

        SpawnOptionsPanel();
    }

    /// <summary>Show or hide the Continue button based on whether a save exists.</summary>
    public void SetContinueVisible(bool visible) => _continue.Visible = visible;

    /// <summary>True while the shared options modal is showing. Test seam.</summary>
    public bool IsOptionsPanelOpen => _optionsPanel?.Visible ?? false;

    private void SpawnOptionsPanel()
    {
        var scene = GD.Load<PackedScene>("res://scenes/ui/options_panel.tscn");
        if (scene == null)
            return;

        _optionsPanel = scene.Instantiate<OptionsPanel>();
        AddChild(_optionsPanel);
    }

    private void OnOptionsPressed()
    {
        OptionsRequested?.Invoke();
        _optionsPanel?.Open();
    }
}
