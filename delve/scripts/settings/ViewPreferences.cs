namespace Delve.Settings;

/// <summary>
/// In-memory camera preference store for the combat proof. The zoom distance only survives within a
/// session; nothing is written to disk. Grow into a real settings store when the meta-layer needs one.
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
