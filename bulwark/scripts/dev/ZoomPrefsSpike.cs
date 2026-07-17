using Bulwark.Cozy;
using Godot;

using Bulwark.Settings;
namespace Bulwark.Dev;

/// <summary>
/// Headless spike for <see cref="ViewPreferences"/> persistence: defaults with no settings file,
/// zoom round-trip across a simulated restart (<c>ResetForReload</c> drops the cache so the next
/// access re-reads user://settings.json), setter and on-load clamping, and corrupt-file fallback.
/// Backs up and restores any real settings file so a dev's own preferences survive the run.
/// </summary>
public partial class ZoomPrefsSpike : SpikeBase
{
    private const string SettingsPath = ViewPreferences.SettingsPath;

    private bool _settingsExisted;
    private string _settingsBackup = string.Empty;

    public override void _Ready()
    {
        GD.Print("=== ZOOM PREFS SPIKE ===");
        BackupSettings();
        try
        {
            RunChecks();
        }
        catch (System.Exception e)
        {
            GD.PushError($"[ZoomPrefsSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSettings();
        }
        FinishAndQuit("ZoomPrefsSpike");
    }

    private void RunChecks()
    {
        // (1) No settings file -> defaults, nothing flagged as stored.
        DeleteSettings();
        ViewPreferences.ResetForReload();
        Check("(1) no file: cozy zoom defaults to 2.0", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, ViewPreferences.ZoomDefault));
        Check("(1) no file: combat distance defaults to 16", Mathf.IsEqualApprox(ViewPreferences.CombatCameraDistance, ViewPreferences.CombatDistanceDefault));
        Check("(1) no file: combat distance not flagged as stored", !ViewPreferences.HasStoredCombatCameraDistance);

        // (2) Cozy zoom mutations write the settings file immediately.
        ViewPreferences.ZoomIn();
        ViewPreferences.ZoomIn();
        Check("(2) ZoomIn x2 -> 2.5", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, 2.5f));
        Check("(2) settings.json written on change", Godot.FileAccess.FileExists(SettingsPath));

        // (3) Simulated restart -> cozy zoom survives; untouched combat distance stays unstored
        //     (so OrbitCameraRig keeps preferring its scene-authored InitialDistance).
        ViewPreferences.ResetForReload();
        Check("(3) cozy zoom survives reload", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, 2.5f));
        Check("(3) untouched combat distance still unstored after reload", !ViewPreferences.HasStoredCombatCameraDistance);

        // (4) Combat distance round-trips once set.
        ViewPreferences.CombatCameraDistance = 22.4f;
        ViewPreferences.ResetForReload();
        Check("(4) combat distance survives reload", Mathf.IsEqualApprox(ViewPreferences.CombatCameraDistance, 22.4f));
        Check("(4) combat distance flagged as stored", ViewPreferences.HasStoredCombatCameraDistance);
        Check("(4) cozy zoom unaffected by combat write", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, 2.5f));

        // (5) Setter clamps out-of-range values.
        ViewPreferences.CombatCameraDistance = 100f;
        Check("(5) setter clamps combat distance to max 30", Mathf.IsEqualApprox(ViewPreferences.CombatCameraDistance, ViewPreferences.CombatDistanceMax));

        // (6) Out-of-range values on disk clamp on load.
        WriteSettings("{\"cozyZoom\": 99.0, \"combatCameraDistance\": -5.0}");
        ViewPreferences.ResetForReload();
        Check("(6) disk cozy zoom clamps to max 4", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, ViewPreferences.ZoomMax));
        Check("(6) disk combat distance clamps to min 6", Mathf.IsEqualApprox(ViewPreferences.CombatCameraDistance, ViewPreferences.CombatDistanceMin));

        // (7) Corrupt file -> defaults, no throw.
        WriteSettings("this is not json {{{");
        ViewPreferences.ResetForReload();
        Check("(7) corrupt file: cozy zoom falls back to default", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, ViewPreferences.ZoomDefault));
        Check("(7) corrupt file: combat distance falls back to default", Mathf.IsEqualApprox(ViewPreferences.CombatCameraDistance, ViewPreferences.CombatDistanceDefault));
        Check("(7) corrupt file: combat distance not flagged as stored", !ViewPreferences.HasStoredCombatCameraDistance);

        // (8) A change after corruption rewrites a valid file that round-trips again.
        ViewPreferences.ZoomOut();
        ViewPreferences.ResetForReload();
        Check("(8) post-corruption save round-trips (1.75)", Mathf.IsEqualApprox(ViewPreferences.CozyZoom, 1.75f));
    }

    private void BackupSettings()
    {
        _settingsExisted = Godot.FileAccess.FileExists(SettingsPath);
        if (!_settingsExisted) return;
        using var file = Godot.FileAccess.Open(SettingsPath, Godot.FileAccess.ModeFlags.Read);
        if (file != null) _settingsBackup = file.GetAsText();
    }

    private void RestoreSettings()
    {
        if (_settingsExisted)
            WriteSettings(_settingsBackup);
        else
            DeleteSettings();
        ViewPreferences.ResetForReload();
    }

    private static void WriteSettings(string text)
    {
        using var file = Godot.FileAccess.Open(SettingsPath, Godot.FileAccess.ModeFlags.Write);
        file?.StoreString(text);
    }

    private static void DeleteSettings()
    {
        if (Godot.FileAccess.FileExists(SettingsPath))
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SettingsPath));
    }
}
