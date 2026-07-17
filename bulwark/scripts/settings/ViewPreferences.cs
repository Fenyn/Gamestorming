using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;

namespace Bulwark.Settings;

/// <summary>
/// Player view preferences (cozy overworld zoom + combat camera distance). Plain static C# —
/// deliberately NOT part of <see cref="Bulwark.Autoload.GameState"/> or the save file: camera zoom
/// is presentation, not world state. Instead it persists to <c>user://settings.json</c> (tiny
/// camelCase JSON, e.g. <c>{"cozyZoom":2.5,"combatCameraDistance":16.0}</c>): lazily loaded on
/// first access, rewritten on every change. A missing or corrupt file silently falls back to
/// defaults, and loaded values are clamped to the valid ranges — preference I/O must never break
/// the game. The HUD raises zoom intents, the world scene mutates this and applies it to the
/// player Camera2D; <see cref="Bulwark.Combat.OrbitCameraRig"/> reads/writes the combat distance.
/// </summary>
public static class ViewPreferences
{
    public const string SettingsPath = "user://settings.json";

    public const float ZoomMin = 1.0f;
    public const float ZoomMax = 4.0f;
    public const float ZoomStep = 0.25f;
    public const float ZoomDefault = 2.0f;

    public const float CombatDistanceMin = 6.0f;
    public const float CombatDistanceMax = 30.0f;
    public const float CombatDistanceDefault = 16.0f;

    public const float VolumeMin = 0.0f;
    public const float VolumeMax = 1.0f;
    public const float VolumeDefault = 1.0f;

    public const bool FullscreenDefault = false;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = true,
    };

    private static bool _loaded;
    private static float _cozyZoom = ZoomDefault;
    private static float _combatCameraDistance = CombatDistanceDefault;
    private static bool _combatDistanceStored;
    private static float _masterVolume = VolumeDefault;
    private static float _musicVolume = VolumeDefault;
    private static float _sfxVolume = VolumeDefault;
    private static bool _fullscreen = FullscreenDefault;

    /// <summary>Current cozy camera zoom (Godot 4 semantics: 2 = twice as close as 1).</summary>
    public static float CozyZoom
    {
        get
        {
            EnsureLoaded();
            return _cozyZoom;
        }
    }

    public static void ZoomIn() => SetCozyZoom(CozyZoom + ZoomStep);

    public static void ZoomOut() => SetCozyZoom(CozyZoom - ZoomStep);

    /// <summary>
    /// Preferred combat orbit-camera distance. Setter clamps to
    /// [<see cref="CombatDistanceMin"/>, <see cref="CombatDistanceMax"/>] and persists immediately.
    /// Until the player has ever zoomed in combat (<see cref="HasStoredCombatCameraDistance"/> is
    /// false) this is just the default and the rig's scene-authored InitialDistance should win.
    /// </summary>
    public static float CombatCameraDistance
    {
        get
        {
            EnsureLoaded();
            return _combatCameraDistance;
        }
        set
        {
            EnsureLoaded();
            _combatCameraDistance = Math.Clamp(value, CombatDistanceMin, CombatDistanceMax);
            _combatDistanceStored = true;
            Save();
        }
    }

    /// <summary>
    /// True once a combat camera distance exists in the settings file (loaded or set this session).
    /// While false, <see cref="Bulwark.Combat.OrbitCameraRig"/> keeps its scene-authored default.
    /// </summary>
    public static bool HasStoredCombatCameraDistance
    {
        get
        {
            EnsureLoaded();
            return _combatDistanceStored;
        }
    }

    /// <summary>Master output volume (0..1, linear). Setter clamps and persists immediately.</summary>
    public static float MasterVolume
    {
        get { EnsureLoaded(); return _masterVolume; }
        set { EnsureLoaded(); _masterVolume = Math.Clamp(value, VolumeMin, VolumeMax); Save(); }
    }

    /// <summary>Music bus volume (0..1, linear). Setter clamps and persists immediately.</summary>
    public static float MusicVolume
    {
        get { EnsureLoaded(); return _musicVolume; }
        set { EnsureLoaded(); _musicVolume = Math.Clamp(value, VolumeMin, VolumeMax); Save(); }
    }

    /// <summary>Sfx bus volume (0..1, linear). Setter clamps and persists immediately.</summary>
    public static float SfxVolume
    {
        get { EnsureLoaded(); return _sfxVolume; }
        set { EnsureLoaded(); _sfxVolume = Math.Clamp(value, VolumeMin, VolumeMax); Save(); }
    }

    /// <summary>Preferred window mode. Setter persists immediately.</summary>
    public static bool Fullscreen
    {
        get { EnsureLoaded(); return _fullscreen; }
        set { EnsureLoaded(); _fullscreen = value; Save(); }
    }

    /// <summary>Test hook: drop all cached state so the next access re-reads the settings file,
    /// simulating a game restart. Spikes only — gameplay code never needs this.</summary>
    internal static void ResetForReload()
    {
        _loaded = false;
        _cozyZoom = ZoomDefault;
        _combatCameraDistance = CombatDistanceDefault;
        _combatDistanceStored = false;
        _masterVolume = VolumeDefault;
        _musicVolume = VolumeDefault;
        _sfxVolume = VolumeDefault;
        _fullscreen = FullscreenDefault;
    }

    private static void SetCozyZoom(float value)
    {
        _cozyZoom = Math.Clamp(value, ZoomMin, ZoomMax);
        Save();
    }

    private static void EnsureLoaded()
    {
        if (_loaded) return;
        _loaded = true;

        try
        {
            if (!Godot.FileAccess.FileExists(SettingsPath)) return;
            using var file = Godot.FileAccess.Open(SettingsPath, Godot.FileAccess.ModeFlags.Read);
            if (file == null) return;

            var dto = JsonSerializer.Deserialize<SettingsDto>(file.GetAsText(), JsonOptions);
            if (dto == null) return;

            if (dto.CozyZoom is float zoom && float.IsFinite(zoom))
                _cozyZoom = Math.Clamp(zoom, ZoomMin, ZoomMax);
            if (dto.CombatCameraDistance is float distance && float.IsFinite(distance))
            {
                _combatCameraDistance = Math.Clamp(distance, CombatDistanceMin, CombatDistanceMax);
                _combatDistanceStored = true;
            }
            if (dto.MasterVolume is float mv && float.IsFinite(mv))
                _masterVolume = Math.Clamp(mv, VolumeMin, VolumeMax);
            if (dto.MusicVolume is float muv && float.IsFinite(muv))
                _musicVolume = Math.Clamp(muv, VolumeMin, VolumeMax);
            if (dto.SfxVolume is float sv && float.IsFinite(sv))
                _sfxVolume = Math.Clamp(sv, VolumeMin, VolumeMax);
            if (dto.Fullscreen is bool fs)
                _fullscreen = fs;
        }
        catch (Exception)
        {
            // Corrupt/unreadable settings file: keep defaults, never throw into gameplay.
            _cozyZoom = ZoomDefault;
            _combatCameraDistance = CombatDistanceDefault;
            _combatDistanceStored = false;
            _masterVolume = VolumeDefault;
            _musicVolume = VolumeDefault;
            _sfxVolume = VolumeDefault;
            _fullscreen = FullscreenDefault;
        }
    }

    private static void Save()
    {
        try
        {
            using var file = Godot.FileAccess.Open(SettingsPath, Godot.FileAccess.ModeFlags.Write);
            if (file == null)
            {
                GD.PushWarning($"[ViewPreferences] Could not open {SettingsPath} for writing: {Godot.FileAccess.GetOpenError()}");
                return;
            }

            var dto = new SettingsDto
            {
                CozyZoom = _cozyZoom,
                // Omit the combat distance until the player has actually zoomed in combat so the
                // rig's scene-authored InitialDistance keeps winning on fresh installs.
                CombatCameraDistance = _combatDistanceStored ? _combatCameraDistance : null,
                MasterVolume = _masterVolume,
                MusicVolume = _musicVolume,
                SfxVolume = _sfxVolume,
                Fullscreen = _fullscreen,
            };
            file.StoreString(JsonSerializer.Serialize(dto, JsonOptions));
        }
        catch (Exception e)
        {
            GD.PushWarning($"[ViewPreferences] Failed to save settings: {e.Message}");
        }
    }

    /// <summary>Shape of user://settings.json. Nullable so absent keys are distinguishable.</summary>
    private sealed class SettingsDto
    {
        public float? CozyZoom { get; set; }
        public float? CombatCameraDistance { get; set; }
        public float? MasterVolume { get; set; }
        public float? MusicVolume { get; set; }
        public float? SfxVolume { get; set; }
        public bool? Fullscreen { get; set; }
    }
}
