using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Applies persisted <see cref="ViewPreferences"/> values to the engine: the three audio bus
/// volumes (Master/Music/Sfx, declared in <c>res://default_bus_layout.tres</c>) and the window
/// fullscreen mode. Pure engine-facing glue — no state of its own. Defensive by design: bus lookups
/// return -1 when a bus is missing (headless dev spikes run with no audio buses loaded) and are
/// skipped rather than throwing; window-mode changes are similarly harmless when no display server
/// is present. Call <see cref="ApplyAll"/> once at boot; the options panel calls the individual
/// appliers live as the player drags a slider / flips the checkbox.
/// </summary>
public static class SettingsApplier
{
    /// <summary>Apply every persisted setting (boot-time call site: BootScene._Ready).</summary>
    public static void ApplyAll()
    {
        ApplyMasterVolume(ViewPreferences.MasterVolume);
        ApplyMusicVolume(ViewPreferences.MusicVolume);
        ApplySfxVolume(ViewPreferences.SfxVolume);
        ApplyFullscreen(ViewPreferences.Fullscreen);
    }

    public static void ApplyMasterVolume(float volume) => ApplyBusVolume("Master", volume);

    public static void ApplyMusicVolume(float volume) => ApplyBusVolume("Music", volume);

    public static void ApplySfxVolume(float volume) => ApplyBusVolume("Sfx", volume);

    /// <summary>Switch the window between fullscreen and windowed. No-op (harmless) when there is
    /// no real display server backing the process, e.g. headless dev spikes.</summary>
    public static void ApplyFullscreen(bool fullscreen)
    {
        DisplayServer.WindowSetMode(fullscreen
            ? DisplayServer.WindowMode.Fullscreen
            : DisplayServer.WindowMode.Windowed);
    }

    /// <summary>Linear 0..1 volume -> bus dB + mute flag. Skips silently if the named bus isn't
    /// loaded (e.g. a headless run with no audio bus layout).</summary>
    private static void ApplyBusVolume(string busName, float volume)
    {
        int idx = AudioServer.GetBusIndex(busName);
        if (idx < 0)
            return;

        bool mute = volume <= 0.001f;
        AudioServer.SetBusMute(idx, mute);
        if (!mute)
            AudioServer.SetBusVolumeDb(idx, Mathf.LinearToDb(volume));
    }
}
