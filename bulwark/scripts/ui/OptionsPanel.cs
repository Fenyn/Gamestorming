using System;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Reusable options modal (CanvasLayer, same modal pattern as SquadPanel/QuestPanel): master/music/
/// sfx volume sliders and a fullscreen toggle. Instanced from both the title screen and the pause
/// menu — this is the sanctioned exception to "UI never mutates state" (per CLAUDE.md/design brief):
/// settings are presentation, not game state, so the panel reads and writes
/// <see cref="ViewPreferences"/> + <see cref="SettingsApplier"/> directly instead of raising intent
/// events for a host to forward. Esc (or the Close button) closes it; <see cref="Opened"/>/
/// <see cref="Closed"/> let a host (the pause menu) coordinate its own visibility around it.
/// </summary>
public partial class OptionsPanel : CanvasLayer
{
    public event Action? Opened;
    public event Action? Closed;

    private HSlider _masterSlider = null!;
    private HSlider _musicSlider = null!;
    private HSlider _sfxSlider = null!;
    private CheckButton _fullscreenCheck = null!;
    private Button _closeButton = null!;

    /// <summary>Guards the load-current-values-into-controls step so setting slider.Value doesn't
    /// immediately bounce back through ValueChanged and re-persist the value it just loaded.</summary>
    private bool _loading;

    public override void _Ready()
    {
        _masterSlider = GetNode<HSlider>("%MasterSlider");
        _musicSlider = GetNode<HSlider>("%MusicSlider");
        _sfxSlider = GetNode<HSlider>("%SfxSlider");
        _fullscreenCheck = GetNode<CheckButton>("%FullscreenCheck");
        _closeButton = GetNode<Button>("%CloseButton");

        _masterSlider.ValueChanged += OnMasterChanged;
        _musicSlider.ValueChanged += OnMusicChanged;
        _sfxSlider.ValueChanged += OnSfxChanged;
        _fullscreenCheck.Toggled += OnFullscreenToggled;
        _closeButton.Pressed += Close;

        Visible = false;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            Close();
            GetViewport().SetInputAsHandled();
        }
    }

    /// <summary>Load the current persisted values into the controls, then show. Loading is guarded
    /// so pushing values into the sliders/checkbox doesn't re-fire the change handlers.</summary>
    public void Open()
    {
        if (Visible)
            return;

        _loading = true;
        _masterSlider.Value = ViewPreferences.MasterVolume;
        _musicSlider.Value = ViewPreferences.MusicVolume;
        _sfxSlider.Value = ViewPreferences.SfxVolume;
        _fullscreenCheck.ButtonPressed = ViewPreferences.Fullscreen;
        _loading = false;

        Visible = true;
        Opened?.Invoke();
    }

    public void Close()
    {
        if (!Visible)
            return;
        Visible = false;
        Closed?.Invoke();
    }

    private void OnMasterChanged(double value)
    {
        if (_loading)
            return;
        float v = (float)value;
        ViewPreferences.MasterVolume = v;
        SettingsApplier.ApplyMasterVolume(v);
    }

    private void OnMusicChanged(double value)
    {
        if (_loading)
            return;
        float v = (float)value;
        ViewPreferences.MusicVolume = v;
        SettingsApplier.ApplyMusicVolume(v);
    }

    private void OnSfxChanged(double value)
    {
        if (_loading)
            return;
        float v = (float)value;
        ViewPreferences.SfxVolume = v;
        SettingsApplier.ApplySfxVolume(v);
    }

    private void OnFullscreenToggled(bool pressed)
    {
        if (_loading)
            return;
        ViewPreferences.Fullscreen = pressed;
        SettingsApplier.ApplyFullscreen(pressed);
    }
}
