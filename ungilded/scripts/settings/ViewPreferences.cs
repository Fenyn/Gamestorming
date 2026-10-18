using System.Collections.Generic;

namespace Ungilded.Settings;

/// <summary>Which camera a remembered zoom belongs to: combat and exploration keep their own.</summary>
public enum CameraZoomSlot { Combat, Exploration }

/// <summary>
/// In-memory camera preference store. Each camera's zoom distance survives within a session;
/// nothing is written to disk. Grow into a real settings store when the meta-layer needs one.
/// </summary>
public static class ViewPreferences
{
    private static readonly Dictionary<CameraZoomSlot, float> Distances = new();

    /// <summary>The last zoom distance the player chose on this camera this session, if any.</summary>
    public static bool TryGetCameraDistance(CameraZoomSlot slot, out float distance)
        => Distances.TryGetValue(slot, out distance);

    public static void SetCameraDistance(CameraZoomSlot slot, float distance) => Distances[slot] = distance;
}
