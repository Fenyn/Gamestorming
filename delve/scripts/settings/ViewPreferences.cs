namespace Delve.Settings;

/// <summary>
/// In-memory camera preference stub for the combat proof. bulwark persists these to
/// user://settings.json; here the zoom distance only survives within a session. Grow into a real
/// settings store when the meta-layer needs one.
/// </summary>
public static class ViewPreferences
{
    private static float _combatCameraDistance;

    /// <summary>True once combat has stored a camera distance this session.</summary>
    public static bool HasStoredCombatCameraDistance { get; private set; }

    /// <summary>Last combat camera zoom distance. Writing marks it as stored.</summary>
    public static float CombatCameraDistance
    {
        get => _combatCameraDistance;
        set
        {
            _combatCameraDistance = value;
            HasStoredCombatCameraDistance = true;
        }
    }
}
